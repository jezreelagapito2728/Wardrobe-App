import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

class _ChatScreenState extends State<ChatScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  // Pass your key at build time instead of hard-coding it, e.g.:
  //   flutter run --dart-define-from-file=env.json
  // where env.json contains: { "GROQ_API_KEY": "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" }
  // (add env.json to .gitignore)
  static const String _apiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _apiUrl =
      'https://api.groq.com/openai/v1/chat/completions';

  // Groq's recommended chat models:
  //   openai/gpt-oss-20b   (fast, good for chat)
  //   openai/gpt-oss-120b  (stronger, slower)
  static const String _model = 'openai/gpt-oss-20b';

  static const String _systemPrompt =
      'You are a friendly AI wardrobe assistant. Give practical, concise '
      'outfit and styling advice based on the user\'s occasion, weather, '
      'body type, budget and taste. Ask a short follow-up question if you '
      'need more details.';

  static const Color _brand = Color(0xff1c1c1c);
  static const Color _sendColor = Color(0xFF6E5A3F);

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

    if (_apiKey.isEmpty) {
      setState(() {
        _messages.add(const _ChatMessage(
          text: 'No API key found. Run the app with '
              '--dart-define=GROQ_API_KEY=your_key '
              'or --dart-define-from-file=env.json',
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
      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': _buildApiMessages(),
              // gpt-oss models "think" first; leave room for the answer.
              'max_completion_tokens': 2048,
              'reasoning_effort': 'low',
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 60));

      // Decode as UTF-8 so emojis / special characters display correctly.
      final String body = utf8.decode(response.bodyBytes);

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

  Widget _buildBubble(_ChatMessage message) {
    final bool isUser = message.isUser;
    final bool isError = message.isError;

    final Color bubbleColor = isUser
        ? _brand
        : isError
            ? Colors.red.shade50
            : Colors.grey.shade200;

    final Color textColor = isUser
        ? Colors.white
        : isError
            ? Colors.red.shade900
            : Colors.black87;

    return Align(
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
            border: isError ? Border.all(color: Colors.red.shade200) : null,
          ),
          child: SelectableText(
            message.text,
            style: TextStyle(color: textColor, fontSize: 16, height: 1.35),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: _brand),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.checkroom_outlined,
                size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'Ask me for outfit ideas!',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              'e.g. "What should I wear to a summer wedding?"',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  /// Send button built without a FloatingActionButton, so it has no Hero
  /// and can't clash with other screens' FABs during navigation.
  Widget _buildSendButton() {
    return Material(
      color: _isLoading ? Colors.grey : _sendColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _isLoading ? null : _sendMessage,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.send, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int itemCount = _messages.length + (_isLoading ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Wardrobe Assistant'),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        elevation: 0,
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
                        return _buildBubble(_messages[index]);
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Ask about wardrobe suggestions...',
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}

class _ApiException implements Exception {
  final int statusCode;
  final String message;
  _ApiException(this.statusCode, this.message);

  @override
  String toString() => 'API error $statusCode: $message';
}