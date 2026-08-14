import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/app_theme.dart';

class ChatMessage {
  final String text;
  final bool isMe;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isMe, required this.timestamp});
}

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  final List<String> _suggestions = [
    "How to post a request?",
    "Is payment secure?",
    "How to contact a seller?",
    "Contact support"
  ];

  @override
  void initState() {
    super.initState();
    _messages.add(
      ChatMessage(
        text: "Hi! I am the Arah AI Assistant. How can I help you today?",
        isMe: false,
        timestamp: DateTime.now(),
      ),
    );
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

  void _handleSend(String text) {
    if (text.trim().isEmpty) return;
    _controller.clear();
    
    setState(() {
      _messages.add(ChatMessage(text: text, isMe: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    // Simulate bot reply
    Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      final reply = _getBotResponse(text);
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(text: reply, isMe: false, timestamp: DateTime.now()));
      });
      _scrollToBottom();
    });
  }

  String _getBotResponse(String query) {
    final clean = query.toLowerCase();
    if (clean.contains("post") || clean.contains("request") || clean.contains("create")) {
      return "To post a task request, go to the Home screen (Discover) and tap the '+' floating action button in the bottom right corner. Fill in the details, budget, and click 'Post Request'.";
    }
    if (clean.contains("payment") || clean.contains("secure") || clean.contains("pay")) {
      return "All payments on Arah are secure. The funds are held safely in escrow and only released to the seller once you approve the completed task. Arah takes a 9% platform commission from the payout, so the seller receives 91% of the order amount.";
    }
    if (clean.contains("contact") || clean.contains("seller") || clean.contains("chat")) {
      return "You can communicate with a seller by tapping 'Chat' on the task or 'Message to Bid' on the workspace screen. This opens a real-time messaging channel.";
    }
    if (clean.contains("support") || clean.contains("help") || clean.contains("email")) {
      return "Our support team is available 24/7. You can reach out directly via email at support@arahapp.com.";
    }
    if (clean.contains("hello") || clean.contains("hi") || clean.contains("hey")) {
      return "Hello! How can I assist you with Arah App today?";
    }
    return "I'm sorry, I didn't quite catch that. You can try tapping one of the suggested questions below or email support@arahapp.com for help!";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        foregroundColor: Theme.of(context).appBarTheme.iconTheme?.color,
  automaticallyImplyLeading: false,
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  surfaceTintColor: Colors.transparent,
  scrolledUnderElevation: 0,
  elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.arahPurple.withOpacity(0.1),
              ),
              padding: const EdgeInsets.all(6),
              child: const Icon(Icons.psychology, color: AppTheme.arahPurple, size: 24),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Arah Assistant",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const Text(
                  "AI Bot - active",
                  style: TextStyle(fontSize: 12, color: AppTheme.successGreen),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _buildMessageBubble(message);
              },
            ),
          ),
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: Row(
                children: [
                  Text(
                    "Arah Assistant is typing...",
                    style: TextStyle(fontSize: 13, color: AppTheme.colorsOf(context).secondaryText, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          _buildSuggestionsList(),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: msg.isMe ? AppTheme.arahPurple : Theme.of(context).cardColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: msg.isMe ? const Radius.circular(12) : const Radius.circular(0),
              bottomRight: msg.isMe ? const Radius.circular(0) : const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.colorsOf(context).shadow,
                blurRadius: 2,
                offset: const Offset(0, 1),
              )
            ],
          ),
          child: Text(
            msg.text,
            style: TextStyle(
              color: msg.isMe
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ActionChip(
              label: Text(
                suggestion,
                style: const TextStyle(color: AppTheme.arahPurple, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              backgroundColor: Theme.of(context).cardColor,
              side: const BorderSide(color: AppTheme.arahPurple, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              onPressed: () => _handleSend(suggestion),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInput() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    hintText: "Ask something...",
                    border: InputBorder.none,
                  ),
                  onSubmitted: _handleSend,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppTheme.arahPurple,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: () => _handleSend(_controller.text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
