import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../i18n/strings.dart';
import 'playful_widgets.dart';

class OcrResultScreen extends StatefulWidget {
  final Map<String, dynamic> ocrData;
  final VoidCallback onEdit;

  const OcrResultScreen({
    super.key,
    required this.ocrData,
    required this.onEdit,
  });

  @override
  State<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends State<OcrResultScreen> {
  bool _isSaving = false;
  double _platformRatePerKm = 10.0;
  double _platformRatePerMin = 1.30;
  bool _isLoadingRates = true;

  @override
  void initState() {
    super.initState();
    _fetchRates();
  }

  Future<void> _fetchRates() async {
    final String platform = widget.ocrData['platform'] ?? 'other';
    final fallbackDefaults = {
      'uber': {'rate_per_km': 12.00, 'rate_per_min': 1.50},
      'rapido': {'rate_per_km': 9.00, 'rate_per_min': 1.20},
      'ola': {'rate_per_km': 11.50, 'rate_per_min': 1.40},
      'indrive': {'rate_per_km': 10.00, 'rate_per_min': 1.10},
      'zomato': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
      'swiggy': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
      'dunzo': {'rate_per_km': 8.50, 'rate_per_min': 1.10},
      'blinkit': {'rate_per_km': 9.00, 'rate_per_min': 1.05},
      'zepto': {'rate_per_km': 8.50, 'rate_per_min': 1.00},
      'bigbasket': {'rate_per_km': 9.50, 'rate_per_min': 1.15},
      'amazon_flex': {'rate_per_km': 10.50, 'rate_per_min': 1.20},
      'urban_company': {'rate_per_km': 14.00, 'rate_per_min': 1.70},
      'porter': {'rate_per_km': 13.00, 'rate_per_min': 1.50},
      'housejoy': {'rate_per_km': 12.50, 'rate_per_min': 1.40},
      'other': {'rate_per_km': 10.00, 'rate_per_min': 1.30},
    };

    try {
      final doc = await FirebaseFirestore.instance.collection('benchmarks').doc(platform).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _platformRatePerKm = (data['rate_per_km'] as num?)?.toDouble() ?? (fallbackDefaults[platform]?['rate_per_km'] ?? 10.0);
          _platformRatePerMin = (data['rate_per_min'] as num?)?.toDouble() ?? (fallbackDefaults[platform]?['rate_per_min'] ?? 1.30);
          _isLoadingRates = false;
        });
      } else {
        final rates = fallbackDefaults[platform] ?? fallbackDefaults['other']!;
        setState(() {
          _platformRatePerKm = rates['rate_per_km']!;
          _platformRatePerMin = rates['rate_per_min']!;
          _isLoadingRates = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching benchmark rates: $e");
      final rates = fallbackDefaults[platform] ?? fallbackDefaults['other']!;
      setState(() {
        _platformRatePerKm = rates['rate_per_km']!;
        _platformRatePerMin = rates['rate_per_min']!;
        _isLoadingRates = false;
      });
    }
  }

  String _getTimeOfDayBucket(DateTime dt) {
    final hour = dt.hour;
    if (hour >= 6 && hour < 12) {
      return 'morning';
    } else if (hour >= 16 && hour < 21) {
      return 'evening';
    } else {
      return 'latenight';
    }
  }

  Future<void> _logJob(double platformExpected, double genericExpected) async {
    setState(() {
      _isSaving = true;
    });

    final s = StringsProvider.instance;
    final String platform = widget.ocrData['platform'] ?? 'other';
    final double fare = (widget.ocrData['fare'] as num).toDouble();
    final double distance = (widget.ocrData['distance'] as num).toDouble();
    final double duration = (widget.ocrData['duration'] as num).toDouble();
    final bool isUnderpaid = fare < (platformExpected * 0.85);

    final String capitalizedPlatform = platform.isNotEmpty
        ? platform[0].toUpperCase() + platform.substring(1)
        : '';
    final String explanationText = isUnderpaid
        ? "This came in noticeably below what's typical for this distance and platform."
        : "This is about what's typical for a ${distance.toStringAsFixed(1)}km $capitalizedPlatform trip.";

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

    final jobData = {
      'user_id': userId,
      'platform': platform,
      'fare': fare,
      'distance_km': distance,
      'duration_min': duration,
      'expected_fare': double.parse(platformExpected.toStringAsFixed(2)),
      'is_underpaid': isUnderpaid,
      'explanation': explanationText,
      'source': 'ocr',
      'rate_source': 'fallback',
      'area_hint': '',
      'job_timestamp': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
      'base_fare': widget.ocrData['base_fare'] != null ? (widget.ocrData['base_fare'] as num).toDouble() : null,
      'incentive_amount': widget.ocrData['incentive_amount'] != null ? (widget.ocrData['incentive_amount'] as num).toDouble() : null,
      'surge_amount': widget.ocrData['surge_amount'] != null ? (widget.ocrData['surge_amount'] as num).toDouble() : null,
      'deduction_amount': widget.ocrData['deduction_amount'] != null ? (widget.ocrData['deduction_amount'] as num).toDouble() : null,
      'deduction_reason_stated': widget.ocrData['deduction_reason_stated'] as bool?,
    };

    try {
      await FirebaseFirestore.instance.collection('jobs').add(jobData);
      debugPrint("Successfully saved OCR job to Firestore.");

      // Write public anonymized report for the map
      final String rawLocality = (widget.ocrData['area_hint'] ?? widget.ocrData['locality'] ?? '').toString().trim();
      if (rawLocality.isNotEmpty) {
        final anonymizedData = {
          'isSeedData': false,
          'platform': platform.toLowerCase(),
          'locality': rawLocality.toLowerCase(),
          'timeOfDay': _getTimeOfDayBucket(DateTime.now()),
          'fareActual': fare,
          'fareExpected': double.parse(platformExpected.toStringAsFixed(2)),
          'distanceKm': distance,
          'durationMin': duration,
          'reportedAt': FieldValue.serverTimestamp(),
        };
        FirebaseFirestore.instance
            .collection('mapFairnessReports')
            .add(anonymizedData)
            .then((_) => debugPrint("Successfully saved anonymous OCR report to mapFairnessReports"))
            .catchError((err) => debugPrint("Failed to save anonymous OCR report: $err"));
      }

      String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      if (!kIsWeb && Platform.isAndroid && (baseUrl.contains("127.0.0.1") || baseUrl.contains("localhost"))) {
        baseUrl = baseUrl.replaceAll("127.0.0.1", "10.0.2.2").replaceAll("localhost", "10.0.2.2");
      }

      // Trigger background auto-recalculate
      final Uri recalculateUrl = Uri.parse('$baseUrl/admin/recalculate-benchmarks?platform=${platform.toLowerCase()}');
      http.post(recalculateUrl, headers: {'ngrok-skip-browser-warning': 'true'}).then((response) {
        debugPrint("Background auto-recalculate triggered: ${response.statusCode}");
      }).catchError((err) {
        debugPrint("Failed auto-recalculate: $err");
      });

      if (userId != 'anonymous_user') {
        final Uri url = Uri.parse('$baseUrl/weekly-insight?user_id=$userId&language_code=${StringsProvider.instance.lang}');
        http.get(url, headers: {'ngrok-skip-browser-warning': 'true'}).then((response) {
          debugPrint("Background weekly-insight triggered: ${response.statusCode}");
        }).catchError((err) {
          debugPrint("Failed weekly-insight: $err");
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.t('logjob_success'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            backgroundColor: PlayfulColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // Go back
      }
    } catch (e) {
      debugPrint("OCR Firestore save error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(StringsProvider.instance.t('err_failed_parse_receipt'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
            backgroundColor: PlayfulColors.secondary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    final platform = widget.ocrData['platform'] ?? 'other';
    final double fare = (widget.ocrData['fare'] as num?)?.toDouble() ?? 0.0;
    final double distance = (widget.ocrData['distance'] as num?)?.toDouble() ?? 0.0;
    final double duration = (widget.ocrData['duration'] as num?)?.toDouble() ?? 0.0;

    final double genericExpected = (12.0 * distance) + (1.0 * duration);
    final double platformExpected = (_platformRatePerKm * distance) + (_platformRatePerMin * duration);

    final bool isUnderpaid = fare < (platformExpected * 0.85);
    final String badgeText = isUnderpaid ? "⚠️ ${s.t('badge_underpaid')}" : "✅ ${s.t('badge_fair_pay')}";

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      bottomNavigationBar: _isLoadingRates
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PlayfulButton(
                      onPressed: _isSaving ? null : () => _logJob(platformExpected, genericExpected),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(s.t('logjob_btn_confirm')),
                    ),
                    const SizedBox(height: 12),
                    PlayfulSecondaryButton(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit();
                      },
                      child: Text(s.t('btn_edit')),
                    ),
                  ],
                ),
              ),
            ),
      body: SafeArea(
        child: _isLoadingRates
            ? const Center(child: CircularProgressIndicator(color: PlayfulColors.accent))
            : SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      Text(
                        s.t('auto_ocr_result_screen_screenshot_analysis_result'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 2.0,
                          color: PlayfulColors.mutedForeground,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Animated badge status
                      Center(
                        child: PlayfulBadge(
                          text: badgeText,
                          isUnderpaid: isUnderpaid,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Clean Extracted Fields Summary
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: PlayfulColors.border, width: 2.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.t('auto_ocr_result_screen_extracted_trip_details'),
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1.2,
                                color: PlayfulColors.mutedForeground,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildInfoRow("Platform", platform.toUpperCase()),
                            const Divider(color: PlayfulColors.border, thickness: 1),
                            _buildInfoRow("Fare", "₹${fare.toStringAsFixed(2)}"),
                            const Divider(color: PlayfulColors.border, thickness: 1),
                            _buildInfoRow("Distance", "${distance.toStringAsFixed(1)} km"),
                            const Divider(color: PlayfulColors.border, thickness: 1),
                            _buildInfoRow("Duration", "${duration.toStringAsFixed(0)} mins"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Benchmarks Comparison Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildComparisonCard(
                              title: s.t('label_platform_benchmark'),
                              amount: platformExpected,
                              shadowColor: PlayfulColors.accent,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildComparisonCard(
                              title: s.t('label_standard_gig_rate'),
                              amount: genericExpected,
                              shadowColor: PlayfulColors.tertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: PlayfulColors.mutedForeground,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: PlayfulColors.foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required double amount,
    required Color shadowColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PlayfulColors.border, width: 2.0),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 10,
              color: PlayfulColors.mutedForeground,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              "₹${amount.toStringAsFixed(2)}",
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: PlayfulColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
