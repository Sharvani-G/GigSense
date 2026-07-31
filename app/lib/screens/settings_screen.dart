import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'playful_widgets.dart';
import '../i18n/strings.dart';
import '../main.dart' show showLanguagePicker;

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
  String _langCode = "en";

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
          _langCode = data['preferredLanguage'] ?? StringsProvider.instance.lang;
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
                                  child: const Icon(Icons.person_outline, color: PlayfulColors.accent, size: 24),
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

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: ListTile(
        onTap: onTap,
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
}

// ---------------------------------------------------------------------------
// EditProfileScreen — sub-screen to update name and worker type
// ---------------------------------------------------------------------------
class EditProfileScreen extends StatefulWidget {
  final String initialName;
  final String initialWorkerType;

  const EditProfileScreen({
    super.key,
    required this.initialName,
    required this.initialWorkerType,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedWorkerType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialName;
    _selectedWorkerType = widget.initialWorkerType;
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || _selectedWorkerType == null) return;

    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'name': name,
          'workerType': _selectedWorkerType,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Error saving profile: $e");
      setState(() => _isLoading = false);
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
    final bool canSave = _nameController.text.trim().isNotEmpty &&
        _selectedWorkerType != null &&
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name Input
              PlayfulInput(
                labelText: s.t('your_name_label'),
                hintText: s.t('your_name_hint'),
                controller: _nameController,
              ),
              const SizedBox(height: 32),

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

              // 3 Options matching onboarding
              _EditStickerCard(
                label: s.t('worker_delivery'),
                isSelected: _selectedWorkerType == "delivery_rider",
                onTap: () => setState(() => _selectedWorkerType = "delivery_rider"),
              ),
              const SizedBox(height: 16),
              _EditStickerCard(
                label: s.t('worker_cab'),
                isSelected: _selectedWorkerType == "cab_driver",
                onTap: () => setState(() => _selectedWorkerType = "cab_driver"),
              ),
              const SizedBox(height: 16),
              _EditStickerCard(
                label: s.t('worker_other'),
                isSelected: _selectedWorkerType == "other_gig_worker",
                onTap: () => setState(() => _selectedWorkerType = "other_gig_worker"),
              ),
              const SizedBox(height: 48),

              // Action button
              if (_isLoading)
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
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
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: PlayfulColors.foreground,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 16),
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
              const Spacer(),
              Text(
                s.t('chat_disclaimer'),
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  color: PlayfulColors.mutedForeground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
