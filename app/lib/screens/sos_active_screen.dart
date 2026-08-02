import 'dart:io';
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

  Map<String, dynamic>? activeContact;
  String? activeLocationLink;
  VoidCallback? onTick;

  bool get isActive => activeContact != null;

  Future<void> startSOS(Map<String, dynamic> contact, Map<String, dynamic> settings, String workerName, BuildContext context, {bool isTest = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    activeContact = contact;

    // Resolve static current location
    String locationLink = "";
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
          locationLink = "https://www.google.com/maps?q=${position.latitude},${position.longitude}";
        }
      }
    } catch (e) {
      debugPrint("Error fetching location for SOS alert: $e");
    }
    activeLocationLink = locationLink;

    // Launch all configured channels
    final Map<String, dynamic> channels = settings['channels'] as Map<String, dynamic>? ?? {
      'whatsapp': true,
      'autoSms': Platform.isAndroid,
      'manualSms': !Platform.isAndroid,
    };

    bool launchedAny = false;
    if (channels['autoSms'] == true) {
      launchedAny = true;
      launchChannel('autoSms', workerName, isTest, context: context);
    }
    if (channels['manualSms'] == true) {
      launchedAny = true;
      launchChannel('manualSms', workerName, isTest, context: context);
    }
    if (channels['whatsapp'] == true) {
      launchedAny = true;
      launchChannel('whatsapp', workerName, isTest, context: context);
    }

    // Keep legacy channels support for safety
    if (channels['sms'] == true) {
      launchedAny = true;
      launchChannel('sms', workerName, isTest, context: context);
    }
    if (channels['call'] == true) {
      launchedAny = true;
      launchChannel('call', workerName, isTest, context: context);
    }

    if (!launchedAny) {
      final String primaryChan = settings['primaryChannel'] ?? (Platform.isAndroid ? 'autoSms' : 'manualSms');
      launchChannel(primaryChan, workerName, isTest, context: context);
    }

    // Navigate to SOS Active Screen
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SOSActiveScreen(contact: contact, isTest: isTest)),
      );
    }
  }

  Future<void> launchChannel(String channel, String workerName, bool isTest, {BuildContext? context}) async {
    if (activeContact == null) return;
    
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
    final String link = activeLocationLink ?? "";

    String message = template
        .replaceAll("{name}", workerName)
        .replaceAll("{link}", link)
        .replaceAll("{time}", timeStr);

    if (isTest) {
      message = "[TEST MODE - IGNORE] $message";
    }

    final String phone = activeContact?['phone']?.toString() ?? '';

    if (channel == 'autoSms' || (channel == 'sms' && Platform.isAndroid)) {
      if (Platform.isAndroid) {
        final String smsPhone = phone.replaceAll(RegExp(r'\s+'), '');
        final bool isPermissionGranted = await Permission.sms.isGranted;
        if (isPermissionGranted) {
          try {
            final bool success = await _smsChannel.invokeMethod('sendSMS', {
              'phone': smsPhone,
              'message': message,
            });
            if (success) {
              debugPrint("Automatic silent SMS sent to $smsPhone");
              return;
            } else {
              debugPrint("Automatic silent SMS returned success=false");
            }
          } catch (e) {
            debugPrint("Failed to send background SMS programmatically: $e");
          }
        } else {
          debugPrint("Automatic SMS skipped because SEND_SMS permission is not granted.");
        }
      } else {
        debugPrint("Automatic SMS is not supported on this platform.");
      }
    } else if (channel == 'manualSms' || (channel == 'sms' && !Platform.isAndroid)) {
      final String smsPhone = phone.replaceAll(RegExp(r'\s+'), '');
      final Uri uri = Uri.parse("sms:$smsPhone?body=${Uri.encodeComponent(message)}");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
      }
    } else if (channel == 'whatsapp') {
      final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      String sanitizedNumber = cleanDigits;
      if (cleanDigits.length == 10) {
        sanitizedNumber = '91$cleanDigits';
      }

      final Uri uri = sanitizedNumber.isNotEmpty
          ? Uri.parse("https://wa.me/$sanitizedNumber?text=${Uri.encodeComponent(message)}")
          : Uri.parse("https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}");

      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context != null) {
            _showClipboardDialog(context, message);
          } else {
            await Clipboard.setData(ClipboardData(text: message));
          }
        }
      } catch (e) {
        debugPrint("Error launching WhatsApp: $e");
        if (context != null) {
          _showClipboardDialog(context, message);
        } else {
          await Clipboard.setData(ClipboardData(text: message));
        }
      }
    } else if (channel == 'call') {
      final String callPhone = phone.replaceAll(RegExp(r'\s+'), '');
      final Uri uri = Uri.parse("tel:$callPhone");
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  void _showClipboardDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: PlayfulColors.border, width: 2),
        ),
        backgroundColor: Colors.white,
        title: Text(
          "WhatsApp Unavailable",
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: PlayfulColors.foreground),
        ),
        content: Text(
          "WhatsApp is not installed or could not be opened. Would you like to copy the SOS alert message to your clipboard instead?",
          style: GoogleFonts.plusJakartaSans(color: PlayfulColors.foreground),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "CANCEL",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: PlayfulColors.mutedForeground),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("SOS alert copied to clipboard.")),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: PlayfulColors.accent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: PlayfulColors.border, width: 1.5),
              ),
            ),
            child: Text(
              "COPY ALERT",
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> stopSOS() async {
    activeContact = null;
    activeLocationLink = null;
    if (onTick != null) onTick!();
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



  @override
  Widget build(BuildContext context) {
    final s = StringsProvider.instance;
    
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
                          "SOS SAFETY ALERT ACTIVE",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE11D48),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Icon(
                          Icons.radar_rounded,
                          size: 72,
                          color: Color(0xFFE11D48),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "A safety alert containing your current location map link has been triggered to your emergency contact.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: PlayfulColors.mutedForeground,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
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
                          onPressed: () => SOSManager.instance.launchChannel('whatsapp', _workerName, widget.isTest, context: context),
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
                          onPressed: () => SOSManager.instance.launchChannel('call', _workerName, widget.isTest, context: context),
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
