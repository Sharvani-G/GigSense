import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

    // 1. Fetch the benchmark values (remote or fallback)
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

    // 2. Calculate the fairness indicators
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
      'source': 'manual',
      'job_timestamp': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };

    // Keep a local copy with local time for immediately passing to UI
    final localJobData = {
      'user_id': userId,
      'platform': platform,
      'fare': fare,
      'distance_km': distance,
      'duration_min': duration,
      'expected_fare': roundedExpectedFare,
      'is_underpaid': isUnderpaid,
      'source': 'manual',
      'job_timestamp': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    // 3. Write row directly to Firestore
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

      // Clear the inputs
      _fareController.clear();
      _distanceController.clear();
      _durationController.clear();
      setState(() {
        _selectedPlatform = "uber";
      });
      _checkFormValid();

      // Navigate to results
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
                        // App Logo Text
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

                        // Pill Toggle
                        PlayfulToggle(
                          activeOption: _activeToggle,
                          onChanged: (val) {
                            setState(() {
                              _activeToggle = val;
                            });
                          },
                        ),
                        const SizedBox(height: 32),

                        // Form Fields
                        PlayfulInput(
                          labelText: "PLATFORM",
                          hintText: "Select Platform",
                          dropdownItems: _platforms,
                          selectedDropdownValue: _selectedPlatform,
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Fare is required";
                            final numVal = double.tryParse(val);
                            if (numVal == null || numVal <= 0) return "Must be a positive number";
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        PlayfulInput(
                          labelText: "DISTANCE (KM)",
                          hintText: "Enter trip distance",
                          controller: _distanceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Distance is required";
                            final numVal = double.tryParse(val);
                            if (numVal == null || numVal <= 0) return "Must be a positive decimal";
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        PlayfulInput(
                          labelText: "DURATION (MIN)",
                          hintText: "Enter duration in minutes",
                          controller: _durationController,
                          keyboardType: TextInputType.number,
                          validator: (val) {
                            if (val == null || val.isEmpty) return "Duration is required";
                            final numVal = double.tryParse(val);
                            if (numVal == null || numVal <= 0) return "Must be a positive number";
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Log Job Button
                        PlayfulButton(
                          onPressed: _isFormValid ? _submitJob : null,
                          child: const Text("LOG JOB"),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
