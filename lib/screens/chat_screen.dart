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
  static const Color background = Color(0xFF000000);
  static const Color surfaceLight = Color(0xFF151515);
  static const Color userBubble = Color(0xFF2A2A2A);
  static const Color userBubbleEnd = Color(0xFF1F1F1F);
  static const Color aiBubble = Color(0xFF0D0D0D);
  static const Color aiBorder = Color(0xFF333333);
  static const Color accentGlow = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFEEEEEE);
  static const Color textSecondary = Color(0xFF888888);
  static const Color inputBg = Color(0xFF0D0D0D);
  static const Color inputBorder = Color(0xFF333333);
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

  // ─── TICKER EXTRACTION ────────────────────────────────────

  // ─── CONTEXT BUILDERS ─────────────────────────────────────


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
      setState(() {
        _statusMessage = '🧠 Analyzing intent...';
      });

      final portfolioData = await _getPortfolioContext();

      final AiResponse response = await _router.sendMessage(
        text,
        marketDataService: service,
        portfolioData: portfolioData,
      );

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
                maxWidth: isUser
                    ? MediaQuery.of(context).size.width * 0.78
                    : MediaQuery.of(context).size.width * 0.92,
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
                              tableBorder: TableBorder.all(
                                color:
                                    _ChatColors.aiBorder.withValues(alpha: 0.8),
                                width: 0.8,
                              ),
                              tableCellsPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 8,
                              ),
                              tableHead: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              tableBody: const TextStyle(
                                color: _ChatColors.textPrimary,
                                fontSize: 12,
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
