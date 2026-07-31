import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'playful_widgets.dart';
import 'fairness_result_screen.dart';

class LogJobScreen extends StatefulWidget {
  const LogJobScreen({super.key});

  @override
  State<LogJobScreen> createState() => _LogJobScreenState();
}

class _LogJobScreenState extends State<LogJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fareController = TextEditingController();
  final _distanceController = TextEditingController();
  final _durationController = TextEditingController();

  String _activeToggle = "manual";
  String? _selectedPlatform = "uber";
  bool _isFormValid = false;
  bool _isLoading = false;
  bool _isOcrLoading = false;
  
  // OCR specific states
  String _jobSource = "manual"; // "manual" or "ocr"
  String? _ocrGeneralNote; // Error fallback message
  String? _fareOcrNote;
  String? _distanceOcrNote;
  String? _durationOcrNote;

  // Highlight pulse flags
  bool _fareHighlighted = false;
  bool _distanceHighlighted = false;
  bool _durationHighlighted = false;
  bool _platformHighlighted = false;

  final List<String> _platforms = ["Uber", "Rapido", "Zomato", "Swiggy", "Other"];

  @override
  void initState() {
    super.initState();
    _fareController.addListener(_checkFormValid);
    _distanceController.addListener(_checkFormValid);
    _durationController.addListener(_checkFormValid);
    _seedBenchmarksIfNeeded();
  }

  @override
  void dispose() {
    _fareController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _checkFormValid() {
    final fare = double.tryParse(_fareController.text) ?? 0.0;
    final distance = double.tryParse(_distanceController.text) ?? 0.0;
    final duration = double.tryParse(_durationController.text) ?? 0.0;

    final isValid = _selectedPlatform != null &&
        fare > 0 &&
        distance > 0 &&
        duration > 0;

    if (isValid != _isFormValid) {
      setState(() {
        _isFormValid = isValid;
      });
    }
  }

  Future<void> _seedBenchmarksIfNeeded() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final query = await firestore.collection('benchmarks').limit(1).get();
      if (query.docs.isEmpty) {
        final defaults = {
          'uber': {'rate_per_km': 12.00, 'rate_per_min': 1.50},
          'rapido': {'rate_per_km': 9.00, 'rate_per_min': 1.20},
          'zomato': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
          'swiggy': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
          'other': {'rate_per_km': 10.00, 'rate_per_min': 1.30},
        };
        for (var entry in defaults.entries) {
          await firestore.collection('benchmarks').doc(entry.key).set(entry.value);
        }
        debugPrint("Seeded default benchmarks into Firestore.");
      }
    } catch (e) {
      debugPrint("Auto-seeding benchmarks failed (expected if Firebase is offline): $e");
    }
  }

  Future<void> _pickAndScanImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile == null) {
      // User cancelled picker, return to manual
      setState(() {
        _activeToggle = "manual";
      });
      return;
    }

    setState(() {
      _isOcrLoading = true;
      _ocrGeneralNote = null;
      _fareOcrNote = null;
      _distanceOcrNote = null;
      _durationOcrNote = null;
    });

    final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
    final Uri url = Uri.parse('$baseUrl/jobs/scan');

    try {
      final request = http.MultipartRequest('POST', url)
        ..files.add(await http.MultipartFile.fromPath('file', pickedFile.path));
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        final String? platform = data['platform'];
        final double? fare = data['fare'] != null ? (data['fare'] as num).toDouble() : null;
        final double? distance = data['distance_km'] != null ? (data['distance_km'] as num).toDouble() : null;
        final double? duration = data['duration_min'] != null ? (data['duration_min'] as num).toDouble() : null;

        setState(() {
          _jobSource = "ocr";
          _activeToggle = "manual"; // Back to manual form prefilled
          
          if (platform != null && _platforms.map((e) => e.toLowerCase()).contains(platform.toLowerCase())) {
            _selectedPlatform = platform.toLowerCase();
            _platformHighlighted = true;
          } else {
            _selectedPlatform = "other";
          }

          if (fare != null) {
            _fareController.text = fare.toString();
            _fareHighlighted = true;
          } else {
            _fareController.clear();
            _fareOcrNote = "Fare not detected in screenshot.";
          }

          if (distance != null) {
            _distanceController.text = distance.toString();
            _distanceHighlighted = true;
          } else {
            _distanceController.clear();
            _distanceOcrNote = "Distance not detected in screenshot.";
          }

          if (duration != null) {
            _durationController.text = duration.toString();
            _durationHighlighted = true;
          } else {
            _durationController.clear();
            _durationOcrNote = "Duration not detected in screenshot.";
          }
        });

        // Clear highlight flags after animation completes
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            setState(() {
              _fareHighlighted = false;
              _distanceHighlighted = false;
              _durationHighlighted = false;
              _platformHighlighted = false;
            });
          }
        });
      } else {
        // 422 or other status codes -> Fail gracefully
        throw Exception("Backend failed with status code ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("OCR scan failed: $e. Falling back to blank form.");
      setState(() {
        _activeToggle = "manual";
        _jobSource = "manual";
        _ocrGeneralNote = "Couldn't read the screenshot clearly — go ahead and fill this in.";
        _fareController.clear();
        _distanceController.clear();
        _durationController.clear();
        _selectedPlatform = "uber";
      });
    } finally {
      setState(() {
        _isOcrLoading = false;
      });
    }
  }

  Future<void> _submitJob() async {
    if (!_formKey.currentState!.validate()) return;

    final double fare = double.parse(_fareController.text);
    final double distance = double.parse(_distanceController.text);
    final double duration = double.parse(_durationController.text);
    final String platform = _selectedPlatform ?? 'other';

    setState(() {
      _isLoading = true;
    });

    double ratePerKm = 10.00;
    double ratePerMin = 1.30;

    // Fetch the benchmark values
    try {
      final doc = await FirebaseFirestore.instance
          .collection('benchmarks')
          .doc(platform)
          .get();

      if (doc.exists && doc.data() != null) {
        ratePerKm = (doc.data()!['rate_per_km'] as num?)?.toDouble() ?? ratePerKm;
        ratePerMin = (doc.data()!['rate_per_min'] as num?)?.toDouble() ?? ratePerMin;
      } else {
        final fallbackDefaults = {
          'uber': {'rate_per_km': 12.00, 'rate_per_min': 1.50},
          'rapido': {'rate_per_km': 9.00, 'rate_per_min': 1.20},
          'zomato': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
          'swiggy': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
          'other': {'rate_per_km': 10.00, 'rate_per_min': 1.30},
        };
        final rates = fallbackDefaults[platform] ?? fallbackDefaults['other']!;
        ratePerKm = rates['rate_per_km']!;
        ratePerMin = rates['rate_per_min']!;
      }
    } catch (e) {
      debugPrint("Error fetching benchmarks: $e. Using local fallbacks.");
      final fallbackDefaults = {
        'uber': {'rate_per_km': 12.00, 'rate_per_min': 1.50},
        'rapido': {'rate_per_km': 9.00, 'rate_per_min': 1.20},
        'zomato': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
        'swiggy': {'rate_per_km': 8.00, 'rate_per_min': 1.00},
        'other': {'rate_per_km': 10.00, 'rate_per_min': 1.30},
      };
      final rates = fallbackDefaults[platform] ?? fallbackDefaults['other']!;
      ratePerKm = rates['rate_per_km']!;
      ratePerMin = rates['rate_per_min']!;
    }

    final expectedFare = (ratePerKm * distance) + (ratePerMin * duration);
    final roundedExpectedFare = double.parse(expectedFare.toStringAsFixed(2));
    final isUnderpaid = fare < (roundedExpectedFare * 0.85);

    final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';

    final jobData = {
      'user_id': userId,
      'platform': platform,
      'fare': fare,
      'distance_km': distance,
      'duration_min': duration,
      'expected_fare': roundedExpectedFare,
      'is_underpaid': isUnderpaid,
      'source': _jobSource,
      'job_timestamp': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };

    final localJobData = {
      'user_id': userId,
      'platform': platform,
      'fare': fare,
      'distance_km': distance,
      'duration_min': duration,
      'expected_fare': roundedExpectedFare,
      'is_underpaid': isUnderpaid,
      'source': _jobSource,
      'job_timestamp': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      final docRef = await FirebaseFirestore.instance.collection('jobs').add(jobData);
      localJobData['id'] = docRef.id;
      debugPrint("Successfully saved job to Firestore with ID: ${docRef.id}");
    } catch (e) {
      debugPrint("Firebase write failed: $e. Running in offline/mock fallback mode.");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Running in offline mode: Job calculation completed successfully!",
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
          ),
          backgroundColor: PlayfulColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: PlayfulColors.border, width: 2),
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });

      _fareController.clear();
      _distanceController.clear();
      _durationController.clear();
      setState(() {
        _selectedPlatform = "uber";
        _jobSource = "manual"; // Reset source to manual
        _ocrGeneralNote = null;
        _fareOcrNote = null;
        _distanceOcrNote = null;
        _durationOcrNote = null;
      });
      _checkFormValid();

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FairnessResultScreen(job: localJobData),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayfulColors.background,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: PlayfulColors.accent,
                ),
              )
            : SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        Text(
                          "GIGSHIELD",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                            letterSpacing: 2.0,
                            color: PlayfulColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Log your trip to verify your pay instantly.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: PlayfulColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 24),

                        PlayfulToggle(
                          activeOption: _activeToggle,
                          onChanged: (val) {
                            setState(() {
                              _activeToggle = val;
                            });
                            if (val == "scan") {
                              _pickAndScanImage();
                            }
                          },
                        ),
                        const SizedBox(height: 32),

                        if (_activeToggle == "scan" || _isOcrLoading) ...[
                          Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: PlayfulColors.border, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: PlayfulColors.border,
                                  offset: Offset(4, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    color: PlayfulColors.accent,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    "Analyzing screenshot...",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: PlayfulColors.foreground,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          if (_ocrGeneralNote != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: PlayfulColors.tertiary.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: PlayfulColors.border, width: 2),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: PlayfulColors.foreground),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _ocrGeneralNote!,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        color: PlayfulColors.foreground,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          PlayfulInput(
                            labelText: "PLATFORM",
                            hintText: "Select Platform",
                            dropdownItems: _platforms,
                            selectedDropdownValue: _selectedPlatform,
                            isHighlighted: _platformHighlighted,
                            onDropdownChanged: (val) {
                              setState(() {
                                _selectedPlatform = val;
                              });
                              _checkFormValid();
                            },
                          ),
                          const SizedBox(height: 20),

                          PlayfulInput(
                            labelText: "FARE (₹)",
                            hintText: "Enter fare amount",
                            controller: _fareController,
                            prefixText: "₹ ",
                            isHighlighted: _fareHighlighted,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Fare is required";
                              final numVal = double.tryParse(val);
                              if (numVal == null || numVal <= 0) return "Must be a positive number";
                              return null;
                            },
                          ),
                          if (_fareOcrNote != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _fareOcrNote!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: PlayfulColors.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          PlayfulInput(
                            labelText: "DISTANCE (KM)",
                            hintText: "Enter trip distance",
                            controller: _distanceController,
                            isHighlighted: _distanceHighlighted,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Distance is required";
                              final numVal = double.tryParse(val);
                              if (numVal == null || numVal <= 0) return "Must be a positive decimal";
                              return null;
                            },
                          ),
                          if (_distanceOcrNote != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _distanceOcrNote!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: PlayfulColors.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),

                          PlayfulInput(
                            labelText: "DURATION (MIN)",
                            hintText: "Enter duration in minutes",
                            controller: _durationController,
                            isHighlighted: _durationHighlighted,
                            keyboardType: TextInputType.number,
                            validator: (val) {
                              if (val == null || val.isEmpty) return "Duration is required";
                              final numVal = double.tryParse(val);
                              if (numVal == null || numVal <= 0) return "Must be a positive number";
                              return null;
                            },
                          ),
                          if (_durationOcrNote != null) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4, left: 4),
                              child: Text(
                                _durationOcrNote!,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  color: PlayfulColors.mutedForeground,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),

                          PlayfulButton(
                            onPressed: _isFormValid ? _submitJob : null,
                            child: Text(_jobSource == "ocr" ? "CONFIRM & LOG JOB" : "LOG JOB"),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
