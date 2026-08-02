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
          "HOW GIGSENSE WORKS",
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
                    // Heading Pop-in style header
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
                            "Welcome to GigSense!",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: PlayfulColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Here is a quick overview of our tools designed to help you check pay fairness, protect your rights, and stay safe.",
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

                    // Section 1: Logging a Job
                    _buildFeatureCard(
                      icon: Icons.add_box_outlined,
                      iconColor: PlayfulColors.accent,
                      title: "Logging Your Trips",
                      description:
                          "Log jobs manually or upload a screenshot of your payslip (OCR scan) to extract earnings automatically. GigSense checks your trip parameters and flags anomalies using two distinct rules:\n\n"
                          "• **Fairness Flag**: Compares your actual fare to expected benchmark rates.\n"
                          "• **Deduction Flag**: Triggers if the platform makes deductions without giving a reason, violating local labor transparency guidelines.",
                    ),
                    const SizedBox(height: 16),

                    // Section 2: GigChat Legal Assistant
                    _buildFeatureCard(
                      icon: Icons.chat_bubble_outline,
                      iconColor: PlayfulColors.secondary,
                      title: "GigChat Assistant",
                      description:
                          "GigChat is your legal coach. It is grounded in verified regulations like India's **Code on Social Security 2020** and **Karnataka's 2025 Act** to answer questions about your rights. Use it to check contract fairness or generate complaint draft text to copy-paste into aggregator chat boxes. Supports voice input/output and multiple regional languages.",
                    ),
                    const SizedBox(height: 16),

                    // Section 3: Earnings Dashboard
                    _buildFeatureCard(
                      icon: Icons.dashboard_outlined,
                      iconColor: PlayfulColors.tertiary,
                      title: "Your Dashboard",
                      description:
                          "Your Home screen aggregates total earnings, total active hours, and flagged (underpaid) trips at a glance. It keeps you informed of your weekly metrics to help monitor your shift details and platform distributions.",
                    ),
                    const SizedBox(height: 16),

                    // Section 4: Locality Fairness Map
                    _buildFeatureCard(
                      icon: Icons.map_outlined,
                      iconColor: PlayfulColors.quaternary,
                      title: "Locality Fairness Map",
                      description:
                          "Shows pay fairness health across different areas (zones) of the city to help you decide where to ride. Zones are color-coded:\n\n"
                          "• **Green**: Generally paid the full expected rates.\n"
                          "• **Orange**: Generally paid close to expected rates.\n"
                          "• **Pink**: High rate of underpayments detected.\n\n"
                          "*Note: Community averages are backed by real worker logs, supplemented with simulated community context for demo purposes where labeled. Switch to **List View** for a simple tabular format.*",
                    ),
                    const SizedBox(height: 16),

                    // Section 5: SOS Shield
                    _buildFeatureCard(
                      icon: Icons.gpp_maybe_outlined,
                      iconColor: PlayfulColors.orange,
                      title: "SOS Safety Shield",
                      description:
                          "Configure emergency contacts and your mobile number to set up emergency triggers. SOS activates three channels:\n\n"
                          "• **WhatsApp**: Opens a pre-filled chat template containing a Google Maps coordinate link.\n"
                          "• **Automatic SMS**: Sends a silent background SMS alert to your contact with coordinates (Android-only).\n"
                          "• **Manual SMS fallback**: Launches your default SMS app with pre-filled details if background sending fails.",
                    ),
                    const SizedBox(height: 16),

                    // Section 6: Smart Utilities
                    _buildFeatureCard(
                      icon: Icons.tips_and_updates_outlined,
                      iconColor: PlayfulColors.blue,
                      title: "Smart Alerts & Goals",
                      description:
                          "• **Savings Goal**: Pin targets to stay motivated.\n"
                          "• **Fatigue Nudge**: Displays a warning alert if you log more than 10 active hours in a 24-hour window, advising you to rest.\n"
                          "• **Weekly Insights**: Automatically compiles logged trips into a coaching summary, highlighting underpayment patterns or platform concentrations.",
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // Bottom CTA section
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
                      child: Text(widget.autoRegisterFlag ? "GET STARTED" : "DISMISS"),
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
          Text(
            description,
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
