import 'dart:convert';
import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../i18n/strings.dart';
import 'playful_widgets.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final bool isSystemError;

  ChatMessage({
    required this.id,
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String? _activeSessionId;
  List<ChatMessage> _localMessages = [];
  bool _isLoading = false;
  bool _initializing = true;
  StreamSubscription<String>? _streamSubscription;

  Future<void> _fetchMessagesForSession(String sessionId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chatSessions')
          .doc(sessionId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .get();

      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        return ChatMessage(
          id: doc.id,
          text: data['content'] ?? '',
          isUser: data['role'] == 'user',
          isSystemError: data['is_system_error'] ?? false,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _localMessages = messages;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("Error fetching messages: $e");
    }
  }

  final FlutterTts _flutterTts = FlutterTts();
  String? _speakingMessageId;
  bool _isTtsAvailable = true;
  final Map<String, bool> _availableLanguages = {};

  Future<void> _checkLanguagesAvailability() async {
    const locales = ['en-IN', 'hi-IN', 'kn-IN', 'te-IN', 'ta-IN', 'ml-IN'];
    for (var locale in locales) {
      try {
        final available = await _flutterTts.isLanguageAvailable(locale);
        _availableLanguages[locale] = (available == true || available == 1);
      } catch (e) {
        _availableLanguages[locale] = false;
      }
    }
    if (mounted) {
      setState(() {});
    }
  }

  String detectLanguageLocale(String text, String preferredLang) {
    if (RegExp(r'[\u0C80-\u0CFF]').hasMatch(text)) {
      return 'kn-IN';
    }
    if (RegExp(r'[\u0900-\u097F]').hasMatch(text)) {
      return 'hi-IN';
    }
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(text)) {
      return 'te-IN';
    }
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(text)) {
      return 'ta-IN';
    }
    if (RegExp(r'[\u0D00-\u0D7F]').hasMatch(text)) {
      return 'ml-IN';
    }
    const mapping = {
      'en': 'en-IN',
      'hi': 'hi-IN',
      'kn': 'kn-IN',
      'te': 'te-IN',
      'ta': 'ta-IN',
      'ml': 'ml-IN',
    };
    return mapping[preferredLang.toLowerCase()] ?? 'en-IN';
  }

  @override
  void initState() {
    super.initState();
    MainNavigationController.activeSessionId.addListener(() => _onDeepLinkSessionChanged());
    _initTts();
    _checkLanguagesAvailability();
    _initializeChat();
  }

  void _initTts() {
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _speakingMessageId = null;
        });
      }
    });
    _flutterTts.setCancelHandler(() {
      if (mounted) {
        setState(() {
          _speakingMessageId = null;
        });
      }
    });
    _flutterTts.setErrorHandler((msg) {
      debugPrint("TTS error: $msg");
      if (mounted) {
        setState(() {
          _speakingMessageId = null;
        });
      }
    });
  }

  Future<void> _speakMessage(String messageId, String text) async {
    if (_speakingMessageId == messageId) {
      await _flutterTts.stop();
      setState(() {
        _speakingMessageId = null;
      });
      return;
    }

    if (_speakingMessageId != null) {
      await _flutterTts.stop();
    }

    setState(() {
      _speakingMessageId = messageId;
    });

    try {
      final preferredLang = StringsProvider.instance.lang;
      final resolvedLocale = detectLanguageLocale(text, preferredLang);
      await _flutterTts.setLanguage(resolvedLocale);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("Failed to play TTS: $e");
      if (mounted) {
        setState(() {
          _speakingMessageId = null;
          _isTtsAvailable = false;
        });
      }
    }
  }

  @override
  void dispose() {
    MainNavigationController.activeSessionId.removeListener(() => _onDeepLinkSessionChanged());
    _streamSubscription?.cancel();
    _flutterTts.stop();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _onDeepLinkSessionChanged() async {
    final deepLinkId = MainNavigationController.activeSessionId.value;
    if (deepLinkId != null && mounted) {
      setState(() {
        _activeSessionId = deepLinkId;
      });
      await _fetchMessagesForSession(deepLinkId);
      // Clear it so it doesn't re-trigger
      MainNavigationController.activeSessionId.value = null;
      
      final msg = MainNavigationController.initialMessageToSend;
      if (msg != null) {
        MainNavigationController.initialMessageToSend = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sendMessage(msg);
        });
      }
    }
  }

  Future<void> _initializeChat() async {
    final deepLinkId = MainNavigationController.activeSessionId.value;
    if (deepLinkId != null) {
      setState(() {
        _activeSessionId = deepLinkId;
        _initializing = false;
      });
      await _fetchMessagesForSession(deepLinkId);
      MainNavigationController.activeSessionId.value = null;

      final msg = MainNavigationController.initialMessageToSend;
      if (msg != null) {
        MainNavigationController.initialMessageToSend = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _sendMessage(msg);
        });
      }
      return;
    }

    await _loadRecentSession();
    if (mounted) {
      setState(() {
        _initializing = false;
      });
    }
  }

  Future<void> _loadRecentSession() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chatSessions')
          .orderBy('updatedAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        if (mounted) {
          setState(() {
            _activeSessionId = snapshot.docs.first.id;
          });
          await _fetchMessagesForSession(snapshot.docs.first.id);
        }
      } else {
        await _createNewSession();
      }
    } catch (e) {
      debugPrint("Error loading recent session: $e");
      // Fallback: create offline temp session ID
      if (mounted) {
        setState(() {
          _activeSessionId = 'temp_offline_session';
        });
      }
    }
  }

  Future<String> _createNewSession({String title = "New Chat"}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('chatSessions')
        .doc();

    final sessionId = docRef.id;

    try {
      await docRef.set({
        'title': title,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Failed to save new session to Firestore: $e");
    }

    _streamSubscription?.cancel();
    _streamSubscription = null;
    if (mounted) {
      setState(() {
        _activeSessionId = sessionId;
        _localMessages = [];
        _isLoading = false;
      });
    }
    return sessionId;
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

  Future<void> _autoTitleIfNeeded(String sessionId, String text) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chatSessions')
          .doc(sessionId)
          .get();

      if (doc.exists) {
        final currentTitle = doc.data()?['title'] ?? 'New Chat';
        if (currentTitle == 'New Chat') {
          final words = text.trim().split(RegExp(r'\s+'));
          final truncated = words.take(6).join(' ');
          final finalTitle = words.length > 6 ? '$truncated...' : truncated;
          await doc.reference.update({'title': finalTitle});
        }
      }
    } catch (e) {
      debugPrint("Error auto-titling: $e");
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Cancel any previous active stream subscription before sending a new one
    await _streamSubscription?.cancel();
    _streamSubscription = null;

    if (_activeSessionId == null) {
      await _createNewSession(title: "New Chat");
    }

    final sessionId = _activeSessionId!;
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

    final String userMsgId = 'user_${DateTime.now().millisecondsSinceEpoch}';
    final String assistantMsgId = 'assistant_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isLoading = true;
      _localMessages.add(ChatMessage(id: userMsgId, text: text, isUser: true));
      _localMessages.add(ChatMessage(id: assistantMsgId, text: "", isUser: false)); // Empty assistant message for streaming
    });
    _inputController.clear();
    _scrollToBottom();

    // Auto title asynchronously
    _autoTitleIfNeeded(sessionId, text);

    String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    if (!kIsWeb && Platform.isAndroid && (baseUrl.contains("127.0.0.1") || baseUrl.contains("localhost"))) {
      baseUrl = baseUrl.replaceAll("127.0.0.1", "10.0.2.2").replaceAll("localhost", "10.0.2.2");
    }
    final Uri url = Uri.parse('$baseUrl/chat');

    try {
      final client = http.Client();
      final request = http.Request('POST', url);
      request.headers['Content-Type'] = 'application/json';
      request.headers['ngrok-skip-browser-warning'] = 'true';
      request.body = json.encode({
        'message': text,
        'user_id': userId,
        'session_id': sessionId,
      });
      
      final response = await client.send(request);
      
      if (response.statusCode != 200) {
        throw Exception("Server returned status code ${response.statusCode}");
      }
      
      _streamSubscription = response.stream.transform(utf8.decoder).transform(const LineSplitter()).listen(
        (line) {
          if (line.trim().isEmpty) return;
          try {
            final data = json.decode(line);
            if (data['error'] != null) {
              if (mounted) {
                setState(() {
                  final idx = _localMessages.indexWhere((m) => m.id == assistantMsgId);
                  if (idx != -1) {
                    _localMessages[idx] = ChatMessage(
                      id: assistantMsgId,
                      text: data['error'],
                      isUser: false,
                      isSystemError: true,
                    );
                  }
                });
              }
            } else if (data['chunk'] != null) {
              if (mounted) {
                setState(() {
                  final idx = _localMessages.indexWhere((m) => m.id == assistantMsgId);
                  if (idx != -1) {
                    _localMessages[idx] = ChatMessage(
                      id: assistantMsgId,
                      text: _localMessages[idx].text + data['chunk'],
                      isUser: false,
                    );
                  }
                });
                _scrollToBottom();
              }
            }
          } catch (_) {}
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
          client.close();
          _streamSubscription = null;
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              final idx = _localMessages.indexWhere((m) => m.id == assistantMsgId);
              if (idx != -1) {
                _localMessages[idx] = ChatMessage(
                  id: assistantMsgId,
                  text: "I'm having trouble responding right now — try again in a moment.",
                  isUser: false,
                  isSystemError: true,
                );
              }
              _isLoading = false;
            });
          }
          client.close();
          _streamSubscription = null;
        }
      );
    } catch (e) {
      debugPrint("Chat query failed: $e");
      if (mounted) {
        setState(() {
          final idx = _localMessages.indexWhere((m) => m.id == assistantMsgId);
          if (idx != -1) {
            _localMessages[idx] = ChatMessage(
              id: assistantMsgId,
              text: "I'm having trouble responding right now — try again in a moment.",
              isUser: false,
              isSystemError: true,
            );
          }
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDrawer() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
    return Drawer(
      backgroundColor: PlayfulColors.background,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: PlayfulColors.border, width: 2),
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // New Chat Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: PlayfulButton(
                  onPressed: () async {
                    Navigator.pop(context); // close drawer
                    await _createNewSession();
                  },
                  child: Text(StringsProvider.instance.t('chat_new')),
                ),
              ),
              const Divider(color: PlayfulColors.border, height: 2, thickness: 2),

              // Sessions list
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('chatSessions')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: PlayfulColors.accent),
                      );
                    }

                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: PlayfulColors.mutedForeground,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              StringsProvider.instance.t('chat_empty_drawer'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: PlayfulColors.mutedForeground,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final sessionId = doc.id;
                        final title = data['title'] ?? 'New Chat';
                        final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();
                        final isSelected = sessionId == _activeSessionId;

                        return _SessionRow(
                          key: ValueKey(sessionId),
                          sessionId: sessionId,
                          title: title,
                          updatedAt: updatedAt,
                          isSelected: isSelected,
                          onSelect: () {
                            _streamSubscription?.cancel();
                            _streamSubscription = null;
                            setState(() {
                              _activeSessionId = sessionId;
                              _localMessages = [];
                              _isLoading = false;
                            });
                            _fetchMessagesForSession(sessionId);
                            Navigator.pop(context); // Close drawer
                          },
                          onRename: (newTitle) async {
                            await doc.reference.update({'title': newTitle});
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initializing) {
      return const Scaffold(
        backgroundColor: PlayfulColors.background,
        body: Center(
          child: CircularProgressIndicator(color: PlayfulColors.accent),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: PlayfulColors.background,
      drawer: _buildDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            // App Bar with Hamburger Drawer Trigger
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: PlayfulColors.border, width: 2),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu, color: PlayfulColors.foreground),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                  const SizedBox(width: 8),
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
                  Expanded(
                    child: Column(
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
                          StringsProvider.instance.t('chat_subtitle'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: PlayfulColors.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Message Board
            Expanded(
              child: Builder(
                builder: (context) {
                  if (_localMessages.isEmpty && !_isLoading) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: PlayfulColors.mutedForeground,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              StringsProvider.instance.t('chat_intro'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                color: PlayfulColors.mutedForeground,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: _localMessages.length,
                    itemBuilder: (context, index) {
                      final message = _localMessages[index];
                      // Show typing indicator if it's the last message, is assistant, is loading, and text is empty
                      if (index == _localMessages.length - 1 && !message.isUser && _isLoading && message.text.isEmpty) {
                        return const _TypingIndicatorBubble();
                      }

                      final isSpeaking = _speakingMessageId == message.id;
                      final String messageLocale = detectLanguageLocale(message.text, StringsProvider.instance.lang);
                      final bool isLangAvailable = _availableLanguages[messageLocale] ?? true;

                      return _MessageBubble(
                        key: ValueKey(message.id),
                        message: message,
                        messageId: message.id,
                        isSpeaking: isSpeaking,
                        onSpeakTap: _isTtsAvailable && !message.isUser && isLangAvailable
                            ? () => _speakMessage(message.id, message.text)
                            : null,
                      );
                    },
                  );
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
                  Builder(
                    builder: (context) {
                      final bool showQuickReplies = !_isLoading && _localMessages.isEmpty;

                      if (!showQuickReplies) return const SizedBox.shrink();

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                QuickReplyChip(
                                  text: StringsProvider.instance.t('chip_pay_fair'),
                                  onTap: () => _sendMessage(StringsProvider.instance.t('chip_pay_fair')),
                                ),
                                const SizedBox(width: 8),
                                QuickReplyChip(
                                  text: StringsProvider.instance.t('chip_rights'),
                                  onTap: () => _sendMessage(StringsProvider.instance.t('chip_rights')),
                                ),
                                const SizedBox(width: 8),
                                QuickReplyChip(
                                  text: StringsProvider.instance.t('chip_complain'),
                                  onTap: () => _sendMessage(StringsProvider.instance.t('chip_complain')),
                                ),
                                const SizedBox(width: 8),
                                QuickReplyChip(
                                  text: StringsProvider.instance.t('chip_deductions'),
                                  onTap: () => _sendMessage(StringsProvider.instance.t('chip_deductions')),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      );
                    },
                  ),

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
                      const SizedBox(width: 8),
                      PlayfulImagePickerButton(
                        onLoadingChanged: (loading) {
                          setState(() {
                            _isLoading = loading;
                          });
                        },
                        onImageScanned: (prompt) {
                          _sendMessage(prompt);
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: PlayfulInput(
                          labelText: "",
                          hintText: StringsProvider.instance.t('chat_hint'),
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
                    StringsProvider.instance.t('chat_disclaimer'),
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

class _SessionRow extends StatefulWidget {
  final String sessionId;
  final String title;
  final DateTime? updatedAt;
  final bool isSelected;
  final VoidCallback onSelect;
  final Function(String) onRename;

  const _SessionRow({
    super.key,
    required this.sessionId,
    required this.title,
    required this.updatedAt,
    required this.isSelected,
    required this.onSelect,
    required this.onRename,
  });

  @override
  State<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends State<_SessionRow> {
  bool _isEditing = false;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.title);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getRelativeTime(DateTime? dt) {
    if (dt == null) return "";
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays == 1) return "Yesterday";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: widget.isSelected ? PlayfulColors.muted : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: widget.isSelected
            ? Border.all(color: PlayfulColors.border, width: 2)
            : null,
      ),
      child: _isEditing
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PlayfulColors.foreground,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (val) {
                        if (val.trim().isNotEmpty) {
                          widget.onRename(val.trim());
                        }
                        setState(() {
                          _isEditing = false;
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, size: 18, color: PlayfulColors.accent),
                    onPressed: () {
                      if (_controller.text.trim().isNotEmpty) {
                        widget.onRename(_controller.text.trim());
                      }
                      setState(() {
                        _isEditing = false;
                      });
                    },
                  ),
                ],
              ),
            )
          : Material(
              color: Colors.transparent,
              child: ListTile(
                onTap: widget.onSelect,
                title: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w600,
                    color: PlayfulColors.foreground,
                    fontSize: 14,
                  ),
                ),
                subtitle: widget.updatedAt != null
                    ? Text(
                        _getRelativeTime(widget.updatedAt),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          color: PlayfulColors.mutedForeground,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : null,
                trailing: IconButton(
                  icon: const Icon(Icons.edit_note, size: 20, color: PlayfulColors.mutedForeground),
                  onPressed: () {
                    setState(() {
                      _isEditing = true;
                      _controller.text = widget.title;
                    });
                  },
                ),
              ),
            ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final ChatMessage message;
  final String? messageId;
  final bool isSpeaking;
  final VoidCallback? onSpeakTap;

  const _MessageBubble({
    super.key,
    required this.message,
    this.messageId,
    this.isSpeaking = false,
    this.onSpeakTap,
  });

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
      curve: Curves.easeOutBack,
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
            message.text.startsWith('[IMAGE SCAN RESULT]')
                ? '📷 Scanned Receipt Details'
                : message.text.startsWith('[IMAGE RAW TEXT]')
                    ? '📷 Scanned General Image'
                    : message.text,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    if (message.text.isEmpty) {
      return const _TypingIndicatorBubble();
    }

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
                padding: const EdgeInsets.only(left: 16, top: 16, right: 16, bottom: 8),
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
                child: Stack(
                  children: [
                    Padding(
                      padding: widget.onSpeakTap != null
                          ? const EdgeInsets.only(bottom: 28)
                          : EdgeInsets.zero,
                      child: PlayfulMarkdownText(
                        text: message.text,
                        style: GoogleFonts.plusJakartaSans(
                          color: message.isSystemError ? Colors.red.shade900 : PlayfulColors.foreground,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (widget.onSpeakTap != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: widget.onSpeakTap,
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.bottomRight,
                            child: Icon(
                              widget.isSpeaking ? Icons.stop : Icons.volume_up,
                              size: 18,
                              color: PlayfulColors.mutedForeground,
                            ),
                          ),
                        ),
                      ),
                  ],
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

class PlayfulImagePickerButton extends StatefulWidget {
  final ValueChanged<String> onImageScanned;
  final ValueChanged<bool> onLoadingChanged;

  const PlayfulImagePickerButton({
    super.key,
    required this.onImageScanned,
    required this.onLoadingChanged,
  });

  @override
  State<PlayfulImagePickerButton> createState() => _PlayfulImagePickerButtonState();
}

class _PlayfulImagePickerButtonState extends State<PlayfulImagePickerButton> {
  bool _isPressed = false;

  Future<void> _pickAndScanImage() async {
    final picker = ImagePicker();
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFDF5),
          border: Border(top: BorderSide(color: PlayfulColors.border, width: 4)),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "SELECT IMAGE SOURCE",
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: PlayfulColors.foreground,
              ),
            ),
            const SizedBox(height: 16),
            PlayfulButton(
              onPressed: () => Navigator.pop(context, ImageSource.camera),
              child: const Text("📸 TAKE PHOTO"),
            ),
            const SizedBox(height: 12),
            PlayfulButton(
              onPressed: () => Navigator.pop(context, ImageSource.gallery),
              child: const Text("📁 CHOOSE FROM GALLERY"),
            ),
            const SizedBox(height: 12),
            PlayfulButton(
              onPressed: () => Navigator.pop(context),
              backgroundColor: const Color(0xFFE2E8F0),
              child: const Text("CANCEL", style: TextStyle(color: PlayfulColors.foreground)),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await picker.pickImage(source: source, imageQuality: 50, maxWidth: 1024);
    if (pickedFile == null) return;

    widget.onLoadingChanged(true);
    
    String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    if (!kIsWeb && Platform.isAndroid && (baseUrl.contains("127.0.0.1") || baseUrl.contains("localhost"))) {
      baseUrl = baseUrl.replaceAll("127.0.0.1", "10.0.2.2").replaceAll("localhost", "10.0.2.2");
    }
    final Uri url = Uri.parse('$baseUrl/jobs/scan');

    try {
      final request = http.MultipartRequest('POST', url)
        ..headers['ngrok-skip-browser-warning'] = 'true'
        ..files.add(await http.MultipartFile.fromPath('file', pickedFile.path));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool relevant = data['relevant'] ?? false;
        final bool isBatch = data['is_batch'] ?? false;
        final String rawText = data['raw_text'] ?? '';

        String promptToSend = "";
        
        if (relevant) {
          if (isBatch) {
            final List<dynamic> candidates = data['candidates'] ?? [];
            promptToSend = "[IMAGE SCAN RESULT]: Batch screenshot detected with ${candidates.length} candidate trips. Details: ${json.encode(candidates)}. Explain these and summarize the pay fairness for each.";
          } else {
            final platform = data['platform'] ?? 'other';
            final fare = data['fare'];
            final dist = data['distance'];
            final dur = data['duration'];
            final base = data['base_fare'];
            final inc = data['incentive_amount'];
            final surge = data['surge_amount'];
            final ded = data['deduction_amount'];
            final reason = data['deduction_reason_stated'] ?? false;

            promptToSend = "[IMAGE SCAN RESULT]: Single trip screenshot analyzed.\n"
                "- Platform: $platform\n"
                "- Total Fare: $fare\n"
                "- Distance: $dist\n"
                "- Duration: $dur\n"
                "- Base Fare: $base\n"
                "- Incentive: $inc\n"
                "- Surge: $surge\n"
                "- Deduction: $ded (reason disclosed: $reason)\n"
                "Please analyze this gig trip receipt payout breakdown, legal compliance, and provide recommendations.";
          }
        } else {
          promptToSend = "[IMAGE RAW TEXT]: \"$rawText\". The user uploaded this screenshot or receipt in chat. Please interpret the details or answer the user's questions about it.";
        }

        widget.onImageScanned(promptToSend);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(StringsProvider.instance.t('err_failed_parse_receipt'))),
        );
      }
    } catch (e) {
      debugPrint("Error scanning image in chat: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StringsProvider.instance.t('err_connecting_scan_service'))),
      );
    } finally {
      widget.onLoadingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Offset translateOffset = _isPressed ? const Offset(1, 1) : Offset.zero;
    Offset shadowOffset = _isPressed ? const Offset(1, 1) : const Offset(2, 2);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _pickAndScanImage();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        transform: Matrix4.translationValues(translateOffset.dx, translateOffset.dy, 0),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
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
          Icons.image_outlined,
          color: PlayfulColors.foreground,
          size: 20,
        ),
      ),
    );
  }
}
