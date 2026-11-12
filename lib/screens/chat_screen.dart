import '../../utils/constants.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart' show rootBundle;
import '../../widgets/modern_app_bar.dart';





class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  String? _apiKey;
  bool _apiKeyLoaded = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Groq's currently supported models (as of 2024/2025):
  //   llama-3.1-8b-instant     (fast, good for chat)
  //   llama-3.1-70b-versatile  (strong, good for chat)
  //   llama-3.2-1b-preview     (small, fast)
  //   llama-3.2-3b-preview     (small, fast)
  //   mixtral-8x7b-32768       (good for complex tasks)
  //   gemma2-9b-it             (fast, efficient)
  static const String _model = 'llama-3.1-8b-instant';

  static const String _systemPrompt =
      'You are a friendly AI wardrobe assistant. Give practical, concise '
      'outfit and styling advice based on the user\'s occasion, weather, '
      'body type, budget and taste. Ask a short follow-up question if you '
      'need more details.';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));
    _animationController.forward();
    _loadApiKey();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    // Try loading from assets (works on device/emulator)
    try {
      final content = await rootBundle.loadString('env.json');
      final json = jsonDecode(content);
      _apiKey = json['GROQ_API_KEY'];
      debugPrint('🔑 ChatScreen: Loaded API key from assets');
    } catch (e) {
      debugPrint('🔑 ChatScreen: Could not load from assets: $e');
    }

    // Fallback to compile-time constant (for --dart-define)
    if (_apiKey == null || _apiKey!.isEmpty) {
      _apiKey = String.fromEnvironment('GROQ_API_KEY');
      if (_apiKey != null && _apiKey!.isNotEmpty) {
        debugPrint('🔑 ChatScreen: Loaded API key from --dart-define');
      }
    }

    setState(() {
      _apiKeyLoaded = true;
    });

    debugPrint('🔑 ChatScreen: API Key loaded = ${_apiKey != null && _apiKey!.isNotEmpty}');
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      debugPrint('🔑 ChatScreen: API Key starts with = ${_apiKey!.substring(0, _apiKey!.length > 10 ? 10 : _apiKey!.length)}...');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Builds the conversation history so the model remembers earlier turns.
  List<Map<String, String>> _buildApiMessages() {
    final history = _messages
        .where((m) => !m.isError)
        .toList()
        .reversed
        .take(20)
        .toList()
        .reversed
        .map((m) => {
              'role': m.isUser ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    return [
      {'role': 'system', 'content': _systemPrompt},
      ...history,
    ];
  }

  Future<void> _sendMessage() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _isLoading) return;

    if (!_apiKeyLoaded) {
      await _loadApiKey();
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      setState(() {
        _messages.add(const _ChatMessage(
          text: 'No API key found. Please add env.json to your pubspec.yaml assets:\n'
              'flutter:\n  assets:\n    - env.json\n\n'
              'Then create env.json in project root with:\n'
              '{\n  "GROQ_API_KEY": "your_groq_api_key"\n}\n\n'
              'Or run with:\n'
              'flutter run --dart-define-from-file=env.json',
          isUser: false,
          isError: true,
        ));
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final requestBody = jsonEncode({
        'model': _model,
        'messages': _buildApiMessages(),
        'max_tokens': 2048,
        'temperature': 0.7,
      });
      debugPrint('📤 ChatScreen: Sending request to $_apiUrl');
      debugPrint('📤 ChatScreen: Model = $_model');
      debugPrint('📤 ChatScreen: Request body = $requestBody');

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: requestBody,
          )
          .timeout(const Duration(seconds: 60));

      debugPrint('📥 ChatScreen: Response status = ${response.statusCode}');
      debugPrint('📥 ChatScreen: Response headers = ${response.headers}');

      // Decode as UTF-8 so emojis / special characters display correctly.
      final String body = utf8.decode(response.bodyBytes);
      debugPrint('📥 ChatScreen: Response body = $body');

      if (response.statusCode != 200) {
        String detail = body;
        try {
          final err = jsonDecode(body);
          detail = err['error']?['message']?.toString() ?? body;
        } catch (_) {}
        throw _ApiException(response.statusCode, detail);
      }

      final data = jsonDecode(body);
      final content = data['choices']?[0]?['message']?['content'];
      if (content is! String || content.trim().isEmpty) {
        throw _ApiException(200, 'The model returned an empty response.');
      }

      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage(text: content.trim(), isUser: false));
        _isLoading = false;
      });
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } on _ApiException catch (e) {
      String msg;
      switch (e.statusCode) {
        case 401:
          msg = 'Authentication failed. Please check your Groq API key.';
          break;
        case 404:
        case 400:
          msg = 'Request rejected (${e.statusCode}): ${e.message}';
          break;
        case 429:
          msg = 'Rate limit exceeded. Please try again in a moment.';
          break;
        case 500:
        case 503:
          msg = 'Groq is having trouble right now. Please try again later.';
          break;
        default:
          msg = 'Error ${e.statusCode}: ${e.message}';
      }
      _showError(msg);
    } catch (e) {
      _showError('Something went wrong. Check your internet connection.\n$e');
    }
    _scrollToBottom();
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: msg, isUser: false, isError: true));
      _isLoading = false;
    });
    _scrollToBottom();
  }

  Widget _buildBubble(_ChatMessage message, int index) {
    final bool isUser = message.isUser;
    final bool isError = message.isError;

    final Color bubbleColor = isUser
        ? forestInk
        : isError
            ? Colors.red.shade50
            : softSage.withValues(alpha: 0.15);

    final Color textColor = isUser
        ? linen
        : isError
            ? Colors.red.shade900
            : forestInk;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final delay = (index * 50).clamp(0, 200).toDouble();
        final progress = (_animationController.value * 600 - delay).clamp(0.0, 600.0) / 600.0;
        final opacity = progress.clamp(0.0, 1.0);
        final offset = Offset(0, 20 * (1 - progress.clamp(0.0, 1.0)));

        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: offset,
            child: Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.78,
                ),
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    border: isError
                        ? Border.all(color: Colors.red.shade200)
                        : Border.all(color: softSage.withValues(alpha: 0.2)),
                  ),
                  child: SelectableText(
                    message.text,
                    style: TextStyle(color: textColor, fontSize: 16, height: 1.35),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: softSage.withValues(alpha: 0.15),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
          border: Border.all(color: softSage.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TypingDot(delay: 0),
            const SizedBox(width: 4),
            _TypingDot(delay: 150),
            const SizedBox(width: 4),
            _TypingDot(delay: 300),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: forestInk.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.checkroom_outlined,
                    size: 56,
                    color: forestInk.withValues(alpha: 0.5),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ask me for outfit ideas!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: forestInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'e.g. "What should I wear to a summer wedding?"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: forestInk.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Send button built without a FloatingActionButton, so it has no Hero
  /// and can't clash with other screens' FABs during navigation.
  Widget _buildSendButton() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: _isLoading ? [] : [
          BoxShadow(
            color: forestInk.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: _isLoading ? softSage.withValues(alpha: 0.5) : forestInk,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isLoading ? null : _sendMessage,
          child: const SizedBox(
            width: 56,
            height: 56,
            child: Icon(Icons.send_rounded, color: linen),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int itemCount = _messages.length + (_isLoading ? 1 : 0);

    return Scaffold(
      backgroundColor: linen,
      appBar: ModernAppBar(
        title: 'AI Wardrobe Assistant',
        centerTitle: false,
        backgroundColor: linen,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: forestInk.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.auto_awesome_rounded, color: forestInk, size: 22),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: itemCount == 0
                  ? _buildEmptyState()
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: itemCount,
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return _buildTypingBubble();
                        }
                        return _buildBubble(_messages[index], index);
                      },
                    ),
            ),
            // Input area
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: linen,
                border: Border(
                  top: BorderSide(
                    color: softSage.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: softSage.withValues(alpha: 0.3)),
                        boxShadow: [
                          BoxShadow(
                            color: forestInk.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(color: forestInk, fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Ask about wardrobe suggestions...',
                          hintStyle: TextStyle(color: forestInk.withValues(alpha: 0.4)),
                          filled: true,
                          fillColor: Colors.transparent,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildSendButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final int delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
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
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.5 + 0.5 * _controller.value,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: forestInk.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

class _ApiException implements Exception {
  final int statusCode;
  final String message;
  _ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API error $statusCode: $message';
}