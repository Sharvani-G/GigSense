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
import '../i18n/strings.dart';

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
  String? _selectedPlatform;
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

  final _searchController = TextEditingController();
  final _platformFieldController = TextEditingController();
  List<PlatformItem> _allPlatforms = [];
  List<PlatformItem> _filteredPlatforms = [];
  String _workerType = 'other_gig_worker';

  final _categoryLabels = {
    'cab': 'CAB & RIDE-HAILING',
    'delivery': 'DELIVERY',
    'other_gig': 'OTHER GIG WORK',
  };

  @override
  void initState() {
    super.initState();
    _fareController.addListener(_checkFormValid);
    _distanceController.addListener(_checkFormValid);
    _durationController.addListener(_checkFormValid);
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _seedBenchmarksIfNeeded();
    await _loadUserProfileAndPlatforms();
  }

  @override
  void dispose() {
    _fareController.dispose();
    _distanceController.dispose();
    _durationController.dispose();
    _searchController.dispose();
    _platformFieldController.dispose();
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

  double? parseSpokenPhrase(String text) {
    // First, check for digit strings
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }

    const Map<String, double> spokenNumbers = {
      // English
      'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6, 'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10,
      'hundred': 100, 'thousand': 1000,
      // Hindi
      'ek': 1, 'do': 2, 'teen': 3, 'chaar': 4, 'paanch': 5, 'chhey': 6, 'saat': 7, 'aath': 8, 'nau': 9, 'das': 10,
      'sau': 100, 'hazaar': 1000, 'hajar': 1000,
      // Kannada
      'ondu': 1, 'eradu': 2, 'mooru': 3, 'naalku': 4, 'aidu': 5, 'aaru': 6, 'elu': 7, 'entu': 8, 'ombattu': 9, 'hattu': 10,
      'nooru': 100, 'saavira': 1000,
      // Telugu
      'okati': 1, 'rendu': 2, 'moodu': 3, 'naalugu': 4, 'edu': 7, 'enimidi': 8, 'tommidi': 9, 'padi': 10,
      'vei': 1000,
      // Tamil
      'ondru': 1, 'irandu': 2, 'moondru': 3, 'naangu': 4, 'aindhu': 5, 'ezhu': 7, 'ettu': 8, 'onbadhu': 9, 'pathu': 10,
      'aayiram': 1000,
      // Malayalam
      'onnu': 1, 'moonnu': 3, 'naalu': 4, 'anchu': 5, 'onpathu': 9,
    };

    final words = text.toLowerCase().split(RegExp(r'\s+'));
    double total = 0.0;
    double current = 0.0;

    for (var word in words) {
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      if (spokenNumbers.containsKey(cleanWord)) {
        final val = spokenNumbers[cleanWord]!;
        if (val == 100 || val == 1000) {
          if (current == 0.0) current = 1.0;
          total += current * val;
          current = 0.0;
        } else {
          current += val;
        }
      }
    }
    total += current;
    return total > 0 ? total : null;
  }

  void _parseAndSetNumber(String text, TextEditingController controller) {
    final parsed = parseSpokenPhrase(text);
    if (parsed != null) {
      setState(() {
        if (parsed == parsed.toInt()) {
          controller.text = parsed.toInt().toString();
        } else {
          controller.text = parsed.toString();
        }
      });
      _checkFormValid();
    }
  }

  Future<void> _seedBenchmarksIfNeeded() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final query = await firestore.collection('benchmarks').get();
      if (query.docs.length < 10) {
        final defaults = {
          'uber': {'displayName': 'Uber', 'rate_per_km': 12.00, 'rate_per_min': 1.50, 'category': 'cab'},
          'rapido': {'displayName': 'Rapido', 'rate_per_km': 9.00, 'rate_per_min': 1.20, 'category': 'cab'},
          'ola': {'displayName': 'Ola', 'rate_per_km': 11.50, 'rate_per_min': 1.40, 'category': 'cab'},
          'indrive': {'displayName': 'InDrive', 'rate_per_km': 10.00, 'rate_per_min': 1.10, 'category': 'cab'},
          'zomato': {'displayName': 'Zomato', 'rate_per_km': 8.00, 'rate_per_min': 1.00, 'category': 'delivery'},
          'swiggy': {'displayName': 'Swiggy', 'rate_per_km': 8.00, 'rate_per_min': 1.00, 'category': 'delivery'},
          'dunzo': {'displayName': 'Dunzo', 'rate_per_km': 8.50, 'rate_per_min': 1.10, 'category': 'delivery'},
          'blinkit': {'displayName': 'Blinkit', 'rate_per_km': 9.00, 'rate_per_min': 1.05, 'category': 'delivery'},
          'zepto': {'displayName': 'Zepto', 'rate_per_km': 8.50, 'rate_per_min': 1.00, 'category': 'delivery'},
          'bigbasket': {'displayName': 'BigBasket', 'rate_per_km': 9.50, 'rate_per_min': 1.15, 'category': 'delivery'},
          'amazon_flex': {'displayName': 'Amazon Flex', 'rate_per_km': 10.50, 'rate_per_min': 1.20, 'category': 'delivery'},
          'urban_company': {'displayName': 'Urban Company', 'rate_per_km': 14.00, 'rate_per_min': 1.70, 'category': 'other_gig'},
          'porter': {'displayName': 'Porter', 'rate_per_km': 13.00, 'rate_per_min': 1.50, 'category': 'other_gig'},
          'housejoy': {'displayName': 'Housejoy', 'rate_per_km': 12.50, 'rate_per_min': 1.40, 'category': 'other_gig'},
          'other': {'displayName': 'Other', 'rate_per_km': 10.00, 'rate_per_min': 1.30, 'category': 'other_gig'},
        };
        for (var entry in defaults.entries) {
          final data = Map<String, dynamic>.from(entry.value);
          data['seedRate'] = {
            'rate_per_km': data['rate_per_km'],
            'rate_per_min': data['rate_per_min'],
          };
          data['communityRate'] = null;
          data['sampleSize'] = 0;
          await firestore.collection('benchmarks').doc(entry.key).set(data);
        }
        debugPrint("Seeded default benchmarks into Firestore.");
      }
    } catch (e) {
      debugPrint("Auto-seeding benchmarks failed (expected if Firebase is offline): $e");
    }
  }

  Future<void> _loadUserProfileAndPlatforms() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          setState(() {
            _workerType = doc.data()?['workerType'] ?? 'other_gig_worker';
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading workerType: $e");
    }

    try {
      final firestore = FirebaseFirestore.instance;
      final snapshot = await firestore.collection('benchmarks').get();
      if (snapshot.docs.isNotEmpty) {
        final List<PlatformItem> loaded = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final int sampleSize = (data['sampleSize'] as num?)?.toInt() ?? 0;
          
          double ratePerKm = 10.0;
          double ratePerMin = 1.3;
          
          Map<String, dynamic>? selectedRate;
          if (sampleSize >= 15 && data['communityRate'] != null) {
            selectedRate = data['communityRate'] as Map<String, dynamic>?;
          } else if (data['seedRate'] != null) {
            selectedRate = data['seedRate'] as Map<String, dynamic>?;
          }
          
          if (selectedRate != null) {
            ratePerKm = (selectedRate['rate_per_km'] as num?)?.toDouble() ?? ratePerKm;
            ratePerMin = (selectedRate['rate_per_min'] as num?)?.toDouble() ?? ratePerMin;
          } else {
            ratePerKm = (data['rate_per_km'] as num?)?.toDouble() ?? ratePerKm;
            ratePerMin = (data['rate_per_min'] as num?)?.toDouble() ?? ratePerMin;
          }

          loaded.add(PlatformItem(
            id: doc.id,
            displayName: data['displayName'] ?? doc.id.toUpperCase(),
            category: data['category'] ?? 'other_gig',
            ratePerKm: ratePerKm,
            ratePerMin: ratePerMin,
            sampleSize: sampleSize,
          ));
        }
        setState(() {
          _allPlatforms = loaded;
          _filteredPlatforms = List.from(loaded);
        });
      }
    } catch (e) {
      debugPrint("Error loading benchmarks: $e. Using local fallback list.");
    }

    if (_allPlatforms.isEmpty) {
      final defaults = [
        PlatformItem(id: 'uber', displayName: 'Uber', category: 'cab', ratePerKm: 12.0, ratePerMin: 1.50, sampleSize: 0),
        PlatformItem(id: 'rapido', displayName: 'Rapido', category: 'cab', ratePerKm: 9.0, ratePerMin: 1.20, sampleSize: 0),
        PlatformItem(id: 'ola', displayName: 'Ola', category: 'cab', ratePerKm: 11.50, ratePerMin: 1.40, sampleSize: 0),
        PlatformItem(id: 'indrive', displayName: 'InDrive', category: 'cab', ratePerKm: 10.0, ratePerMin: 1.10, sampleSize: 0),
        PlatformItem(id: 'zomato', displayName: 'Zomato', category: 'delivery', ratePerKm: 8.0, ratePerMin: 1.00, sampleSize: 0),
        PlatformItem(id: 'swiggy', displayName: 'Swiggy', category: 'delivery', ratePerKm: 8.0, ratePerMin: 1.00, sampleSize: 0),
        PlatformItem(id: 'dunzo', displayName: 'Dunzo', category: 'delivery', ratePerKm: 8.50, ratePerMin: 1.10, sampleSize: 0),
        PlatformItem(id: 'blinkit', displayName: 'Blinkit', category: 'delivery', ratePerKm: 9.0, ratePerMin: 1.05, sampleSize: 0),
        PlatformItem(id: 'zepto', displayName: 'Zepto', category: 'delivery', ratePerKm: 8.50, ratePerMin: 1.00, sampleSize: 0),
        PlatformItem(id: 'bigbasket', displayName: 'BigBasket', category: 'delivery', ratePerKm: 9.50, ratePerMin: 1.15, sampleSize: 0),
        PlatformItem(id: 'amazon_flex', displayName: 'Amazon Flex', category: 'delivery', ratePerKm: 10.50, ratePerMin: 1.20, sampleSize: 0),
        PlatformItem(id: 'urban_company', displayName: 'Urban Company', category: 'other_gig', ratePerKm: 14.00, ratePerMin: 1.70, sampleSize: 0),
        PlatformItem(id: 'porter', displayName: 'Porter', category: 'other_gig', ratePerKm: 13.00, ratePerMin: 1.50, sampleSize: 0),
        PlatformItem(id: 'housejoy', displayName: 'Housejoy', category: 'other_gig', ratePerKm: 12.50, ratePerMin: 1.40, sampleSize: 0),
        PlatformItem(id: 'other', displayName: 'Other', category: 'other_gig', ratePerKm: 10.0, ratePerMin: 1.30, sampleSize: 0),
      ];
      setState(() {
        _allPlatforms = defaults;
        _filteredPlatforms = List.from(defaults);
      });
    }

    if (_selectedPlatform == null) {
      if (_workerType == 'cab_driver') {
        _selectedPlatform = 'uber';
        _platformFieldController.text = 'Uber';
      } else if (_workerType == 'delivery_rider') {
        _selectedPlatform = 'zomato';
        _platformFieldController.text = 'Zomato';
      } else {
        _selectedPlatform = 'other';
        _platformFieldController.text = 'Other';
      }
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
          
          if (platform != null) {
            final matched = _allPlatforms.firstWhere(
              (p) => p.id == platform.toLowerCase(),
              orElse: () => PlatformItem(id: 'other', displayName: 'Other', category: 'other_gig', ratePerKm: 10.0, ratePerMin: 1.30),
            );
            if (matched.id != 'other') {
              _selectedPlatform = matched.id;
              _platformFieldController.text = matched.displayName;
              _platformHighlighted = true;
            } else {
              _selectedPlatform = "other";
              _platformFieldController.text = "Other";
            }
          } else {
            _selectedPlatform = "other";
            _platformFieldController.text = "Other";
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
        _selectedPlatform = "other";
        _platformFieldController.text = "Other";
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
    int jobSampleSize = 0;

    // Fetch the benchmark values
    try {
      final doc = await FirebaseFirestore.instance
          .collection('benchmarks')
          .doc(platform)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final int sampleSize = (data['sampleSize'] as num?)?.toInt() ?? 0;
        jobSampleSize = sampleSize;
        
        Map<String, dynamic>? selectedRate;
        if (sampleSize >= 15 && data['communityRate'] != null) {
          selectedRate = data['communityRate'] as Map<String, dynamic>?;
        } else if (data['seedRate'] != null) {
          selectedRate = data['seedRate'] as Map<String, dynamic>?;
        }
        
        if (selectedRate != null) {
          ratePerKm = (selectedRate['rate_per_km'] as num?)?.toDouble() ?? ratePerKm;
          ratePerMin = (selectedRate['rate_per_min'] as num?)?.toDouble() ?? ratePerMin;
        } else {
          ratePerKm = (data['rate_per_km'] as num?)?.toDouble() ?? ratePerKm;
          ratePerMin = (data['rate_per_min'] as num?)?.toDouble() ?? ratePerMin;
        }
      } else {
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
        final rates = fallbackDefaults[platform] ?? fallbackDefaults['other']!;
        ratePerKm = rates['rate_per_km']!;
        ratePerMin = rates['rate_per_min']!;
      }
    } catch (e) {
      debugPrint("Error fetching benchmarks: $e. Using local fallbacks.");
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
      final rates = fallbackDefaults[platform] ?? fallbackDefaults['other']!;
      ratePerKm = rates['rate_per_km']!;
      ratePerMin = rates['rate_per_min']!;
    }

    final expectedFare = (ratePerKm * distance) + (ratePerMin * duration);
    final roundedExpectedFare = double.parse(expectedFare.toStringAsFixed(2));
    final isUnderpaid = fare < (roundedExpectedFare * 0.85);

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
      'expected_fare': roundedExpectedFare,
      'is_underpaid': isUnderpaid,
      'explanation': explanationText,
      'source': _jobSource,
      'sample_size': jobSampleSize,
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
      'explanation': explanationText,
      'source': _jobSource,
      'sample_size': jobSampleSize,
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
            StringsProvider.instance.t('logjob_offline'),
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
                          StringsProvider.instance.t('app_name'),
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
                          StringsProvider.instance.t('logjob_subtitle'),
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
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    color: PlayfulColors.accent,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    StringsProvider.instance.t('logjob_analyzing'),
                                    style: const TextStyle(
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
                            labelText: StringsProvider.instance.t('logjob_platform'),
                            hintText: StringsProvider.instance.t('logjob_platform_hint'),
                            controller: _platformFieldController,
                            readOnly: true,
                            isHighlighted: _platformHighlighted,
                            onTap: () => _showPlatformPickerBottomSheet(context),
                          ),
                          const SizedBox(height: 20),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: PlayfulInput(
                                  labelText: StringsProvider.instance.t('logjob_fare'),
                                  hintText: StringsProvider.instance.t('logjob_fare_hint'),
                                  controller: _fareController,
                                  prefixText: "₹ ",
                                  isHighlighted: _fareHighlighted,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return StringsProvider.instance.t('logjob_fare_required');
                                    final numVal = double.tryParse(val);
                                    if (numVal == null || numVal <= 0) return StringsProvider.instance.t('logjob_positive');
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: PlayfulMicButton(
                                  textOnLeft: true,
                                  onSpeechResult: (text) => _parseAndSetNumber(text, _fareController),
                                ),
                              ),
                            ],
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

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: PlayfulInput(
                                  labelText: StringsProvider.instance.t('logjob_distance'),
                                  hintText: StringsProvider.instance.t('logjob_distance_hint'),
                                  controller: _distanceController,
                                  isHighlighted: _distanceHighlighted,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return StringsProvider.instance.t('logjob_distance_required');
                                    final numVal = double.tryParse(val);
                                    if (numVal == null || numVal <= 0) return StringsProvider.instance.t('logjob_positive_decimal');
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: PlayfulMicButton(
                                  textOnLeft: true,
                                  onSpeechResult: (text) => _parseAndSetNumber(text, _distanceController),
                                ),
                              ),
                            ],
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

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: PlayfulInput(
                                  labelText: StringsProvider.instance.t('logjob_duration'),
                                  hintText: StringsProvider.instance.t('logjob_duration_hint'),
                                  controller: _durationController,
                                  isHighlighted: _durationHighlighted,
                                  keyboardType: TextInputType.number,
                                  validator: (val) {
                                    if (val == null || val.isEmpty) return StringsProvider.instance.t('logjob_duration_required');
                                    final numVal = double.tryParse(val);
                                    if (numVal == null || numVal <= 0) return StringsProvider.instance.t('logjob_positive');
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: PlayfulMicButton(
                                  textOnLeft: true,
                                  onSpeechResult: (text) => _parseAndSetNumber(text, _durationController),
                                ),
                              ),
                            ],
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
                            child: Text(_jobSource == "ocr"
                                ? StringsProvider.instance.t('logjob_btn_confirm')
                                : StringsProvider.instance.t('logjob_btn')),
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

  void _showPlatformPickerBottomSheet(BuildContext context) {
    _searchController.clear();
    _filteredPlatforms = List.from(_allPlatforms);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSheet) {
            // Update filtered platforms inside bottom sheet
            void searchListener() {
              if (context.mounted) {
                setStateSheet(() {
                  _filteredPlatforms = _allPlatforms
                      .where((p) =>
                          p.displayName.toLowerCase().contains(_searchController.text.toLowerCase()) ||
                          p.id.toLowerCase().contains(_searchController.text.toLowerCase()))
                      .toList();
                });
              }
            }

            _searchController.removeListener(searchListener);
            _searchController.addListener(searchListener);

            final sortedCategories = _getSortedCategories();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              padding: const EdgeInsets.only(top: 12, left: 24, right: 24, bottom: 24),
              decoration: const BoxDecoration(
                color: PlayfulColors.background,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                border: Border(
                  top: BorderSide(color: PlayfulColors.border, width: 2),
                  left: BorderSide(color: PlayfulColors.border, width: 2),
                  right: BorderSide(color: PlayfulColors.border, width: 2),
                ),
              ),
              child: Column(
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
                    "SELECT PLATFORM",
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      letterSpacing: 2.0,
                      color: PlayfulColors.foreground,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Search Field
                  PlayfulInput(
                    labelText: "Search",
                    hintText: "Type platform name...",
                    controller: _searchController,
                    onTap: () {},
                  ),
                  const SizedBox(height: 16),
                  
                  // Grouped platform list
                  Expanded(
                    child: ListView(
                      children: sortedCategories.map((cat) {
                        final itemsInCat = _filteredPlatforms.where((p) => p.category == cat).toList();
                        if (itemsInCat.isEmpty) return const SizedBox.shrink();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                _categoryLabels[cat] ?? cat.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                  letterSpacing: 1.5,
                                  color: PlayfulColors.mutedForeground,
                                ),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: PlayfulColors.border, width: 2.0),
                              ),
                              child: Column(
                                children: List.generate(itemsInCat.length, (idx) {
                                  final p = itemsInCat[idx];
                                  final isLast = idx == itemsInCat.length - 1;

                                  return Container(
                                    decoration: BoxDecoration(
                                      border: isLast
                                          ? null
                                          : const Border(
                                              bottom: BorderSide(color: PlayfulColors.border, width: 1),
                                            ),
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: ListTile(
                                        onTap: () {
                                          setState(() {
                                            _selectedPlatform = p.id;
                                            _platformFieldController.text = p.displayName;
                                          });
                                          _checkFormValid();
                                          Navigator.pop(context);
                                        },
                                        title: Text(
                                          p.displayName,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: PlayfulColors.foreground,
                                          ),
                                        ),
                                        subtitle: Text(
                                          p.sampleSize >= 15
                                              ? "${p.displayName}'s fair rate is based on ${p.sampleSize} real trips logged by GigShield workers in the last 60 days."
                                              : "${p.displayName}'s fair rate is currently an estimate — not enough real data yet.",
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: PlayfulColors.mutedForeground,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _getSortedCategories() {
    if (_workerType == 'cab_driver') {
      return ['cab', 'delivery', 'other_gig'];
    } else if (_workerType == 'delivery_rider') {
      return ['delivery', 'cab', 'other_gig'];
    } else {
      return ['other_gig', 'delivery', 'cab'];
    }
  }
}

class PlatformItem {
  final String id;
  final String displayName;
  final String category;
  final double ratePerKm;
  final double ratePerMin;
  final int sampleSize;

  PlatformItem({
    required this.id,
    required this.displayName,
    required this.category,
    required this.ratePerKm,
    required this.ratePerMin,
    required this.sampleSize,
  });
}
