import 'dart:io' show Platform;
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'playful_widgets.dart';
import '../i18n/strings.dart';
import '../main.dart' show showLanguagePicker;
import 'sos_active_screen.dart';

// ---------------------------------------------------------------------------
// SettingsScreen — The 4th tab of GigShield
// Displays profile summary card, list of settings options, and sign out
// ---------------------------------------------------------------------------
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  String _name = "THERE";
  String _workerType = "other_gig_worker";
  String _phoneNumber = "";
  String _profilePhotoBase64 = "";
  String _langCode = "en";
  Map<String, dynamic>? _savingsGoal;
  List<Map<String, dynamic>> _emergencyContacts = [];
  Map<String, dynamic>? _sosSettings;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (user.isAnonymous) {
      if (mounted) {
        setState(() {
          _name = "Guest User";
          _workerType = "other_gig_worker";
          _phoneNumber = "";
          _profilePhotoBase64 = "";
          _langCode = StringsProvider.instance.lang;
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        setState(() {
          _name = data['name'] ?? "THERE";
          _workerType = data['workerType'] ?? "other_gig_worker";
          _phoneNumber = data['phoneNumber'] ?? "";
          _profilePhotoBase64 = data['profilePhotoBase64'] ?? "";
          _langCode = data['preferredLanguage'] ?? StringsProvider.instance.lang;
          _savingsGoal = data['savingsGoal'] as Map<String, dynamic>?;
          _emergencyContacts = List<Map<String, dynamic>>.from((data['emergencyContacts'] as List?)?.map((e) => Map<String,dynamic>.from(e)) ?? []);
          _sosSettings = data['sosSettings'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading profile: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getWorkerTypeLabel(String code, StringsProvider s) {
    switch (code) {
      case 'delivery_rider':
        return s.t('worker_delivery');
      case 'cab_driver':
        return s.t('worker_cab');
      default:
        return s.t('worker_other');
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'hi':
        return 'हिन्दी (Hindi)';
      case 'kn':
        return 'ಕನ್ನಡ (Kannada)';
      case 'ta':
        return 'தமிழ் (Tamil)';
      case 'te':
        return 'తెలుగు (Telugu)';
      default:
        return 'English';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;

    // Listen to changes in StringsProvider so that if language is updated,
    // the Settings screen dynamically updates its code
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final currentLanguage = _getLanguageName(s.lang);

        return Scaffold(
          backgroundColor: PlayfulColors.background,
          body: SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: PlayfulColors.accent))
                : RefreshIndicator(
                    onRefresh: _fetchUserProfile,
                    color: PlayfulColors.accent,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            s.t('settings_title'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              letterSpacing: 2.0,
                              color: PlayfulColors.foreground,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Profile summary card (Sticker Card styling)
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
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: PlayfulColors.accent.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: PlayfulColors.border, width: 2),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9999),
                                    child: _profilePhotoBase64.isNotEmpty
                                        ? Image.memory(
                                            base64Decode(_profilePhotoBase64),
                                            fit: BoxFit.cover,
                                            width: 48,
                                            height: 48,
                                          )
                                        : const Icon(Icons.person_outline, color: PlayfulColors.accent, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: PlayfulColors.foreground,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: PlayfulColors.muted,
                                          borderRadius: BorderRadius.circular(9999),
                                          border: Border.all(color: PlayfulColors.border, width: 1.5),
                                        ),
                                        child: Text(
                                          _getWorkerTypeLabel(_workerType, s),
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: PlayfulColors.foreground,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 36),

                          // Settings List Rows
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: PlayfulColors.border, width: 2.0),
                            ),
                            child: Column(
                              children: [
                                // Edit Profile row
                                _buildSettingsRow(
                                  icon: Icons.edit_outlined,
                                  label: s.t('edit_profile'),
                                  onTap: () async {
                                    final updated = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EditProfileScreen(
                                          initialName: _name,
                                          initialWorkerType: _workerType,
                                          initialPhoneNumber: _phoneNumber,
                                        ),
                                      ),
                                    );
                                    if (updated == true) {
                                      _fetchUserProfile();
                                    }
                                  },
                                ),
                                _buildDivider(),

                                // Language row
                                _buildSettingsRow(
                                  icon: Icons.language_outlined,
                                  label: s.t('settings_language'),
                                  trailingText: currentLanguage,
                                  onTap: () => showLanguagePicker(context),
                                ),
                                _buildDivider(),

                                // Savings Goal row
                                _buildSettingsRow(
                                  icon: Icons.savings_outlined,
                                  label: "Savings Goal",
                                  trailingText: _savingsGoal != null
                                      ? "₹${formatIndianCurrency((_savingsGoal!['targetAmount'] as num).toDouble())} / ${_savingsGoal!['period']}"
                                      : "Not set",
                                  onTap: () => _showSavingsGoalBottomSheet(context),
                                ),
                                _buildDivider(),


                                // Emergency Contacts row
                                _buildSettingsRow(
                                  icon: Icons.health_and_safety_outlined,
                                  label: "Emergency Contacts",
                                  trailingText: "${_emergencyContacts.length}/5",
                                  onTap: () async {
                                    final updated = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => EmergencyContactsScreen(
                                          contacts: _emergencyContacts,
                                        ),
                                      ),
                                    );
                                    if (updated == true) {
                                      _fetchUserProfile();
                                    }
                                  },
                                ),
                                _buildDivider(),

                                // SOS Settings row
                                _buildSettingsRow(
                                  icon: Icons.sos_outlined,
                                  label: s.t('sos_settings'),
                                  trailingText: "Configure",
                                  onTap: () => _showSOSSettingsBottomSheet(context),
                                ),
                                _buildDivider(),
                                // About row
                                _buildSettingsRow(
                                  icon: Icons.info_outline_rounded,
                                  label: s.t('about_gigshield'),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                                    );
                                  },
                                  onLongPress: _triggerRecalculateBenchmarks,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Sign Out (separated visually with space + outlined Secondary Button style)
                          PlayfulButton(
                            backgroundColor: Colors.white,
                            onPressed: () async {
                              await FirebaseAuth.instance.signOut();
                            },
                            child: Text(
                              s.t('sign_out'),
                              style: GoogleFonts.outfit(
                                color: PlayfulColors.foreground,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _triggerRecalculateBenchmarks() async {
    bool dialogClosed = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: PlayfulColors.border, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: PlayfulColors.accent),
              const SizedBox(height: 16),
              Text(
                "Recalculating community rates...",
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: PlayfulColors.foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:8000';
      if (!kIsWeb && Platform.isAndroid && (baseUrl.contains("127.0.0.1") || baseUrl.contains("localhost"))) {
        baseUrl = baseUrl.replaceAll("127.0.0.1", "10.0.2.2").replaceAll("localhost", "10.0.2.2");
      }
      final Uri url = Uri.parse('$baseUrl/admin/recalculate-benchmarks');
      final response = await http.post(url, headers: {'ngrok-skip-browser-warning': 'true'}).timeout(const Duration(seconds: 30));
      
      if (mounted && !dialogClosed) {
        Navigator.pop(context);
        dialogClosed = true;
      }

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Successfully recalculated community rates!",
                style: GoogleFonts.plusJakartaSans(
                  color: PlayfulColors.foreground,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: const Color(0xFFFFFDF5),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: PlayfulColors.border, width: 2),
              ),
            ),
          );
        }
      } else {
        throw Exception("Server returned ${response.statusCode}");
      }
    } catch (e) {
      if (mounted && !dialogClosed) {
        Navigator.pop(context);
        dialogClosed = true;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Recalculation failed: $e",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: PlayfulColors.border, width: 2),
            ),
          ),
        );
      }
    }
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    String? trailingText,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(icon, color: PlayfulColors.foreground, size: 22),
        title: Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: PlayfulColors.foreground,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: PlayfulColors.mutedForeground,
                ),
              ),
              const SizedBox(width: 8),
            ],
            const Icon(
              Icons.chevron_right,
              color: PlayfulColors.mutedForeground,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1.5,
      color: PlayfulColors.border.withOpacity(0.15),
    );
  }

  void _showSavingsGoalBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SavingsGoalBottomSheetContent(
          initialGoal: _savingsGoal,
          onSave: (goal) {
            setState(() {
              _savingsGoal = goal;
            });
          },
        );
      },
    );
  }

  void _showSOSSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _SOSSettingsBottomSheetContent(
          initialSettings: _sosSettings,
          emergencyContacts: _emergencyContacts,
          onSave: (settings) async {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              try {
                if (!user.isAnonymous) {
                  await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                    'sosSettings': settings,
                  });
                }
                setState(() {
                  _sosSettings = settings;
                });
              } catch (e) {
                debugPrint("Error saving SOS settings: $e");
              }
            }
          },
        );
      },
    );
  }
}

class _SavingsGoalBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic>? initialGoal;
  final ValueChanged<Map<String, dynamic>?> onSave;

  const _SavingsGoalBottomSheetContent({
    required this.initialGoal,
    required this.onSave,
  });

  @override
  State<_SavingsGoalBottomSheetContent> createState() => _SavingsGoalBottomSheetContentState();
}

class _SavingsGoalBottomSheetContentState extends State<_SavingsGoalBottomSheetContent> {
  late TextEditingController _amountController;
  String _period = "weekly";
  bool _isSaving = false;

  double _bestHistoricalWeek = 0.0;
  double _bestHistoricalMonth = 0.0;

  @override
  void initState() {
    super.initState();
    final amountVal = widget.initialGoal != null ? widget.initialGoal!['targetAmount'].toString() : "";
    _amountController = TextEditingController(text: amountVal);
    _amountController.addListener(_onAmountChanged);
    _period = widget.initialGoal != null ? widget.initialGoal!['period'] ?? "weekly" : "weekly";
    _loadHistoricalBest();
  }

  void _onAmountChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    super.dispose();
  }

  DateTime? _parseTimestamp(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) {
      try {
        return DateTime.parse(val);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _loadHistoricalBest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('jobs')
          .where('user_id', isEqualTo: user.uid)
          .get();

      final Map<int, double> weeklyFares = {};
      final Map<String, double> monthlyFares = {};

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timestampVal = data['job_timestamp'];
        final jobDate = _parseTimestamp(timestampVal);
        if (jobDate == null) continue;

        final fare = (data['fare'] as num?)?.toDouble() ?? 0.0;

        // Calendar week grouping
        final weekId = jobDate.millisecondsSinceEpoch ~/ (7 * 24 * 3600 * 1000);
        weeklyFares[weekId] = (weeklyFares[weekId] ?? 0.0) + fare;

        // Calendar month grouping
        final monthId = "${jobDate.year}-${jobDate.month}";
        monthlyFares[monthId] = (monthlyFares[monthId] ?? 0.0) + fare;
      }

      double maxWeek = 0.0;
      for (var val in weeklyFares.values) {
        if (val > maxWeek) maxWeek = val;
      }

      double maxMonth = 0.0;
      for (var val in monthlyFares.values) {
        if (val > maxMonth) maxMonth = val;
      }

      if (mounted) {
        setState(() {
          _bestHistoricalWeek = maxWeek;
          _bestHistoricalMonth = maxMonth;
        });
      }
    } catch (e) {
      debugPrint("Error loading historical best: $e");
    }
  }

  String? _getValidationError() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return null;
    final val = double.tryParse(text);
    if (val == null || val <= 0) {
      return "Please enter a valid amount greater than 0.";
    }
    return null;
  }

  bool _shouldShowWarning() {
    final text = _amountController.text.trim();
    if (text.isEmpty) return false;
    final val = double.tryParse(text);
    if (val == null || val <= 0) return false;

    final bestHistory = _period == "weekly" ? _bestHistoricalWeek : _bestHistoricalMonth;
    if (bestHistory <= 0) return false;

    return val > (20 * bestHistory);
  }

  Future<void> _setGoal() async {
    if (_getValidationError() != null) return;
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StringsProvider.instance.t('snack_enter_target_amount'))),
      );
      return;
    }
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StringsProvider.instance.t('snack_enter_valid_amount'))),
      );
      return;
    }

    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {

      final goalData = {
        'targetAmount': amount,
        'period': _period,
        'startDate': widget.initialGoal != null && widget.initialGoal!['startDate'] != null
            ? widget.initialGoal!['startDate']
            : Timestamp.now(),
      };

      
      try {
        if (!user.isAnonymous) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'savingsGoal': goalData,
          }, SetOptions(merge: true));
        }
        widget.onSave(goalData);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: PlayfulColors.accent,
              content: Text(StringsProvider.instance.t('snack_savings_goal_updated')),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error setting savings goal: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(StringsProvider.instance.t('snack_savings_goal_failed'))),
          );
        }
      }
    }
    setState(() => _isSaving = false);
  }

  Future<void> _removeGoal() async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        if (!user.isAnonymous) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'savingsGoal': null,
          }, SetOptions(merge: true));
        }
        widget.onSave(null);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: PlayfulColors.accent,
              content: Text(StringsProvider.instance.t('snack_savings_goal_removed')),
            ),
          );
        }
      } catch (e) {
        debugPrint("Error removing savings goal: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(StringsProvider.instance.t('snack_savings_goal_remove_failed'))),
          );
        }
      }
    }
    setState(() => _isSaving = false);
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
            "SET SAVINGS GOAL",
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 2.0,
              color: PlayfulColors.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            "TARGET AMOUNT (₹)",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: PlayfulColors.mutedForeground,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PlayfulColors.border, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: PlayfulColors.border,
                  offset: Offset(4, 4),
                  blurRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: PlayfulColors.foreground,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: "e.g. 3000",
                isDense: true,
              ),
            ),
          ),
          Builder(
            builder: (context) {
              final errorText = _getValidationError();
              if (errorText != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    errorText,
                    style: GoogleFonts.plusJakartaSans(
                      color: PlayfulColors.mutedForeground,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              }
              
              if (_shouldShowWarning()) {
                final bestHistory = _period == "weekly" ? _bestHistoricalWeek : _bestHistoricalMonth;
                final suggestedAmount = (bestHistory * 1.5).round();
                return Padding(
                  padding: const EdgeInsets.only(top: 12.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: PlayfulColors.border, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "This target is a lot higher than anything you've earned before — want to set something more achievable instead?",
                          style: GoogleFonts.plusJakartaSans(
                            color: PlayfulColors.foreground,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _amountController.text = suggestedAmount.toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: PlayfulColors.accent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: PlayfulColors.border, width: 1.5),
                            ),
                            child: Text(
                              "Set to ₹${formatIndianCurrency(suggestedAmount.toDouble())}",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return const SizedBox.shrink();
            },
          ),
          const SizedBox(height: 24),
          Text(
            "GOAL PERIOD",
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: PlayfulColors.mutedForeground,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: PlayfulColors.border, width: 2),
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
                  child: GestureDetector(
                    onTap: () => setState(() => _period = "weekly"),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _period == "weekly" ? PlayfulColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: _period == "weekly" ? Border.all(color: PlayfulColors.border, width: 2) : null,
                      ),
                      child: Center(
                        child: Text(
                          "Weekly",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: PlayfulColors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _period = "monthly"),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _period == "monthly" ? PlayfulColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: _period == "monthly" ? Border.all(color: PlayfulColors.border, width: 2) : null,
                      ),
                      child: Center(
                        child: Text(
                          "Monthly",
                          style: GoogleFonts.outfit(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: PlayfulColors.foreground,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 36),
          if (_isSaving) ...[
            const Center(child: CircularProgressIndicator(color: PlayfulColors.accent)),
          ] else ...[
            PlayfulButton(
              onPressed: _setGoal,
              child: Text(StringsProvider.instance.t('btn_set_savings_goal')),
            ),
            if (widget.initialGoal != null) ...[
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: _removeGoal,
                  child: Text(
                    StringsProvider.instance.t('btn_remove_goal'),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: PlayfulColors.secondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EditProfileScreen — sub-screen to update full user profile properties
// ---------------------------------------------------------------------------
class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialWorkerType;
  final String initialPhoneNumber;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialWorkerType,
    required this.initialPhoneNumber,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _expYearsController = TextEditingController();
  final _expMonthsController = TextEditingController();

  // Emergency contact inline add text controllers
  final _emContactNameController = TextEditingController();
  final _emContactPhoneController = TextEditingController();

  List<String> _selectedWorkerTypes = [];
  List<String> _workingPlatforms = [];
  String _profilePhotoBase64 = '';
  List<Map<String, dynamic>> _emergencyContacts = [];

  bool _isLoading = true;
  bool _isSaving = false;

  final Map<String, String> _allPlatformsMap = {
    'uber': 'Uber',
    'rapido': 'Rapido',
    'ola': 'Ola',
    'indrive': 'InDrive',
    'zomato': 'Zomato',
    'swiggy': 'Swiggy',
    'dunzo': 'Dunzo',
    'blinkit': 'Blinkit',
    'zepto': 'Zepto',
    'bigbasket': 'BigBasket',
    'amazon_flex': 'Amazon Flex',
    'urban_company': 'Urban Company',
    'porter': 'Porter',
    'housejoy': 'Housejoy',
    'other': 'Other',
  };

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _expYearsController.dispose();
    _expMonthsController.dispose();
    _emContactNameController.dispose();
    _emContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;
        _nameController.text = data['name'] ?? widget.initialName;
        _phoneController.text = data['phoneNumber'] ?? widget.initialPhoneNumber;
        _bioController.text = data['bio'] ?? "";
        _expYearsController.text = (data['experienceYears'] ?? 0).toString();
        _expMonthsController.text = (data['experienceMonths'] ?? 0).toString();

        final wts = data['workerTypes'];
        if (wts is List) {
          _selectedWorkerTypes = List<String>.from(wts);
        } else {
          final wt = data['workerType'] ?? widget.initialWorkerType;
          _selectedWorkerTypes = [wt];
        }

        final wps = data['workingPlatforms'];
        if (wps is List) {
          _workingPlatforms = List<String>.from(wps);
        }

        _profilePhotoBase64 = data['profilePhotoBase64'] ?? "";
        _emergencyContacts = List<Map<String, dynamic>>.from(
            (data['emergencyContacts'] as List?)?.map((e) => Map<String, dynamic>.from(e)) ?? []);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint("Error loading profile details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String normalizeIndianPhoneNumber(String input) {
    String cleaned = input.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    final match = RegExp(r'^(?:\+91|91)?([6-9]\d{9})$').firstMatch(cleaned);
    if (match != null) {
      return '+91${match.group(1)}';
    }
    return '';
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 200,
        maxHeight: 200,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _profilePhotoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  void _addEmergencyContact() {
    final name = _emContactNameController.text.trim();
    final phone = _emContactPhoneController.text.trim();
    final normalized = normalizeIndianPhoneNumber(phone);

    if (name.isEmpty || normalized.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringsProvider.instance.t('err_valid_name_phone')),
          backgroundColor: PlayfulColors.secondary,
        ),
      );
      return;
    }

    if (_emergencyContacts.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringsProvider.instance.t('err_max_contacts')),
          backgroundColor: PlayfulColors.secondary,
        ),
      );
      return;
    }

    setState(() {
      _emergencyContacts.add({'name': name, 'phone': normalized});
      _emContactNameController.clear();
      _emContactPhoneController.clear();
    });
  }

  void _removeEmergencyContact(int index) {
    setState(() {
      _emergencyContacts.removeAt(index);
    });
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final normalizedPhone = normalizeIndianPhoneNumber(phone);
    final bio = _bioController.text.trim();
    final expYears = int.tryParse(_expYearsController.text.trim()) ?? 0;
    final expMonths = int.tryParse(_expMonthsController.text.trim()) ?? 0;

    if (name.isEmpty || normalizedPhone.isEmpty || _selectedWorkerTypes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringsProvider.instance.t('err_profile_required')),
          backgroundColor: PlayfulColors.secondary,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': name,
          'phoneNumber': normalizedPhone,
          'workerType': _selectedWorkerTypes.first, // Backward compatibility
          'workerTypes': _selectedWorkerTypes,
          'workingPlatforms': _workingPlatforms,
          'bio': bio,
          'experienceYears': expYears,
          'experienceMonths': expMonths,
          'profilePhotoBase64': _profilePhotoBase64,
          'emergencyContacts': _emergencyContacts,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving profile: $e");
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringsProvider.instance.t('logjob_offline_note')),
          backgroundColor: PlayfulColors.secondary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    final phoneVal = normalizeIndianPhoneNumber(_phoneController.text);
    final bool canSave = _nameController.text.trim().isNotEmpty &&
        _selectedWorkerTypes.isNotEmpty &&
        phoneVal.isNotEmpty &&
        !_isSaving &&
        !_isLoading;

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        backgroundColor: PlayfulColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PlayfulColors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          s.t('edit_profile'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: PlayfulColors.foreground),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: PlayfulColors.accent))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Profile Photo Picker Section
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: PlayfulColors.border, width: 3.0),
                                boxShadow: const [
                                  BoxShadow(
                                    color: PlayfulColors.border,
                                    offset: Offset(4, 4),
                                    blurRadius: 0,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9999),
                                child: _profilePhotoBase64.isNotEmpty
                                    ? Image.memory(
                                        base64Decode(_profilePhotoBase64),
                                        fit: BoxFit.cover,
                                        width: 96,
                                        height: 96,
                                      )
                                    : const Icon(Icons.person, size: 48, color: PlayfulColors.mutedForeground),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: PlayfulColors.accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2.0),
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Name Input
                    PlayfulInput(
                      labelText: s.t('your_name_label'),
                      hintText: s.t('your_name_hint'),
                      controller: _nameController,
                    ),
                    const SizedBox(height: 20),

                    // Phone Input
                    PlayfulInput(
                      labelText: "MOBILE NUMBER (10-DIGIT)",
                      hintText: "e.g., 9876543210",
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 20),

                    // Bio input
                    PlayfulInput(
                      labelText: "SHORT BIO / NOTE",
                      hintText: "e.g. Full-time Swiggy rider, Indiranagar area",
                      controller: _bioController,
                    ),
                    const SizedBox(height: 20),

                    // Experience inline Row
                    Row(
                      children: [
                        Expanded(
                          child: PlayfulInput(
                            labelText: "YEARS ACTIVE",
                            hintText: "Years",
                            controller: _expYearsController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: PlayfulInput(
                            labelText: "MONTHS ACTIVE",
                            hintText: "Months",
                            controller: _expMonthsController,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Worker Type Selector (Multi-select)
                    Text(
                      s.t('worker_type_label') + " (MULTI-SELECT)",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: PlayfulColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _EditStickerCard(
                      label: s.t('worker_delivery'),
                      isSelected: _selectedWorkerTypes.contains("delivery_rider"),
                      onTap: () {
                        setState(() {
                          if (_selectedWorkerTypes.contains("delivery_rider")) {
                            if (_selectedWorkerTypes.length > 1) {
                              _selectedWorkerTypes.remove("delivery_rider");
                            }
                          } else {
                            _selectedWorkerTypes.add("delivery_rider");
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _EditStickerCard(
                      label: s.t('worker_cab'),
                      isSelected: _selectedWorkerTypes.contains("cab_driver"),
                      onTap: () {
                        setState(() {
                          if (_selectedWorkerTypes.contains("cab_driver")) {
                            if (_selectedWorkerTypes.length > 1) {
                              _selectedWorkerTypes.remove("cab_driver");
                            }
                          } else {
                            _selectedWorkerTypes.add("cab_driver");
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    _EditStickerCard(
                      label: s.t('worker_other'),
                      isSelected: _selectedWorkerTypes.contains("other_gig_worker"),
                      onTap: () {
                        setState(() {
                          if (_selectedWorkerTypes.contains("other_gig_worker")) {
                            if (_selectedWorkerTypes.length > 1) {
                              _selectedWorkerTypes.remove("other_gig_worker");
                            }
                          } else {
                            _selectedWorkerTypes.add("other_gig_worker");
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 32),

                    // Working Platforms Multi-select
                    Text(
                      "WHICH PLATFORMS DO YOU GIG ON?",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: PlayfulColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allPlatformsMap.entries.map((entry) {
                        final bool isSelected = _workingPlatforms.contains(entry.key);
                        return ChoiceChip(
                          label: Text(
                            entry.value,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isSelected ? Colors.white : PlayfulColors.foreground,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: PlayfulColors.accent,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: PlayfulColors.border, width: 1.5),
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _workingPlatforms.add(entry.key);
                              } else {
                                _workingPlatforms.remove(entry.key);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Emergency Contact Management
                    Text(
                      "EMERGENCY CONTACTS (MAX 5)",
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        color: PlayfulColors.foreground,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Contacts List Cards
                    if (_emergencyContacts.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: PlayfulColors.muted.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PlayfulColors.border, width: 1.5),
                        ),
                        child: Text(
                          "No emergency contacts added yet.",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: PlayfulColors.mutedForeground,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _emergencyContacts.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final contact = entry.value;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: PlayfulColors.border, width: 2.0),
                              boxShadow: const [
                                BoxShadow(
                                  color: PlayfulColors.border,
                                  offset: Offset(2, 2),
                                  blurRadius: 0,
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.contact_phone, color: PlayfulColors.accent, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        contact['name'] ?? "",
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: PlayfulColors.foreground,
                                        ),
                                      ),
                                      Text(
                                        contact['phone'] ?? "",
                                        style: GoogleFonts.shareTechMono(
                                          fontSize: 12,
                                          color: PlayfulColors.mutedForeground,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: PlayfulColors.secondary, size: 20),
                                  onPressed: () => _removeEmergencyContact(idx),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 16),

                    // Add Contact inline Form
                    if (_emergencyContacts.length < 5)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: PlayfulColors.border, width: 2.0),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "ADD EMERGENCY CONTACT",
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                color: PlayfulColors.foreground,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emContactNameController,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: "Contact Name",
                                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: PlayfulColors.mutedForeground),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emContactPhoneController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: "Mobile Number",
                                labelStyle: GoogleFonts.plusJakartaSans(fontSize: 12, color: PlayfulColors.mutedForeground),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            PlayfulButton(
                              onPressed: _addEmergencyContact,
                              height: 36,
                              backgroundColor: PlayfulColors.tertiary,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add, size: 16, color: PlayfulColors.foreground),
                                  const SizedBox(width: 4),
                                  Text(
                                    "ADD TO LIST",
                                    style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: PlayfulColors.foreground),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 48),

                    // Action button
                    if (_isSaving)
                      const Center(child: CircularProgressIndicator(color: PlayfulColors.accent))
                    else
                      PlayfulButton(
                        onPressed: canSave ? _saveProfile : null,
                        child: Text(s.t('btn_save')),
                      ),
                  ],
                ),
              ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? PlayfulColors.accent : PlayfulColors.border,
            width: 2.0,
          ),
          boxShadow: [
            if (isSelected)
              const BoxShadow(
                color: PlayfulColors.accent,
                offset: Offset(4, 4),
                blurRadius: 0,
              )
            else
              const BoxShadow(
                color: PlayfulColors.border,
                offset: Offset(2, 2),
                blurRadius: 0,
              ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: PlayfulColors.foreground,
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: PlayfulColors.accent,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AboutScreen — sub-screen presenting information about GigShield
// ---------------------------------------------------------------------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;

    final List<Map<String, dynamic>> features = [
      {
        'title': s.t('about_feat_map_title'),
        'desc': s.t('about_feat_map_desc'),
        'icon': Icons.map,
        'color': PlayfulColors.teal,
      },
      {
        'title': s.t('about_feat_check_title'),
        'desc': s.t('about_feat_check_desc'),
        'icon': Icons.check_circle_outline,
        'color': PlayfulColors.accent,
      },
      {
        'title': s.t('about_feat_ocr_title'),
        'desc': s.t('about_feat_ocr_desc'),
        'icon': Icons.qr_code_scanner,
        'color': PlayfulColors.secondary,
      },
      {
        'title': s.t('about_feat_chat_title'),
        'desc': s.t('about_feat_chat_desc'),
        'icon': Icons.chat_bubble_outline,
        'color': PlayfulColors.tertiary,
      },
      {
        'title': s.t('about_feat_sos_title'),
        'desc': s.t('about_feat_sos_desc'),
        'icon': Icons.emergency_share,
        'color': const Color(0xFFE11D48),
      },
      {
        'title': s.t('about_feat_fatigue_title'),
        'desc': s.t('about_feat_fatigue_desc'),
        'icon': Icons.access_time,
        'color': PlayfulColors.orange,
      },
    ];

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        backgroundColor: PlayfulColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: PlayfulColors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          s.t('about_gigshield'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: PlayfulColors.foreground),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  children: [
                    Text(
                      s.t('app_name'),
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: PlayfulColors.foreground,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.t('about_desc'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: PlayfulColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                s.t('about_features_title'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: PlayfulColors.foreground,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ...features.map((feat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 18.0),
                  child: Container(
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: feat['color'],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: PlayfulColors.border, width: 2.0),
                          ),
                          child: Icon(
                            feat['icon'],
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feat['title'],
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: PlayfulColors.foreground,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                feat['desc'],
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                  color: PlayfulColors.mutedForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              Text(
                s.t('chat_disclaimer'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: PlayfulColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}


class EmergencyContactsScreen extends StatefulWidget {
  final List<Map<String, dynamic>> contacts;
  const EmergencyContactsScreen({super.key, required this.contacts});

  @override
  State<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends State<EmergencyContactsScreen> {
  late List<Map<String, dynamic>> _contacts;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _contacts = List.from(widget.contacts.map((c) => Map<String, dynamic>.from(c)));
  }

  Future<void> _saveContacts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      Navigator.pop(context);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'emergencyContacts': _contacts,
      }, SetOptions(merge: true));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving contacts: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PlayfulColors.border, width: 2),
        ),
        title: Text(
          "Add Contact",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: "Phone Number",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(StringsProvider.instance.t('btn_cancel'), style: const TextStyle(color: PlayfulColors.foreground)),
          ),
          PlayfulButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                setState(() {
                  _contacts.add({
                    'name': nameCtrl.text.trim(),
                    'phone': phoneCtrl.text.trim(),
                  });
                });
                Navigator.pop(ctx);
              }
            },
            child: Text(StringsProvider.instance.t('btn_add')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PlayfulColors.background,
      appBar: AppBar(
        backgroundColor: PlayfulColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: PlayfulColors.foreground),
        title: Text(
          "Emergency Contacts",
          style: GoogleFonts.outfit(
            color: PlayfulColors.foreground,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: PlayfulColors.tertiary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: PlayfulColors.tertiary, width: 2),
                ),
                child: Text(
                  "Set up to 5 trusted contacts. If you ever feel unsafe on a job, you can quickly draft and send an SOS alert to them from the Home screen.",
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    color: PlayfulColors.foreground,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (ctx, i) {
                    final c = _contacts[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: PlayfulColors.border, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: PlayfulColors.secondary,
                            offset: Offset(3, 3),
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
                                Text(
                                  c['name'],
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  c['phone'],
                                  style: GoogleFonts.plusJakartaSans(
                                    color: PlayfulColors.mutedForeground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () {
                              setState(() => _contacts.removeAt(i));
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_contacts.length < 5)
                PlayfulButton(
                  onPressed: _showAddDialog,
                  backgroundColor: PlayfulColors.secondary,
                  child: Text(
                    "ADD CONTACT",
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
                  ),
                ),
              const SizedBox(height: 16),
              PlayfulButton(
                onPressed: _isLoading ? null : _saveContacts,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "SAVE CHANGES",
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w900),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SOSSettingsBottomSheetContent — Custom layout sheet for SOS Settings
// ---------------------------------------------------------------------------
class _SOSSettingsBottomSheetContent extends StatefulWidget {
  final Map<String, dynamic>? initialSettings;
  final List<Map<String, dynamic>> emergencyContacts;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _SOSSettingsBottomSheetContent({
    required this.initialSettings,
    required this.emergencyContacts,
    required this.onSave,
  });

  @override
  State<_SOSSettingsBottomSheetContent> createState() => _SOSSettingsBottomSheetContentState();
}

class _SOSSettingsBottomSheetContentState extends State<_SOSSettingsBottomSheetContent> {
  late TextEditingController _templateController;
  
  bool _whatsappEnabled = true;
  bool _autoSmsEnabled = false;
  bool _manualSmsEnabled = false;
  
  String _primaryChannel = 'whatsapp';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final settings = widget.initialSettings ?? {};
    final channels = settings['channels'] as Map<String, dynamic>? ?? {};
    
    final isAndroid = Platform.isAndroid;
    _whatsappEnabled = channels['whatsapp'] ?? true;
    
    if (isAndroid) {
      _autoSmsEnabled = channels['autoSms'] ?? (channels['sms'] ?? true);
      _manualSmsEnabled = channels['manualSms'] ?? false;
      _primaryChannel = settings['primaryChannel'] ?? 'autoSms';
      if (_primaryChannel == 'sms') _primaryChannel = 'autoSms';
    } else {
      _autoSmsEnabled = false;
      _manualSmsEnabled = channels['manualSms'] ?? (channels['sms'] ?? true);
      _primaryChannel = settings['primaryChannel'] ?? 'manualSms';
      if (_primaryChannel == 'sms') _primaryChannel = 'manualSms';
    }
    
    final s = StringsProvider.instance;
    final defaultTemplate = s.t('sos_message_template');
    _templateController = TextEditingController(text: settings['messageTemplate'] ?? defaultTemplate);
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  void _resetTemplate() {
    final s = StringsProvider.instance;
    setState(() {
      _templateController.text = s.t('sos_message_template');
    });
  }

  Future<void> _saveSettings() async {
    if (!_whatsappEnabled && !_autoSmsEnabled && !_manualSmsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StringsProvider.instance.t('err_enable_channel'))),
      );
      return;
    }
    
    if (_primaryChannel == 'autoSms' && !_autoSmsEnabled) {
      _primaryChannel = _whatsappEnabled ? 'whatsapp' : 'manualSms';
    }
    if (_primaryChannel == 'manualSms' && !_manualSmsEnabled) {
      _primaryChannel = _whatsappEnabled ? 'whatsapp' : 'autoSms';
    }
    if (_primaryChannel == 'whatsapp' && !_whatsappEnabled) {
      _primaryChannel = _autoSmsEnabled ? 'autoSms' : 'manualSms';
    }

    final settings = {
      'channels': {
        'whatsapp': _whatsappEnabled,
        'autoSms': _autoSmsEnabled,
        'manualSms': _manualSmsEnabled,
      },
      'primaryChannel': _primaryChannel,
      'messageTemplate': _templateController.text.trim(),
    };

    setState(() => _isSaving = true);
    await widget.onSave(settings);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StringsProvider.instance.t('snack_sos_updated'))),
      );
    }
  }

  Future<void> _sendTestAlert() async {
    if (widget.emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(StringsProvider.instance.t('err_configure_contact'))),
      );
      return;
    }

    final currentSettings = {
      'channels': {
        'whatsapp': _whatsappEnabled,
        'autoSms': _autoSmsEnabled,
        'manualSms': _manualSmsEnabled,
      },
      'primaryChannel': _primaryChannel,
      'messageTemplate': _templateController.text.trim(),
    };

    await widget.onSave(currentSettings);

    final user = FirebaseAuth.instance.currentUser;
    String workerName = "Worker";
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        workerName = doc.data()!['name'] ?? "Worker";
      }
    }

    if (mounted) {
      Navigator.pop(context); // close bottom sheet
      await SOSManager.instance.startSOS(widget.emergencyContacts.first, currentSettings, workerName, context, isTest: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = StringsProvider.instance;
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: mq.viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        border: Border(
          top: BorderSide(color: PlayfulColors.border, width: 4),
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "SOS SETTINGS",
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: PlayfulColors.foreground,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: PlayfulColors.border, size: 24),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(color: PlayfulColors.border, thickness: 2),
            const SizedBox(height: 16),
            
            Text(
              "CHANNELS",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: PlayfulColors.mutedForeground,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            
            CheckboxListTile(
              title: Text(s.t('alert_whatsapp_title'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(s.t('alert_whatsapp_subtitle'), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: PlayfulColors.mutedForeground)),
              value: _whatsappEnabled,
              activeColor: PlayfulColors.accent,
              onChanged: (val) {
                setState(() {
                  _whatsappEnabled = val ?? false;
                });
              },
            ),
            if (Platform.isAndroid)
              CheckboxListTile(
                title: Text(
                  "Automatic SMS Alert (Silent)",
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                subtitle: Text(
                  "Sends SMS programmatically in background. Requires SMS permission.",
                  style: GoogleFonts.plusJakartaSans(fontSize: 11, color: PlayfulColors.mutedForeground),
                ),
                value: _autoSmsEnabled,
                activeColor: PlayfulColors.accent,
                onChanged: (val) async {
                  final messenger = ScaffoldMessenger.of(context);
                  if (val == true) {
                    var status = await Permission.sms.status;
                    if (!status.isGranted) {
                      status = await Permission.sms.request();
                    }
                    if (status.isGranted) {
                      setState(() {
                        _autoSmsEnabled = true;
                      });
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(s.t('err_sms_permission_required')),
                          backgroundColor: const Color(0xFFE11D48),
                        ),
                      );
                      setState(() {
                        _autoSmsEnabled = false;
                      });
                    }
                  } else {
                    setState(() {
                      _autoSmsEnabled = false;
                    });
                  }
                },
              ),
            CheckboxListTile(
              title: Text(s.t('alert_manual_sms_title'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(s.t('alert_manual_sms_subtitle'), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: PlayfulColors.mutedForeground)),
              value: _manualSmsEnabled,
              activeColor: PlayfulColors.accent,
              onChanged: (val) {
                setState(() {
                  _manualSmsEnabled = val ?? false;
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            Text(
              "PRIMARY SOS METHOD",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: PlayfulColors.mutedForeground,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_autoSmsEnabled && Platform.isAndroid)
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(s.t('alert_auto_sms'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11)),
                      value: 'autoSms',
                      groupValue: _primaryChannel,
                      activeColor: PlayfulColors.accent,
                      onChanged: (val) => setState(() => _primaryChannel = val!),
                    ),
                  ),
                if (_manualSmsEnabled)
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(s.t('alert_manual_sms'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11)),
                      value: 'manualSms',
                      groupValue: _primaryChannel,
                      activeColor: PlayfulColors.accent,
                      onChanged: (val) => setState(() => _primaryChannel = val!),
                    ),
                  ),
                if (_whatsappEnabled)
                  Expanded(
                    child: RadioListTile<String>(
                      title: Text(s.t('alert_whatsapp'), style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11)),
                      value: 'whatsapp',
                      groupValue: _primaryChannel,
                      activeColor: PlayfulColors.accent,
                      onChanged: (val) => setState(() => _primaryChannel = val!),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "CUSTOM ALERT MESSAGE",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: PlayfulColors.mutedForeground,
                    letterSpacing: 1.5,
                  ),
                ),
                TextButton(
                  onPressed: _resetTemplate,
                  child: Text(
                    "Reset to Default",
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 11, color: PlayfulColors.accent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _templateController,
              maxLines: 3,
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: PlayfulColors.foreground),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                helperText: "Use placeholders {name}, {link}, and {time} to keep info dynamic.",
                helperStyle: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: PlayfulColors.border, width: 2),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: PlayfulColors.accent, width: 2),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            Row(
              children: [
                Expanded(
                  child: PlayfulButton(
                    onPressed: _isSaving ? null : _saveSettings,
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            "SAVE SETTINGS",
                            style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            PlayfulButton(
              onPressed: _sendTestAlert,
              backgroundColor: PlayfulColors.secondary,
              child: Text(
                "SEND TEST ALERT",
                style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
