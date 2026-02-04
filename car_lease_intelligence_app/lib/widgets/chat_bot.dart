import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ============================================================================
// CHAT SERVICE - Manages contract context and API calls
// ============================================================================

class ChatService {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  Map<String, dynamic>? _contractData;
  final List<ChatMessage> _conversationHistory = [];

  void setContractData(Map<String, dynamic>? data) {
    _contractData = data;
    print('📄 Contract data updated in ChatService');
  }

  Map<String, dynamic>? get contractData => _contractData;
  List<ChatMessage> get conversationHistory => _conversationHistory;

  void addMessage(ChatMessage message) {
    _conversationHistory.add(message);
  }

  void clearHistory() {
    _conversationHistory.clear();
  }

  Future<String> sendMessage(String message) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:8000/chat/ask'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'contract_data': _contractData,
          'conversation_history': _conversationHistory
              .map((msg) => {'role': msg.role, 'content': msg.content})
              .toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['response'] ?? 'No response from assistant';
      } else {
        throw Exception('Failed to get response');
      }
    } catch (e) {
      print('❌ Chat API error: $e');
      return 'Sorry, I encountered an error. Please try again.';
    }
  }
}

// ============================================================================
// CHAT MESSAGE MODEL
// ============================================================================

class ChatMessage {
  final String role; // "user" or "assistant"
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

// ============================================================================
// FLOATING CHAT BUTTON - Bottom right corner
// ============================================================================

class FloatingChatButton extends StatefulWidget {
  const FloatingChatButton({super.key});

  @override
  State<FloatingChatButton> createState() => _FloatingChatButtonState();
}

class _FloatingChatButtonState extends State<FloatingChatButton>
    with SingleTickerProviderStateMixin {
  bool _isChatOpen = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleChat() {
    setState(() {
      _isChatOpen = !_isChatOpen;
      if (_isChatOpen) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Chat Window
        if (_isChatOpen)
          Positioned(
            bottom: 90,
            right: 20,
            child: ScaleTransition(
              scale: _scaleAnimation,
              alignment: Alignment.bottomRight,
              child: _ChatWindow(onClose: _toggleChat),
            ),
          ),

        // Chat Button
        Positioned(
          bottom: 20,
          right: 20,
          child: _ChatToggleButton(
            isOpen: _isChatOpen,
            onTap: _toggleChat,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CHAT TOGGLE BUTTON
// ============================================================================

class _ChatToggleButton extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onTap;

  const _ChatToggleButton({
    required this.isOpen,
    required this.onTap,
  });

  @override
  State<_ChatToggleButton> createState() => _ChatToggleButtonState();
}

class _ChatToggleButtonState extends State<_ChatToggleButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFB1597).withOpacity(_isHovered ? 0.6 : 0.4),
                blurRadius: _isHovered ? 20 : 15,
                spreadRadius: _isHovered ? 4 : 2,
              ),
            ],
          ),
          child: Icon(
            widget.isOpen ? Icons.close : Icons.chat_bubble_outline,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT WINDOW
// ============================================================================

class _ChatWindow extends StatefulWidget {
  final VoidCallback onClose;

  const _ChatWindow({required this.onClose});

  @override
  State<_ChatWindow> createState() => _ChatWindowState();
}

class _ChatWindowState extends State<_ChatWindow> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add welcome message
    _messages.add(ChatMessage(
      role: 'assistant',
      content: _chatService.contractData != null
          ? "Hi! I've reviewed your lease contract. Ask me anything about it, or I can help you negotiate better terms!"
          : "Hi! I'm your car lease assistant. Upload a contract to get started, or ask me general questions about car leases.",
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    // Add user message
    setState(() {
      _messages.add(ChatMessage(role: 'user', content: text));
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    // Get AI response
    final response = await _chatService.sendMessage(text);

    // Add assistant message
    setState(() {
      _messages.add(ChatMessage(role: 'assistant', content: response));
      _isLoading = false;
    });
    
    // Save to history
    _chatService.addMessage(_messages[_messages.length - 2]); // user msg
    _chatService.addMessage(_messages[_messages.length - 1]); // assistant msg
    
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    return Container(
      width: 380,
      height: 550,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1C0B14),
            Color(0xFF2D1622),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFB1597), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            // Header
            _ChatHeader(
              hasContract: _chatService.contractData != null,
              onClose: widget.onClose,
            ),

            // Messages
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return const _TypingIndicator();
                  }
                  return _MessageBubble(message: _messages[index]);
                },
              ),
            ),

            // Input
            _ChatInput(
              controller: _messageController,
              onSend: _sendMessage,
              isLoading: _isLoading,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT HEADER
// ============================================================================

class _ChatHeader extends StatelessWidget {
  final bool hasContract;
  final VoidCallback onClose;

  const _ChatHeader({
    required this.hasContract,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.support_agent, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Lease Assistant',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  hasContract ? 'Contract Loaded ✓' : 'No Contract',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MESSAGE BUBBLE
// ============================================================================

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFFFB1597),
              child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: isUser
                    ? const LinearGradient(
                        colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
                      )
                    : null,
                color: isUser ? null : const Color(0xFF3F1D2B),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: SelectableText(
                message.content,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF4A2438),
              child: Icon(Icons.person, color: Colors.white, size: 18),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// TYPING INDICATOR
// ============================================================================

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFFB1597),
            child: Icon(Icons.smart_toy, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF3F1D2B),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                _TypingDot(delay: 0),
                const SizedBox(width: 4),
                _TypingDot(delay: 200),
                const SizedBox(width: 4),
                _TypingDot(delay: 400),
              ],
            ),
          ),
        ],
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

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
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
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Color(0xFFFB1597),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ============================================================================
// CHAT INPUT
// ============================================================================

class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isLoading;

  const _ChatInput({
    required this.controller,
    required this.onSend,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1C0B14),
        border: Border(
          top: BorderSide(color: const Color(0xFFFB1597).withOpacity(0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: !isLoading,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: const Color(0xFF3F1D2B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => onSend(),
              maxLines: null,
            ),
          ),
          const SizedBox(width: 8),
          _SendButton(
            onTap: onSend,
            isLoading: isLoading,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SEND BUTTON
// ============================================================================

class _SendButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isLoading;

  const _SendButton({
    required this.onTap,
    required this.isLoading,
  });

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.isLoading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFB1597), Color(0xFFFD86C8)],
            ),
            shape: BoxShape.circle,
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFFFB1597).withOpacity(0.5),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            widget.isLoading ? Icons.hourglass_empty : Icons.send,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}