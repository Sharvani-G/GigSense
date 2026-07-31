import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'playful_widgets.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystemError;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isSystemError = false,
  });
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add default intro message from the app
    _messages.add(
      ChatMessage(
        text: "Hey — ask me anything about your pay, your rights, or how to raise a complaint. I'll look at your recent jobs if it's relevant.",
        isUser: false,
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    final Uri url = Uri.parse('$baseUrl/chat');
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': text,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add(ChatMessage(
            text: data['response'] ?? 'I could not generate a response.',
            isUser: false,
          ));
        });
      } else if (response.statusCode == 503) {
        final data = json.decode(response.body);
        setState(() {
          _messages.add(ChatMessage(
            text: data['error'] ?? 'Assistant is temporarily unavailable — please try again in a moment.',
            isUser: false,
            isSystemError: true,
          ));
        });
      } else {
        throw Exception("Server returned status code ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Chat query failed: $e");
      setState(() {
        _messages.add(ChatMessage(
          text: "I'm having trouble responding right now — try again in a moment.",
          isUser: false,
          isSystemError: true,
        ));
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showQuickReplies = !_isLoading && (_messages.length <= 1 || !_messages.last.isUser);

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: PlayfulColors.border, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: PlayfulColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: PlayfulColors.border, width: 2),
                    ),
                    child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "GIGCHAT",
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: PlayfulColors.foreground,
                        ),
                      ),
                      Text(
                        "Worker pay & rights assistant",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: PlayfulColors.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Message Board
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _messages.length && _isLoading) {
                    return const _TypingIndicatorBubble();
                  }

                  final message = _messages[index];
                  return _MessageBubble(message: message);
                },
              ),
            ),

            // Quick replies & Input Panel
            Container(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: PlayfulColors.border, width: 2),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Quick reply chips
                  if (showQuickReplies) ...[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          QuickReplyChip(
                            text: "Is my pay fair?",
                            onTap: () => _sendMessage("Is my pay fair?"),
                          ),
                          const SizedBox(width: 8),
                          QuickReplyChip(
                            text: "What are my rights?",
                            onTap: () => _sendMessage("What are my rights?"),
                          ),
                          const SizedBox(width: 8),
                          QuickReplyChip(
                            text: "How do I complain?",
                            onTap: () => _sendMessage("How do I complain?"),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Input Box
                  Row(
                    children: [
                      PlayfulMicButton(
                        onSpeechResult: (text) {
                          setState(() {
                            _inputController.text = text;
                          });
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: PlayfulInput(
                          labelText: "",
                          hintText: "Type your question...",
                          controller: _inputController,
                        ),
                      ),
                      const SizedBox(width: 12),
                      PlayfulSendButton(
                        onTap: () => _sendMessage(_inputController.text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "General guidance, not legal advice.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      color: PlayfulColors.mutedForeground,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack, // Playful bounce!
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _buildBubbleContent(),
      ),
    );
  }

  Widget _buildBubbleContent() {
    final message = widget.message;
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 40),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: PlayfulColors.accent,
            border: Border.all(color: PlayfulColors.border, width: 2),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomRight: Radius.circular(16),
              bottomLeft: Radius.circular(0),
            ),
          ),
          child: Text(
            message.text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    // GigChat Response
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PlayfulColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: PlayfulColors.border, width: 2),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 40),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: message.isSystemError ? Colors.red.shade50 : PlayfulColors.background,
                  border: Border.all(
                    color: message.isSystemError ? Colors.red.shade900 : PlayfulColors.border,
                    width: 2,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(0),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: PlayfulColors.border,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.plusJakartaSans(
                    color: message.isSystemError ? Colors.red.shade900 : PlayfulColors.foreground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TypingIndicatorBubble extends StatelessWidget {
  const _TypingIndicatorBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: PlayfulColors.accent,
                shape: BoxShape.circle,
                border: Border.all(color: PlayfulColors.border, width: 2),
              ),
              child: const Icon(Icons.shield_outlined, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: PlayfulColors.background,
                border: Border.all(color: PlayfulColors.border, width: 2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(0),
                ),
                boxShadow: const [
                  BoxShadow(
                    color: PlayfulColors.border,
                    offset: Offset(4, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
              child: const TypingIndicator(),
            ),
          ],
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: -8.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    for (int i = 0; i < 3; i++) {
      await Future.delayed(Duration(milliseconds: i * 150));
      if (mounted) {
        _controllers[i].repeat(reverse: true);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text(
        "...",
        style: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: PlayfulColors.foreground,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controllers[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.0),
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: PlayfulColors.foreground,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

class QuickReplyChip extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const QuickReplyChip({super.key, required this.text, required this.onTap});

  @override
  State<QuickReplyChip> createState() => _QuickReplyChipState();
}

class _QuickReplyChipState extends State<QuickReplyChip> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isTapped = true),
      onTapUp: (_) {
        Future.delayed(const Duration(milliseconds: 150), () {
          if (mounted) setState(() => _isTapped = false);
        });
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isTapped = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isTapped ? PlayfulColors.tertiary : Colors.transparent,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: PlayfulColors.border, width: 2),
        ),
        child: Text(
          widget.text,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: PlayfulColors.foreground,
          ),
        ),
      ),
    );
  }
}

class PlayfulSendButton extends StatefulWidget {
  final VoidCallback onTap;

  const PlayfulSendButton({super.key, required this.onTap});

  @override
  State<PlayfulSendButton> createState() => _PlayfulSendButtonState();
}

class _PlayfulSendButtonState extends State<PlayfulSendButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    Offset translateOffset = _isPressed ? const Offset(1, 1) : Offset.zero;
    Offset shadowOffset = _isPressed ? const Offset(1, 1) : const Offset(2, 2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(translateOffset.dx, translateOffset.dy, 0),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: PlayfulColors.accent,
          shape: BoxShape.circle,
          border: Border.all(color: PlayfulColors.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: PlayfulColors.border,
              offset: shadowOffset,
              blurRadius: 0,
            ),
          ],
        ),
        child: const Icon(
          Icons.send,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}


