import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'playful_widgets.dart';
import '../i18n/strings.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _PlayfulStickerCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PlayfulStickerCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _selectedWorkerType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateState);
    _phoneController.addListener(_updateState);
  }

  void _updateState() {
    setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  String normalizeIndianPhoneNumber(String input) {
    String cleaned = input.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
    final match = RegExp(r'^(?:\+91|91)?([6-9]\d{9})$').firstMatch(cleaned);
    if (match != null) {
      return '+91${match.group(1)}';
    }
    return '';
  }

  Future<void> _submitOnboarding() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final normalizedPhone = normalizeIndianPhoneNumber(phone);

    if (name.isEmpty || _selectedWorkerType == null || normalizedPhone.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception("No authenticated user found");

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'phoneNumber': normalizedPhone,
        'workerType': _selectedWorkerType,
        'workerTypes': [_selectedWorkerType],
        'workingPlatforms': <String>[],
        'bio': '',
        'experienceYears': 0,
        'experienceMonths': 0,
        'profilePhotoBase64': '',
        'hasSeenHelpWalkthrough': false,
        'preferredLanguage': 'en',
        'createdAt': FieldValue.serverTimestamp(),
      });

      widget.onComplete();
    } catch (e) {
      debugPrint("Onboarding Firestore Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            StringsProvider.instance.t('logjob_offline_note'),
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
      // Even if Firestore fails (offline demo cache), allow entering the app
      widget.onComplete();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final bool canSubmit = name.isNotEmpty &&
        _selectedWorkerType != null &&
        normalizeIndianPhoneNumber(phone).isNotEmpty &&
        !_isLoading;

    return Scaffold(
      backgroundColor: PlayfulColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              // Heading
              Text(
                s.t('onboarding_heading'),
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  color: PlayfulColors.foreground,
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
                labelText: StringsProvider.instance.t('label_mobile_num_10_digit'),
                hintText: StringsProvider.instance.t('hint_mobile_num_example'),
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 36),

              // Worker Type Selector Label
              Text(
                s.t('worker_type_label'),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  color: PlayfulColors.foreground,
                ),
              ),
              const SizedBox(height: 12),

              // 3 Sticker Cards
              _PlayfulStickerCard(
                label: s.t('worker_delivery'),
                isSelected: _selectedWorkerType == "delivery_rider",
                onTap: () => setState(() => _selectedWorkerType = "delivery_rider"),
              ),
              const SizedBox(height: 16),
              _PlayfulStickerCard(
                label: s.t('worker_cab'),
                isSelected: _selectedWorkerType == "cab_driver",
                onTap: () => setState(() => _selectedWorkerType = "cab_driver"),
              ),
              const SizedBox(height: 16),
              _PlayfulStickerCard(
                label: s.t('worker_other'),
                isSelected: _selectedWorkerType == "other_gig_worker",
                onTap: () => setState(() => _selectedWorkerType = "other_gig_worker"),
              ),
              const SizedBox(height: 48),

              // Action button
              if (_isLoading)
                const Center(
                  child: CircularProgressIndicator(color: PlayfulColors.accent),
                )
              else
                PlayfulButton(
                  onPressed: canSubmit ? _submitOnboarding : null,
                  child: Text(s.t('btn_get_started')),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
