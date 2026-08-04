import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'i18n/strings.dart';
import 'screens/home_screen.dart';
import 'screens/log_job_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/playful_widgets.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Top-Level framework error handler
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint("Top-level Flutter Error caught: ${details.exception}");
  };

  // Top-level widget error renderer (avoids red screen of death on UI exceptions)
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFFFFDF5),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 64),
              const SizedBox(height: 16),
              Text(
                "Something went wrong",
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "An unexpected exception occurred. The app is protected and has recovered. You can continue using other features.",
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  // No-op or try to pop
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF1A1A1A), width: 2),
                  ),
                  child: Text(
                    "Dismiss",
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  };
  
  // Load environment variables (if any)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("No .env file found. Proceeding.");
  }

  // Initialize Firebase using the generated options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const GiGlyApp());
}

class GiGlyApp extends StatelessWidget {
  const GiGlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder wraps the entire app so any language change
    // causes a full rebuild of the widget tree.
    return ListenableBuilder(
      listenable: StringsProvider.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'GiGly',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B5CF6)),
            useMaterial3: true,
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E293B),
              contentTextStyle: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFF1A1A1A), width: 2),
              ),
            ),
          ),
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context);
            return MediaQuery(
              data: mediaQuery.copyWith(
                textScaler: TextScaler.linear(StringsProvider.instance.textScaleFactor),
              ),
              child: child!,
            );
          },
          home: const GiGlySplash(),
        );
      },
    );
  }
}

class AuthGateway extends StatefulWidget {
  const AuthGateway({super.key});

  @override
  State<AuthGateway> createState() => _AuthGatewayState();
}

class _AuthGatewayState extends State<AuthGateway> {
  User? _user;
  bool _checkingDoc = true;
  bool _docExists = false;
  bool _bypassAuth = false;
  StreamSubscription<User?>? _authStateSub;

  @override
  void initState() {
    super.initState();
    _authStateSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          _checkingDoc = true;
          if (user == null) {
            _bypassAuth = false;
          }
        });
        _checkUserDoc(user);
      }
    });
  }

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }

  Future<void> _checkUserDoc(User? user) async {
    if (user == null) {
      if (mounted) {
        setState(() {
          _docExists = false;
          _checkingDoc = false;
        });
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      // Load user's preferred language before rendering the main app
      if (doc.exists) {
        final lang = doc.data()?['preferredLanguage'] as String?;
        if (lang != null && lang.isNotEmpty) {
          StringsProvider.instance.setLanguage(lang);
        }
        final fs = doc.data()?['fontSizePreference'] as String?;
        if (fs != null && fs.isNotEmpty) {
          StringsProvider.instance.setFontSize(fs);
        }
      }

      if (mounted) {
        setState(() {
          _docExists = doc.exists;
          _checkingDoc = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking user doc: $e');
      if (mounted) {
        setState(() {
          _docExists = true;
          _checkingDoc = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null && !_bypassAuth) {
      return LoginScreen(
        onBypass: () {
          setState(() {
            _bypassAuth = true;
            _docExists = false;
            _checkingDoc = false;
          });
        },
      );
    }

    if (_checkingDoc) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFFDF5),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF8B5CF6),
          ),
        ),
      );
    }

    if (!_docExists) {
      return OnboardingScreen(
        onComplete: () {
          if (mounted) {
            setState(() {
              _docExists = true;
            });
          }
        },
      );
    }

    return const MainNavigation();
  }
}

class MainNavigationController {
  static final ValueNotifier<int> currentTab = ValueNotifier<int>(0);
  static final ValueNotifier<String?> activeSessionId = ValueNotifier<String?>(null);
  static String? initialMessageToSend;

  static void selectTab(int index) {
    currentTab.value = index;
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = MainNavigationController.currentTab.value;
    MainNavigationController.currentTab.addListener(_onTabChanged);
    _screens = [
      HomeScreen(
        onNavigateToLogJob: () {
          MainNavigationController.selectTab(1);
        },
      ),
      const LogJobScreen(),
      const ChatScreen(),
      const SettingsScreen(),
    ];
  }

  void _onTabChanged() {
    if (mounted) {
      setState(() {
        _currentIndex = MainNavigationController.currentTab.value;
      });
    }
  }

  @override
  void dispose() {
    MainNavigationController.currentTab.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StringsProvider.instance,
      builder: (context, _) {
        final s = StringsProvider.instance;
        return Scaffold(
          body: _screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              MainNavigationController.selectTab(index);
            },
            type: BottomNavigationBarType.fixed,
            selectedItemColor: PlayfulColors.accent,
            unselectedItemColor: PlayfulColors.mutedForeground,
            backgroundColor: Colors.white,
            selectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 11),
            unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 11),
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.home),
                label: s.t('nav_home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.add_circle_outline),
                label: s.t('nav_log_job'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.chat_bubble_outline),
                label: s.t('nav_chat'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings),
                label: s.t('settings_title'),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Language Picker — compact bottom-sheet with 3 radio Sticker Cards
// Triggered from the Home AppBar globe icon.
// ---------------------------------------------------------------------------
class LanguagePickerSheet extends StatefulWidget {
  const LanguagePickerSheet({super.key});

  @override
  State<LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<LanguagePickerSheet> {
  late String _selected;

  static const List<Map<String, String>> _langs = [
    {'code': 'en', 'key': 'lang_en'},
    {'code': 'hi', 'key': 'lang_hi'},
    {'code': 'kn', 'key': 'lang_kn'},
    {'code': 'ta', 'key': 'lang_ta'},
    {'code': 'te', 'key': 'lang_te'},
    {'code': 'ml', 'key': 'lang_ml'},
  ];

  @override
  void initState() {
    super.initState();
    _selected = StringsProvider.instance.lang;
  }

  Future<void> _applyLanguage(String code) async {
    setState(() => _selected = code);
    StringsProvider.instance.setLanguage(code);

    // Persist to Firestore (best-effort — never blocks UI)
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update({'preferredLanguage': code});
      } catch (e) {
        debugPrint('Failed to persist language preference: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFDF5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A), width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            s.t('settings_language'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1A1A1A),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 20),
          for (final lang in _langs) ...[
            _LangCard(
              label: s.t(lang['key']!),
              isSelected: _selected == lang['code'],
              onTap: () => _applyLanguage(lang['code']!),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangCard({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF1A1A1A),
            width: 2.0,
          ),
          boxShadow: [
            if (isSelected)
              const BoxShadow(
                color: Color(0xFF8B5CF6),
                offset: Offset(4, 4),
                blurRadius: 0,
              )
            else
              const BoxShadow(
                color: Color(0xFF1A1A1A),
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
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF8B5CF6), size: 22),
          ],
        ),
      ),
    );
  }
}

/// Helper — open the language picker from anywhere.
void showLanguagePicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const LanguagePickerSheet(),
  );
}
