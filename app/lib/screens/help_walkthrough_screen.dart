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
