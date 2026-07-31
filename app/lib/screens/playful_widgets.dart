import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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
                color: isEnabled ? Colors.white : const Color(0xFF94A3B8),
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
                      color: const Color(0xFF94A3B8),
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
                      color: const Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    border: InputBorder.none,
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
                  color: activeOption == "manual" ? PlayfulColors.accent : Colors.transparent,
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
                  color: activeOption == "scan" ? PlayfulColors.accent : Colors.transparent,
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

class PlayfulMicButton extends StatefulWidget {
  final ValueChanged<String> onSpeechResult;

  const PlayfulMicButton({super.key, required this.onSpeechResult});

  @override
  State<PlayfulMicButton> createState() => _PlayfulMicButtonState();
}

class _PlayfulMicButtonState extends State<PlayfulMicButton> with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();

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

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize(
        onError: (val) => debugPrint('Speech initialize error: $val'),
        onStatus: (val) => debugPrint('Speech status: $val'),
      );
      if (mounted) {
        setState(() {
          _speechAvailable = available;
        });
      }
    } catch (e) {
      debugPrint('Speech initialization failed: $e');
    }
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      await _initSpeech();
      if (!_speechAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Speech recognition is not available on this device.",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
            backgroundColor: PlayfulColors.secondary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: PlayfulColors.border, width: 2),
            ),
          ),
        );
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
      _pulseController.stop();
      setState(() {
        _isListening = false;
      });
    } else {
      setState(() {
        _isListening = true;
      });
      if (!MediaQuery.of(context).disableAnimations) {
        _pulseController.repeat(reverse: true);
      }
      await _speech.listen(
        onResult: (result) {
          widget.onSpeechResult(result.recognizedWords);
          if (result.finalResult) {
            _pulseController.stop();
            if (mounted) {
              setState(() {
                _isListening = false;
              });
            }
          }
        },
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
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
              offset: _isListening ? const Offset(1, 1) : const Offset(2, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(
          _isListening ? Icons.mic : Icons.mic_none,
          color: Colors.white,
          size: 20,
        ),
      ),
    );

    if (_isListening && !disableMotion) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: buttonBody,
      );
    }

    return buttonBody;
  }
}
