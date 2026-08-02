import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'playful_widgets.dart';
import '../i18n/strings.dart';

class CandidateRow {
  String platform;
  final TextEditingController fareController;
  final TextEditingController distanceController;
  String distanceUnit;
  final TextEditingController durationController;
  String durationUnit;

  CandidateRow({
    required this.platform,
    required String fare,
    required String distance,
    required this.distanceUnit,
    required String duration,
    required this.durationUnit,
  })  : fareController = TextEditingController(text: fare),
        distanceController = TextEditingController(text: distance),
        durationController = TextEditingController(text: duration);

  void dispose() {
    fareController.dispose();
    distanceController.dispose();
    durationController.dispose();
  }
}

class BatchConfirmScreen extends StatefulWidget {
  final List<dynamic> candidates;

  const BatchConfirmScreen({super.key, required this.candidates});

  @override
  State<BatchConfirmScreen> createState() => _BatchConfirmScreenState();
}

class _BatchConfirmScreenState extends State<BatchConfirmScreen> {
  final List<CandidateRow> _rows = [];
  bool _isSubmitting = false;

  final List<Map<String, String>> _platforms = [
    {'id': 'uber', 'name': 'Uber'},
    {'id': 'rapido', 'name': 'Rapido'},
    {'id': 'ola', 'name': 'Ola'},
    {'id': 'indrive', 'name': 'InDrive'},
    {'id': 'zomato', 'name': 'Zomato'},
    {'id': 'swiggy', 'name': 'Swiggy'},
    {'id': 'dunzo', 'name': 'Dunzo'},
    {'id': 'blinkit', 'name': 'Blinkit'},
    {'id': 'zepto', 'name': 'Zepto'},
    {'id': 'bigbasket', 'name': 'BigBasket'},
    {'id': 'amazon_flex', 'name': 'Amazon Flex'},
    {'id': 'urban_company', 'name': 'Urban Company'},
    {'id': 'porter', 'name': 'Porter'},
    {'id': 'housejoy', 'name': 'Housejoy'},
    {'id': 'other', 'name': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    for (var c in widget.candidates) {
      final String plat = c['platform'] ?? 'other';
      final String fare = c['fare'] != null ? c['fare'].toString() : '';
      final String distance = c['distance'] != null ? c['distance'].toString() : '';
      final String distUnit = c['distance_unit'] ?? 'km';
      final String duration = c['duration'] != null ? c['duration'].toString() : '';
      final String durUnit = c['duration_unit'] ?? 'min';

      _rows.add(CandidateRow(
        platform: plat,
        fare: fare,
        distance: distance,
        distanceUnit: distUnit,
        duration: duration,
        durationUnit: durUnit,
      ));
    }
  }

  @override
  void dispose() {
    for (var row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _submitAllJobs() async {
    // 1. Validation check
    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final fareVal = double.tryParse(row.fareController.text);
      final distVal = double.tryParse(row.distanceController.text);
      final durVal = double.tryParse(row.durationController.text);

      if (fareVal == null || fareVal <= 0) {
        _showError("Row #${i + 1} has an invalid or empty fare.");
        return;
      }
      if (distVal == null || distVal <= 0) {
        _showError("Row #${i + 1} has an invalid or empty distance.");
        return;
      }
      if (durVal == null || durVal <= 0) {
        _showError("Row #${i + 1} has an invalid or empty duration.");
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

      // Define local fallback rates mapping
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

      for (var row in _rows) {
        final fare = double.parse(row.fareController.text);
        final rawDist = double.parse(row.distanceController.text);
        final distance = row.distanceUnit == 'm' ? rawDist / 1000 : rawDist;
        final rawDur = double.parse(row.durationController.text);
        final duration = row.durationUnit == 'hr' ? rawDur * 60 : rawDur;

        // Retrieve benchmark
        double ratePerKm = 10.0;
        double ratePerMin = 1.3;
        try {
          final doc = await FirebaseFirestore.instance.collection('benchmarks').doc(row.platform).get();
          if (doc.exists && doc.data() != null) {
            ratePerKm = (doc.data()!['ratePerKm'] as num).toDouble();
            ratePerMin = (doc.data()!['ratePerMin'] as num).toDouble();
          } else {
            final rates = fallbackDefaults[row.platform] ?? fallbackDefaults['other']!;
            ratePerKm = rates['rate_per_km']!;
            ratePerMin = rates['rate_per_min']!;
          }
        } catch (_) {
          final rates = fallbackDefaults[row.platform] ?? fallbackDefaults['other']!;
          ratePerKm = rates['rate_per_km']!;
          ratePerMin = rates['rate_per_min']!;
        }

        final expectedFare = (ratePerKm * distance) + (ratePerMin * duration);
        final roundedExpectedFare = double.parse(expectedFare.toStringAsFixed(2));
        final isUnderpaid = fare < (roundedExpectedFare * 0.85);

        final String capitalizedPlatform = row.platform.isNotEmpty
            ? row.platform[0].toUpperCase() + row.platform.substring(1)
            : '';
        final String explanationText = isUnderpaid
            ? "This came in noticeably below what's typical for this distance and platform."
            : "This is about what's typical for a ${distance.toStringAsFixed(1)}km $capitalizedPlatform trip.";

        final jobData = {
          'user_id': uid,
          'platform': row.platform,
          'fare': fare,
          'distance_km': distance,
          'duration_min': duration,
          'expected_fare': roundedExpectedFare,
          'is_underpaid': isUnderpaid,
          'explanation': explanationText,
          'source': 'ocr',
          'rate_source': 'fallback',
          'job_timestamp': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance.collection('jobs').add(jobData);
      }

      // Fire background community rates recalculation for distinct platforms imported in this batch
      final distinctPlatforms = _rows.map((r) => r.platform.toLowerCase().trim()).where((p) => p.isNotEmpty).toSet();
      final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      for (final platform in distinctPlatforms) {
        final Uri recalculateUrl = Uri.parse('$baseUrl/admin/recalculate-benchmarks?platform=$platform');
        http.post(recalculateUrl).then((response) {
          debugPrint("Background batch auto-recalculate triggered for $platform: ${response.statusCode}");
        }).catchError((err) {
          debugPrint("Failed to trigger background batch auto-recalculate for $platform: $err");
        });
      }

      // Fire insight regeneration once
      if (uid != 'anonymous_user') {
        final Uri url = Uri.parse('$baseUrl/weekly-insight?user_id=$uid');
        http.get(url).then((response) {
          debugPrint("Background batch weekly-insight regeneration triggered: ${response.statusCode}");
        }).catchError((err) {
          debugPrint("Failed to trigger background weekly-insight: $err");
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Successfully logged ${_rows.length} jobs!")),
      );
      Navigator.pop(context);
    } catch (e) {
      _showError("Failed to save jobs: $e");
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: PlayfulColors.secondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        title: Text(
          "CONFIRM BATCH SCANS",
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18, color: PlayfulColors.foreground),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: PlayfulColors.foreground),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Text(
                "We detected ${_rows.length} trip entries. Verify or edit each one before committing to logs.",
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PlayfulColors.mutedForeground,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _rows.length,
                itemBuilder: (context, index) {
                  final row = _rows[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: PlayfulColors.border, width: 2.0),
                      boxShadow: const [
                        BoxShadow(
                          color: PlayfulColors.tertiary,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "TRIP #${index + 1}",
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: PlayfulColors.mutedForeground,
                                letterSpacing: 1.0,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _rows.removeAt(index);
                                });
                              },
                              icon: const Icon(Icons.delete_outline, color: PlayfulColors.secondary, size: 24),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        PlayfulInput(
                          labelText: "Platform",
                          dropdownItems: _platforms.map((p) => p['name']!).toList(),
                          selectedDropdownValue: _platforms.firstWhere(
                            (p) => p['id'] == row.platform,
                            orElse: () => _platforms.last,
                          )['name']!.toLowerCase(),
                          onDropdownChanged: (newVal) {
                            if (newVal != null) {
                              final matched = _platforms.firstWhere(
                                (p) => p['name']!.toLowerCase() == newVal.toLowerCase(),
                                orElse: () => _platforms.last,
                              );
                              setState(() {
                                row.platform = matched['id']!;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        PlayfulInput(
                          labelText: "Fare (₹)",
                          hintText: "Enter fare amount",
                          controller: row.fareController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: PlayfulUnitInput(
                                labelText: "Distance",
                                hintText: "Distance",
                                controller: row.distanceController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                unitOptions: const ["km", "m"],
                                currentUnit: row.distanceUnit,
                                onUnitChanged: (unit) {
                                  setState(() {
                                    row.distanceUnit = unit;
                                  });
                                },
                                isHighlighted: false,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: PlayfulUnitInput(
                                labelText: "Duration",
                                hintText: "Duration",
                                controller: row.durationController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                unitOptions: const ["min", "hr"],
                                currentUnit: row.durationUnit,
                                onUnitChanged: (unit) {
                                  setState(() {
                                    row.durationUnit = unit;
                                  });
                                },
                                isHighlighted: false,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isSubmitting
                  ? const Center(child: CircularProgressIndicator(color: PlayfulColors.accent))
                  : PlayfulButton(
                      onPressed: _rows.isEmpty ? null : _submitAllJobs,
                      child: Text("CONFIRM & LOG ALL (${_rows.length})"),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
