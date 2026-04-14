import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/market_data_service.dart';
import '../services/onyx_ai_router_service.dart';

// ─────────────────────────────────────────────────────────────
// CONSTANTS & THEME TOKENS
// ─────────────────────────────────────────────────────────────

class _ChatColors {
  static const Color background = Color(0xFF0A0A0F);
  static const Color surfaceLight = Color(0xFF1C1C28);
  static const Color userBubble = Color(0xFF6C3FEE);
  static const Color userBubbleEnd = Color(0xFF4A2DBA);
  static const Color aiBubble = Color(0xFF1A1A26);
  static const Color aiBorder = Color(0xFF2A2A3A);
  static const Color accentGlow = Color(0xFF8B5CF6);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF9090A8);
  static const Color inputBg = Color(0xFF16161F);
  static const Color inputBorder = Color(0xFF2A2A3A);
}

// ─────────────────────────────────────────────────────────────
// MAIN CHAT SCREEN
// ─────────────────────────────────────────────────────────────

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  /// Singleton AI router — handles model selection & API key rotation.
  final OnyxAiRouterService _router = OnyxAiRouterService();

  final List<Message> _messages = [];
  bool _isLoading = false;
  String? _statusMessage;

  // Animation controllers for slide-up / fade-in per message.
  final List<AnimationController> _messageAnimControllers = [];

  // ── ONYX System Prompt ────────────────────────────────────
  static const String _systemPrompt =
      "You are ONYX, an elite algorithmic trading assistant and financial expert. \n\n"
      "**[1. PERSONA & TONE (THE 'NO BS' APPROACH)]**\n"
      "Speak exactly like a senior Egyptian software architect and financial expert. Be pragmatic, straightforward, and tell it like it is. No sugar-coating. No fluff. No pseudo-questions. Use full sentences with real clarity. Sound smart, grounded, and direct, like you’re actually helping. Don't flatter the user; always tell the truth. Use natural Egyptian tech/trading slang gracefully (e.g., 'يا هندسة', 'من الآخر', 'بص', 'الزتونة'). NEVER sound like a generic AI or apologize.\n\n"
      "**[2. EXTREME BREVITY (NO YAPPING)]**\n"
      "Since your token limit is open, you are strictly bound by brevity. Get straight to the point immediately. Deliver high-value information in the absolute minimum number of words. If a 3-word answer works, do not use 10. The user's time is money.\n\n"
      "Assume all queries about markets/stocks refer to the Egyptian Stock Exchange (EGX).\n\n"
      "**[4. ANTI-EVASION & RISK HANDLING (CRITICAL)]**\n"
      "DO NOT refuse high-risk questions. DO NOT narrate your search process. Provide a brutally honest 1-sentence reality check about risks, then IMMEDIATELY provide the requested data and specific stock picks (Tickers).\n\n"
      "**[5. MANDATORY PORTFOLIO ALLOCATION FORMAT]**\n"
      "When asked to allocate money (e.g., 'معايا 10000 جنيه'), strictly use this Markdown format:\n"
      "⚠️ **تحذير مهم:** (1 sentence pragmatic reality check).\n"
      "📊 **وضع البورصة دلوقتي:** (1 sentence on current EGX momentum).\n"
      "💡 **أبرز الأسهم المرشحة:** (List 3-4 specific EGX stocks).\n"
      "🗂️ **توزيعة مقترحة لـ [Amount]:**\n"
      "| السهم | القطاع | المبلغ المقترح | السبب |\n"
      "|---|---|---|---|\n"
      "| [Stock Name] | [Sector] | [Allocated Value] | [Brief Reason] |\n"
      "🔴 **نصائح سريعة:** (2 short bullet points).\n\n"
      "**[CRITICAL formatting]**: You MUST fully complete all rows of the Markdown table. Keep your text explanations outside the table to an absolute minimum (max 1 short sentence) to ensure you have enough tokens to finish rendering the table completely.\n\n"
      "**[DATA ENFORCEMENT - ZERO TOLERANCE]**: You HAVE access to live EGX prices in the <MARKET_DATA_INTERNAL> tags. The prices provided there are the ABSOLUTE TRUTH. Never claim you don't have access to data. If a stock is in the tags, use its price. If NOT in the tags, say 'I don't have the live price for this asset'. NEVER guess or hallucinate a price.";
  @override
  void initState() {
    super.initState();

    if (!_router.hasValidKeys) {
      _addMessage(Message(
        text:
            'Hello! No valid Gemini API Keys were found. Please update the `.env` file with your keys (GEMINI_API_KEY_1 through GEMINI_API_KEY_5) to start chatting.',
        isUser: false,
      ));
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    for (final c in _messageAnimControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── INTENT DETECTION ─────────────────────────────────────
  // Determines whether the user's message should route to the
  // deep analysis model vs. the fast general chat model.

  /// Returns true if the message looks like a stock analysis request:
  /// contains an analysis keyword AND a recognised EGX ticker.
  bool _isAnalysisRequest(String text) {
    final lower = text.toLowerCase();
    final hasKeyword = lower.contains('حلل') ||
        lower.contains('تحليل') ||
        lower.contains('analyze') ||
        lower.contains('analyse') ||
        lower.contains('analysis') ||
        lower.contains('أداء') ||
        lower.contains('تقييم');
    return hasKeyword && _extractTicker(text) != null;
  }

  // ─── TICKER EXTRACTION ────────────────────────────────────

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

  // ─── CONTEXT BUILDERS ─────────────────────────────────────

  /// Builds a compact string of the top 25 EGX assets for the AI context.
  String _buildOptimizedMarketScan(MarketDataService service) {
    if (!service.hasData) return "Market Data is currently unavailable.";

    final List<String> lines = [];
    final stocks = service.stocksData;
    
    // Get all tickers to provide full EGX100 visibility as requested
    final tickers = stocks.keys.toList()..sort();
    final topTickers = tickers.take(100);

    for (final t in topTickers) {
      final data = stocks[t];
      if (data == null) continue;
      
      final price = data['price'] ?? '?';
      final change = data['change'] ?? '0';
      final rsi = data['rsi'] ?? '50';
      final macd = data['macd'] ?? 'Neutral';
      
      lines.add("$t: $price ($change%), RSI: $rsi, MACD: $macd");
    }

    return lines.join(" | ");
  }

  /// Extracted helper to identify stock mentions in Arabic and English.
  List<String> _extractAllMentionedTickers(String text, MarketDataService service) {
    final Set<String> foundTickers = {};
    final words = text.toLowerCase();

    // 1. Check for English Tickers (e.g. COMI)
    for (final ticker in service.stocksData.keys) {
      final symbol = ticker.split('.')[0].toLowerCase();
      if (words.contains(symbol)) {
        foundTickers.add(ticker);
      }
    }

    // 2. Map Arabic Names to Tickers
    final Map<String, String> arabicMap = {
      'تجاري': 'COMI.CA',
      'طلعت': 'TMGH.CA',
      'مصطفي': 'TMGH.CA',
      'مصطفى': 'TMGH.CA',
      'شرقية': 'EAST.CA',
      'دخان': 'EAST.CA',
      'أوراسكوم': 'ORAS.CA',
      'انشاء': 'ORAS.CA',
      'فوري': 'FWRY.CA',
      'هرماس': 'HRHO.CA',
      'بيلتون': 'BTEL.CA',
      'أبو قير': 'ABUK.CA',
      'القلعة': 'CCAP.CA',
      'إعمار': 'EMFD.CA',
      'موبكو': 'MFPC.CA',
      'سويدي': 'SWDY.CA',
    };

    arabicMap.forEach((arabic, ticker) {
      if (words.contains(arabic)) {
        foundTickers.add(ticker);
      }
    });

    return foundTickers.toList();
  }

  /// Retrieves the user's portfolio data from Firestore for prompt injection.
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

  Future<String> _buildSystemInstruction(
      String userText, MarketDataService service) async {
    final portfolioContext = await _getPortfolioContext();

    // 1. Identify ALL mentioned tickers (Arabic or English)
    final mentionedTickers = _extractAllMentionedTickers(userText, service);
    
    // 2. Build High-Priority Context for these assets
    String priorityContext = '';
    if (mentionedTickers.isNotEmpty) {
      priorityContext = "\n<PRIORITY_LIVE_DATA>\n";
      for (final ticker in mentionedTickers) {
        final stockData = service.getStockData(ticker);
        if (stockData != null) {
          priorityContext +=
              "[EXACT_LIVE_DATA: $ticker is at ${stockData['price']} (${stockData['change']}%), Vol: ${stockData['volume']}, RSI: ${stockData['rsi']}, MACD: ${stockData['macd']}]\n";
        }
      }
      priorityContext += "</PRIORITY_LIVE_DATA>\n";
    }

    final newsContext = service.news.isNotEmpty
        ? "\n<MARKET_NEWS_INTERNAL>\n${service.news.join('\n')}\n</MARKET_NEWS_INTERNAL>\n"
        : "";

    final macroContext = service.macro.isNotEmpty
        ? "\n<MARKET_MACRO_INTERNAL>\n"
            "EGX100 Index: ${service.macro['egx100']}\n"
            "USD/EGP Rate: ${service.macro['usd_egp']}\n"
            "Gold (GC=F): ${service.macro['gold']}\n"
            "Market Breadth: ${service.breadth}\n"
            "</MARKET_MACRO_INTERNAL>\n"
        : "";

    return """
$_systemPrompt

$priorityContext
$portfolioContext
$newsContext
$macroContext
""";
  }

  /// Builds the Gemini `contents` array from current message history,
  /// strictly enforcing alternating 'user' and 'model' roles.
  List<Map<String, dynamic>> _buildContents() {
    final List<Map<String, dynamic>> filtered = [];
    for (final msg in _messages) {
      final role = msg.isUser ? 'user' : 'model';
      // Gemini API strictly requires starting with 'user' and alternating.
      if (filtered.isEmpty) {
        if (role == 'user') {
          filtered.add({
            'role': role,
            'parts': [{'text': msg.text}],
          });
        }
      } else {
        if (filtered.last['role'] != role) {
          filtered.add({
            'role': role,
            'parts': [{'text': msg.text}],
          });
        }
      }
    }
    return filtered;
  }

  // ─── SEND MESSAGE (MAIN ENTRY POINT) ──────────────────────

  void _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final service = Provider.of<MarketDataService>(context, listen: false);

    setState(() {
      _addMessage(Message(text: text, isUser: true));
      _isLoading = true;
      _statusMessage = null;
    });

    _textController.clear();
    _scrollToBottom();

    try {
      // Build shared context.
      final systemInstruction = await _buildSystemInstruction(text, service);
      final contents = _buildContents();

      // ── Intelligent routing ──────────────────────────────
      // If the message is a stock deep-dive → analysisModel
      // Otherwise → fast chatModel
      final AiResponse response;

      if (_isAnalysisRequest(text)) {
        debugPrint('🤖 ChatScreen: Routing to ANALYSIS model');
        setState(() {
          _statusMessage = '🔬 Deep analysis mode...';
        });
        response = await _router.analyzeStock(
          text,
          systemInstruction: systemInstruction,
          conversationHistory: contents,
        );
      } else {
        final marketScan = _buildOptimizedMarketScan(service);
        response = await _router.sendChatMessage(
          text,
          systemInstruction: systemInstruction,
          conversationHistory: contents,
          enableGrounding: false,
          localMarketData: marketScan,
        );
      }

      // ── Handle success ───────────────────────────────────
      setState(() {
        _addMessage(Message(
          text: response.text,
          isUser: false,
          sources: response.sources,
          aiModelName: response.modelName,
          tokenCount: response.tokenCount,
        ));
        _isLoading = false;
        _statusMessage = null;
      });
      _scrollToBottom();
    } on AiQuotaException {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isUser) {
          _messages.removeLast();
          _messageAnimControllers.removeLast().dispose();
        }
        _textController.text = text;
        _addMessage(Message(
          text:
              '⚠️ Servers busy. My brain is overloaded (Quota reached). Please try again in 5 mins.',
          isUser: false,
        ));
        _isLoading = false;
        _statusMessage = null;
      });
      _scrollToBottom();
    } on AiServerException {
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isUser) {
          _messages.removeLast();
          _messageAnimControllers.removeLast().dispose();
        }
        _textController.text = text;
        _addMessage(Message(
          text: 'السيرفر عليه ضغط حالياً من جوجل، جرب تسأل تاني كمان دقيقة.',
          isUser: false,
        ));
        _isLoading = false;
        _statusMessage = null;
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('AI Chat Error: $e');
      setState(() {
        if (_messages.isNotEmpty && _messages.last.isUser) {
          _messages.removeLast();
          _messageAnimControllers.removeLast().dispose();
        }
        _textController.text = text;
        _addMessage(Message(
          text: 'عذراً يا هندسة، حصلت مشكلة تقنية. جرب تاني كمان شوية.',
          isUser: false,
        ));
        _isLoading = false;
        _statusMessage = null;
      });
      _scrollToBottom();
    }
  }

  // ─── MESSAGE MANAGEMENT ───────────────────────────────────

  /// Adds a message and kicks off its entrance animation.
  void _addMessage(Message msg) {
    _messages.add(msg);
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _messageAnimControllers.add(controller);
    controller.forward();
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

  void _clearChat() {
    setState(() {
      _messages.clear();
      for (final c in _messageAnimControllers) {
        c.dispose();
      }
      _messageAnimControllers.clear();
    });
  }

  // ─── BUILD ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ChatColors.background,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildBackgroundDecoration(),
          Column(
            children: [
              SizedBox(
                  height:
                      MediaQuery.of(context).padding.top + kToolbarHeight + 8),
              Expanded(child: _buildMessageList()),
              _buildInputBar(),
            ],
          ),
        ],
      ),
    );
  }

  // ─── APP BAR (No Model Switcher — routing is automatic) ───

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _ChatColors.background.withValues(alpha: 0.85),
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(color: Colors.transparent),
        ),
      ),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: _ChatColors.surfaceLight.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 16, color: _ChatColors.textPrimary),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _ChatColors.accentGlow.withValues(alpha: 0.25),
                  _ChatColors.accentGlow.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 16, color: _ChatColors.accentGlow),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ONYX',
                style: TextStyle(
                  color: _ChatColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'AI Financial Assistant',
                style: TextStyle(
                  color: _ChatColors.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _ChatColors.surfaceLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.delete_sweep_rounded,
                size: 18, color: _ChatColors.textSecondary),
          ),
          onPressed: _clearChat,
          tooltip: 'Clear Chat',
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── BACKGROUND ───────────────────────────────────────────

  Widget _buildBackgroundDecoration() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -60,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _ChatColors.accentGlow.withValues(alpha: 0.08),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -40,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  _ChatColors.userBubble.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── MESSAGE LIST ─────────────────────────────────────────

  Widget _buildMessageList() {
    if (_messages.isEmpty && !_isLoading) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return _buildTypingIndicator();
        }

        final msg = _messages[index];
        final animController = index < _messageAnimControllers.length
            ? _messageAnimControllers[index]
            : null;

        Widget bubble = _MessageBubble(
          message: msg,
          userName: FirebaseAuth.instance.currentUser?.displayName ?? 'U',
        );

        if (animController != null) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animController,
              curve: Curves.easeOutCubic,
            )),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animController,
                curve: Curves.easeOut,
              ),
              child: bubble,
            ),
          );
        }

        return bubble;
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _ChatColors.accentGlow.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: _ChatColors.accentGlow.withValues(alpha: 0.15),
              ),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: _ChatColors.accentGlow,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'ONYX Assistant',
            style: TextStyle(
              color: _ChatColors.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your elite financial AI companion',
            style: TextStyle(
              color: _ChatColors.textSecondary.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 32),
          // Quick prompt chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _buildQuickPrompt('📊 Market Overview',
                  payload: 'نظرة عامة على السوق المصري (EGX) وأحدث الأخبار'),
              _buildQuickPrompt('💰 أشتري إيه؟',
                  payload:
                      'بناءً على السوق المصري اليوم، إيه أفضل الأسهم اللي ممكن أشتريها دلوقتي وليه؟'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompt(String label, {String? payload}) {
    return GestureDetector(
      onTap: () {
        _textController.text = payload ??
            label.replaceAll(RegExp(r'[^\w\s\u0600-\u06FF؟]'), '').trim();
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _ChatColors.surfaceLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _ChatColors.aiBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _ChatColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _ChatColors.accentGlow.withValues(alpha: 0.3),
                  _ChatColors.accentGlow.withValues(alpha: 0.1),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _ChatColors.accentGlow.withValues(alpha: 0.3),
              ),
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 16, color: _ChatColors.accentGlow),
          ),
          const SizedBox(width: 10),
          // Typing dots
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _ChatColors.aiBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(
                color: _ChatColors.aiBorder.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TypingDot(delay: 0),
                    SizedBox(width: 4),
                    _TypingDot(delay: 150),
                    SizedBox(width: 4),
                    _TypingDot(delay: 300),
                  ],
                ),
                if (_statusMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _statusMessage!,
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.9),
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── INPUT BAR ────────────────────────────────────────────

  Widget _buildInputBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: SafeArea(
        top: false,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
              decoration: BoxDecoration(
                color: _ChatColors.inputBg.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _ChatColors.inputBorder.withValues(alpha: 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                  BoxShadow(
                    color: _ChatColors.accentGlow.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Text field
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      focusNode: _inputFocusNode,
                      style: const TextStyle(
                        color: _ChatColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ask ONYX anything...',
                        hintStyle: TextStyle(
                          color:
                              _ChatColors.textSecondary.withValues(alpha: 0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 12,
                        ),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      maxLines: 4,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: _isLoading
                            ? null
                            : const LinearGradient(
                                colors: [
                                  _ChatColors.userBubble,
                                  _ChatColors.accentGlow,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                        color: _isLoading ? _ChatColors.surfaceLight : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _isLoading
                            ? []
                            : [
                                BoxShadow(
                                  color: _ChatColors.accentGlow
                                      .withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        size: 20,
                        color: _isLoading
                            ? _ChatColors.textSecondary.withValues(alpha: 0.4)
                            : Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MESSAGE MODEL
// ─────────────────────────────────────────────────────────────

class Message {
  final String text;
  final bool isUser;
  final List<Map<String, String>>? sources;
  final String? aiModelName;
  final int? tokenCount;

  Message({
    required this.text,
    required this.isUser,
    this.sources,
    this.aiModelName,
    this.tokenCount,
  });
}

// ─────────────────────────────────────────────────────────────
// MESSAGE BUBBLE
// ─────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final Message message;
  final String userName;

  const _MessageBubble({required this.message, required this.userName});

  /// Launches a URL in the device's external browser.
  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('⚠️ Could not launch URL: $url');
      }
    } catch (e) {
      debugPrint('⚠️ Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // AI Avatar (left)
          if (!isUser) ...[
            _buildAiAvatar(),
            const SizedBox(width: 10),
          ],
          // Bubble
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [
                          _ChatColors.userBubble,
                          _ChatColors.userBubbleEnd
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isUser ? null : _ChatColors.aiBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isUser
                      ? const Radius.circular(20)
                      : const Radius.circular(4),
                  bottomRight: isUser
                      ? const Radius.circular(4)
                      : const Radius.circular(20),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: _ChatColors.aiBorder.withValues(alpha: 0.5),
                        width: 1,
                      ),
                boxShadow: [
                  BoxShadow(
                    color: isUser
                        ? _ChatColors.userBubble.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Message content
                  isUser
                      ? Text(
                          message.text,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.5,
                          ),
                        )
                      : Directionality(
                          textDirection: TextDirection.rtl,
                          child: MarkdownBody(
                            data: message.text,
                            selectable: true,
                            onTapLink: (text, href, title) {
                              if (href != null && href.isNotEmpty) {
                                _launchUrl(href);
                              }
                            },
                            styleSheet: MarkdownStyleSheet(
                              a: const TextStyle(
                                color: Color(0xFF8B9CF6),
                                decoration: TextDecoration.underline,
                                decorationColor: Color(0xFF8B9CF6),
                              ),
                              p: const TextStyle(
                                color: _ChatColors.textPrimary,
                                height: 1.65,
                                fontSize: 14.5,
                              ),
                              strong: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              em: TextStyle(
                                color: _ChatColors.textPrimary
                                    .withValues(alpha: 0.85),
                                fontStyle: FontStyle.italic,
                              ),
                              code: const TextStyle(
                                color: Color(0xFF7DD3FC),
                                backgroundColor: Color(0xFF1A1A2E),
                                fontFamily: 'monospace',
                                fontSize: 13,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: const Color(0xFF0D0D15),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _ChatColors.aiBorder
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              listBullet: const TextStyle(
                                color: _ChatColors.accentGlow,
                              ),
                              h1: const TextStyle(
                                color: _ChatColors.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                              h2: const TextStyle(
                                color: _ChatColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              h3: const TextStyle(
                                color: _ChatColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                              blockquoteDecoration: BoxDecoration(
                                color: _ChatColors.accentGlow
                                    .withValues(alpha: 0.08),
                                borderRadius: const BorderRadius.only(
                                  topRight: Radius.circular(8),
                                  bottomRight: Radius.circular(8),
                                ),
                                border: Border(
                                  right: BorderSide(
                                    color: _ChatColors.accentGlow
                                        .withValues(alpha: 0.5),
                                    width: 3,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                  // Sources
                  if (!isUser &&
                      message.sources != null &&
                      message.sources!.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:
                              _ChatColors.surfaceLight.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _ChatColors.aiBorder.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.link_rounded,
                                    size: 14,
                                    color: _ChatColors.textSecondary
                                        .withValues(alpha: 0.7)),
                                const SizedBox(width: 6),
                                Text(
                                  'المصادر',
                                  style: TextStyle(
                                    color: _ChatColors.textSecondary
                                        .withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ...message.sources!.map((source) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: InkWell(
                                    onTap: () {
                                      final uri = source['uri'];
                                      if (uri != null && uri.isNotEmpty) {
                                        _launchUrl(uri);
                                      }
                                    },
                                    child: Text(
                                      source['title'] ??
                                          source['uri'] ??
                                          'رابط',
                                      style: TextStyle(
                                        color: _ChatColors.accentGlow
                                            .withValues(alpha: 0.85),
                                        fontSize: 12,
                                        decoration: TextDecoration.underline,
                                        decorationColor: _ChatColors.accentGlow
                                            .withValues(alpha: 0.4),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // User Avatar (right)
          if (isUser) ...[
            const SizedBox(width: 10),
            _buildUserAvatar(),
          ],
        ],
      ),
    );
  }

  Widget _buildAiAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _ChatColors.accentGlow.withValues(alpha: 0.3),
            _ChatColors.accentGlow.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _ChatColors.accentGlow.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: _ChatColors.accentGlow.withValues(alpha: 0.15),
            blurRadius: 8,
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          size: 16, color: _ChatColors.accentGlow),
    );
  }

  Widget _buildUserAvatar() {
    final initial = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_ChatColors.userBubble, _ChatColors.userBubbleEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: _ChatColors.userBubble.withValues(alpha: 0.2),
            blurRadius: 6,
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TYPING ANIMATION DOT
// ─────────────────────────────────────────────────────────────

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: _ChatColors.accentGlow.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
