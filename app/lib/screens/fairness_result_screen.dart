import '../i18n/strings.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'package:share_plus/share_plus.dart';

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

    final String badgeText = isUnderpaid ? "⚠️ ${StringsProvider.instance.t('badge_underpaid')}" : "✅ ${StringsProvider.instance.t('badge_fair_pay')}";

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Center(
                child: PlayfulSafetyContextWidget(
                  timestamp: job['job_timestamp'] != null
                      ? (job['job_timestamp'] is Timestamp
                          ? (job['job_timestamp'] as Timestamp).toDate()
                          : (job['job_timestamp'] is String
                              ? DateTime.tryParse(job['job_timestamp'] as String)
                              : null))
                      : (job['created_at'] != null
                          ? (job['created_at'] is Timestamp
                              ? (job['created_at'] as Timestamp).toDate()
                              : (job['created_at'] is String
                                  ? DateTime.tryParse(job['created_at'] as String)
                                  : null))
                          : null),
                  areaHint: job['area_hint'] as String?,
                ),
              ),
              _buildLegalDisclosureFlag(job),
              const SizedBox(height: 16),

              // Trip Detail Block ("Receipt" of what was compared)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PlayfulColors.border, width: 2.0),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDetailItem(Icons.navigation_outlined, "${distanceKm.toStringAsFixed(1)} km"),
                    _buildDetailDivider(),
                    _buildDetailItem(Icons.access_time, "${durationMin.toStringAsFixed(0)} min"),
                    _buildDetailDivider(),
                    _buildDetailItem(
                      Icons.currency_rupee,
                      distanceKm > 0
                          ? "₹${(fare / distanceKm).toStringAsFixed(1)}/km"
                          : "₹0/km",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

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
                              "₹${formatIndianCurrency(fare, decimals: 2)}",
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
                              "₹${formatIndianCurrency(expectedFare, decimals: 2)}",
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
              _buildBreakdownView(job),
              const SizedBox(height: 24),
              if (expectedFare > 0.0) ...[
                Center(
                  child: PlayfulArcGauge(
                    percentage: fare / expectedFare,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<int>(
                  future: _getSampleSize(platform, job['sample_size']),
                  builder: (context, snapshot) {
                    final size = snapshot.data ?? 0;
                    final pct = (fare / expectedFare * 100).toStringAsFixed(0);
                    final reportsCountText = size > 0 ? "$size recent reports" : "platform baseline benchmarks";
                    final percentageExplanation = "You were paid $pct% of what similar ${distanceKm.toStringAsFixed(1)}km trips on this platform typically earn (based on $reportsCountText).";

                    final rateSource = job['rate_source'] ?? (size >= 15 ? 'community' : 'seed');
                    String text;
                    String status;
                    if (rateSource == 'seed' || rateSource == 'fallback' || size < 15) {
                      text = "Typical reported range";
                      status = "gathering data";
                    } else if (size < 50) {
                      text = "Community baseline";
                      status = "growing dataset";
                    } else {
                      text = "Community baseline";
                      status = "well-established";
                    }
                    
                    String infoText = "";
                    if (status == "gathering data") {
                      infoText = "We are still collecting enough trips for this platform to calculate a reliable community median. Currently falling back to typical reported range benchmarks (reference tables).";
                    } else if (status == "growing dataset") {
                      infoText = "We have collected enough recent trips to start calculating a real community median, but the dataset is still growing.";
                    } else {
                      infoText = "We have a strong dataset of recent, fair trips for this platform, allowing us to compute a highly reliable community median.";
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text(
                            percentageExplanation,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: PlayfulColors.foreground,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                "$text — $status ($size trips)",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: PlayfulColors.mutedForeground,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: PlayfulColors.background,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: const BorderSide(color: PlayfulColors.border, width: 2),
                                    ),
                                    title: Text(StringsProvider.instance.t('label_rate_source'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                                    content: Text(infoText, style: GoogleFonts.plusJakartaSans()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: Text(StringsProvider.instance.t('btn_got_it'), style: GoogleFonts.plusJakartaSans(color: PlayfulColors.accent, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: const Icon(Icons.info_outline, size: 16, color: PlayfulColors.mutedForeground),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
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
              if (isUnderpaid) ...[
                Row(
                  children: [
                    Expanded(
                      child: PlayfulSecondaryButton(
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
                          final title = "$capitalizedPlatform trip — ₹${formatIndianCurrency(fare)}";
                          
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
                              "I want to ask about this ride:\nPlatform: $capitalizedPlatform\nFare: ₹${formatIndianCurrency(fare, decimals: 2)}\nDistance: ${distanceKm.toStringAsFixed(1)} km\nDuration: ${durationMin.toStringAsFixed(0)} mins. Is this pay fair?";
                          MainNavigationController.activeSessionId.value = newSessionId;
                          MainNavigationController.selectTab(2);

                          // 3. Pop result screen
                          Navigator.pop(context);
                        },
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(StringsProvider.instance.t('btn_ask_about_this')),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PlayfulSecondaryButton(
                        onPressed: () => _showComplaintDraftBottomSheet(context),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(StringsProvider.instance.t('btn_draft_complaint')),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              PlayfulButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(isReadOnly ? "GO BACK" : "LOG ANOTHER JOB"),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: PlayfulColors.mutedForeground),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: PlayfulColors.foreground,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailDivider() {
    return Container(
      height: 16,
      width: 2,
      color: PlayfulColors.border,
    );
  }

  Widget _buildLegalDisclosureFlag(Map<String, dynamic> job) {
    final double? deduction = job['deduction_amount'] != null ? (job['deduction_amount'] as num).toDouble() : null;
    final bool reasonStated = job['deduction_reason_stated'] ?? false;

    if (deduction == null || deduction <= 0 || reasonStated) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2), // Light red/pink background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PlayfulColors.secondary, width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.gavel,
            size: 16,
            color: PlayfulColors.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "This screenshot shows a ₹${deduction.toStringAsFixed(2)} deduction with no reason given. Karnataka's Platform-Based Gig Workers Act requires aggregators to disclose deduction reasons.",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: PlayfulColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownView(Map<String, dynamic> job) {
    final double? baseFare = job['base_fare'] != null ? (job['base_fare'] as num).toDouble() : null;
    final double? incentive = job['incentive_amount'] != null ? (job['incentive_amount'] as num).toDouble() : null;
    final double? surge = job['surge_amount'] != null ? (job['surge_amount'] as num).toDouble() : null;
    final double? deduction = job['deduction_amount'] != null ? (job['deduction_amount'] as num).toDouble() : null;
    final double fare = (job['fare'] as num?)?.toDouble() ?? 0.0;

    if (baseFare == null && incentive == null && surge == null && deduction == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          Text(
            "TRIP BREAKDOWN",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: PlayfulColors.mutedForeground,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          if (baseFare != null)
            _buildBreakdownRow("Base Fare", "₹${baseFare.toStringAsFixed(2)}"),
          if (incentive != null && incentive > 0)
            _buildBreakdownRow("Incentive / Bonus", "+ ₹${incentive.toStringAsFixed(2)}", isPositive: true),
          if (surge != null && surge > 0)
            _buildBreakdownRow("Surge / Peak Pay", "+ ₹${surge.toStringAsFixed(2)}", isPositive: true),
          if (deduction != null && deduction > 0)
            _buildBreakdownRow("Platform Commission / Deduction", "- ₹${deduction.toStringAsFixed(2)}", isNegative: true),
          const Divider(color: PlayfulColors.border, thickness: 1.5, height: 24),
          _buildBreakdownRow(
            "Actual Earnings",
            "₹${fare.toStringAsFixed(2)}",
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(String label, String value, {bool isPositive = false, bool isNegative = false, bool isBold = false}) {
    Color valColor = PlayfulColors.foreground;
    if (isPositive) valColor = PlayfulColors.quaternary;
    if (isNegative) valColor = PlayfulColors.secondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
                color: PlayfulColors.foreground,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.shareTechMono(
              fontWeight: FontWeight.bold,
              fontSize: isBold ? 15 : 13,
              color: valColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showComplaintDraftBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String draftText = "";
        bool loading = true;
        String errorMsg = "";

        return StatefulBuilder(
          builder: (context, setStateSheet) {
            if (loading && errorMsg.isEmpty) {
              () async {
                try {
                  String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
                  if (!kIsWeb && Platform.isAndroid && (baseUrl.contains("127.0.0.1") || baseUrl.contains("localhost"))) {
                    baseUrl = baseUrl.replaceAll("127.0.0.1", "10.0.2.2").replaceAll("localhost", "10.0.2.2");
                  }
                  final Uri url = Uri.parse('$baseUrl/complaint-draft');
                  final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

                  final response = await http.post(
                    url,
                    headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
                    body: json.encode({
                      'job_id': job['id'] ?? '',
                      'user_id': uid,
                    }),
                  ).timeout(const Duration(seconds: 30));

                  if (response.statusCode == 200) {
                    final data = json.decode(response.body);
                    if (context.mounted) {
                      setStateSheet(() {
                        draftText = data['draft_text'] ?? "";
                        loading = false;
                      });
                    }
                  } else {
                    if (context.mounted) {
                      setStateSheet(() {
                        errorMsg = "Failed to generate draft. Status: ${response.statusCode}";
                        loading = false;
                      });
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    setStateSheet(() {
                      errorMsg = "Unable to connect to backend.";
                      loading = false;
                    });
                  }
                }
              }();
            }

            return _ComplaintBottomSheetContent(
              loading: loading,
              errorMsg: errorMsg,
              initialDraftText: draftText,
            );
          },
        );
      },
    );
  }
}

class _ComplaintBottomSheetContent extends StatefulWidget {
  final bool loading;
  final String errorMsg;
  final String initialDraftText;

  const _ComplaintBottomSheetContent({
    required this.loading,
    required this.errorMsg,
    required this.initialDraftText,
  });

  @override
  State<_ComplaintBottomSheetContent> createState() => _ComplaintBottomSheetContentState();
}

class _ComplaintBottomSheetContentState extends State<_ComplaintBottomSheetContent> {
  late TextEditingController _controller;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialDraftText);
  }

  @override
  void didUpdateWidget(_ComplaintBottomSheetContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDraftText != widget.initialDraftText) {
      _controller.text = widget.initialDraftText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: PlayfulColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: PlayfulColors.border, width: 2),
          left: BorderSide(color: PlayfulColors.border, width: 2),
          right: BorderSide(color: PlayfulColors.border, width: 2),
        ),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 24,
        right: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 6,
              decoration: BoxDecoration(
                color: PlayfulColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "COMPLAINT DRAFT",
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 2.0,
              color: PlayfulColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          if (widget.loading) ...[
            const SizedBox(
              height: 150,
              child: Center(
                child: CircularProgressIndicator(color: PlayfulColors.accent),
              ),
            ),
          ] else if (widget.errorMsg.isNotEmpty) ...[
            SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  widget.errorMsg,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: PlayfulColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PlayfulColors.border, width: 2),
              ),
              child: _isEditing
                  ? TextField(
                      controller: _controller,
                      maxLines: 8,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PlayfulColors.foreground,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                  : Text(
                      _controller.text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: PlayfulColors.foreground,
                        height: 1.4,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                  icon: Icon(
                    _isEditing ? Icons.check : Icons.edit_outlined,
                    size: 16,
                    color: PlayfulColors.accent,
                  ),
                  label: Text(
                    _isEditing ? "SAVE" : "EDIT",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PlayfulColors.accent,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    "CLOSE",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: PlayfulColors.mutedForeground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: PlayfulButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _controller.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: PlayfulColors.accent,
                          content: Text(
                            StringsProvider.instance.t('copied_to_clipboard'),
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      );
                      Navigator.pop(context);
                    },
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(StringsProvider.instance.t('btn_copy'))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PlayfulSecondaryButton(
                    onPressed: () {
                      Share.share(_controller.text);
                    },
                    child: FittedBox(fit: BoxFit.scaleDown, child: Text(StringsProvider.instance.t('btn_share'))),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                StringsProvider.instance.t('draft_disclaimer'),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: PlayfulColors.mutedForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
