import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'market_data_service.dart';

// ─────────────────────────────────────────────────────────────
// AI RESPONSE MODEL
// ─────────────────────────────────────────────────────────────

/// Structured response from any Gemini/Gemma model call.
class AiResponse {
  final String text;
  final List<Map<String, String>>? sources;
  final String? modelName;
  final int? tokenCount;

  const AiResponse({
    required this.text,
    this.sources,
    this.modelName,
    this.tokenCount,
  });
}

// ─────────────────────────────────────────────────────────────
// CUSTOM EXCEPTIONS
// ─────────────────────────────────────────────────────────────

/// Thrown when all API keys have been exhausted (429 / quota).
class AiQuotaException implements Exception {
  final String message;
  const AiQuotaException(this.message);
  @override
  String toString() => 'AiQuotaException: $message';
}

/// Thrown on Gemini server-side errors (500, 503).
class AiServerException implements Exception {
  final String message;
  const AiServerException(this.message);
  @override
  String toString() => 'AiServerException: $message';
}

/// Thrown on any other API / network error.
class AiException implements Exception {
  final String message;
  const AiException(this.message);
  @override
  String toString() => 'AiException: $message';
}

// ─────────────────────────────────────────────────────────────
// ONYX AI ROUTER SERVICE
// ─────────────────────────────────────────────────────────────
//
// Intelligent model router that maps each task type to the
// optimal Gemini / Gemma model for speed, accuracy, and cost.
//
// Usage:
//   final router = OnyxAiRouterService();
//   final res = await router.sendChatMessage('What is RSI?');
//   print(res.text);
// ─────────────────────────────────────────────────────────────

class OnyxAiRouterService {
  // ── Singleton ─────────────────────────────────────────────
  static final OnyxAiRouterService _instance = OnyxAiRouterService._internal();
  factory OnyxAiRouterService() => _instance;

  OnyxAiRouterService._internal() {
    _loadApiKeys();
  }

  // ── Model Constants ───────────────────────────────────────
  // Each constant maps to a specific Google AI model optimized
  // for a particular task type within the ONYX ecosystem.

  /// Fast general-purpose chat — Gemini 2.5 Flash
  static const String _chatModel = 'models/gemini-2.5-flash';

  /// Deep stock / financial analysis — Gemini 3.1 Flash Preview
  static const String _analysisModel = 'models/gemini-3.1-flash-preview';

  /// Structured data extraction (JSON) — Gemma 4 31B Instruct
  static const String _dataModel = 'models/gemma-4-31b-it';

  /// Lightweight sentiment classification — Gemini 2.5 Flash Lite
  static const String _scannerModel = 'models/gemini-2.5-flash-lite';

  /// Concise summarization — Gemini 3.1 Flash Lite Preview
  static const String _summaryModel = 'models/gemini-3.1-flash-lite-preview';

  static const String _routerPrompt = '''You are the Router for the ONYX financial system. Your job is to classify the user's intent. Read the user's message and strictly output a JSON object. Do NOT output any other text. Rules:
1. General question/greeting -> {"intent": "general_chat", "reply": "Your response in Arabic"}
2. Needs financial analysis, recommendations, or mentions a stock -> {"intent": "call_expert", "stock_symbol": "SYMBOL_OR_NULL"}''';

  static const String _nemotronExpertPrompt = '''[SYSTEM PERSONA & RULES]
You are ONYX, an elite AI financial analyst for the EGX. You receive data inside <MARKET_DATA>, <MARKET_NEWS>, and <USER_PORTFOLIO>.
1. NO HALLUCINATION: Base analysis ONLY on context. Do not invent indicators.
2. STRICT RISK MANAGEMENT: Every trade MUST have an exit strategy. Buy orders MUST use the provided 'Resistance' as Target Price (TP) and 'Support' as Stop-Loss (SL).
3. NO MATH: Read Portfolio values as provided. Calculate shares strictly as (Amount/Price).
[STRICT OUTPUT FORMATTING - TEXT BLOCKS ONLY]
NO Markdown tables. Answer precisely:
نظرة عامة:
• وضع السوق: [1 sentence]
• حالة المحفظة: [1 sentence]

أوامر التداول والتخصيص:
**[Stock Symbol] - [Action: شراء/بيع/احتفاظ]**
• السعر اللحظي: [Price] ج.م
• الكمية المقترحة: [Number] سهم (بإجمالي [Amount] ج.م تقريباً)
• الهدف وإيقاف الخسارة: هدف [Resistance] / إيقاف [Support]
• التبرير: [1 sentence logic]''';

  // ── API Key Management ────────────────────────────────────

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  late List<String> _apiKeys;
  int _currentKeyIndex = 0;

  /// Returns true if at least one valid API key is loaded.
  bool get hasValidKeys =>
      _apiKeys.isNotEmpty && _apiKeys.first.isNotEmpty;

  /// Loads all non-empty GEMINI_API_KEY_* values from the .env file.
  void _loadApiKeys() {
    _apiKeys = [
      dotenv.env['GEMINI_API_KEY_1'] ?? '',
      dotenv.env['GEMINI_API_KEY_2'] ?? '',
      dotenv.env['GEMINI_API_KEY_3'] ?? '',
      dotenv.env['GEMINI_API_KEY_4'] ?? '',
      dotenv.env['GEMINI_API_KEY_5'] ?? '',
    ].where((k) => k.isNotEmpty && !k.contains('YOUR_')).toList();

    debugPrint(
        '🤖 OnyxAiRouter: Loaded ${_apiKeys.length} valid API keys.');

    if (_apiKeys.isEmpty) {
      debugPrint('⚠️ OnyxAiRouter: No API keys found in .env!');
      _apiKeys = ['']; // Prevent index errors; calls will fail gracefully.
    }
  }

  /// Rotates to the next API key. Returns false if all keys exhausted.
  bool _rotateKey() {
    if (_currentKeyIndex < _apiKeys.length - 1) {
      _currentKeyIndex++;
      debugPrint(
          '🔄 OnyxAiRouter: Rotated to key index $_currentKeyIndex');
      return true;
    }
    return false;
  }

  /// Resets key index back to 0 (called after a successful response
  /// or at the start of a new top-level request).
  void _resetKeyIndex() {
    _currentKeyIndex = 0;
  }

  // ─────────────────────────────────────────────────────────
  // PUBLIC API — Task-Specific Methods
  // ─────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _detectIntent(String userMessage) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': _routerPrompt}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': userMessage}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      },
    };

    try {
      final response = await _callModelWithRetry(_chatModel, body);
      var text = response.text.trim();
      if (text.startsWith('```json')) {
        text = text.replaceAll('```json', '').replaceAll('```', '').trim();
      }
      return json.decode(text);
    } catch (e) {
      debugPrint('Intent parsing failed: $e');
      return {'intent': 'general_chat', 'reply': 'عذراً، لم أفهم طلبك. هل تسأل عن سهم معين؟'};
    }
  }

  Future<String> _callNemotronDeepAnalysis(String contextData, String userMessage) async {
    final apiKey = dotenv.env['OPENROUTER_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return "Missing OpenRouter API Key in .env file.";
    }

    try {
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': 'nvidia/nemotron-3-super-120b-a12b:free',
          'temperature': 0.2,
          'messages': [
            {'role': 'system', 'content': _nemotronExpertPrompt},
            {'role': 'user', 'content': '$contextData\n\nUser Question: $userMessage'}
          ]
        }),
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content ?? 'No analysis returned.';
      } else {
        throw 'OpenRouter API Error: \${response.statusCode} - \${response.body}';
      }
    } catch (e) {
      debugPrint('Nemotron deep analysis error: \$e');
      throw const AiException('فشل في الاتصال بمحلل السوق العميق: \$e');
    }
  }

  /// **Main Orchestrator** 
  Future<AiResponse> sendMessage(
      String userMessage, {
      required MarketDataService marketDataService,
      required String portfolioData,
  }) async {
    try {
      final intentJson = await _detectIntent(userMessage);
      final intent = intentJson['intent'] ?? 'general_chat';

      if (intent == 'general_chat') {
        final reply = intentJson['reply'] ?? 'أهلاً بك!';
        return AiResponse(text: reply, modelName: 'Gemini Router');
      } else if (intent == 'call_expert') {
        final stockSymbol = intentJson['stock_symbol'];
        
        String marketData = '';
        if (stockSymbol != null && stockSymbol != 'SYMBOL_OR_NULL' && stockSymbol.toString().isNotEmpty) {
          marketData = marketDataService.buildMarketDataContext(stockSymbol); // returns <MARKET_DATA_INTERNAL>
        }
        if (marketData.isEmpty) {
           marketData = '<MARKET_DATA>\n${marketDataService.generateOptimizedMarketScan()}\n</MARKET_DATA>';
        } else {
           marketData = marketData.replaceAll('MARKET_DATA_INTERNAL', 'MARKET_DATA');
        }

        final marketNews = '<MARKET_NEWS>\n${marketDataService.news.join("\\n")}\n</MARKET_NEWS>';
        final userPortContext = '<USER_PORTFOLIO>\n$portfolioData\n</USER_PORTFOLIO>';

        final contextData = '$marketData\n$marketNews\n$userPortContext';

        final nemotronRes = await _callNemotronDeepAnalysis(contextData, userMessage);
        return AiResponse(text: nemotronRes, modelName: 'Nvidia Nemotron');
      }
      
      return const AiResponse(text: 'عذراً لا استطيع الخدمة الان', modelName: 'System');
    } catch (e) {
      if (e is AiQuotaException || e is AiServerException || e is AiException) {
        rethrow;
      }
      debugPrint('sendMessage Orchestrator Error: $e');
      throw AiException('حدث خطأ أثناء المعالجة: $e');
    }
  }

  /// **General Chat** — Uses [_chatModel] (Gemini 2.5 Flash).
  ///
  /// Designed for the main ChatScreen. Supports full conversation
  /// history and Google Search grounding for real-time data.
  ///
  /// [prompt] — The user's latest message (used when no history).
  /// [systemInstruction] — Optional system prompt (e.g. ONYX persona).
  /// [conversationHistory] — Optional list of prior messages in
  ///   Gemini `contents` format. If provided, [prompt] is ignored
  ///   (assumed already included in history).
  /// [enableGrounding] — Whether to enable Google Search tool.
  Future<AiResponse> sendChatMessage(
    String prompt, {
    String? systemInstruction,
    List<Map<String, dynamic>>? conversationHistory,
    bool enableGrounding = false,
    String? localMarketData,
  }) async {
    String ragContext = '';
    if (enableGrounding) {
      ragContext = await _fetchMarketContext(prompt);
    }

    // Build contents: use history if provided, else wrap prompt.
    var contents = conversationHistory ??
        [
          {
            'role': 'user',
            'parts': [
              {'text': prompt}
            ]
          }
        ];

    // Inject market data and RAG context invisibly into the latest user message
    if (contents.isNotEmpty && contents.last['role'] == 'user') {
      // Deep clone to prevent mutating the caller's history reference
      final newContents = List<Map<String, dynamic>>.from(contents);
      final lastMsg = Map<String, dynamic>.from(newContents.last);
      final parts = List<Map<String, dynamic>>.from(lastMsg['parts']);
      final part = Map<String, dynamic>.from(parts[0]);

      String originalText = part['text'];
      String modifiedText = originalText;

      if (localMarketData != null && localMarketData.isNotEmpty) {
        modifiedText = "<MARKET_DATA_INTERNAL>\n$localMarketData\n</MARKET_DATA_INTERNAL>\n\nUser Question: $modifiedText";
      }

      if (ragContext.isNotEmpty) {
        modifiedText = "Context: $ragContext\n\nUser Question: $modifiedText";
      }
      
      part['text'] = modifiedText;

      parts[0] = part;
      lastMsg['parts'] = parts;
      newContents[newContents.length - 1] = lastMsg;
      contents = newContents;
    }

    // ── Sliding Window ──────────────────────────────────────
    // Limit history to the last 6 messages (≈ 3 user + 3 model)
    // to minimize TPM quota usage, especially critical when
    // Google Search grounding is enabled.
    const int maxHistoryMessages = 6;
    if (contents.length > maxHistoryMessages) {
      contents = contents.sublist(contents.length - maxHistoryMessages);
      debugPrint(
          '✂️ OnyxAiRouter: Trimmed history to last $maxHistoryMessages messages');
    }

    final body = <String, dynamic>{
      'contents': contents,
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 4096,
      },
    };

    if (systemInstruction != null) {
      body['systemInstruction'] = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    return _callModelWithRetry(_chatModel, body);
  }

  /// **Deep Stock Analysis** — Uses [_analysisModel] (Gemini 3.1 Flash).
  ///
  /// Triggered when the user explicitly asks for a stock deep-dive
  /// (e.g. "Analyze CIB", "حلل فوري"). Uses a more capable model
  /// for nuanced financial analysis.
  ///
  /// [stockData] — Formatted string containing ticker, price, RSI,
  ///   MACD, and any additional market context.
  /// [systemInstruction] — Optional override; defaults to a built-in
  ///   expert analyst persona.
  /// [conversationHistory] — Optional chat history for context.
  Future<AiResponse> analyzeStock(
    String stockData, {
    String? systemInstruction,
    List<Map<String, dynamic>>? conversationHistory,
  }) async {
    final sysPrompt = systemInstruction ??
        "You are an elite financial analyst specializing in the Egyptian Exchange (EGX). "
            "Analyze the provided stock data with extreme precision and depth.\n"
            "Focus on: Price action, RSI levels, MACD signals, support/resistance levels, "
            "volume trends, and provide clear actionable recommendations (BUY / HOLD / SELL).\n"
            "Use clean Markdown formatting with emojis 📊📈🎯💰 for readability.\n"
            "Be direct, confident, and speak like a senior Egyptian trader. Zero disclaimers.";

    final contents = conversationHistory ??
        [
          {
            'role': 'user',
            'parts': [
              {'text': stockData}
            ]
          }
        ];

    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': sysPrompt}
        ]
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.5,
        'maxOutputTokens': 4096,
      },
    };

    return _callModelWithRetry(_analysisModel, body);
  }

  /// **JSON Data Extraction** — Uses [_dataModel] (Gemma 4 31B-IT).
  ///
  /// Parses raw news headlines, reports, or unstructured text into
  /// structured JSON. Enforces JSON-only output via responseMimeType.
  ///
  /// [text] — The raw text to parse into structured data.
  Future<AiResponse> extractJsonData(String text) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {
            'text':
                "You are a data extraction service. Parse the provided text and "
                    "return ONLY valid JSON. No explanations, no markdown code fences, "
                    "no text before or after the JSON object. The output must be a single "
                    "valid JSON object or array."
          }
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': text}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      },
    };

    return _callModelWithRetry(_dataModel, body);
  }

  /// **Sentiment Analysis** — Uses [_scannerModel] (Gemini 2.5 Flash Lite).
  ///
  /// Lightweight, fast classification of a news headline's sentiment.
  /// Returns exactly one word: "Positive", "Negative", or "Neutral".
  ///
  /// [headline] — The news headline or short text to classify.
  Future<AiResponse> analyzeSentiment(String headline) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {
            'text':
                "You are a sentiment classification engine for financial news. "
                    "Analyze the sentiment of the provided headline and respond with "
                    "EXACTLY one word: Positive, Negative, or Neutral. "
                    "No explanations, no punctuation, no extra text."
          }
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': headline}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.0,
      },
    };

    return _callModelWithRetry(_scannerModel, body);
  }

  /// **Report Summarization** — Uses [_summaryModel] (Gemini 3.1 Flash Lite).
  ///
  /// Takes a long market report or article and distills it into a
  /// concise 3-bullet-point summary.
  ///
  /// [longText] — The full report text to summarize.
  Future<AiResponse> summarizeReport(String longText) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {
            'text':
                "You are a financial report summarizer. Summarize the provided text "
                    "into exactly 3 concise bullet points. Focus on the most impactful "
                    "and actionable information. Use clean Markdown bullet formatting. "
                    "Be extremely brief and direct. No introductions, no conclusions."
          }
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': longText}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
      },
    };

    return _callModelWithRetry(_summaryModel, body);
  }

  // ─────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────
  // TAVILY RAG FETCH ENGINE
  // ─────────────────────────────────────────────────────────

  Future<String> _fetchMarketContext(String userQuery) async {
    final apiKey = dotenv.env['TAVILY_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) return '';

    try {
      final response = await http
          .post(
            Uri.parse('https://api.tavily.com/search'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'api_key': apiKey,
              'query': '$userQuery البورصة المصرية EGX',
              'search_depth': 'basic',
              'include_answer': true,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String fetchResult = data['answer'] ?? '';
        return fetchResult.length > 1500
            ? '${fetchResult.substring(0, 1500)}...'
            : fetchResult;
      }
    } catch (e) {
      debugPrint('⚠️ Tavily RAG Error: $e');
    }
    return '';
  }

  // ─────────────────────────────────────────────────────────
  // CORE HTTP ENGINE
  // ─────────────────────────────────────────────────────────

  /// Makes the API call with automatic key rotation on quota errors.
  ///
  /// Tries each API key sequentially. If all keys return 429/quota,
  /// throws [AiQuotaException]. Server errors throw [AiServerException].
  /// All other errors throw [AiException].
  Future<AiResponse> _callModelWithRetry(
    String model,
    Map<String, dynamic> body,
  ) async {
    _resetKeyIndex();
    int attempts = 0;

    while (attempts < _apiKeys.length) {
      try {
        return await _executeRequest(model, body);
      } catch (e) {
        debugPrint('Raw API Error: ${e.toString()}');
        attempts++;
        debugPrint('Key $_currentKeyIndex failed, switching to next key... (attempt $attempts/${_apiKeys.length})');

        if (!_rotateKey()) {
          // All keys exhausted. Throw to UI based on the last error encountered.
          final errorStr = e.toString();
          if (_isQuotaError(errorStr)) {
            throw const AiQuotaException(
              'All API keys have reached their quota. '
              'Please try again in a few minutes.',
            );
          } else if (_isServerError(errorStr)) {
            throw AiServerException(
              'Google servers are currently overloaded. '
              'Please try again in a moment. ($errorStr)',
            );
          } else {
            throw AiException(
              'An error occurred while communicating with the AI. ($errorStr)',
            );
          }
        }
        // Key rotated successfully, the while loop will now retry _executeRequest
        // Note: Because we use the direct REST API via HTTP, we do not need to
        // "re-instantiate" any GenerativeModel objects. The new key is cleanly
        // injected into the URL on the next loop iteration. Tools are in the JSON body.
      }
    }

    // Should not reach here, but safeguard
    throw const AiQuotaException('All API keys exhausted.');
  }

  /// Executes a single HTTP POST to the Gemini REST API.
  Future<AiResponse> _executeRequest(
    String model,
    Map<String, dynamic> body,
  ) async {
    final apiKey = _apiKeys[_currentKeyIndex];
    final url = '$_baseUrl/$model:generateContent?key=$apiKey';

    debugPrint('🤖 OnyxAiRouter: Calling $model (key $_currentKeyIndex)');

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      return _parseResponse(response.body, model);
    } else {
      throw 'Gemini API Error [${response.statusCode}]: '
          '${response.body.length > 200 ? response.body.substring(0, 200) : response.body}';
    }
  }

  // ── Friendly Model Names ──────────────────────────────────

  static const Map<String, String> _modelDisplayNames = {
    'models/gemini-2.5-flash': 'Gemini 2.5 Flash',
    'models/gemini-3.1-flash-preview': 'Gemini 3.1 Flash',
    'models/gemma-4-31b-it': 'Gemma 4 31B',
    'models/gemini-2.5-flash-lite': 'Gemini 2.5 Flash Lite',
    'models/gemini-3.1-flash-lite-preview': 'Gemini 3.1 Flash Lite',
  };

  /// Parses a successful Gemini REST API response into [AiResponse].
  AiResponse _parseResponse(String responseBody, String model) {
    final data = json.decode(responseBody);
    final candidates = data['candidates'] as List?;

    if (candidates == null || candidates.isEmpty) {
      throw const AiException('No candidates returned from model.');
    }

    final candidate = candidates[0];

    // Extract text content
    final parts = candidate['content']?['parts'] as List?;
    final text = parts?.isNotEmpty == true
        ? (parts![0]['text'] as String?) ?? ''
        : '';

    if (text.isEmpty) {
      throw const AiException('Empty response from model.');
    }

    // Extract token usage from usageMetadata
    int? tokenCount;
    final usageMetadata = data['usageMetadata'];
    if (usageMetadata != null) {
      tokenCount = (usageMetadata['totalTokenCount'] as num?)?.toInt();
    }

    // Friendly model name
    final modelName = _modelDisplayNames[model] ?? model;

    // Extract grounding sources (if present)
    List<Map<String, String>>? sources;
    final groundingMetadata = candidate['groundingMetadata'];
    if (groundingMetadata != null) {
      final chunks = groundingMetadata['groundingChunks'] as List?;
      if (chunks != null && chunks.isNotEmpty) {
        sources = [];
        for (final chunk in chunks) {
          final web = chunk['web'];
          if (web != null) {
            sources.add({
              'title': (web['title'] as String?) ?? 'Source',
              'uri': (web['uri'] as String?) ?? '',
            });
          }
        }
      }
    }

    return AiResponse(
      text: text,
      sources: sources,
      modelName: modelName,
      tokenCount: tokenCount,
    );
  }

  // ── Error Classification ──────────────────────────────────

  bool _isQuotaError(String error) {
    final lower = error.toLowerCase();
    return lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('resource exhausted');
  }

  bool _isServerError(String error) {
    return error.contains('[503]') || error.contains('[500]');
  }
}
