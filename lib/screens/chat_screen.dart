import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/market_data_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _models = [
    'gemini-3.1-pro-preview',
    'gemini-3-flash-preview',
    'gemini-3.1-flash-lite-preview',
    'gemini-2.5-flash',
  ];

  late List<String> _apiKeys;
  int _currentKeyIndex = 0;
  int _currentModelIndex = 0;

  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _statusMessage;

  static const String _systemPrompt =
      "You are ONYX, an elite algorithmic trading assistant and financial expert. \n\n"
      "**[STRICT DIRECTIVE - HARDCORE RULE]**\n"
      "You are FORBIDDEN from mentioning, referencing, or analyzing the user's portfolio data UNLESS the user explicitly asks about it (e.g., using words like محفظتي, محفظتك, portfolio). If the user asks about a specific stock, ONLY analyze that exact stock. End of rule.\n\n"
      "**[VITAL CONSTRAINT]**\n"
      "You have access to the user's live portfolio and market data as background context. Answer ONLY the specific question asked. DO NOT analyze the user's portfolio or provide general market overviews unless explicitly requested. Be extremely concise, direct, and pragmatic. No fluff.\n\n"
      "**[Your Personality & Tone]**\n"
      "Speak exactly like a senior Egyptian financial engineer talking to a peer. "
      "Use a pragmatic, 'No BS', confident, and direct tone. "
      "Use natural Egyptian developer/trader slang gracefully "
      "(e.g., 'يا هندسة', 'من الآخر', 'بص', 'فرصة ممتازة', 'السهم ده جاب آخره'). "
      "NEVER sound like a generic AI or a corporate robot.\n\n"
      "**[Core Directives - STRICT INSTRUCTIONS]**\n"
      "1. **ZERO Disclaimers:** NEVER say 'I am an AI', 'I cannot give financial advice', "
      "'Consult a professional', or 'The decision is yours'. "
      "The user explicitly accepts all risks. Stop apologizing and start analyzing.\n"
      "2. **Specific Stock Analysis:** Focus exclusively on the metrics provided in the <MARKET_DATA_INTERNAL> for the requested ticker. "
      "If the user asks for general recommendations like 'أشتري إيه النهاردة؟', you may analyze the <FULL_MARKET_SCAN> to find top RSI/MACD signals.\n"
      "3. **Format:** Output your technical breakdowns in clean, organized Markdown. "
      "Use bullet points and emojis 💰📊📈🎯 for readability.\n"
      "4. **ZERO Hallucination (Strict Grounding):** Your technical analysis for EGX stocks must be based "
      "EXCLUSIVELY on the exact numbers provided inside the <MARKET_DATA_INTERNAL> tags. "
      "If the user asks about a stock that is NOT in the list (e.g., Apple, Tesla), you should answer using the most recent general market knowledge available.";

  @override
  void initState() {
    super.initState();

    // Load Gemini API keys from .env
    _apiKeys = [
      dotenv.env['GEMINI_API_KEY_1'] ?? '',
      dotenv.env['GEMINI_API_KEY_2'] ?? '',
      dotenv.env['GEMINI_API_KEY_3'] ?? '',
      dotenv.env['GEMINI_API_KEY_4'] ?? '',
      dotenv.env['GEMINI_API_KEY_5'] ?? '',
    ].where((k) => k.isNotEmpty && !k.contains('YOUR_')).toList();

    debugPrint('DEBUG CHECK: Loaded ${_apiKeys.length} valid API keys.');

    if (_apiKeys.isEmpty) {
      _messages.add(Message(
        text:
            'Hello! No valid Gemini API Keys were found. Please update the `.env` file with your keys (GEMINI_API_KEY_1 through GEMINI_API_KEY_4) to start chatting.',
        isUser: false,
      ));
      _apiKeys = [''];
    }

    _initializeModel();
  }

  /// Initializes the Gemini state (replaces SDK initialization).
  void _initializeModel() {
    debugPrint('Ready for REST calls with key index $_currentKeyIndex');
  }

  /// Attempts to fall back: first to the next API key, then to the next model.
  /// Returns [true] if a new source was successfully selected, [false] if all exhausted.
  bool _attemptFallback() {
    if (_currentKeyIndex < _apiKeys.length - 1) {
      _currentKeyIndex++;
      return true;
    }

    if (_currentModelIndex < _models.length - 1) {
      _currentModelIndex++;
      _currentKeyIndex = 0;
      return true;
    }

    return false;
  }

  /// Checks if an error message indicates a quota/rate-limit issue.
  bool _isQuotaError(String errorString) {
    final lower = errorString.toLowerCase();
    return lower.contains('429') ||
        lower.contains('quota') ||
        lower.contains('rate limit') ||
        lower.contains('resource exhausted');
  }

  /// Checks if an error message indicates a Gemini server-side error (503/500).
  bool _isServerError(String errorString) {
    return errorString.contains('[503]') || errorString.contains('[500]');
  }

  /// Maps common Arabic/English keywords to EGX ticker symbols.
  String? _extractTicker(String message) {
    final lower = message.toLowerCase();
    const Map<String, String> tickerKeywords = {
      // البنوك والمالية
      'تجاري': 'COMI.CA', 'cib': 'COMI.CA',
      'فوري': 'FWRY.CA', 'fawry': 'FWRY.CA',
      'بلتون': 'BTFH.CA', 'btfh': 'BTFH.CA',
      'القلعة': 'CCAP.CA', 'ccap': 'CCAP.CA', 'qalaa': 'CCAP.CA',
      'ابو ظبي': 'ADIB.CA', 'adib': 'ADIB.CA',
      'إي فاينانس': 'EFIH.CA', 'efih': 'EFIH.CA',
      'هيرميس': 'HRHO.CA', 'hrho': 'HRHO.CA', 'efg': 'HRHO.CA',
      'فالمور': 'VLMR.CA', 'vlmr': 'VLMR.CA',

      // العقارات والمقاولات
      'طلعت': 'TMGH.CA', 'مصطفى': 'TMGH.CA', 'tmg': 'TMGH.CA',
      'بالم هيلز': 'PHDC.CA', 'phdc': 'PHDC.CA',
      'مصر الجديدة': 'HELI.CA', 'heli': 'HELI.CA',
      'اوراسكوم للانشاء': 'ORAS.CA', 'oras': 'ORAS.CA',
      'اوراسكوم للتنمية': 'ORHD.CA', 'orhd': 'ORHD.CA',
      'اعمار': 'EMFD.CA', 'emfd': 'EMFD.CA',

      // البتروكيماويات والأسمدة
      'ابو قير': 'ABUK.CA', 'abuk': 'ABUK.CA',
      'اموك': 'AMOC.CA', 'amoc': 'AMOC.CA',
      'كيما': 'EGCH.CA', 'kima': 'EGCH.CA',

      // الصناعة والاستهلاك
      'إيديتا': 'EFID.CA', 'edita': 'EFID.CA', 'efid': 'EFID.CA',
      'جي بي كورب': 'GBCO.CA', 'غبور': 'GBCO.CA', 'gbco': 'GBCO.CA',
      'الشرقية': 'EAST.CA', 'دخان': 'EAST.CA', 'east': 'EAST.CA',
      'النساجون': 'ORWE.CA', 'orwe': 'ORWE.CA',
      'جهينة': 'JUFO.CA', 'jufo': 'JUFO.CA',
      'مصر للالومنيوم': 'EGAL.CA', 'egal': 'EGAL.CA',
      'العربية للأسمنت': 'ARCC.CA', 'arcc': 'ARCC.CA',
      'أسمنت قنا': 'MCQE.CA', 'mcqe': 'MCQE.CA',

      // التكنولوجيا والاتصالات
      'المصرية للاتصالات': 'ETEL.CA', 'we': 'ETEL.CA', 'etel': 'ETEL.CA',
      'راية': 'RAYA.CA', 'raya': 'RAYA.CA',
      'اوراسكوم للاستثمار': 'OIH.CA', 'oih': 'OIH.CA',

      // الرعاية الصحية
      'ابن سينا': 'ISPH.CA', 'isph': 'ISPH.CA',
      'راميدا': 'RMDA.CA', 'rmda': 'RMDA.CA',
    };

    for (final entry in tickerKeywords.entries) {
      if (lower.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  /// Builds a concise, pre-filtered market scan for the AI to save tokens.
  String _buildOptimizedMarketScan(MarketDataService service) {
    if (service.stocksData.isEmpty) return '';
    final buffer = StringBuffer();
    buffer.writeln('<FULL_MARKET_SCAN>');
    service.stocksData.forEach((ticker, info) {
      if (info is Map) {
        final double rsi = (info['rsi'] as num?)?.toDouble() ?? 50.0;
        if (rsi <= 35 || rsi >= 75) {
          final price = info['price'] ?? '?';
          final macd = info['macd'] ?? 'Unknown';
          buffer.write('$ticker: Price=$price, RSI=$rsi, MACD=$macd | ');
        }
      }
    });
    buffer.writeln('\n</FULL_MARKET_SCAN>');
    return buffer.toString();
  }

  /// Retrieves the current user's portfolio data from Firestore and
  /// formats it as an XML-like string for injection into the prompt.
  Future<String> _getPortfolioContext() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return '';

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('investments')
          .get();

      if (snapshot.docs.isEmpty) return 'No investments found.';

      final buffer = StringBuffer();
      buffer.writeln('<PORTFOLIO_DATA>');
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final portfolioName = data['name'] ?? 'Portfolio';
        final assets = data['assets'] as List<dynamic>? ?? [];

        buffer.writeln('Portfolio: $portfolioName');
        for (final asset in assets) {
          final name = asset['name'] ?? '?';
          final qty = asset['quantity'] ?? 0;
          buffer.writeln('  - $name: Qty=$qty');
        }
      }
      buffer.writeln('</PORTFOLIO_DATA>');
      return buffer.toString();
    } catch (e) {
      debugPrint('Error fetching portfolio context: $e');
      return 'Error loading portfolio.';
    }
  }

  Future<void> _sendToGeminiRest(
      String userText, MarketDataService service) async {
    final apiKey = _apiKeys[_currentKeyIndex];
    final modelName = _models[_currentModelIndex];
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey';

    // 1. Prepare dynamic context
    final marketScan = _buildOptimizedMarketScan(service);
    final portfolioContext = await _getPortfolioContext();

    // 2. Check for specific ticker in this prompt for deep context
    final ticker = _extractTicker(userText);
    String tickerContext = '';
    if (ticker != null) {
      final stockData = service.getStockData(ticker);
      if (stockData != null) {
        tickerContext =
            "\n[LIVE_DATA_SNIPPET: $ticker is trading at ${stockData['price']}, RSI is ${stockData['rsi']}, MACD is ${stockData['macd']}]\n";
      }
    }

    final fullSystemInstruction = """
$_systemPrompt

$portfolioContext
$tickerContext

<MARKET_DATA_INTERNAL>
$marketScan
</MARKET_DATA_INTERNAL>
""";

    // 2. Prepare conversation history for the REST body
    final List<Map<String, dynamic>> contents = [];
    for (var msg in _messages) {
      contents.add({
        'role': msg.isUser ? 'user' : 'model',
        'parts': [
          {'text': msg.text}
        ]
      });
    }

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': fullSystemInstruction}
        ]
      },
      'contents': contents,
      'tools': [
        {'googleSearch': {}}
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 1024,
      }
    };

    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final candidate = candidates[0];
        final aiText = candidate['content']['parts'][0]['text'] as String?;

        List<Map<String, String>>? aiSources;
        final groundingMetadata = candidate['groundingMetadata'];
        if (groundingMetadata != null) {
          final chunks = groundingMetadata['groundingChunks'] as List?;
          if (chunks != null) {
            aiSources = [];
            for (var chunk in chunks) {
              final web = chunk['web'];
              if (web != null) {
                aiSources.add({
                  'title': (web['title'] as String?) ?? 'Source',
                  'uri': (web['uri'] as String?) ?? '',
                });
              }
            }
          }
        }

        if (aiText != null) {
          setState(() {
            _messages.add(Message(
              text: aiText,
              isUser: false,
              sources: aiSources,
            ));
            _isLoading = false;
            _statusMessage = null;
          });
          _scrollToBottom();
        }
      }
    } else {
      throw 'Gemini API Error [${response.statusCode}]';
    }
  }

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final service = Provider.of<MarketDataService>(context, listen: false);

    setState(() {
      _messages.add(Message(text: text, isUser: true));
      _isLoading = true;
      _statusMessage = null;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      await _sendToGeminiRest(text, service);
    } catch (e) {
      final errorString = e.toString();
      debugPrint('AI Chat Error: $errorString');

      if (_isQuotaError(errorString)) {
        if (_attemptFallback()) {
          setState(() {
            _statusMessage = '🚀 Optimizing connection (switching keys)...';
          });
          _sendMessageInner(text, service);
          return;
        } else {
          setState(() {
            _messages.add(Message(
                text:
                    '⚠️ Servers busy. My brain is overloaded (Quota reached). Please try again in 5 mins.',
                isUser: false));
            _isLoading = false;
            _statusMessage = null;
          });
        }
      } else if (_isServerError(errorString)) {
        setState(() {
          _messages.add(Message(
              text:
                  'السيرفر عليه ضغط حالياً من جوجل، جرب تسأل تاني كمان دقيقة.',
              isUser: false));
          _isLoading = false;
          _statusMessage = null;
        });
      } else {
        setState(() {
          _messages.add(Message(
              text: 'عذراً يا هندسة، حصلت مشكلة تقنية. جرب تاني كمان شوية.',
              isUser: false));
          _isLoading = false;
          _statusMessage = null;
        });
      }
      _scrollToBottom();
    }
  }

  void _sendMessageInner(String text, MarketDataService service) async {
    try {
      await _sendToGeminiRest(text, service);
    } catch (e) {
      final errorString = e.toString();
      if (_isQuotaError(errorString) && _attemptFallback()) {
        _sendMessageInner(text, service);
      } else {
        setState(() {
          _messages.add(Message(
              text: '⚠️ Still having trouble reaching Gemini.', isUser: false));
          _isLoading = false;
          _statusMessage = null;
        });
        _scrollToBottom();
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gemini Assistant'),
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.w500),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16.0),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          if (_statusMessage != null) ...[
                            const SizedBox(height: 10),
                            Text(
                              _statusMessage!,
                              style: TextStyle(
                                color: Colors.amber.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                final msg = _messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF121212),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle:
                      TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: const Color(0xFF1E1E1E),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 14.0,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.black),
                onPressed: _isLoading ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Message {
  final String text;
  final bool isUser;
  final List<Map<String, String>>? sources;

  Message({required this.text, required this.isUser, this.sources});
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFF2C2C2C)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft:
                message.isUser ? const Radius.circular(20) : Radius.zero,
            bottomRight:
                message.isUser ? Radius.zero : const Radius.circular(20),
          ),
          border: message.isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            message.isUser
                ? Text(
                    message.text,
                    style: const TextStyle(color: Colors.white),
                  )
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: MarkdownBody(
                      data: message.text,
                      selectable: true,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(color: Colors.white, height: 1.6),
                        strong: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        code: TextStyle(
                          color: Colors.greenAccent,
                          backgroundColor: Colors.black.withValues(alpha: 0.5),
                        ),
                        codeblockDecoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),
            if (!message.isUser &&
                message.sources != null &&
                message.sources!.isNotEmpty) ...[
              const Divider(color: Colors.white24, height: 20),
              const Text(
                'المصادر:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              ...message.sources!.map((source) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () {
                        // In a real app, use url_launcher. For now, we assume web interface
                        debugPrint('Opening source: ${source['uri']}');
                      },
                      child: Text(
                        source['title'] ?? source['uri'] ?? 'رابط',
                        style: const TextStyle(
                          color: Colors.blueAccent,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
