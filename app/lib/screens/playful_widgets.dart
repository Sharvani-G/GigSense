import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import '../i18n/strings.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'package:record/record.dart' as rec;
import 'package:path_provider/path_provider.dart';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;

// Playful Geometric Design System Colors
class PlayfulColors {
  static const Color background = Color(0xFFFFFDF5); // Warm Cream/Off-White
  static const Color foreground = Color(0xFF1E293B); // Slate 800
  static const Color muted = Color(0xFFF1F5F9); // Slate 100
  static const Color mutedForeground = Color(0xFF64748B); // Slate 500
  static const Color accent = Color(0xFF8B5CF6); // Vivid Violet (Primary)
  static const Color secondary = Color(0xFFF472B6); // Hot Pink (Playful pop)
  static const Color tertiary = Color(0xFFFBBF24); // Amber/Yellow
  static const Color quaternary = Color(0xFF34D399); // Emerald/Mint
  static const Color blue = Color(0xFF60A5FA); // Sky Blue
  static const Color orange = Color(0xFFFB923C); // Warm Orange
  static const Color teal = Color(0xFF2DD4BF); // Vibrant Teal
  static const Color border = Color(0xFF1E293B); // Dark border
  static const Color cardBg = Colors.white;
}

class PlayfulButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color backgroundColor;
  final double height;
  final bool fullWidth;

  const PlayfulButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor = PlayfulColors.accent,
    this.height = 56.0,
    this.fullWidth = true,
  });

  @override
  State<PlayfulButton> createState() => _PlayfulButtonState();
}

class _PlayfulButtonState extends State<PlayfulButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onPressed != null;

    Offset translateOffset;
    Offset shadowOffset;

    if (!isEnabled) {
      translateOffset = Offset.zero;
      shadowOffset = const Offset(2, 2);
    } else if (_isPressed) {
      translateOffset = const Offset(2, 2);
      shadowOffset = const Offset(2, 2);
    } else if (_isHovered) {
      translateOffset = const Offset(-2, -2);
      shadowOffset = const Offset(6, 6);
    } else {
      translateOffset = Offset.zero;
      shadowOffset = const Offset(4, 4);
    }

    final Color bg = isEnabled ? widget.backgroundColor : const Color(0xFFCBD5E1);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
        onTapUp: isEnabled ? (_) {
          setState(() => _isPressed = false);
          widget.onPressed!();
        } : null,
        onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutQuad,
          transform: Matrix4.translationValues(translateOffset.dx, translateOffset.dy, 0),
          height: widget.height,
          width: widget.fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9999), // pill shape
            border: Border.all(color: PlayfulColors.border, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: PlayfulColors.border,
                offset: shadowOffset,
                blurRadius: 0,
              ),
            ],
          ),
          child: Center(
            child: DefaultTextStyle(
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800, // Extra Bold
                color: isEnabled ? Colors.white : PlayfulColors.foreground,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class PlayfulInput extends StatefulWidget {
  final String labelText;
  final String? hintText;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final List<String>? dropdownItems;
  final void Function(String?)? onDropdownChanged;
  final String? selectedDropdownValue;
  final String? prefixText;
  final bool isHighlighted;
  final bool obscureText;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  const PlayfulInput({
    super.key,
    required this.labelText,
    this.hintText,
    this.controller,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.dropdownItems,
    this.onDropdownChanged,
    this.selectedDropdownValue,
    this.prefixText,
    this.isHighlighted = false,
    this.obscureText = false,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  @override
  State<PlayfulInput> createState() => _PlayfulInputState();
}

class _PlayfulInputState extends State<PlayfulInput> with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  late final AnimationController _pulseController;
  late final Animation<Color?> _pulseAnimation;



  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _pulseAnimation = ColorTween(
      begin: PlayfulColors.accent,
      end: const Color(0xFFCBD5E1),
    ).animate(_pulseController);

    if (widget.isHighlighted) {
      _pulseController.forward();
    }
  }

  @override
  void didUpdateWidget(covariant PlayfulInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _pulseController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.labelText.toUpperCase(),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.5,
            color: PlayfulColors.foreground,
          ),
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            Color borderColor = const Color(0xFFCBD5E1);
            if (_isFocused) {
              borderColor = PlayfulColors.accent;
            } else if (_pulseController.isAnimating) {
              borderColor = _pulseAnimation.value ?? borderColor;
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: 2.0,
                ),
                boxShadow: [
                  if (_isFocused)
                    const BoxShadow(
                      color: PlayfulColors.accent,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    )
                  else if (_pulseController.isAnimating)
                    BoxShadow(
                      color: PlayfulColors.accent.withOpacity(0.3 * (1.0 - _pulseController.value)),
                      offset: const Offset(4, 4),
                      blurRadius: 0,
                    ),
                ],
              ),
              child: child,
            );
          },
          child: widget.dropdownItems != null
              ? DropdownButtonFormField<String>(
                  value: widget.selectedDropdownValue,
                  focusNode: _focusNode,
                  validator: widget.validator,
                  onChanged: widget.onDropdownChanged,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: PlayfulColors.foreground.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: InputBorder.none,
                  ),
                  icon: const Icon(Icons.arrow_drop_down, color: PlayfulColors.foreground, size: 28),
                  dropdownColor: Colors.white,
                  style: GoogleFonts.plusJakartaSans(
                    color: PlayfulColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  items: widget.dropdownItems!
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.toLowerCase(),
                          child: Text(item),
                        ),
                      )
                      .toList(),
                )
              : TextFormField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  validator: widget.validator,
                  keyboardType: widget.keyboardType,
                  obscureText: widget.obscureText,
                  readOnly: widget.readOnly,
                  onTap: widget.onTap,
                  style: GoogleFonts.plusJakartaSans(
                    color: PlayfulColors.foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    prefixText: widget.prefixText,
                    prefixStyle: GoogleFonts.plusJakartaSans(
                      color: PlayfulColors.foreground,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    hintText: widget.hintText,
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: PlayfulColors.foreground.withOpacity(0.75),
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: InputBorder.none,
                    suffixIcon: widget.suffixIcon,
                  ),
                ),
        ),
      ],
    );
  }
}

class PlayfulBadge extends StatefulWidget {
  final String text;
  final bool isUnderpaid;

  const PlayfulBadge({
    super.key,
    required this.text,
    required this.isUnderpaid,
  });

  @override
  State<PlayfulBadge> createState() => _PlayfulBadgeState();
}

class _PlayfulBadgeState extends State<PlayfulBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color fill = widget.isUnderpaid ? PlayfulColors.secondary : PlayfulColors.quaternary;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Transform.rotate(
        angle: -2 * 3.1415926535 / 180, // -2 degrees in radians
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(9999), // pill shape
            border: Border.all(color: PlayfulColors.border, width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: PlayfulColors.border,
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              widget.text,
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayfulToggle extends StatelessWidget {
  final String activeOption;
  final ValueChanged<String> onChanged;

  const PlayfulToggle({
    super.key,
    required this.activeOption,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: PlayfulColors.border, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: PlayfulColors.border,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged("manual"),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: activeOption == "manual" ? PlayfulColors.foreground : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Center(
                  child: Text(
                    "Manual Entry",
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: activeOption == "manual" ? Colors.white : PlayfulColors.foreground,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged("scan"),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: activeOption == "scan" ? PlayfulColors.foreground : Colors.transparent,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 16,
                        color: activeOption == "scan" ? Colors.white : PlayfulColors.foreground,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "Scan Screenshot",
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: activeOption == "scan" ? Colors.white : PlayfulColors.foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayfulSecondaryButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double height;
  final bool fullWidth;

  const PlayfulSecondaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height = 56.0,
    this.fullWidth = true,
  });

  @override
  State<PlayfulSecondaryButton> createState() => _PlayfulSecondaryButtonState();
}

class _PlayfulSecondaryButtonState extends State<PlayfulSecondaryButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final Color bg = _isPressed
        ? PlayfulColors.tertiary.withOpacity(0.8)
        : (_isHovered ? PlayfulColors.tertiary : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onPressed();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          height: widget.height,
          width: widget.fullWidth ? double.infinity : null,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(9999), // pill shape
            border: Border.all(color: PlayfulColors.border, width: 2.0),
          ),
          child: Center(
            child: DefaultTextStyle(
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w800, // Extra Bold
                color: PlayfulColors.foreground,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

String getBCP47Locale(String langCode) {
  const mapping = {
    'en': 'en-IN',
    'hi': 'hi-IN',
    'kn': 'kn-IN',
    'te': 'te-IN',
    'ta': 'ta-IN',
    'ml': 'ml-IN',
  };
  return mapping[langCode.toLowerCase()] ?? 'en-IN';
}

String getLanguageName(String langCode) {
  const names = {
    'en': 'English',
    'hi': 'Hindi',
    'kn': 'Kannada',
    'te': 'Telugu',
    'ta': 'Tamil',
    'ml': 'Malayalam',
  };
  return names[langCode.toLowerCase()] ?? 'English';
}

class PlayfulMicButton extends StatefulWidget {
  final ValueChanged<String> onSpeechResult;
  final bool textOnLeft;

  const PlayfulMicButton({
    super.key,
    required this.onSpeechResult,
    this.textOnLeft = false,
  });

  @override
  State<PlayfulMicButton> createState() => _PlayfulMicButtonState();
}

class _PlayfulMicButtonState extends State<PlayfulMicButton> with SingleTickerProviderStateMixin {
  late final rec.AudioRecorder _audioRecorder;
  bool _isListening = false;
  bool _isProcessing = false;
  String? _recordedFilePath;

  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  Timer? _timeoutTimer;

  final List<String> _supportedLanguages = ['en', 'hi', 'kn', 'te', 'ta', 'ml'];
  late String _currentOverrideLang;

  @override
  void initState() {
    super.initState();
    _currentOverrideLang = StringsProvider.instance.lang;
    if (!_supportedLanguages.contains(_currentOverrideLang)) {
      _currentOverrideLang = 'en';
    }

    _audioRecorder = rec.AudioRecorder();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _handleSttError() {
    _timeoutTimer?.cancel();
    _pulseController.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _isProcessing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StringsProvider.instance.t('stt_didnt_catch'),
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: PlayfulColors.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isDenied || status.isPermanentlyDenied) {
      if (status.isPermanentlyDenied) {
        _showPermissionDialog();
        return false;
      }
      status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        _showPermissionDialog();
        return false;
      }
    }
    return true;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(StringsProvider.instance.t('stt_mic_access_req'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(StringsProvider.instance.t('stt_mic_access_desc'), style: GoogleFonts.plusJakartaSans()),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: PlayfulColors.border, width: 2)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(StringsProvider.instance.t('stt_cancel'), style: GoogleFonts.plusJakartaSans(color: PlayfulColors.foreground)),
          ),
          PlayfulSecondaryButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              openAppSettings();
            },
            child: Text(StringsProvider.instance.t('stt_open_settings')),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleListening() async {
    if (_isProcessing) return;

    final hasPerm = await _requestMicrophonePermission();
    if (!hasPerm) return;

    if (_isListening) {
      _timeoutTimer?.cancel();
      _pulseController.stop();
      setState(() {
        _isListening = false;
        _isProcessing = true;
      });

      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          _recordedFilePath = path;
          await _uploadAndTranscribe();
        } else {
          _handleSttError();
        }
      } catch (e) {
        debugPrint("Error stopping recording: $e");
        _handleSttError();
      }
    } else {
      try {
        if (await _audioRecorder.hasPermission()) {
          setState(() {
            _isListening = true;
            _isProcessing = false;
          });
          if (!MediaQuery.of(context).disableAnimations) {
            _pulseController.repeat(reverse: true);
          }

          _timeoutTimer = Timer(const Duration(seconds: 15), () {
            if (_isListening && mounted) {
              _toggleListening();
            }
          });

          String recordPath = 'audio.m4a';
          if (!kIsWeb) {
            final tempDir = await getTemporaryDirectory();
            recordPath = '${tempDir.path}/audio_${io.Platform.isAndroid ? DateTime.now().millisecondsSinceEpoch : DateTime.now().microsecondsSinceEpoch}.m4a';
          }

          await _audioRecorder.start(
            const rec.RecordConfig(
              encoder: rec.AudioEncoder.aacLc,
              bitRate: 64000,
              sampleRate: 16000,
            ),
            path: recordPath,
          );
        } else {
          _showPermissionDialog();
        }
      } catch (e) {
        debugPrint("Error starting recording: $e");
        _handleSttError();
      }
    }
  }

  Future<void> _uploadAndTranscribe() async {
    if (_recordedFilePath == null) {
      _handleSttError();
      return;
    }

    try {
      String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      if (!kIsWeb && io.Platform.isAndroid && (baseUrl.contains("127.0.0.1") || baseUrl.contains("localhost"))) {
        baseUrl = baseUrl.replaceAll("127.0.0.1", "10.0.2.2").replaceAll("localhost", "10.0.2.2");
      }
      final Uri url = Uri.parse('$baseUrl/stt');

      final request = http.MultipartRequest('POST', url)
        ..headers['ngrok-skip-browser-warning'] = 'true';

      if (kIsWeb) {
        final response = await http.get(Uri.parse(_recordedFilePath!), headers: {'ngrok-skip-browser-warning': 'true'});
        final bytes = response.bodyBytes;
        request.files.add(http.MultipartFile.fromBytes(
          'audio',
          bytes,
          filename: 'audio.m4a',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'audio',
          _recordedFilePath!,
        ));
      }

      request.fields['language'] = _currentOverrideLang;

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final transcript = data['transcript'] ?? '';

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }

        if (transcript.toString().trim().isEmpty) {
          _handleSttError();
        } else {
          widget.onSpeechResult(transcript);
        }
      } else {
        debugPrint("STT server error: ${response.statusCode} - ${response.body}");
        _handleSttError();
      }
    } catch (e) {
      debugPrint("STT request failed: $e");
      _handleSttError();
    }
  }

  void _cycleLanguage() {
    if (_isListening || _isProcessing) return;
    int idx = _supportedLanguages.indexOf(_currentOverrideLang);
    setState(() {
      _currentOverrideLang = _supportedLanguages[(idx + 1) % _supportedLanguages.length];
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.of(context).disableAnimations;
    final Color btnBg = _isListening
        ? (disableMotion ? PlayfulColors.tertiary : PlayfulColors.accent)
        : PlayfulColors.accent;

    Widget buttonBody = GestureDetector(
      onTap: _toggleListening,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: btnBg,
          shape: BoxShape.circle,
          border: Border.all(color: PlayfulColors.border, width: 2),
          boxShadow: [
            BoxShadow(
              color: PlayfulColors.border,
              offset: _isListening || _isProcessing ? const Offset(1, 1) : const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: _isProcessing
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: btnBg == PlayfulColors.tertiary ? PlayfulColors.foreground : Colors.white,
                size: 20,
              ),
      ),
    );

    final activeLangName = getLanguageName(_currentOverrideLang);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isListening && widget.textOnLeft) ...[
          Text(
            StringsProvider.instance.t('stt_listening').replaceAll('{}', activeLangName),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: PlayfulColors.accent,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (_isProcessing && widget.textOnLeft) ...[
          Text(
            "Transcribing...",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: PlayfulColors.accent,
            ),
          ),
          const SizedBox(width: 8),
        ],

        if (!_isListening && !_isProcessing) ...[
          GestureDetector(
            onTap: _cycleLanguage,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PlayfulColors.secondary,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: PlayfulColors.border, width: 1.5),
              ),
              child: Text(
                _currentOverrideLang.toUpperCase(),
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: PlayfulColors.foreground,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],

        _isListening && !disableMotion
            ? AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: child,
                  );
                },
                child: buttonBody,
              )
            : buttonBody,

        if (_isListening && !widget.textOnLeft) ...[
          const SizedBox(width: 8),
          Text(
            StringsProvider.instance.t('stt_listening').replaceAll('{}', activeLangName),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: PlayfulColors.accent,
            ),
          ),
        ],
        if (_isProcessing && !widget.textOnLeft) ...[
          const SizedBox(width: 8),
          Text(
            "Transcribing...",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: PlayfulColors.accent,
            ),
          ),
        ],
      ],
    );
  }
}

class PlayfulMarkdownText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const PlayfulMarkdownText({
    super.key,
    required this.text,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final List<Widget> children = [];

    for (var line in lines) {
      if (line.trim().isEmpty) {
        children.add(const SizedBox(height: 8));
        continue;
      }

      // Check if it is a list item (starts with digit. or * or -)
      final listMatch = RegExp(r'^(\s*)(?:\d+\.|\*|-)\s+(.*)$').firstMatch(line);
      if (listMatch != null) {
        final isNumbered = RegExp(r'^\s*\d+\.').hasMatch(line.trim());
        final indent = listMatch.group(1) ?? '';
        final contentText = listMatch.group(2) ?? '';
        
        final prefix = isNumbered 
            ? RegExp(r'^\s*(\d+\.)').firstMatch(line)!.group(1)! 
            : '•';

        children.add(
          Padding(
            padding: EdgeInsets.only(left: 16.0 + (indent.length * 4), top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$prefix ',
                  style: style.copyWith(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: style,
                      children: _parseInlineBold(contentText, style),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        // Normal paragraph line
        children.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: RichText(
              text: TextSpan(
                style: style,
                children: _parseInlineBold(line, style),
              ),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  List<InlineSpan> _parseInlineBold(String text, TextStyle defaultStyle) {
    final List<InlineSpan> spans = [];
    final parts = text.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (i % 2 == 1) {
        spans.add(
          TextSpan(
            text: parts[i],
            style: defaultStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else {
        if (parts[i].isNotEmpty) {
          spans.add(
            TextSpan(
              text: parts[i],
              style: defaultStyle,
            ),
          );
        }
      }
    }
    return spans;
  }
}

class PlayfulArcGauge extends StatefulWidget {
  final double percentage; // e.g. 0.0 to 1.5 (for 0% to 150%)

  const PlayfulArcGauge({
    super.key,
    required this.percentage,
  });

  @override
  State<PlayfulArcGauge> createState() => _PlayfulArcGaugeState();
}

class _PlayfulArcGaugeState extends State<PlayfulArcGauge> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(begin: 0.0, end: widget.percentage).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(PlayfulArcGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.percentage != widget.percentage) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.percentage,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int percentInt = (widget.percentage * 100).round();

    // Resolve color based on percentage
    Color activeColor;
    if (percentInt >= 100) {
      activeColor = PlayfulColors.quaternary; // Mint
    } else if (percentInt >= 85) {
      activeColor = PlayfulColors.tertiary; // Amber
    } else {
      activeColor = PlayfulColors.secondary; // Hot pink
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(140, 100),
          painter: _ArcGaugePainter(
            value: _animation.value,
            activeColor: activeColor,
            textColor: PlayfulColors.foreground,
            percentText: "$percentInt%",
          ),
        );
      },
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double value; // 0.0 to 1.5
  final Color activeColor;
  final Color textColor;
  final String percentText;

  _ArcGaugePainter({
    required this.value,
    required this.activeColor,
    required this.textColor,
    required this.percentText,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final radius = size.width / 2.2;

    // Symmetrical gauge with bottom open portion
    const double startAngle = 5.0 * 3.141592653589793 / 6.0; // 150 degrees
    const double totalSweepAngle = 4.0 * 3.141592653589793 / 3.0; // 240 degrees

    final paintTrack = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final paintActive = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Draw track arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweepAngle,
      false,
      paintTrack,
    );

    // Limit value to display range 0.0 to 1.5
    final double displayVal = value.clamp(0.0, 1.5);
    // 150% fills the entire gauge (totalSweepAngle). 100% fills 2/3 of it.
    final double sweepAngle = (displayVal / 1.5) * totalSweepAngle;

    // Draw active arc
    if (sweepAngle > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paintActive,
      );
    }

    // Draw text in center
    final textPainter = TextPainter(
      text: TextSpan(
        text: percentText,
        style: GoogleFonts.outfit(
          color: textColor,
          fontSize: 26,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    final textOffset = Offset(
      center.dx - textPainter.width / 2,
      center.dy - textPainter.height / 2 - 5,
    );
    textPainter.paint(canvas, textOffset);
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.percentText != percentText;
  }
}

class PlayfulSafetyContextWidget extends StatefulWidget {
  final DateTime? timestamp;
  final String? areaHint;

  const PlayfulSafetyContextWidget({
    super.key,
    required this.timestamp,
    this.areaHint,
  });

  @override
  State<PlayfulSafetyContextWidget> createState() => _PlayfulSafetyContextWidgetState();
}

class _PlayfulSafetyContextWidgetState extends State<PlayfulSafetyContextWidget> {
  bool _expanded = true;
  bool _loading = false;
  String? _score;
  String? _message;

  @override
  void initState() {
    super.initState();
    _fetchRouteSafety();
  }

  @override
  void didUpdateWidget(covariant PlayfulSafetyContextWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp || oldWidget.areaHint != widget.areaHint) {
      _fetchRouteSafety();
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'hi':
        return 'Hindi';
      case 'kn':
        return 'Kannada';
      case 'ta':
        return 'Tamil';
      case 'te':
        return 'Telugu';
      case 'ml':
        return 'Malayalam';
      default:
        return 'English';
    }
  }

  Future<void> _fetchRouteSafety() async {
    if (widget.timestamp == null) return;
    
    setState(() {
      _loading = true;
      _score = null;
      _message = null;
    });

    try {
      final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final Uri url = Uri.parse('$baseUrl/route-safety');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: json.encode({
          'job_timestamp': widget.timestamp!.toUtc().toIso8601String(),
          'area_hint': widget.areaHint ?? '',
          'language_name': _getLanguageName(StringsProvider.instance.lang),
        }),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _score = data['score'];
            _message = data['message'];
            _loading = false;
          });
        }
        return;
      }
    } catch (e) {
      debugPrint("Error fetching route safety: $e. Falling back to local checks.");
    }

    // Fallback logic on error/failure
    if (mounted) {
      final hour = widget.timestamp!.hour;
      final isEvening = hour >= 21 && hour < 23;
      final isLateNight = hour >= 23 || hour < 5;

      setState(() {
        if (isLateNight) {
          _score = "higher";
          _message = "Late-night trips warrant extra caution; consider sharing your trip details with someone you trust.";
        } else if (isEvening) {
          _score = "moderate";
          _message = "This route passes through 2 zones with limited recent fairness data — treat the comparison as an estimate.";
        } else {
          _score = "low";
          _message = "";
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.timestamp == null) return const SizedBox.shrink();
    if (_loading) {
      return const SizedBox(
        height: 24,
        width: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: PlayfulColors.accent),
      );
    }

    // Determine values based on resolved safety score
    final score = _score ?? "low";
    final message = _message ?? "";

    if (score == "low") {
      return const SizedBox.shrink();
    }

    final isHigher = score == "higher";
    final pillLabel = isHigher ? "🌙 High Risk Alert" : "🌆 Moderate Route Warning";
    final pillColor = isHigher ? const Color(0xFFFDF2F8) : const Color(0xFFFFFBEB);
    final borderColor = isHigher ? const Color(0xFFEF4444) : PlayfulColors.tertiary; // Red for higher, yellow/amber for moderate
    final textColor = isHigher ? const Color(0xFFEF4444) : const Color(0xFFD97706);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _expanded = !_expanded;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: pillColor, 
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: borderColor, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pillLabel,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: textColor,
                ),
              ],
            ),
          ),
        ),
        if (_expanded && message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PlayfulColors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: borderColor,
                  offset: const Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: PlayfulColors.foreground,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Route Safety Guidance — based on localized time context & location details.",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: PlayfulColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class PlayfulUnitInput extends StatelessWidget {
  final String labelText;
  final String hintText;
  final TextEditingController controller;
  final bool isHighlighted;
  final FormFieldValidator<String>? validator;
  final TextInputType keyboardType;
  final List<String> unitOptions;
  final String currentUnit;
  final ValueChanged<String> onUnitChanged;

  const PlayfulUnitInput({
    super.key,
    required this.labelText,
    required this.hintText,
    required this.controller,
    required this.isHighlighted,
    this.validator,
    this.keyboardType = TextInputType.text,
    required this.unitOptions,
    required this.currentUnit,
    required this.onUnitChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PlayfulInput(
      labelText: labelText,
      hintText: hintText,
      controller: controller,
      isHighlighted: isHighlighted,
      keyboardType: keyboardType,
      validator: validator,
      suffixIcon: Padding(
        padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
        child: Container(
          decoration: BoxDecoration(
            color: PlayfulColors.tertiary,
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: PlayfulColors.border, width: 2),
            boxShadow: const [
              BoxShadow(
                color: PlayfulColors.border,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: unitOptions.map((unit) {
              final isSelected = unit == currentUnit;
              return GestureDetector(
                onTap: () {
                  if (!isSelected) {
                    onUnitChanged(unit);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? PlayfulColors.foreground : Colors.transparent,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    unit,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : PlayfulColors.foreground,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

String formatIndianCurrency(double val, {int decimals = 0}) {
  final isNegative = val < 0;
  final numVal = val.abs();
  
  final parts = numVal.toStringAsFixed(decimals).split('.');
  final integerPart = parts[0];
  final decimalPart = parts.length > 1 ? ".${parts[1]}" : "";
  
  if (integerPart.length <= 3) {
    return "${isNegative ? "-" : ""}$integerPart$decimalPart";
  }
  
  final lastThree = integerPart.substring(integerPart.length - 3);
  final remaining = integerPart.substring(0, integerPart.length - 3);
  
  final buffer = StringBuffer();
  int count = 0;
  for (int i = remaining.length - 1; i >= 0; i--) {
    buffer.write(remaining[i]);
    count++;
    if (count == 2 && i > 0) {
      buffer.write(',');
      count = 0;
    }
  }
  
  final groupedRemaining = buffer.toString().split('').reversed.join('');
  return "${isNegative ? "-" : ""}$groupedRemaining,$lastThree$decimalPart";
}

Color getPlatformColor(String platform) {
  final clean = platform.trim().toLowerCase();
  if (clean.isEmpty) return PlayfulColors.mutedForeground;
  
  final List<Color> colors = [
    PlayfulColors.accent,      // Violet
    PlayfulColors.tertiary,    // Amber
    PlayfulColors.blue,        // Blue
    PlayfulColors.orange,      // Orange
    PlayfulColors.teal,        // Teal
  ];
  
  int hash = 0;
  for (int i = 0; i < clean.length; i++) {
    hash = clean.codeUnitAt(i) + ((hash << 5) - hash);
  }
  
  final index = hash.abs() % colors.length;
  return colors[index];
}
