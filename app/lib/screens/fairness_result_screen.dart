import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'playful_widgets.dart';

class FairnessResultScreen extends StatelessWidget {
  final Map<String, dynamic> job;

  const FairnessResultScreen({
    super.key,
    required this.job,
  });

  @override
  Widget build(BuildContext context) {
    final String platform = job['platform'] ?? 'other';
    final double fare = (job['fare'] as num?)?.toDouble() ?? 0.0;
    final double distanceKm = (job['distance_km'] as num?)?.toDouble() ?? 0.0;
    final double durationMin = (job['duration_min'] as num?)?.toDouble() ?? 0.0;
    final double expectedFare = (job['expected_fare'] as num?)?.toDouble() ?? 0.0;
    final bool isUnderpaid = job['is_underpaid'] ?? false;

    // Capitalize platform name
    final String capitalizedPlatform = platform.isNotEmpty
        ? platform[0].toUpperCase() + platform.substring(1)
        : '';

    // Description text templates
    final String explanationText = isUnderpaid
        ? "This came in noticeably below what's typical for this distance and platform."
        : "This is about what's typical for a ${distanceKm.toStringAsFixed(1)}km $capitalizedPlatform trip.";

    final String badgeText = isUnderpaid ? "⚠️ Possibly Underpaid" : "✅ Fair Pay";

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Screen Title
              Text(
                "FAIRNESS CHECK",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 2.0,
                  color: PlayfulColors.mutedForeground,
                ),
              ),
              const SizedBox(height: 32),

              // The animated large status badge
              Center(
                child: PlayfulBadge(
                  text: badgeText,
                  isUnderpaid: isUnderpaid,
                ),
              ),
              const SizedBox(height: 48),

              // Side-by-side Expected vs Actual boxes
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PlayfulColors.border, width: 2.0),
                        boxShadow: const [
                          BoxShadow(
                            color: PlayfulColors.tertiary, // Yellow shadow
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "ACTUAL",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: PlayfulColors.mutedForeground,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "₹${fare.toStringAsFixed(2)}",
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: PlayfulColors.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: PlayfulColors.border, width: 2.0),
                        boxShadow: const [
                          BoxShadow(
                            color: PlayfulColors.accent, // Violet shadow
                            offset: Offset(4, 4),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "EXPECTED",
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: PlayfulColors.mutedForeground,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "₹${expectedFare.toStringAsFixed(2)}",
                              style: GoogleFonts.outfit(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: PlayfulColors.foreground,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Description sentence
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PlayfulColors.border, width: 2.0),
                ),
                child: Text(
                  explanationText,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: PlayfulColors.foreground,
                    height: 1.4,
                  ),
                ),
              ),

              const Spacer(),

              // Action Buttons
              PlayfulButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("LOG ANOTHER JOB"),
              ),
              const SizedBox(height: 16),
              PlayfulSecondaryButton(
                onPressed: () {
                  debugPrint("Ask About This tapped for job: $job");
                },
                child: const Text("ASK ABOUT THIS"),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
