import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'playful_widgets.dart';
import '../i18n/strings.dart';

// ---------------------------------------------------------------------------
// SOSManager — Central State Coordinator for live locations and timers
// ---------------------------------------------------------------------------
class SOSManager {
  SOSManager._();
  static final SOSManager instance = SOSManager._();
  static const MethodChannel _smsChannel = MethodChannel('com.example.app/sms');

  String? activeSessionId;
  Map<String, dynamic>? activeContact;
  DateTime? expiresAt;
  Timer? _locationTimer;
  Timer? _countdownTimer;
  int secondsRemaining = 0;
  
  VoidCallback? onTick;

  bool get isActive => activeSessionId != null && expiresAt != null && DateTime.now().isBefore(expiresAt!);

  Future<void> startSOS(Map<String, dynamic> contact, Map<String, dynamic> settings, String workerName, BuildContext context, {bool isTest = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final sessionId = FirebaseFirestore.instance.collection('liveLocations').doc().id;
    activeSessionId = sessionId;
    activeContact = contact;
    
    final durationMin = settings['liveLocationDurationMinutes'] as int? ?? 30;
    final startedAt = DateTime.now();
    expiresAt = startedAt.add(Duration(minutes: durationMin));
    secondsRemaining = durationMin * 60;

    try {
      // 1. Initialize doc in Firestore
      await FirebaseFirestore.instance.collection('liveLocations').doc(sessionId).set({
        'uid': user.uid,
        'startedAt': Timestamp.fromDate(startedAt),
        'expiresAt': Timestamp.fromDate(expiresAt!),
        'active': true,
        'locations': [],
      });
    } catch (e) {
      debugPrint("Error writing liveLocations doc: $e");
    }

    // 2. Start location timer
    _locationTimer?.cancel();
    _locationTimer = Timer.periodic(const Duration(seconds: 20), (t) => _updateLocation());
    _updateLocation();

    // 3. Start countdown timer
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (secondsRemaining <= 1) {
        stopSOS();
        if (onTick != null) onTick!();
      } else {
        secondsRemaining--;
        if (onTick != null) onTick!();
      }
    });

    // 4. Launch primary intent
    final String primaryChan = settings['primaryChannel'] ?? 'sms';
    await launchChannel(primaryChan, workerName, isTest);

    // 5. Navigate to SOS Active Screen
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SOSActiveScreen(contact: contact, isTest: isTest)),
      );
    }
  }

  Future<void> _updateLocation() async {
    if (activeSessionId == null) return;
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          final Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
          ).timeout(const Duration(seconds: 5));

          await FirebaseFirestore.instance.collection('liveLocations').doc(activeSessionId).update({
            'locations': FieldValue.arrayUnion([
              {
                'latitude': position.latitude,
                'longitude': position.longitude,
                'timestamp': Timestamp.now(),
              }
            ])
          });
        }
      }
    } catch (e) {
      debugPrint("Error updating location: $e");
    }
  }

  Future<void> launchChannel(String channel, String workerName, bool isTest) async {
    if (activeSessionId == null) return;
    
    // Resolve template
    final s = StringsProvider.instance;
    final user = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? userSettings;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          userSettings = doc.data()?['sosSettings'] as Map<String, dynamic>?;
        }
      } catch (e) {
        debugPrint("Error loading user settings: $e");
      }
    }

    final defaultTemplate = s.t('sos_message_template');
    String template = userSettings?['messageTemplate'] ?? defaultTemplate;
    if (template.isEmpty) {
      template = defaultTemplate;
    }

    final String timeStr = TimeOfDay.now().format(WidgetsBinding.instance.focusManager.primaryFocus?.context ?? WidgetsBinding.instance.rootElement!);
    final String link = "https://gigshield-e38ec.web.app/track/$activeSessionId";

    String message = template
        .replaceAll("{name}", workerName)
        .replaceAll("{link}", link)
        .replaceAll("{time}", timeStr);

    if (isTest) {
      message = "[TEST MODE - IGNORE] $message";
    }

    final String phone = activeContact?['phone']?.toString().replaceAll(RegExp(r'\s+'), '') ?? '';

    if (channel == 'sms') {
      bool isPermissionGranted = await Permission.sms.isGranted;
      if (!isPermissionGranted) {
        final status = await Permission.sms.request();
        isPermissionGranted = status.isGranted;
      }

      if (isPermissionGranted) {
        try {
          final bool success = await _smsChannel.invokeMethod('sendSMS', {
            'phone': phone,
            'message': message,
          });
          if (success) {
            return;
          }
        } catch (e) {
          debugPrint("Failed to send background SMS, falling back to url_launcher: $e");
        }
      }

      final Uri uri = Uri.parse("sms:$phone?body=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
      }
    } else if (channel == 'whatsapp') {
      final Uri uri = Uri.parse("https://wa.me/$phone?text=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
      }
    } else if (channel == 'call') {
      final Uri uri = Uri.parse("tel:$phone");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  Future<void> stopSOS() async {
    if (activeSessionId != null) {
      try {
        await FirebaseFirestore.instance.collection('liveLocations').doc(activeSessionId).update({
          'active': false,
        });
      } catch (e) {
        debugPrint("Error stopping SOS: $e");
      }
    }
    _locationTimer?.cancel();
    _countdownTimer?.cancel();
    activeSessionId = null;
    activeContact = null;
    expiresAt = null;
    secondsRemaining = 0;
  }
}

// ---------------------------------------------------------------------------
// SOSActiveScreen — The Stateful UI for SOS active mode
// ---------------------------------------------------------------------------
class SOSActiveScreen extends StatefulWidget {
  final Map<String, dynamic> contact;
  final bool isTest;

  const SOSActiveScreen({super.key, required this.contact, this.isTest = false});

  @override
  State<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends State<SOSActiveScreen> {
  String _workerName = "Worker";

  @override
  void initState() {
    super.initState();
    _loadProfile();
    SOSManager.instance.onTick = () {
      if (mounted) {
        setState(() {});
        if (!SOSManager.instance.isActive) {
          Navigator.pop(context);
        }
      }
    };
  }

  @override
  void dispose() {
    SOSManager.instance.onTick = null;
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null && mounted) {
        setState(() {
          _workerName = doc.data()!['name'] ?? "Worker";
        });
      }
    }
  }

  String _formatDuration(int totalSecs) {
    final int minutes = totalSecs ~/ 60;
    final int seconds = totalSecs % 60;
    return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    final seconds = SOSManager.instance.secondsRemaining;
    
    // Check which secondary channels are enabled in settings
    return PopScope(
      canPop: false, // Prevent physical back navigation
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFDF5),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                // Heading Indicator Box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    border: Border.all(color: PlayfulColors.border, width: 3),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: PlayfulColors.border,
                        offset: Offset(4, 4),
                        blurRadius: 0,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 40),
                      const SizedBox(height: 8),
                      Text(
                        widget.isTest ? "TEST ALERT RUNNING" : s.t('sos_active_title'),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Live status Card
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: PlayfulColors.border, width: 3),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: PlayfulColors.border,
                          offset: Offset(4, 4),
                          blurRadius: 0,
                        )
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          s.t('sos_sharing_location'),
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: PlayfulColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatDuration(seconds),
                          style: GoogleFonts.shareTechMono(
                            fontSize: 54,
                            fontWeight: FontWeight.bold,
                            color: PlayfulColors.foreground,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Contact Info
                        const Divider(color: PlayfulColors.border, thickness: 2),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.person, color: PlayfulColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.t('sos_contact_alerted').replaceAll("{}", widget.contact['name'] ?? 'Trusted Contact'),
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: PlayfulColors.foreground,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.phone, color: PlayfulColors.accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              widget.contact['phone'] ?? '',
                              style: GoogleFonts.shareTechMono(
                                fontSize: 14,
                                color: PlayfulColors.foreground,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Secondary trigger actions (Manual options)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: PlayfulButton(
                          onPressed: () => SOSManager.instance.launchChannel('whatsapp', _workerName, widget.isTest),
                          backgroundColor: const Color(0xFF25D366),
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.message_outlined, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "WhatsApp",
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 6.0),
                        child: PlayfulButton(
                          onPressed: () => SOSManager.instance.launchChannel('call', _workerName, widget.isTest),
                          backgroundColor: const Color(0xFF3B82F6),
                          height: 48,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.phone, color: Colors.white, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                "Call",
                                style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Stop Sharing Button
                PlayfulButton(
                  onPressed: () async {
                    await SOSManager.instance.stopSOS();
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  backgroundColor: PlayfulColors.accent,
                  child: Text(
                    s.t('sos_stop_sharing'),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
