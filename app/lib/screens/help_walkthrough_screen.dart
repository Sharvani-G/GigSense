import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'playful_widgets.dart';
import '../i18n/strings.dart';

class HelpWalkthroughScreen extends StatefulWidget {
  final bool autoRegisterFlag;

  const HelpWalkthroughScreen({super.key, this.autoRegisterFlag = false});

  @override
  State<HelpWalkthroughScreen> createState() => _HelpWalkthroughScreenState();
}

class _HelpWalkthroughScreenState extends State<HelpWalkthroughScreen> {
  bool _isSaving = false;

  Future<void> _dismiss() async {
    if (widget.autoRegisterFlag) {
      setState(() => _isSaving = true);
      try {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'hasSeenHelpWalkthrough': true,
          });
        }
      } catch (e) {
        debugPrint("Error updating walkthrough flag: $e");
      }
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        backgroundColor: PlayfulColors.background,
        elevation: 0,
        automaticallyImplyLeading: !widget.autoRegisterFlag,
        leading: widget.autoRegisterFlag
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: PlayfulColors.foreground),
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          s.t('walkthrough_title'),
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.0,
            color: PlayfulColors.foreground,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: PlayfulColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PlayfulColors.border, width: 2.0),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.stars, color: PlayfulColors.accent, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            s.t('walkthrough_welcome'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: PlayfulColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.t('walkthrough_welcome_desc'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: PlayfulColors.mutedForeground,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    _buildFeatureCard(
                      icon: Icons.add_box_outlined,
                      iconColor: PlayfulColors.accent,
                      title: s.t('walkthrough_log_title'),
                      description: s.t('walkthrough_log_desc'),
                    ),
                    const SizedBox(height: 16),

                    _buildFeatureCard(
                      icon: Icons.chat_bubble_outline,
                      iconColor: PlayfulColors.secondary,
                      title: s.t('walkthrough_chat_title'),
                      description: s.t('walkthrough_chat_desc'),
                    ),
                    const SizedBox(height: 16),

                    _buildFeatureCard(
                      icon: Icons.dashboard_outlined,
                      iconColor: PlayfulColors.tertiary,
                      title: s.t('walkthrough_dashboard_title'),
                      description: s.t('walkthrough_dashboard_desc'),
                    ),
                    const SizedBox(height: 16),

                    _buildFeatureCard(
                      icon: Icons.map_outlined,
                      iconColor: PlayfulColors.quaternary,
                      title: s.t('walkthrough_map_title'),
                      description: s.t('walkthrough_map_desc'),
                    ),
                    const SizedBox(height: 16),

                    _buildFeatureCard(
                      icon: Icons.gpp_maybe_outlined,
                      iconColor: PlayfulColors.orange,
                      title: s.t('walkthrough_sos_title'),
                      description: s.t('walkthrough_sos_desc'),
                    ),
                    const SizedBox(height: 16),

                    _buildFeatureCard(
                      icon: Icons.tips_and_updates_outlined,
                      iconColor: PlayfulColors.blue,
                      title: s.t('walkthrough_smart_title'),
                      description: s.t('walkthrough_smart_desc'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: PlayfulColors.border, width: 2.0),
                ),
              ),
              child: _isSaving
                  ? const Center(child: CircularProgressIndicator(color: PlayfulColors.accent))
                  : PlayfulButton(
                      onPressed: _dismiss,
                      child: Text(widget.autoRegisterFlag ? s.t('walkthrough_btn_start') : s.t('walkthrough_btn_dismiss')),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PlayfulColors.border, width: 2.0),
        boxShadow: const [
          BoxShadow(
            color: PlayfulColors.border,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PlayfulColors.border, width: 1.5),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: PlayfulColors.foreground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _FeatureIllustration(
            icon: icon,
            color: iconColor,
            title: title,
          ),
          const SizedBox(height: 14),
          PlayfulMarkdownText(
            text: description,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: PlayfulColors.foreground,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureIllustration extends StatefulWidget {
  final IconData icon;
  final Color color;
  final String title;

  const _FeatureIllustration({required this.icon, required this.color, required this.title});

  @override
  State<_FeatureIllustration> createState() => _FeatureIllustrationState();
}

class _FeatureIllustrationState extends State<_FeatureIllustration> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        double offset = _animation.value * 6.0 - 3.0; // small translation motion
        double scale = 1.0 + (_animation.value * 0.06); // small scale motion
        
        Widget illustration;
        final titleLower = widget.title.toLowerCase();
        if (titleLower.contains("ocr") || titleLower.contains("log") || titleLower.contains("trip")) {
          // OCR/Scan diagram flow animation: a document icon sliding into a scanning box!
          illustration = SizedBox(
            height: 60,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.translate(
                  offset: Offset(_animation.value * 20.0 - 10.0, 0),
                  child: Icon(Icons.description_outlined, color: widget.color, size: 28),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, color: widget.color.withOpacity(0.5), size: 18),
                const SizedBox(width: 8),
                Icon(Icons.document_scanner_outlined, color: widget.color, size: 32),
              ],
            ),
          );
        } else if (titleLower.contains("chat") || titleLower.contains("ai") || titleLower.contains("assistant")) {
          // Chat: pulsing message bubbles!
          illustration = SizedBox(
            height: 60,
            child: Center(
              child: Transform.scale(
                scale: scale,
                child: Icon(widget.icon, color: widget.color, size: 36),
              ),
            ),
          );
        } else if (titleLower.contains("map") || titleLower.contains("locality")) {
          // Map: radar scan pulse!
          illustration = SizedBox(
            height: 60,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 32 + (_animation.value * 24),
                    height: 32 + (_animation.value * 24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.15 * (1.0 - _animation.value)),
                      border: Border.all(color: widget.color.withOpacity(0.3 * (1.0 - _animation.value)), width: 2),
                    ),
                  ),
                  Icon(widget.icon, color: widget.color, size: 28),
                ],
              ),
            ),
          );
        } else if (titleLower.contains("sos") || titleLower.contains("unsafe") || titleLower.contains("shield")) {
          // SOS: flashing beacon pulse!
          illustration = SizedBox(
            height: 60,
            child: Center(
              child: Icon(
                widget.icon,
                color: _animation.value > 0.5 ? widget.color : widget.color.withOpacity(0.3),
                size: 32,
              ),
            ),
          );
        } else {
          // General floating bounce
          illustration = SizedBox(
            height: 60,
            child: Center(
              child: Transform.translate(
                offset: Offset(0, offset),
                child: Icon(widget.icon, color: widget.color, size: 32),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 70,
          decoration: BoxDecoration(
            color: widget.color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PlayfulColors.border.withOpacity(0.2), width: 1.5),
          ),
          child: illustration,
        );
      },
    );
  }
}
class _EditStickerCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _EditStickerCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? PlayfulColors.accent : PlayfulColors.border,
            width: 2.0,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}
