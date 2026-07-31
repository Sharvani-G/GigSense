import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import '../main.dart';
import 'playful_widgets.dart';

class FairnessResultScreen extends StatelessWidget {
  final Map<String, dynamic> job;
  final bool isReadOnly;

  const FairnessResultScreen({
    super.key,
    required this.job,
    this.isReadOnly = false,
  });

  Future<int> _getSampleSize(String platform, dynamic jobSampleSize) async {
    if (jobSampleSize != null) {
      return (jobSampleSize as num).toInt();
    }
    if (platform.isEmpty || platform == 'other') {
      return 0;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('benchmarks').doc(platform).get();
      if (doc.exists && doc.data() != null) {
        return (doc.data()!['sampleSize'] as num?)?.toInt() ?? 0;
      }
    } catch (e) {
      debugPrint("Error fetching platform sample size: $e");
    }
    return 0;
  }

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
    final String explanationText = job['explanation'] ?? (isUnderpaid
        ? "This came in noticeably below what's typical for this distance and platform."
        : "This is about what's typical for a ${distanceKm.toStringAsFixed(1)}km $capitalizedPlatform trip.");

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
              const SizedBox(height: 24),
              if (expectedFare > 0.0) ...[
                Center(
                  child: PlayfulArcGauge(
                    percentage: fare / expectedFare,
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: FutureBuilder<int>(
                    future: _getSampleSize(platform, job['sample_size']),
                    builder: (context, snapshot) {
                      final size = snapshot.data ?? 0;
                      String text;
                      if (size < 15) {
                        text = "Estimated rate — still gathering real data for this platform";
                      } else if (size < 50) {
                        text = "Based on a growing set of real trips from other GigShield workers";
                      } else {
                        text = "Based on a well-established set of real trips from other GigShield workers";
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PlayfulColors.mutedForeground,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 32),

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
                child: Text(isReadOnly ? "GO BACK" : "LOG ANOTHER JOB"),
              ),
              const SizedBox(height: 16),
              PlayfulSecondaryButton(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
                  
                  // Generate new session ID
                  final sessionCollection = FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('chatSessions');
                  final newSessionDoc = sessionCollection.doc();
                  final newSessionId = newSessionDoc.id;

                  final String capitalizedPlatform = platform.isNotEmpty
                      ? platform[0].toUpperCase() + platform.substring(1)
                      : '';
                  
                  // Auto-title from job context
                  final title = "$capitalizedPlatform trip — ₹${fare.toStringAsFixed(0)}";
                  
                  try {
                    // 1. Create chatSession document
                    await newSessionDoc.set({
                      'title': title,
                      'createdAt': FieldValue.serverTimestamp(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });
                  } catch (e) {
                    debugPrint("Error creating deep-linked chat session: $e");
                  }

                  // 2. Set initial message to send on chat screen init and navigate to Chat tab
                  MainNavigationController.initialMessageToSend = 
                      "I want to ask about this ride:\nPlatform: $capitalizedPlatform\nFare: ₹${fare.toStringAsFixed(2)}\nDistance: ${distanceKm.toStringAsFixed(1)} km\nDuration: ${durationMin.toStringAsFixed(0)} mins. Is this pay fair?";
                  MainNavigationController.activeSessionId.value = newSessionId;
                  MainNavigationController.selectTab(2);

                  // 3. Pop result screen
                  Navigator.pop(context);
                },
                child: const Text("ASK ABOUT THIS"),
              ),
              if (isUnderpaid) ...[
                const SizedBox(height: 16),
                PlayfulButton(
                  onPressed: () => _showComplaintDraftDialog(
                    context,
                    platform,
                    fare,
                    distanceKm,
                    durationMin,
                    expectedFare,
                  ),
                  child: const Text("DRAFT A COMPLAINT"),
                ),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showComplaintDraftDialog(
    BuildContext context,
    String platform,
    double fare,
    double distanceKm,
    double durationMin,
    double expectedFare,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        String draftText = "";
        bool loading = true;
        String errorMsg = "";

        return StatefulBuilder(
          builder: (context, setState) {
            if (loading && errorMsg.isEmpty) {
              // Trigger API call
              () async {
                try {
                  final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
                  final Uri url = Uri.parse('$baseUrl/jobs/draft-complaint');
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

                  final response = await http.post(
                    url,
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'platform': platform,
                      'fare': fare,
                      'distance_km': distanceKm,
                      'duration_min': durationMin,
                      'expected_fare': expectedFare,
                      'user_id': uid,
                    }),
                  );

                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    setState(() {
                      draftText = data['complaint_draft'] ?? "";
                      loading = false;
                    });
                  } else {
                    setState(() {
                      errorMsg = "Failed to generate draft. Please try again.";
                      loading = false;
                    });
                  }
                } catch (e) {
                  setState(() {
                    errorMsg = "Unable to connect to backend.";
                    loading = false;
                  });
                }
              }();
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: PlayfulColors.background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: PlayfulColors.border, width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "COMPLAINT DRAFT",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 2.0,
                        color: PlayfulColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    if (loading) ...[
                      const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: PlayfulColors.accent,
                          ),
                        ),
                      ),
                    ] else if (errorMsg.isNotEmpty) ...[
                      SizedBox(
                        height: 120,
                        child: Center(
                          child: Text(
                            errorMsg,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: PlayfulColors.border, width: 2),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              draftText,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: PlayfulColors.foreground,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      PlayfulButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: draftText));
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: PlayfulColors.accent,
                              content: Text(
                                "Complaint draft copied to clipboard!",
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text("COPY & CLOSE"),
                      ),
                    ],
                    if (!loading) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "CANCEL",
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w800,
                            color: PlayfulColors.mutedForeground,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
