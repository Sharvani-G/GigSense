import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../main.dart';
import '../i18n/strings.dart';
import 'playful_widgets.dart'; // color definitions

class GiGlySplash extends StatefulWidget {
  const GiGlySplash({super.key});

  @override
  State<GiGlySplash> createState() => _GiGlySplashState();
}

class _GiGlySplashState extends State<GiGlySplash> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<String> _letters = ['G', 'i', 'G', 'l', 'y'];
  final List<Animation<double>> _letterScales = [];
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    const curve = Cubic(0.34, 1.56, 0.64, 1.0);

    // Stagger letters over the 1.2s duration
    for (int i = 0; i < _letters.length; i++) {
      double start = i * 0.12;
      double end = (start + 0.4).clamp(0.0, 1.0);
      _letterScales.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(start, end, curve: curve),
          ),
        ),
      );
    }

    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    // Check motion reduction after frame layout
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (disableMotion) {
        // Quick 500ms hold then transition
        Timer(const Duration(milliseconds: 500), _navigateToGateway);
      } else {
        _controller.forward().then((_) {
          // Hold for 400ms after animation completes, then navigate
          Timer(const Duration(milliseconds: 400), _navigateToGateway);
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

  @override
  Widget build(BuildContext context) {
    final disableMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    
    final textStyle = GoogleFonts.outfit(
      fontSize: 56,
      fontWeight: FontWeight.w900,
      color: PlayfulColors.foreground,
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (disableMotion) ...[
              // Instant non-animated view
              Text("GiGly", style: textStyle),
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
                children: List.generate(_letters.length, (index) {
                  return ScaleTransition(
                    scale: _letterScales[index],
                    child: Text(
                      _letters[index],
                      style: textStyle,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),
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
    );
  }
}
