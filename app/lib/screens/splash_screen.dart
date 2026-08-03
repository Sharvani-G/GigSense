import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../main.dart';
import '../i18n/strings.dart';
import 'playful_widgets.dart'; // color and avatar definitions

class GiGlySplash extends StatefulWidget {
  const GiGlySplash({super.key});

  @override
  State<GiGlySplash> createState() => _GiGlySplashState();
}

class _GiGlySplashState extends State<GiGlySplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<String> _letters = ['G', 'i', 'G', 'l', 'y'];
  final List<Animation<double>> _letterScales = [];
  late final Animation<double> _eyePopScale;
  late final Animation<double> _gigiScale;
  late final Animation<double> _taglineOpacity;
  late final Animation<double> _bodyOpacity;

  final List<Color> _letterColors = [
    const Color(0xFF4F46E5), // Indigo
    const Color(0xFFFBBF24), // Amber
    const Color(0xFF10B981), // Emerald
    const Color(0xFFE11D48), // Crimson
    const Color(0xFF4F46E5), // Indigo
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2300),
    );

    const curve = Cubic(0.34, 1.56, 0.64, 1.0);

    // Stage 2 — Letter reveals (150ms to 950ms -> intervals mapping out of 2300ms)
    // Each letter pop takes 400ms. Stagger offset is 100ms.
    _letterScales.add(
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(150 / 2300, 550 / 2300, curve: curve),
        ),
      ),
    );
    _letterScales.add(
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(250 / 2300, 650 / 2300, curve: curve),
        ),
      ),
    );
    _letterScales.add(
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(350 / 2300, 750 / 2300, curve: curve),
        ),
      ),
    );
    _letterScales.add(
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(450 / 2300, 850 / 2300, curve: curve),
        ),
      ),
    );
    _letterScales.add(
      Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _controller,
          curve: const Interval(550 / 2300, 950 / 2300, curve: curve),
        ),
      ),
    );

    // Stage 3 — Eye pop detail (950ms to 1150ms)
    _eyePopScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(950 / 2300, 1150 / 2300, curve: curve),
      ),
    );

    // Stage 4 — GiGi cameo (1150ms to 1900ms)
    _gigiScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(1150 / 2300, 1550 / 2300, curve: curve),
      ),
    );

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(1150 / 2300, 1900 / 2300, curve: Curves.easeIn),
      ),
    );

    // Stage 5 — Hold & Transition fade (2000ms to 2300ms)
    _bodyOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(2000 / 2300, 1.0, curve: Curves.easeOut),
      ),
    );

    // Check motion reduction after frame layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableMotion) {
        Timer(const Duration(milliseconds: 500), _navigateToGateway);
      } else {
        _controller.forward().then((_) {
          _navigateToGateway();
        });
      }
    });
  }

  void _navigateToGateway() {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AuthGateway()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildLetterI(Animation<double> bodyScale, Animation<double> dotScale, TextStyle textStyle) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // Body: dotless i
        ScaleTransition(
          scale: bodyScale,
          child: Text(
            "ı",
            style: textStyle.copyWith(color: _letterColors[1]),
          ),
        ),
        // Dot
        Positioned(
          top: 6,
          child: ScaleTransition(
            scale: dotScale,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: _letterColors[1],
                shape: BoxShape.circle,
                border: Border.all(color: PlayfulColors.border, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStaticLetterI(TextStyle textStyle) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Text(
          "ı",
          style: textStyle.copyWith(color: _letterColors[1]),
        ),
        Positioned(
          top: 6,
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: _letterColors[1],
              shape: BoxShape.circle,
              border: Border.all(color: PlayfulColors.border, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    
    final textStyle = GoogleFonts.outfit(
      fontSize: 56,
      fontWeight: FontWeight.w900,
      shadows: const [
        Shadow(
          color: PlayfulColors.border,
          offset: Offset(4, 4),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFFDF5),
      body: Center(
        child: FadeTransition(
          opacity: _bodyOpacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (disableMotion) ...[
                // Instant non-animated view
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("G", style: textStyle.copyWith(color: _letterColors[0])),
                    _buildStaticLetterI(textStyle),
                    Text("G", style: textStyle.copyWith(color: _letterColors[2])),
                    Text("l", style: textStyle.copyWith(color: _letterColors[3])),
                    Text("y", style: textStyle.copyWith(color: _letterColors[4])),
                  ],
                ),
                const SizedBox(height: 24),
                const GiGiAvatar(size: 64),
                const SizedBox(height: 16),
                Text(
                  StringsProvider.instance.t('tagline'),
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: PlayfulColors.mutedForeground,
                  ),
                ),
              ] else ...[
                // Animated view
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _letterScales[0],
                      child: Text("G", style: textStyle.copyWith(color: _letterColors[0])),
                    ),
                    _buildLetterI(_letterScales[1], _eyePopScale, textStyle),
                    ScaleTransition(
                      scale: _letterScales[2],
                      child: Text("G", style: textStyle.copyWith(color: _letterColors[2])),
                    ),
                    ScaleTransition(
                      scale: _letterScales[3],
                      child: Text("l", style: textStyle.copyWith(color: _letterColors[3])),
                    ),
                    ScaleTransition(
                      scale: _letterScales[4],
                      child: Text("y", style: textStyle.copyWith(color: _letterColors[4])),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ScaleTransition(
                  scale: _gigiScale,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      final ms = _controller.value * 2300;
                      final isBlinking = ms >= 1550 && ms <= 1800;
                      final gigiState = isBlinking ? GiGiState.blink : GiGiState.idle;
                      return GiGiAvatar(
                        size: 64,
                        forceState: gigiState,
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _taglineOpacity,
                  child: Text(
                    StringsProvider.instance.t('tagline'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: PlayfulColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
