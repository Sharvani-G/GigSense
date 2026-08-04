import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'playful_widgets.dart';
import 'history_screen.dart';
import 'fairness_map_screen.dart';
import '../i18n/strings.dart';
import 'sos_active_screen.dart';
import '../main.dart' show showLanguagePicker, MainNavigationController;
import 'help_walkthrough_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onNavigateToLogJob;

  const HomeScreen({
    super.key,
    required this.onNavigateToLogJob,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {


  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _jobs = [];
  
  // Aggregated data
  double _totalEarnings = 0.0;
  double _totalHours = 0.0;
  int _flaggedCount = 0;
  List<MapEntry<String, double>> _chartData = [];
  List<PlatformBreakdown> _platformsBreakdown = [];
  int _selectedWeekOffset = 0;

  // Fatigue nudge variables
  bool _showFatigueNudge = false;
  double _fatigueHours = 0.0;
  String _fatigueMessage = "";
  bool _isFatigueLoading = false;
  String? _anonymousLastNudgeDate;

  // User profile personalization
  String _userName = "THERE";
  bool _userFetched = false;
  bool _isPhoneSheetOpen = false;
  bool _isHelpWalkthroughOpen = false;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  // Savings Goal variables
  Map<String, dynamic>? _savingsGoal;
  double _savingsProgress = 0.0;
  double _savingsTarget = 0.0;
  int _savingsDaysRemaining = 0;
  double _savingsEarned = 0.0;

  // AI Weekly Insight
  String _insightText = "Log a few jobs and I'll have your first weekly insight ready.";
  bool _isInsightLoading = true;
  late final AnimationController _insightAnimationController;
  late final Animation<double> _insightScaleAnimation;

  @override
  void initState() {
    super.initState();
    _insightAnimationController = AnimationController(
      duration: const Duration(milliseconds: 550),
      vsync: this,
    );
    _insightScaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _insightAnimationController,
        curve: Curves.easeOutBack,
      ),
    );
    MainNavigationController.currentTab.addListener(_onTabChanged);
    _fetchAndProcessJobs();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      if (user.isAnonymous) {
        _userName = "THERE";
        _insightText = "Log a few jobs and I'll have your first weekly insight ready.";
        _isInsightLoading = false;
        _userFetched = true;
      } else {
        _userSubscription = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((doc) {
          if (doc.exists && mounted) {
            final data = doc.data()!;
            final cachedText = data['cachedInsightText'] as String?;
            setState(() {
              _userName = (data['name'] as String?)?.toUpperCase() ?? "THERE";
              _savingsGoal = data['savingsGoal'] as Map<String, dynamic>?;
              if (cachedText != null) {
                _insightText = cachedText;
                _isInsightLoading = false;
                _insightAnimationController.forward(from: 0.0);
              }
              _userFetched = true;
            });
            _calculateSavingsProgress();

            // Trigger non-dismissible phone input sheet if missing
            final phone = data['phoneNumber'] as String?;
            if ((phone == null || phone.isEmpty) && !_isPhoneSheetOpen && mounted) {
              _isPhoneSheetOpen = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showRequiredPhoneSheet();
              });
            }
          }
        });
      }
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (SOSManager.instance.isActive && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SOSActiveScreen(contact: SOSManager.instance.activeContact!),
          ),
        );
      }
    });
  }

  void _onTabChanged() {
    if (MainNavigationController.currentTab.value == 0) {
      _fetchAndProcessJobs();
    }
  }

  @override
  void dispose() {
    MainNavigationController.currentTab.removeListener(_onTabChanged);
    _userSubscription?.cancel();
    _insightAnimationController.dispose();
    super.dispose();
  }

  void _showRequiredPhoneSheet() {
    final controller = TextEditingController();
    bool loading = false;
    String error = "";

    String normalizeIndianPhoneNumber(String input) {
      String cleaned = input.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
      final match = RegExp(r'^(?:\+91|91)?([6-9]\d{9})$').firstMatch(cleaned);
      if (match != null) {
        return '+91${match.group(1)}';
      }
      return '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return PopScope(
          canPop: false, // Prevent dismissal via physical back button
          child: StatefulBuilder(
            builder: (context, setStateSheet) {
              controller.addListener(() {
                if (mounted) setStateSheet(() {});
              });
              final phoneVal = normalizeIndianPhoneNumber(controller.text);
              final bool canSubmit = phoneVal.isNotEmpty && !loading;

              Future<void> submit() async {
                if (!canSubmit) return;
                setStateSheet(() {
                  loading = true;
                  error = "";
                });

                try {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance.collection('users').doc(uid).update({
                      'phoneNumber': phoneVal,
                    });
                  }
                  if (context.mounted) {
                    Navigator.pop(context); // Close sheet
                  }
                  _isPhoneSheetOpen = false;
                } catch (e) {
                  setStateSheet(() {
                    loading = false;
                    error = "Failed to update phone number. Try again.";
                  });
                }
              }

              return Container(
                decoration: const BoxDecoration(
                  color: PlayfulColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                  border: Border(
                    top: BorderSide(color: PlayfulColors.border, width: 4),
                  ),
                ),
                padding: EdgeInsets.only(
                  top: 24,
                  left: 24,
                  right: 24,
                  bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "MOBILE NUMBER REQUIRED",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        color: PlayfulColors.foreground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "To ensure your safety alerts function correctly, please provide your 10-digit Indian mobile number.",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        color: PlayfulColors.mutedForeground,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    PlayfulInput(
                      labelText: "MOBILE NUMBER",
                      hintText: "e.g., 9876543210",
                      controller: controller,
                      keyboardType: TextInputType.phone,
                    ),
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        style: GoogleFonts.plusJakartaSans(
                          color: PlayfulColors.secondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 24),
                    if (loading)
                      const Center(
                        child: CircularProgressIndicator(color: PlayfulColors.accent),
                      )
                    else
                      PlayfulButton(
                        onPressed: canSubmit ? submit : null,
                        child: Text(StringsProvider.instance.t('btn_save_continue')),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // Parses various timestamp/date types safely
  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) {
      return val.toDate();
    }
    if (val is String) {
      return DateTime.tryParse(val);
    }
    return null;
  }

  // Custom weekday format label
  String _getWeekdayLabel(DateTime dt) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dt.weekday - 1];
  }

  Future<void> _fetchAndProcessJobs() async {
    setState(() {
      _isLoading = true;
      if (!_userFetched) {
        _isInsightLoading = true;
      }
      _hasError = false;
    });

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user';
      
      // Query jobs collection by user_id
      final querySnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('user_id', isEqualTo: userId)
          .get();

      final List<Map<String, dynamic>> allJobs = querySnapshot.docs
          .map((doc) => {...doc.data(), 'id': doc.id})
          .toList();

      final now = DateTime.now();
      // Find the Monday of the current week (weekday: 1 is Mon, 7 is Sun)
      final currentMonday = now.subtract(Duration(days: now.weekday - 1));
      final targetMonday = currentMonday.add(Duration(days: _selectedWeekOffset * 7));
      final weekStart = DateTime(targetMonday.year, targetMonday.month, targetMonday.day);
      final weekEnd = weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));

      // Filter jobs logged in the target week
      final List<Map<String, dynamic>> weeklyJobs = allJobs.where((job) {
        final jobDate = _parseTimestamp(job['job_timestamp'] ?? job['created_at']);
        return jobDate != null && 
            jobDate.isAfter(weekStart.subtract(const Duration(seconds: 1))) && 
            jobDate.isBefore(weekEnd.add(const Duration(seconds: 1)));
      }).toList();

      // Aggregate calculations
      double totalEarnings = 0.0;
      double totalMinutes = 0.0;
      int flaggedCount = 0;

      for (var job in weeklyJobs) {
        totalEarnings += (job['fare'] as num?)?.toDouble() ?? 0.0;
        totalMinutes += (job['duration_min'] as num?)?.toDouble() ?? 0.0;
        if (job['is_underpaid'] == true) {
          flaggedCount++;
        }
      }

      // Generate daily earnings chart data (Monday to Sunday)
      final List<MapEntry<String, double>> chartData = [];
      for (int i = 0; i < 7; i++) {
        final day = weekStart.add(Duration(days: i));
        final dayLabel = _getWeekdayLabel(day);
        
        double dayEarnings = 0.0;
        for (var job in allJobs) {
          final jobDate = _parseTimestamp(job['job_timestamp'] ?? job['created_at']);
          if (jobDate != null &&
              jobDate.year == day.year &&
              jobDate.month == day.month &&
              jobDate.day == day.day) {
            dayEarnings += (job['fare'] as num?)?.toDouble() ?? 0.0;
          }
        }
        chartData.add(MapEntry(dayLabel, dayEarnings));
      }

      // Platform breakdown calculation
      final Map<String, PlatformBreakdown> platformMap = {};
      for (var job in weeklyJobs) {
        final platformRaw = (job['platform'] as String?) ?? 'other';
        final platform = platformRaw.toLowerCase();
        final fare = (job['fare'] as num?)?.toDouble() ?? 0.0;
        final isUnderpaid = job['is_underpaid'] == true;

        if (platformMap.containsKey(platform)) {
          platformMap[platform]!.total += fare;
          platformMap[platform]!.count += 1;
          if (isUnderpaid) {
            platformMap[platform]!.underpaidCount += 1;
          }
        } else {
          platformMap[platform] = PlatformBreakdown(
            name: platformRaw,
            total: fare,
            count: 1,
            underpaidCount: isUnderpaid ? 1 : 0,
          );
        }
      }

      setState(() {
        _jobs = allJobs;
        _totalEarnings = totalEarnings;
        _totalHours = double.parse((totalMinutes / 60.0).toStringAsFixed(1));
        _flaggedCount = flaggedCount;
        _chartData = chartData;
        _platformsBreakdown = platformMap.values.toList();
        _platformsBreakdown.sort((a, b) => b.total.compareTo(a.total));
        _isLoading = false;
      });

      _fetchUserProfile();
      _checkFatigueNudge();
      _calculateSavingsProgress();
    } catch (e) {
      debugPrint("Error fetching jobs from Firestore: $e");
      setState(() {
        _hasError = true;
        _isLoading = false;
        _isInsightLoading = false;
      });
    }
  }

  Future<void> _fetchUserProfile() async {
    if (_userFetched) return;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (user.isAnonymous) {
          setState(() {
            _userName = "THERE";
            _insightText = "Log a few jobs and I'll have your first weekly insight ready.";
            _isInsightLoading = false;
            _userFetched = true;
          });
          _insightAnimationController.forward(from: 0.0);
          return;
        }
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && mounted) {
          final data = doc.data()!;
          
          final cachedText = data['cachedInsightText'] as String?;
          final cachedWeekStart = data['cachedInsightWeekStart'] as Timestamp?;
          
          setState(() {
            _userName = (data['name'] as String?)?.toUpperCase() ?? "THERE";
            _savingsGoal = data['savingsGoal'] as Map<String, dynamic>?;
            
            if (cachedText != null) {
              _insightText = cachedText;
              _isInsightLoading = false;
              _insightAnimationController.forward(from: 0.0);
            } else {
              if (_jobs.isNotEmpty) {
                _isInsightLoading = true;
                _fetchWeeklyInsight(user.uid);
              } else {
                _insightText = "Log a few jobs and I'll have your first weekly insight ready.";
                _isInsightLoading = false;
                _insightAnimationController.forward(from: 0.0);
              }
            }
            
            _userFetched = true;
          });
          _calculateSavingsProgress();

          final hasSeenHelp = data['hasSeenHelpWalkthrough'] ?? true;
          if (hasSeenHelp == false && !_isHelpWalkthroughOpen) {
            _isHelpWalkthroughOpen = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HelpWalkthroughScreen(autoRegisterFlag: true),
                ),
              ).then((_) {
                _isHelpWalkthroughOpen = false;
              });
            });
          }
          
          if (cachedWeekStart != null) {
            final weekStartDateTime = cachedWeekStart.toDate();
            final now = DateTime.now();
            final currentWeekStart = now.subtract(Duration(days: now.weekday - 1));
            final currentWeekStartNormalized = DateTime(currentWeekStart.year, currentWeekStart.month, currentWeekStart.day);
            final cachedWeekStartNormalized = DateTime(weekStartDateTime.year, weekStartDateTime.month, weekStartDateTime.day);
            
            if (currentWeekStartNormalized.isAfter(cachedWeekStartNormalized)) {
              setState(() {
                _isInsightLoading = true;
              });
              _fetchWeeklyInsight(user.uid);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
    }
  }

  Future<void> _checkFatigueNudge() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final twentyFourHoursAgo = now.subtract(const Duration(hours: 24));

    double fatigueMinutes = 0.0;
    for (var job in _jobs) {
      final jobDate = _parseTimestamp(job['job_timestamp'] ?? job['created_at']);
      if (jobDate != null && jobDate.isAfter(twentyFourHoursAgo)) {
        fatigueMinutes += (job['duration_min'] as num?)?.toDouble() ?? 0.0;
      }
    }

    if (fatigueMinutes >= 600.0) {
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      
      if (user.isAnonymous) {
        if (_anonymousLastNudgeDate != todayStr) {
          setState(() {
            _showFatigueNudge = true;
            _fatigueHours = fatigueMinutes / 60.0;
              _fetchFatigueMessage(user.uid, _fatigueHours);
          });
        } else {
          setState(() {
            _showFatigueNudge = false;
          });
        }
      } else {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          final lastNudgeDate = userDoc.data()?['lastFatigueNudgeDate'] as String?;
          if (lastNudgeDate != todayStr && _anonymousLastNudgeDate != todayStr) {
            setState(() {
              _showFatigueNudge = true;
              _fatigueHours = fatigueMinutes / 60.0;
              _fetchFatigueMessage(user.uid, _fatigueHours);
            });
          } else {
            setState(() {
              _showFatigueNudge = false;
            });
          }
        } catch (e) {
          debugPrint("Error fetching user profile for fatigue nudge: $e");
          if (_anonymousLastNudgeDate != todayStr) {
            setState(() {
              _showFatigueNudge = true;
              _fatigueHours = fatigueMinutes / 60.0;
              _fetchFatigueMessage(user.uid, _fatigueHours);
            });
          } else {
            setState(() {
              _showFatigueNudge = false;
            });
          }
        }
      }
    } else {
      setState(() {
        _showFatigueNudge = false;
      });
    }
  }


  Future<void> _fetchFatigueMessage(String userId, double hours) async {
    setState(() {
      _isFatigueLoading = true;
      _fatigueMessage = "";
    });
    try {
      final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      final Uri url = Uri.parse('$baseUrl/fatigue-nudge');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json', 'ngrok-skip-browser-warning': 'true'},
        body: json.encode({
          'user_id': userId,
          'total_hours': hours,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _fatigueMessage = data['message'] ?? "You've logged over 10 hours today! Remember to take a quick break.";
        });
      } else {
        setState(() {
          _fatigueMessage = "You've logged over 10 hours today! Remember to take a quick break.";
        });
      }
    } catch (e) {
      debugPrint("Error fetching fatigue message: $e");
      setState(() {
        _fatigueMessage = "You've logged over 10 hours today! Remember to take a quick break.";
      });
    } finally {
      setState(() {
        _isFatigueLoading = false;
      });
      // Save notification to Firestore
      try {
        final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': 'Fatigue Check-in',
          'message': _fatigueMessage,
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'fatigue_nudge',
        });
        if (userId != 'anonymous_user') {
          await FirebaseFirestore.instance.collection('users').doc(userId).set({
            'lastFatigueNudgeDate': todayStr,
          }, SetOptions(merge: true));
        } else {
          _anonymousLastNudgeDate = todayStr;
        }
      } catch (e) {
        debugPrint("Error writing fatigue notification: $e");
      }
    }
  }

  Future<void> _dismissFatigueNudge() async {
    setState(() {
      _showFatigueNudge = false;
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (user.isAnonymous) {
      _anonymousLastNudgeDate = todayStr;
    } else {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'lastFatigueNudgeDate': todayStr,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error saving fatigue nudge timestamp to Firestore: $e");
        _anonymousLastNudgeDate = todayStr;
      }
    }
  }

  void _showNotificationsSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final userId = user?.uid ?? 'anonymous_user';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFDF5),
                border: Border(
                  top: BorderSide(color: PlayfulColors.border, width: 4),
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        StringsProvider.instance.t('notifications_title'),
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: PlayfulColors.foreground,
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          try {
                            // Mark all as read
                            final qSnapshot = await FirebaseFirestore.instance
                                .collection('users')
                                .doc(userId)
                                .collection('notifications')
                                .where('read', isEqualTo: false)
                                .get();
                            if (qSnapshot.docs.isNotEmpty) {
                              final batch = FirebaseFirestore.instance.batch();
                              for (var doc in qSnapshot.docs) {
                                batch.update(doc.reference, {'read': true});
                              }
                              await batch.commit();
                            }
                          } catch (e) {
                            debugPrint("Error marking all notifications as read: $e");
                          }
                        },
                        child: Text(
                          StringsProvider.instance.t('notifications_mark_all'),
                          style: GoogleFonts.plusJakartaSans(
                            color: PlayfulColors.accent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: PlayfulColors.border, thickness: 2),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .collection('notifications')
                          .orderBy('timestamp', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator(color: PlayfulColors.accent));
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.notifications_none, size: 48, color: PlayfulColors.mutedForeground),
                                const SizedBox(height: 12),
                                Text(
                                  StringsProvider.instance.t('notifications_empty'),
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: PlayfulColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data = docs[index].data() as Map<String, dynamic>;
                            final isRead = data['read'] ?? false;
                            final title = data['title'] ?? 'Alert';
                            final message = data['message'] ?? '';
                            final ts = data['timestamp'];
                            DateTime? dt;
                            if (ts is Timestamp) {
                              dt = ts.toDate();
                            }
                            
                            return GestureDetector(
                              onTap: () async {
                                if (!isRead) {
                                  try {
                                    await docs[index].reference.update({'read': true});
                                  } catch (e) {
                                    debugPrint("Error marking notification as read: $e");
                                  }
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isRead ? Colors.white : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isRead ? PlayfulColors.border : PlayfulColors.tertiary,
                                    width: 2.0,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: isRead ? PlayfulColors.border : PlayfulColors.tertiary,
                                      offset: const Offset(2, 2),
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
                                          title.toUpperCase(),
                                          style: GoogleFonts.outfit(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                            color: PlayfulColors.foreground,
                                          ),
                                        ),
                                        if (dt != null)
                                          Text(
                                            "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10,
                                              color: PlayfulColors.mutedForeground,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      message,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: PlayfulColors.foreground,
                                        height: 1.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
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

  void _calculateSavingsProgress() {
    if (_savingsGoal == null) {
      if (mounted) {
        setState(() {
          _savingsTarget = 0.0;
          _savingsEarned = 0.0;
          _savingsDaysRemaining = 0;
          _savingsProgress = 0.0;
        });
      }
      return;
    }

    final target = (_savingsGoal!['targetAmount'] as num?)?.toDouble() ?? 0.0;
    final period = _savingsGoal!['period'] ?? "weekly";
    final startDateVal = _savingsGoal!['startDate'];
    final startDate = _parseTimestamp(startDateVal) ?? DateTime.now();

    final now = DateTime.now();
    final startDateLocal = startDate;
    final elapsedDays = now.difference(startDateLocal).inDays;
    final periodLength = period == 'weekly' ? 7 : 30;
    final periodsElapsed = elapsedDays >= 0 ? (elapsedDays ~/ periodLength) : 0;
    final periodStart = startDateLocal.add(Duration(days: periodsElapsed * periodLength));
    final periodEnd = periodStart.add(Duration(days: periodLength));

    // Permanently roll over the goal window if we've passed periods
    if (periodsElapsed > 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.isAnonymous) {
        FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'savingsGoal': {
            'startDate': Timestamp.fromDate(periodStart),
          }
        }, SetOptions(merge: true));
      }
      _savingsGoal!['startDate'] = Timestamp.fromDate(periodStart);
    }

    
    // We add 1 to match expected inclusive days (e.g. today is 1 day remaining)
    final daysRemaining = periodEnd.difference(now).inDays + 1;

    double periodEarnings = 0.0;
    for (var job in _jobs) {
      final jobDate = _parseTimestamp(job['job_timestamp'] ?? job['created_at']);
      if (jobDate != null &&
          jobDate.isAfter(periodStart.subtract(const Duration(seconds: 1))) &&
          jobDate.isBefore(periodEnd.add(const Duration(seconds: 1)))) {
        periodEarnings += (job['fare'] as num?)?.toDouble() ?? 0.0;
      }
    }

    if (mounted) {
      setState(() {
        _savingsTarget = target;
        _savingsEarned = periodEarnings;
        _savingsDaysRemaining = daysRemaining < 0 ? 0 : daysRemaining;
        _savingsProgress = target > 0 ? (periodEarnings / target) : 0.0;
      });
    }
  }

  Future<void> _fetchWeeklyInsight(String userId) async {
    setState(() {
      _isInsightLoading = true;
    });
    try {
      String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      if (!kIsWeb && Platform.isAndroid && (baseUrl.contains("127.0.0.1") || baseUrl.contains("localhost"))) {
        baseUrl = baseUrl.replaceAll("127.0.0.1", "10.0.2.2").replaceAll("localhost", "10.0.2.2");
      }
      final Uri url = Uri.parse('$baseUrl/weekly-insight?user_id=$userId');
      final response = await http.get(url, headers: {'ngrok-skip-browser-warning': 'true'})
          .timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _insightText = data['insight_text'] ?? "Log a few jobs and I'll have your first weekly insight ready.";
          _isInsightLoading = false;
        });
        _insightAnimationController.forward(from: 0.0);
      } else {
        throw Exception("Server returned status code ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching weekly insight: $e");
      setState(() {
        _insightText = "Insight is taking longer than expected — tap to retry";
        _isInsightLoading = false;
      });
      _insightAnimationController.forward(from: 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Current week date range text
    final now = DateTime.now();
    final currentMonday = now.subtract(Duration(days: now.weekday - 1));
    final targetMonday = currentMonday.add(Duration(days: _selectedWeekOffset * 7));
    final start = DateTime(targetMonday.year, targetMonday.month, targetMonday.day);
    final end = start.add(const Duration(days: 6));
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final startMonth = months[start.month - 1];
    final endMonth = months[end.month - 1];
    final String dateRange;
    if (_selectedWeekOffset == 0) {
      dateRange = "This week · ${start.day} $startMonth – ${end.day} $endMonth";
    } else if (_selectedWeekOffset == -1) {
      dateRange = "Last week · ${start.day} $startMonth – ${end.day} $endMonth";
    } else {
      dateRange = "${start.day} $startMonth – ${end.day} $endMonth";
    }

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        backgroundColor: PlayfulColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(FirebaseAuth.instance.currentUser?.uid ?? 'anonymous_user')
                .collection('notifications')
                .where('read', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data?.docs.length ?? 0;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      unreadCount > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_outlined,
                      color: PlayfulColors.foreground,
                    ),
                    tooltip: 'Notifications',
                    onPressed: () => _showNotificationsSheet(context),
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: PlayfulColors.secondary,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '$unreadCount',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.language, color: PlayfulColors.foreground),
            tooltip: 'Language',
            onPressed: () => showLanguagePicker(context),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: PlayfulColors.foreground),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAndProcessJobs,
          color: PlayfulColors.accent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Error banner (non-blocking)
                if (_hasError)
                  Container(
                    color: PlayfulColors.secondary,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.white),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            StringsProvider.instance.t('home_error'),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _fetchAndProcessJobs,
                          child: Text(
                            StringsProvider.instance.t('retry'),
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // Header
                       Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "${StringsProvider.instance.t('greeting')}, $_userName!",
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 28,
                                  color: PlayfulColors.foreground,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const HelpWalkthroughScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: PlayfulColors.border, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: PlayfulColors.border,
                                    offset: Offset(2, 2),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.help_outline,
                                color: PlayfulColors.accent,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedWeekOffset--;
                              });
                              _fetchAndProcessJobs();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: PlayfulColors.border, width: 1.5),
                              ),
                              child: const Icon(
                                Icons.chevron_left,
                                color: PlayfulColors.foreground,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            dateRange,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: PlayfulColors.mutedForeground,
                            ),
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: _selectedWeekOffset >= 0
                                ? null
                                : () {
                                    setState(() {
                                      _selectedWeekOffset++;
                                    });
                                    _fetchAndProcessJobs();
                                  },
                            child: Opacity(
                              opacity: _selectedWeekOffset >= 0 ? 0.3 : 1.0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: PlayfulColors.border, width: 1.5),
                                ),
                                child: const Icon(
                                  Icons.chevron_right,
                                  color: PlayfulColors.foreground,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Fatigue Nudge Banner
                      if (_showFatigueNudge) ...[
                        AnimatedOpacity(
                          opacity: _showFatigueNudge ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB), // Soft warm amber background
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: PlayfulColors.tertiary, width: 2.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: PlayfulColors.tertiary,
                                  offset: Offset(4, 4),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.warning_amber_rounded,
                                      color: Color(0xFFD97706),
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          _isFatigueLoading
                                              ? const SizedBox(
                                                  height: 20,
                                                  width: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                                                  ),
                                                )
                                              : Text(
                                                  _fatigueMessage,

                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: PlayfulColors.foreground,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 24), // Leave room for close button
                                  ],
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: _dismissFatigueNudge,
                                    child: const Icon(
                                      Icons.close,
                                      size: 18,
                                      color: Color(0xFFD97706),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      // AI Weekly Insight Pop-in Card
                      GestureDetector(
                        onTap: () {
                          if (_insightText == "Insight is taking longer than expected — tap to retry" && !_isInsightLoading) {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              _fetchWeeklyInsight(user.uid);
                            }
                          }
                        },
                        child: ScaleTransition(
                          scale: _insightScaleAnimation,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _insightText.toLowerCase().contains("burnout") || _insightText.toLowerCase().contains("rest") 
                                  ? const Color(0xFFFEF2F2) // very light red
                                  : PlayfulColors.tertiary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _insightText.toLowerCase().contains("burnout") || _insightText.toLowerCase().contains("rest") 
                                    ? const Color(0xFFEF4444) // red border
                                    : PlayfulColors.border,
                                width: 2.0
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: PlayfulColors.tertiary,
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(color: PlayfulColors.border, width: 2),
                                      ),
                                      child: Text(
                                        StringsProvider.instance.t('ai_insight'),
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                          color: PlayfulColors.foreground,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _isInsightLoading
                                    ? const SizedBox(
                                        height: 48,
                                        child: Center(
                                          child: CircularProgressIndicator(
                                            color: PlayfulColors.accent,
                                          ),
                                        ),
                                      )
                                    : PlayfulMarkdownText(
                                        text: _insightText,
                                        style: GoogleFonts.plusJakartaSans(
                                          color: PlayfulColors.foreground,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildFairnessMapCard(context),
                      const SizedBox(height: 32),

                      // Loader or Render View
                      if (_isLoading)
                        _buildLoadingState()
                      else
                        _buildMainDashboard(),
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'sosBtn',
            onPressed: _triggerSOS,
            backgroundColor: const Color(0xFFE11D48),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: PlayfulColors.border, width: 2),
            ),
            icon: const Icon(Icons.shield_outlined, size: 24),
            label: Text(
              "I feel unsafe",
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'logJobBtn',
            onPressed: widget.onNavigateToLogJob,
            backgroundColor: PlayfulColors.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: PlayfulColors.border, width: 2),
            ),
            child: const Icon(Icons.add, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        Row(
          children: const [
            Expanded(child: PlayfulSkeleton(height: 100, width: double.infinity)),
            SizedBox(width: 12),
            Expanded(child: PlayfulSkeleton(height: 100, width: double.infinity)),
            SizedBox(width: 12),
            Expanded(child: PlayfulSkeleton(height: 100, width: double.infinity)),
          ],
        ),
        const SizedBox(height: 32),
        const PlayfulSkeleton(height: 200, width: double.infinity),
        const SizedBox(height: 32),
        Row(
          children: const [
            PlayfulSkeleton(height: 36, width: 120),
            SizedBox(width: 12),
            PlayfulSkeleton(height: 36, width: 120),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        const SizedBox(height: 24),
        // Empty illustration using calm primitives
        SizedBox(
          width: double.infinity,
          height: 140,
          child: CustomPaint(
            painter: EmptyStatePainter(),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          StringsProvider.instance.t('home_empty'),
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: PlayfulColors.mutedForeground,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildMainDashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              StringsProvider.instance.t('home_summary').toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.0,
                color: PlayfulColors.mutedForeground,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HistoryScreen()),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    StringsProvider.instance.t('view_all'),
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: PlayfulColors.accent,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: PlayfulColors.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Stats Cards Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: StringsProvider.instance.t('stat_earnings'),
                value: "₹${formatIndianCurrency(_totalEarnings)}",
                icon: Icons.currency_rupee,
                iconColor: PlayfulColors.accent,
                shadowColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: StringsProvider.instance.t('stat_hours'),
                value: "${_totalHours}h",
                icon: Icons.access_time,
                iconColor: PlayfulColors.quaternary,
                shadowColor: const Color(0xFFE2E8F0),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HistoryScreen(
                        initialFairnessFilter: 'Possibly Underpaid',
                      ),
                    ),
                  );
                },
                child: _buildStatCard(
                  label: StringsProvider.instance.t('stat_flagged'),
                  value: "$_flaggedCount",
                  icon: Icons.warning_amber_rounded,
                  iconColor: PlayfulColors.secondary,
                  shadowColor: PlayfulColors.secondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Savings Goal Card
        if (_savingsGoal != null) ...[
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "SAVINGS TARGET",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: PlayfulColors.mutedForeground,
                      ),
                    ),
                    if (_savingsEarned >= _savingsTarget)
                      Text(
                        "₹${formatIndianCurrency(_savingsEarned)} of ₹${formatIndianCurrency(_savingsTarget)} — Ahead! 🎉",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: PlayfulColors.quaternary, // Mint
                        ),
                      )
                    else
                      Text(
                        "${((_savingsProgress) * 100).clamp(0, 100).round()}% Completed",
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: PlayfulColors.foreground,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 12,
                    width: double.infinity,
                    color: const Color(0xFFE2E8F0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: _savingsProgress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6), // Violet
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "₹${formatIndianCurrency(_savingsEarned)} of ₹${formatIndianCurrency(_savingsTarget)} this ${_savingsGoal!['period']}",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: PlayfulColors.foreground,
                      ),
                    ),
                    Text(
                      "${_savingsDaysRemaining}d remaining",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: PlayfulColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
                if (_savingsTarget > 0) ...[
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 12),
                  Text(
                    () {
                      final periodLength = _savingsGoal!['period'] == 'weekly' ? 7 : 30;
                      final daysElapsed = periodLength - _savingsDaysRemaining;
                      if (daysElapsed < 3 || _jobs.length < 3) {
                        return "Pacing: More logged trips needed to calculate a reliable pacing forecast.";
                      }
                      if (daysElapsed <= 0) {
                        return "Pacing details will appear after the first day of the goal period.";
                      }
                      final dailyAvg = _savingsEarned / daysElapsed;
                      double projection = dailyAvg * periodLength;
                      if (projection.isInfinite || projection.isNaN || projection > 1e12) {
                        projection = _savingsTarget;
                      }
                      
                      final String statusMsg;
                      if (projection >= _savingsTarget) {
                        statusMsg = "you are on track to reach your goal!";
                      } else {
                        final deficit = _savingsTarget - projection;
                        final displayDeficit = (deficit.isInfinite || deficit.isNaN || deficit > 1e12 || deficit < 0) ? 0.0 : deficit;
                        statusMsg = "running about ₹${formatIndianCurrency(displayDeficit)} under pace.";
                      }
                      
                      return "Pacing: At your current rate, you are projected to reach ₹${formatIndianCurrency(projection)} — $statusMsg";
                    }(),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: PlayfulColors.mutedForeground,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],

        // Chart Section
        Text(
          StringsProvider.instance.t('daily_earnings'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.0,
            color: PlayfulColors.foreground,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          padding: const EdgeInsets.only(right: 16, top: 16, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PlayfulColors.border, width: 2.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFFE2E8F0),
                offset: Offset(4, 4),
                blurRadius: 0,
              ),
            ],
          ),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: _getMaxEarningsValue() * 1.25,
              barTouchData: BarTouchData(enabled: true),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < _chartData.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            _chartData[index].key,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: PlayfulColors.foreground,
                            ),
                          ),
                        );
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) => const FlLine(
                  color: Color(0xFFE2E8F0),
                  strokeWidth: 1.0,
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(_chartData.length, (index) {
                final entry = _chartData[index];
                return BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: entry.value,
                      color: PlayfulColors.accent,
                      width: 14,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Platform Breakdown Section
        Text(
          StringsProvider.instance.t('platform_breakdown'),
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 1.0,
            color: PlayfulColors.foreground,
          ),
        ),
        const SizedBox(height: 16),
        _platformsBreakdown.isEmpty
            ? Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "No platform earnings logged for this week.",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: PlayfulColors.mutedForeground,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : Builder(
                builder: (context) {
                  final assignedColors = _assignPlatformColors();
                  return Wrap(
                    spacing: 8.0,
                    runSpacing: 8.0,
                    children: List.generate(_platformsBreakdown.length, (index) {
                      final pb = _platformsBreakdown[index];
                      final Color bg = assignedColors[pb.name.toLowerCase().trim()] ?? PlayfulColors.accent;
                      final Color textCol = _getPlatformTextColor(bg);
                      final String nameCapitalized = pb.name.isNotEmpty
                          ? pb.name[0].toUpperCase() + pb.name.substring(1)
                          : '';

                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: PlayfulColors.border, width: 2.0),
                          boxShadow: const [
                            BoxShadow(
                              color: PlayfulColors.border,
                              offset: Offset(2, 2),
                              blurRadius: 0,
                            ),
                          ],
                        ),
                        child: Text(
                          "$nameCapitalized · ₹${formatIndianCurrency(pb.total)} · ${pb.count} ${pb.count == 1 ? 'job' : 'jobs'} (Trust: ${pb.trustScore}%)",
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: textCol,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
        const SizedBox(height: 180),
      ],
    );
  }

  Widget _buildFairnessMapCard(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FairnessMapScreen()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE0F2FE), // Light blue background
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: PlayfulColors.border, width: 2.0),
          boxShadow: const [
            BoxShadow(
              color: PlayfulColors.border,
              offset: Offset(4, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, color: PlayfulColors.accent, size: 24),
                      const SizedBox(width: 8),
                      Text(
                        "FAIRNESS MAP",
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: PlayfulColors.foreground,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "View live pay fairness trends and underpayment zones across Bengaluru.",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: PlayfulColors.mutedForeground,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: PlayfulColors.border, width: 2),
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: PlayfulColors.accent,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
    required Color shadowColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 24, bottom: 12, left: 8, right: 8),
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
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: PlayfulColors.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: PlayfulColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -16,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor,
                shape: BoxShape.circle,
                border: Border.all(color: PlayfulColors.border, width: 2.0),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _getMaxEarningsValue() {
    double maxVal = 100.0;
    for (var entry in _chartData) {
      if (entry.value > maxVal) {
        maxVal = entry.value;
      }
    }
    return maxVal;
  }

  Map<String, Color> _assignPlatformColors() {
    final List<Color> colors = [
      PlayfulColors.accent,      // Violet
      PlayfulColors.tertiary,    // Amber
      PlayfulColors.blue,        // Blue
      PlayfulColors.orange,      // Orange
      PlayfulColors.teal,        // Teal
    ];

    final Map<String, Color> assigned = {};
    final Set<int> usedIndices = {};

    for (var pb in _platformsBreakdown) {
      final name = pb.name.toLowerCase().trim();
      
      // Hash name to get initial index
      int hash = 0;
      for (int i = 0; i < name.length; i++) {
        hash = name.codeUnitAt(i) + ((hash << 5) - hash);
      }
      
      int index = hash.abs() % colors.length;
      
      // Collision resolution: shift to next available index
      int attempts = 0;
      while (usedIndices.contains(index) && attempts < colors.length) {
        index = (index + 1) % colors.length;
        attempts++;
      }
      
      usedIndices.add(index);
      assigned[name] = colors[index];
    }
    
    return assigned;
  }

  Color _getPlatformTextColor(Color bg) {
    if (bg == PlayfulColors.tertiary || bg == PlayfulColors.blue || bg == PlayfulColors.teal) {
      return PlayfulColors.foreground;
    }
    return Colors.white;
  }

  Future<void> _triggerSOS() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    // Check if trusted contact exists
    Map<String, dynamic>? trustedContact;
    Map<String, dynamic> sosSettings = {
      'channels': {'sms': true, 'whatsapp': false, 'call': false},
      'primaryChannel': 'sms',
      'locationMode': 'live',
      'liveLocationDurationMinutes': 30,
      'messageTemplate': null,
    };
    String workerName = "Worker";

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        workerName = data['name'] ?? "Worker";
        final contacts = data['emergencyContacts'] as List<dynamic>?;
        if (contacts != null && contacts.isNotEmpty) {
          trustedContact = Map<String, dynamic>.from(contacts.first);
        }
        if (data['sosSettings'] != null) {
          sosSettings = Map<String, dynamic>.from(data['sosSettings']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching trusted contact/settings: $e");
    }

    if (!mounted) return;

    if (trustedContact == null || trustedContact['phone'] == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: PlayfulColors.border, width: 2),
          ),
          backgroundColor: Colors.white,
          title: Text(
            "Emergency Setup",
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: PlayfulColors.foreground),
          ),
          content: Text(
            "You haven't set up any emergency contacts in Settings. One-tap SMS works best when a contact is configured.",
            style: GoogleFonts.plusJakartaSans(color: PlayfulColors.foreground),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _triggerSOSWithContact({'name': 'Emergency Contact', 'phone': ''});
              },
              child: Text(
                "SEND ANYWAY",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFE11D48)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                MainNavigationController.selectTab(3); // settings tab
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: PlayfulColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: PlayfulColors.border, width: 1.5),
                ),
              ),
              child: Text(
                "SET UP NOW",
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ],
        ),
      );
      return;
    }

    _showSOSConfirmDialog(trustedContact, sosSettings, workerName);
  }

  void _showSOSConfirmDialog(
    Map<String, dynamic> contact,
    Map<String, dynamic> settings,
    String workerName,
  ) {
    final channels = settings['channels'] as Map<String, dynamic>? ?? {
      'whatsapp': true,
      'autoSms': Platform.isAndroid,
      'manualSms': !Platform.isAndroid,
    };
    final bool whatsappEnabled = channels['whatsapp'] ?? false;
    final bool autoSmsEnabled = Platform.isAndroid && (channels['autoSms'] ?? false);
    final bool manualSmsEnabled = channels['manualSms'] ?? false;
    
    // Legacy support
    final bool legacySmsEnabled = channels['sms'] ?? false;
    final bool smsIsAuto = Platform.isAndroid;
    final bool hasAutoSms = autoSmsEnabled || (legacySmsEnabled && smsIsAuto);
    final bool hasManualSms = manualSmsEnabled || (legacySmsEnabled && !smsIsAuto);
    final bool legacyCallEnabled = channels['call'] ?? false;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: PlayfulColors.border, width: 3),
        ),
        title: Column(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE11D48), size: 48),
            const SizedBox(height: 12),
            Text(
              "TRIGGER EMERGENCY SOS",
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.w900,
                fontSize: 20,
                letterSpacing: 1.0,
                color: PlayfulColors.foreground,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Select a channel to alert your trusted contact:",
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: PlayfulColors.mutedForeground,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: PlayfulColors.background,
                border: Border.all(color: PlayfulColors.border, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    contact['name'] ?? "Trusted Contact",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact['phone'] ?? "",
                    style: GoogleFonts.shareTechMono(fontSize: 14, color: PlayfulColors.mutedForeground),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Channel Buttons
            if (whatsappEnabled && (hasAutoSms || hasManualSms)) ...[
              PlayfulButton(
                backgroundColor: const Color(0xFFE11D48), // Rose
                height: 52,
                onPressed: () {
                  Navigator.pop(ctx);
                  _triggerSOSWithChannels(contact, settings, workerName, {
                    'whatsapp': true,
                    'autoSms': hasAutoSms,
                    'manualSms': hasManualSms,
                    'call': false,
                  });
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "TRIGGER FULL SOS",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        Platform.isAndroid 
                            ? "Auto background SMS + WhatsApp" 
                            : "Manual SMS + WhatsApp Alert",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            
            if (hasAutoSms) ...[
              PlayfulButton(
                backgroundColor: const Color(0xFF0EA5E9), // Sky Blue
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  _triggerSOSWithChannels(contact, settings, workerName, {
                    'whatsapp': false,
                    'autoSms': true,
                    'manualSms': false,
                    'call': false,
                  });
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "SEND AUTOMATIC SMS",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        "Silent background send (no tap needed)",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            
            if (hasManualSms) ...[
              PlayfulButton(
                backgroundColor: const Color(0xFF0EA5E9), // Sky Blue
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  _triggerSOSWithChannels(contact, settings, workerName, {
                    'whatsapp': false,
                    'autoSms': false,
                    'manualSms': true,
                    'call': false,
                  });
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "SEND SMS ALERT",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        "Opens Messages app pre-filled (requires tap)",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            
            if (whatsappEnabled) ...[
              PlayfulButton(
                backgroundColor: const Color(0xFF22C55E), // WhatsApp Green
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  _triggerSOSWithChannels(contact, settings, workerName, {
                    'whatsapp': true,
                    'autoSms': false,
                    'manualSms': false,
                    'call': false,
                  });
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "SEND WHATSAPP ALERT",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        "Opens WhatsApp (requires send tap)",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            
            if (legacyCallEnabled) ...[
              PlayfulButton(
                backgroundColor: const Color(0xFFF59E0B), // Amber
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  _triggerSOSWithChannels(contact, settings, workerName, {
                    'whatsapp': false,
                    'autoSms': false,
                    'manualSms': false,
                    'call': true,
                  });
                },
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "MAKE EMERGENCY CALL",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
                      ),
                      Text(
                        "Opens Phone dialer immediately",
                        style: GoogleFonts.plusJakartaSans(color: Colors.white.withOpacity(0.8), fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "CANCEL",
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: PlayfulColors.mutedForeground,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _triggerSOSWithChannels(
    Map<String, dynamic> contact,
    Map<String, dynamic> baseSettings,
    String workerName,
    Map<String, dynamic> selectedChannels,
  ) async {
    final customSettings = Map<String, dynamic>.from(baseSettings);
    customSettings['channels'] = selectedChannels;
    
    if (mounted) {
      await SOSManager.instance.startSOS(contact, customSettings, workerName, context);
    }
  }

  Future<void> _triggerSOSWithContact(Map<String, dynamic> contact) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Fetch settings and name
    Map<String, dynamic> sosSettings = {
      'channels': {'sms': true, 'whatsapp': false, 'call': false},
      'primaryChannel': 'sms',
      'locationMode': 'live',
      'liveLocationDurationMinutes': 30,
      'messageTemplate': null,
    };
    String workerName = "Worker";
    
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        workerName = data['name'] ?? "Worker";
        if (data['sosSettings'] != null) {
          sosSettings = Map<String, dynamic>.from(data['sosSettings']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching settings for SOS: $e");
    }

    if (!mounted) return;
    await SOSManager.instance.startSOS(contact, sosSettings, workerName, context);
  }
}

class PlatformBreakdown {
  final String name;
  double total;
  int count;
  int underpaidCount;

  PlatformBreakdown({
    required this.name,
    required this.total,
    required this.count,
    this.underpaidCount = 0,
  });

  int get trustScore {
    if (count == 0) return 100;
    return (100 * (count - underpaidCount) / count).round();
  }
}

// Painter for empty state calm decorative line + shapes
class EmptyStatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.6,
    );

    // Draw dashed path
    const double dashWidth = 6.0;
    const double dashSpace = 4.0;
    double distance = 0.0;
    final Path dashPath = Path();

    for (var metric in path.computeMetrics()) {
      while (distance < metric.length) {
        dashPath.addPath(
          metric.extractPath(distance, distance + dashWidth),
          Offset.zero,
        );
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashPath, paint);

    // Draw calm circle
    final circlePaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 24, circlePaint);

    final circleOutline = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.5), 24, circleOutline);

    // Draw calm square
    final squarePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.5),
        width: 24,
        height: 24,
      ),
      squarePaint,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.5),
        width: 24,
        height: 24,
      ),
      circleOutline,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PlayfulSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const PlayfulSkeleton({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 16.0,
  });

  @override
  State<PlayfulSkeleton> createState() => _PlayfulSkeletonState();
}

class _PlayfulSkeletonState extends State<PlayfulSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_controller.value * 0.4),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(color: const Color(0xFFCBD5E1), width: 2.0),
            ),
          ),
        );
      },
    );
  }
}
