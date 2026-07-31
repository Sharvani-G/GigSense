import 'package:flutter/foundation.dart';

// ---------------------------------------------------------------------------
// AppStrings — hand-written translation map
// Keys: see the table in the Phase 10 plan.
// Fallback rule: if a key is missing in the active locale, the English value
// is returned silently. The raw key is the absolute last resort (never crash).
// Hindi / Kannada values are machine-translation passes, clearly labelled.
// ---------------------------------------------------------------------------
class AppStrings {
  AppStrings._();

  static const Map<String, Map<String, String>> all = {
    // ------------------------------------------------------------------ ENGLISH
    'en': {
      'app_name': 'GIGSHIELD',
      'tagline': 'Fair pay, on your side.',

      // Login
      'login': 'Log In',
      'signup': 'Sign Up',
      'email_address': 'EMAIL ADDRESS',
      'password': 'PASSWORD',
      'forgot_password': 'Forgot Password?',
      'btn_login': 'LOG IN',
      'btn_create_account': 'CREATE ACCOUNT',
      'continue_as_guest': 'Continue as Guest',

      // Onboarding
      'onboarding_heading': 'Tell us a bit about you',
      'your_name_label': 'WHAT IS YOUR NAME?',
      'your_name_hint': 'Enter your name',
      'worker_type_label': 'WHAT KIND OF WORK DO YOU DO?',
      'worker_delivery': '🛵  Delivery Rider',
      'worker_cab': '🚗  Cab Driver',
      'worker_other': '💼  Other Gig Work',
      'btn_get_started': 'GET STARTED',

      // Bottom Nav
      'nav_home': 'Home',
      'nav_log_job': 'Log Job',
      'nav_chat': 'Chat',

      // Home
      'greeting': 'HELLO',
      'ai_insight': 'AI INSIGHT',
      'home_empty': 'No jobs logged yet — tap below and let\'s check your first payout',
      'home_insight_placeholder': 'Log a few jobs and I\'ll have your first weekly insight ready.',
      'home_error': 'Database sync issue. Using offline cache.',
      'retry': 'RETRY',
      'stat_earnings': 'EARNINGS',
      'stat_hours': 'HOURS',
      'stat_flagged': 'FLAGGED',
      'daily_earnings': 'DAILY EARNINGS',
      'platform_breakdown': 'PLATFORM BREAKDOWN',
      'home_summary': 'Summary',
      'view_all': 'View All',

      // Log Job
      'logjob_subtitle': 'Log your trip to verify your pay instantly.',
      'logjob_platform': 'PLATFORM',
      'logjob_platform_hint': 'Select Platform',
      'logjob_fare': 'FARE (₹)',
      'logjob_fare_hint': 'Enter fare amount',
      'logjob_fare_required': 'Fare is required',
      'logjob_distance': 'DISTANCE (KM)',
      'logjob_distance_hint': 'Enter trip distance',
      'logjob_distance_required': 'Distance is required',
      'logjob_duration': 'DURATION (MIN)',
      'logjob_duration_hint': 'Enter duration in minutes',
      'logjob_duration_required': 'Duration is required',
      'logjob_positive': 'Must be a positive number',
      'logjob_positive_decimal': 'Must be a positive decimal',
      'logjob_btn': 'LOG JOB',
      'logjob_btn_confirm': 'CONFIRM & LOG JOB',
      'logjob_analyzing': 'Analyzing screenshot...',
      'logjob_offline': 'Running in offline mode: Job calculation completed successfully!',
      'logjob_offline_note': 'Connection issue. Using offline mode.',

      // Chat
      'chat_title': 'GIGCHAT',
      'chat_subtitle': 'Worker pay & rights assistant',
      'chat_empty_drawer': 'No conversations yet — start one below',
      'chat_new': '+ NEW CHAT',
      'chat_intro':
          'Hey — ask me anything about your pay, your rights, or how to raise a complaint. I\'ll look at your recent jobs if it\'s relevant.',
      'chat_hint': 'Type your question...',
      'chat_disclaimer': 'General guidance, not legal advice.',
      'chat_error_loading': 'Error loading messages.',
      'chat_error_reply':
          'I\'m having trouble responding right now — try again in a moment.',

      // Quick-reply chips
      'chip_pay_fair': 'Is my pay fair?',
      'chip_rights': 'What are my rights?',
      'chip_complain': 'How do I complain?',

      // Settings / Language picker
      'settings_title': 'SETTINGS',
      'settings_language': 'LANGUAGE',
      'lang_en': 'English',
      'lang_hi': 'हिन्दी (Hindi)',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_ta': 'தமிழ் (Tamil)',
      'lang_te': 'తెలుగు (Telugu)',
      'edit_profile': 'Edit Profile',
      'btn_save': 'SAVE',
      'about_gigshield': 'About GigShield',
      'about_desc': 'GigShield is your companion for verifying pay and protecting gig worker rights in India.',
      'sign_out': 'Sign Out',
    },

    // ------------------------------------------------------------------ HINDI
    // Note: machine-translation pass — review with a fluent speaker before production.
    'hi': {
      'app_name': 'GIGSHIELD',
      'tagline': 'उचित वेतन, आपके साथ।',

      // Login
      'login': 'लॉग इन',
      'signup': 'साइन अप',
      'email_address': 'ईमेल पता',
      'password': 'पासवर्ड',
      'forgot_password': 'पासवर्ड भूल गए?',
      'btn_login': 'लॉग इन करें',
      'btn_create_account': 'खाता बनाएं',
      'continue_as_guest': 'अतिथि के रूप में जारी रखें',

      // Onboarding
      'onboarding_heading': 'हमें अपने बारे में बताएं',
      'your_name_label': 'आपका नाम क्या है?',
      'your_name_hint': 'अपना नाम दर्ज करें',
      'worker_type_label': 'आप किस तरह का काम करते हैं?',
      'worker_delivery': '🛵  डिलीवरी राइडर',
      'worker_cab': '🚗  कैब ड्राइवर',
      'worker_other': '💼  अन्य गिग कार्य',
      'btn_get_started': 'शुरू करें',

      // Bottom Nav
      'nav_home': 'होम',
      'nav_log_job': 'काम दर्ज करें',
      'nav_chat': 'चैट',

      // Home
      'greeting': 'नमस्ते',
      'ai_insight': 'AI जानकारी',
      'home_empty': 'अभी तक कोई काम दर्ज नहीं — नीचे टैप करें और पहला भुगतान जांचें',
      'home_insight_placeholder': 'कुछ काम दर्ज करें और मैं आपकी पहली साप्ताहिक जानकारी तैयार करूंगा।',
      'home_error': 'डेटाबेस सिंक समस्या। ऑफलाइन कैश का उपयोग हो रहा है।',
      'retry': 'पुनः प्रयास',
      'stat_earnings': 'कमाई',
      'stat_hours': 'घंटे',
      'stat_flagged': 'फ्लैग',
      'daily_earnings': 'दैनिक कमाई',
      'platform_breakdown': 'प्लेटफ़ॉर्म विवरण',

      // Log Job
      'logjob_subtitle': 'अपनी सवारी दर्ज करें और तुरंत भुगतान जांचें।',
      'logjob_platform': 'प्लेटफ़ॉर्म',
      'logjob_platform_hint': 'प्लेटफ़ॉर्म चुनें',
      'logjob_fare': 'किराया (₹)',
      'logjob_fare_hint': 'किराया राशि दर्ज करें',
      'logjob_fare_required': 'किराया आवश्यक है',
      'logjob_distance': 'दूरी (KM)',
      'logjob_distance_hint': 'यात्रा दूरी दर्ज करें',
      'logjob_distance_required': 'दूरी आवश्यक है',
      'logjob_duration': 'अवधि (मिनट)',
      'logjob_duration_hint': 'मिनटों में अवधि दर्ज करें',
      'logjob_duration_required': 'अवधि आवश्यक है',
      'logjob_positive': 'एक सकारात्मक संख्या होनी चाहिए',
      'logjob_positive_decimal': 'एक सकारात्मक दशमलव होना चाहिए',
      'logjob_btn': 'काम दर्ज करें',
      'logjob_btn_confirm': 'पुष्टि करें और दर्ज करें',
      'logjob_analyzing': 'स्क्रीनशॉट विश्लेषण हो रहा है...',
      'logjob_offline': 'ऑफलाइन मोड: काम की गणना सफलतापूर्वक पूरी हुई!',
      'logjob_offline_note': 'कनेक्शन समस्या। ऑफलाइन मोड का उपयोग हो रहा है।',

      // Chat
      'chat_title': 'GIGCHAT',
      'chat_subtitle': 'श्रमिक वेतन और अधिकार सहायक',
      'chat_empty_drawer': 'अभी तक कोई बातचीत नहीं — नीचे शुरू करें',
      'chat_new': '+ नई चैट',
      'chat_intro':
          'नमस्ते — अपने वेतन, अधिकारों, या शिकायत करने के तरीके के बारे में कुछ भी पूछें। मैं आपके हाल के कामों को भी देखूंगा।',
      'chat_hint': 'अपना सवाल टाइप करें...',
      'chat_disclaimer': 'सामान्य मार्गदर्शन, कानूनी सलाह नहीं।',
      'chat_error_loading': 'संदेश लोड करने में त्रुटि।',
      'chat_error_reply': 'मुझे अभी जवाब देने में परेशानी हो रही है — एक पल में फिर कोशिश करें।',

      // Quick-reply chips
      'chip_pay_fair': 'क्या मेरा वेतन उचित है?',
      'chip_rights': 'मेरे अधिकार क्या हैं?',
      'chip_complain': 'मैं शिकायत कैसे करूं?',

      // Settings / Language picker
      'settings_title': 'सेटिंग्स',
      'settings_language': 'भाषा',
      'lang_en': 'English',
      'lang_hi': 'हिन्दी (Hindi)',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_ta': 'தமிழ் (Tamil)',
      'lang_te': 'తెలుగు (Telugu)',
      'edit_profile': 'प्रोफ़ाइल संपादित करें',
      'btn_save': 'सहेजें',
      'about_gigshield': 'गिगशील्ड के बारे में',
      'about_desc': 'गिगशील्ड भारत में वेतन की पुष्टि करने और गिग श्रमिकों के अधिकारों की रक्षा करने के लिए आपका साथी है।',
      'sign_out': 'साइन आउट',
    },

    // ------------------------------------------------------------------ KANNADA
    // Note: machine-translation pass — review with a fluent speaker before production.
    'kn': {
      'app_name': 'GIGSHIELD',
      'tagline': 'ನ್ಯಾಯಯುತ ವೇತನ, ನಿಮ್ಮ ಪರವಾಗಿ.',

      // Login
      'login': 'ಲಾಗಿನ್',
      'signup': 'ಸೈನ್ ಅಪ್',
      'email_address': 'ಇಮೇಲ್ ವಿಳಾಸ',
      'password': 'ಪಾಸ್‌ವರ್ಡ್',
      'forgot_password': 'ಪಾಸ್‌ವರ್ಡ್ ಮರೆತಿದ್ದೀರಾ?',
      'btn_login': 'ಲಾಗಿನ್ ಮಾಡಿ',
      'btn_create_account': 'ಖಾತೆ ರಚಿಸಿ',
      'continue_as_guest': 'ಅತಿಥಿಯಾಗಿ ಮುಂದುವರಿಯಿರಿ',

      // Onboarding
      'onboarding_heading': 'ನಿಮ್ಮ ಬಗ್ಗೆ ಸ್ವಲ್ಪ ಹೇಳಿ',
      'your_name_label': 'ನಿಮ್ಮ ಹೆಸರೇನು?',
      'your_name_hint': 'ನಿಮ್ಮ ಹೆಸರು ನಮೂದಿಸಿ',
      'worker_type_label': 'ನೀವು ಯಾವ ರೀತಿಯ ಕೆಲಸ ಮಾಡುತ್ತೀರಿ?',
      'worker_delivery': '🛵  ಡೆಲಿವರಿ ರೈಡರ್',
      'worker_cab': '🚗  ಕ್ಯಾಬ್ ಡ್ರೈವರ್',
      'worker_other': '💼  ಇತರ ಗಿಗ್ ಕೆಲಸ',
      'btn_get_started': 'ಪ್ರಾರಂಭಿಸಿ',

      // Bottom Nav
      'nav_home': 'ಮನೆ',
      'nav_log_job': 'ಕೆಲಸ ದಾಖಲಿಸಿ',
      'nav_chat': 'ಚಾಟ್',

      // Home
      'greeting': 'ನಮಸ್ಕಾರ',
      'ai_insight': 'AI ಒಳನೋಟ',
      'home_empty': 'ಇನ್ನೂ ಯಾವುದೇ ಕೆಲಸ ದಾಖಲಿಸಿಲ್ಲ — ಕೆಳಗೆ ಟ್ಯಾಪ್ ಮಾಡಿ',
      'home_insight_placeholder': 'ಕೆಲವು ಕೆಲಸ ದಾಖಲಿಸಿ ಮತ್ತು ನಾನು ನಿಮ್ಮ ಮೊದಲ ಸಾಪ್ತಾಹಿಕ ಒಳನೋಟ ತಯಾರಿಸುತ್ತೇನೆ.',
      'home_error': 'ಡೇಟಾಬೇಸ್ ಸಿಂಕ್ ಸಮಸ್ಯೆ. ಆಫ್‌ಲೈನ್ ಕ್ಯಾಶ್ ಬಳಸಲಾಗುತ್ತಿದೆ.',
      'retry': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
      'stat_earnings': 'ಆದಾಯ',
      'stat_hours': 'ಗಂಟೆಗಳು',
      'stat_flagged': 'ಫ್ಲಾಗ್',
      'daily_earnings': 'ದೈನಂದಿನ ಆದಾಯ',
      'platform_breakdown': 'ಪ್ಲಾಟ್‌ಫಾರ್ಮ್ ವಿವರ',

      // Log Job
      'logjob_subtitle': 'ನಿಮ್ಮ ಪ್ರಯಾಣ ದಾಖಲಿಸಿ ಮತ್ತು ತಕ್ಷಣ ಪಾವತಿ ಪರಿಶೀಲಿಸಿ.',
      'logjob_platform': 'ಪ್ಲಾಟ್‌ಫಾರ್ಮ್',
      'logjob_platform_hint': 'ಪ್ಲಾಟ್‌ಫಾರ್ಮ್ ಆಯ್ಕೆ ಮಾಡಿ',
      'logjob_fare': 'ಬಾಡಿಗೆ (₹)',
      'logjob_fare_hint': 'ಬಾಡಿಗೆ ಮೊತ್ತ ನಮೂದಿಸಿ',
      'logjob_fare_required': 'ಬಾಡಿಗೆ ಅಗತ್ಯ',
      'logjob_distance': 'ದೂರ (KM)',
      'logjob_distance_hint': 'ಪ್ರಯಾಣ ದೂರ ನಮೂದಿಸಿ',
      'logjob_distance_required': 'ದೂರ ಅಗತ್ಯ',
      'logjob_duration': 'ಅವಧಿ (ನಿಮಿಷ)',
      'logjob_duration_hint': 'ನಿಮಿಷಗಳಲ್ಲಿ ಅವಧಿ ನಮೂದಿಸಿ',
      'logjob_duration_required': 'ಅವಧಿ ಅಗತ್ಯ',
      'logjob_positive': 'ಧನಾತ್ಮಕ ಸಂಖ್ಯೆಯಾಗಿರಬೇಕು',
      'logjob_positive_decimal': 'ಧನಾತ್ಮಕ ದಶಮಾಂಶವಾಗಿರಬೇಕು',
      'logjob_btn': 'ಕೆಲಸ ದಾಖಲಿಸಿ',
      'logjob_btn_confirm': 'ದೃಢಪಡಿಸಿ ಮತ್ತು ದಾಖಲಿಸಿ',
      'logjob_analyzing': 'ಸ್ಕ್ರೀನ್‌ಶಾಟ್ ವಿಶ್ಲೇಷಿಸಲಾಗುತ್ತಿದೆ...',
      'logjob_offline': 'ಆಫ್‌ಲೈನ್ ಮೋಡ್: ಕೆಲಸದ ಲೆಕ್ಕಾಚಾರ ಯಶಸ್ವಿಯಾಗಿ ಪೂರ್ಣವಾಯಿತು!',
      'logjob_offline_note': 'ಸಂಪರ್ಕ ಸಮಸ್ಯೆ. ಆಫ್‌ಲೈನ್ ಮೋಡ್ ಬಳಸಲಾಗುತ್ತಿದೆ.',

      // Chat
      'chat_title': 'GIGCHAT',
      'chat_subtitle': 'ಕಾರ್ಮಿಕ ವೇತನ ಮತ್ತು ಹಕ್ಕುಗಳ ಸಹಾಯಕ',
      'chat_empty_drawer': 'ಇನ್ನೂ ಯಾವುದೇ ಸಂವಾದ ಇಲ್ಲ — ಕೆಳಗೆ ಪ್ರಾರಂಭಿಸಿ',
      'chat_new': '+ ಹೊಸ ಚಾಟ್',
      'chat_intro':
          'ನಮಸ್ಕಾರ — ನಿಮ್ಮ ವೇತನ, ಹಕ್ಕುಗಳು ಅಥವಾ ದೂರು ಸಲ್ಲಿಸುವ ಬಗ್ಗೆ ಏನಾದರೂ ಕೇಳಿ. ನಾನು ನಿಮ್ಮ ಇತ್ತೀಚಿನ ಕೆಲಸಗಳನ್ನು ಕೂಡ ನೋಡುತ್ತೇನೆ.',
      'chat_hint': 'ನಿಮ್ಮ ಪ್ರಶ್ನೆ ಟೈಪ್ ಮಾಡಿ...',
      'chat_disclaimer': 'ಸಾಮಾನ್ಯ ಮಾರ್ಗದರ್ಶನ, ಕಾನೂನು ಸಲಹೆ ಅಲ್ಲ.',
      'chat_error_loading': 'ಸಂದೇಶಗಳನ್ನು ಲೋಡ್ ಮಾಡಲು ದೋಷ.',
      'chat_error_reply': 'ಈಗ ಉತ್ತರಿಸಲು ಸಮಸ್ಯೆ ಆಗುತ್ತಿದೆ — ಸ್ವಲ್ಪ ಸಮಯದ ನಂತರ ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ.',

      // Quick-reply chips
      'chip_pay_fair': 'ನನ್ನ ವೇತನ ನ್ಯಾಯಯುತವೇ?',
      'chip_rights': 'ನನ್ನ ಹಕ್ಕುಗಳೇನು?',
      'chip_complain': 'ನಾನು ಹೇಗೆ ದೂರು ಸಲ್ಲಿಸಲಿ?',

      // Settings / Language picker
      'settings_title': 'ಸೆಟ್ಟಿಂಗ್‌ಗಳು',
      'settings_language': 'ಭಾಷೆ',
      'lang_en': 'English',
      'lang_hi': 'हिन्दी (Hindi)',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_ta': 'தமிழ் (Tamil)',
      'lang_te': 'తెలుగు (Telugu)',
      'edit_profile': 'ಪ್ರೊಫೈಲ್ ಸಂಪಾದಿಸಿ',
      'btn_save': 'ಉಳಿಸು',
      'about_gigshield': 'ಗಿshield ಬಗ್ಗೆ',
      'about_desc': 'ಭಾರతದಲ್ಲಿ ಪಾವತಿಯನ್ನು ಪರಿಶೀಲಿಸಲು ಮತ್ತು ಗಿಗ್ ಕಾರ್ಮಿಕರ ಹಕ್ಕುಗಳನ್ನು ರಕ್ಷಿಸಲು ಗಿಗ್‌ಶೀಲ್ಡ್ ನಿಮ್ಮ ಸಂಗಾತಿಯಾಗಿದೆ.',
      'sign_out': 'ಸೈನ್ ಅೌಟ್',
    },
    // ------------------------------------------------------------------ TAMIL
    // Note: machine-translation pass — review with a fluent speaker before production.
    'ta': {
      'app_name': 'GIGSHIELD',
      'tagline': 'நியாயமான ஊதியம், உங்கள் பக்கத்தில்.',

      // Login
      'login': 'உள்நுழைக',
      'signup': 'பதிவு செய்க',
      'email_address': 'மின்னஞ்சல் முகவரி',
      'password': 'கடவுச்சொல்',
      'forgot_password': 'கடவுச்சொல் மறந்துவிட்டதா?',
      'btn_login': 'உள்நுழைக',
      'btn_create_account': 'கணக்கை உருவாக்கு',
      'continue_as_guest': 'விருந்தினராக தொடரவும்',

      // Onboarding
      'onboarding_heading': 'உங்களைப் பற்றி கொஞ்சம் சொல்லுங்கள்',
      'your_name_label': 'உங்கள் பெயர் என்ன?',
      'your_name_hint': 'உங்கள் பெயரை உள்ளிடவும்',
      'worker_type_label': 'நீங்கள் என்ன வகையான வேலை செய்கிறீர்கள்?',
      'worker_delivery': '🛵  டெலிவரி ரைடர்',
      'worker_cab': '🚗  கேப் டிரைவர்',
      'worker_other': '💼  இதர கிக் வேலை',
      'btn_get_started': 'தொடங்குங்கள்',

      // Bottom Nav
      'nav_home': 'முகப்பு',
      'nav_log_job': 'வேலை பதிவு',
      'nav_chat': 'அரட்டை',

      // Home
      'greeting': 'வணக்கம்',
      'ai_insight': 'AI நுண்ணறிவு',
      'home_empty': 'இன்னும் வேலைகள் எதுவும் பதிவு செய்யப்படவில்லை - கீழே தட்டி முதல் தொகையைச் சரிபார்க்கவும்',
      'home_insight_placeholder': 'சில வேலைகளைப் பதிவு செய்யுங்கள், உங்கள் முதல் வாராந்திர நுண்ணறிவைத் தயார் செய்வேன்.',
      'home_error': 'தரவுத்தள ஒத்திசைவு சிக்கல். ஆஃப்லைன் தற்காலிக சேமிப்பைப் பயன்படுத்துகிறது.',
      'retry': 'மீண்டும் முயற்சி செய்',
      'stat_earnings': 'வருவாய்',
      'stat_hours': 'மணிநேரம்',
      'stat_flagged': 'கொடியிடப்பட்டது',
      'daily_earnings': 'தினசரி வருவாய்',
      'platform_breakdown': 'தளத்தின் முறிவு',

      // Log Job
      'logjob_subtitle': 'உங்கள் கட்டணத்தை உடனடியாகச் சரிபார்க்க உங்கள் பயணத்தைப் பதிவுசெய்யவும்.',
      'logjob_platform': 'தளம்',
      'logjob_platform_hint': 'தளத்தைத் தேர்ந்தெடுக்கவும்',
      'logjob_fare': 'கட்டணம் (₹)',
      'logjob_fare_hint': 'கட்டண தொகையை உள்ளிடவும்',
      'logjob_fare_required': 'கட்டணம் தேவை',
      'logjob_distance': 'தூரம் (KM)',
      'logjob_distance_hint': 'பயண தூரத்தை உள்ளிடவும்',
      'logjob_distance_required': 'தூரம் தேவை',
      'logjob_duration': 'நேரம் (MIN)',
      'logjob_duration_hint': 'நேரத்தை நிமிடங்களில் உள்ளிடவும்',
      'logjob_duration_required': 'நேரம் தேவை',
      'logjob_positive': 'நேர்மறை எண்ணாக இருக்க வேண்டும்',
      'logjob_positive_decimal': 'நேர்மறை தசமமாக இருக்க வேண்டும்',
      'logjob_btn': 'வேலை பதிவு செய்',
      'logjob_btn_confirm': 'உறுதிசெய்து வேலை பதிவு செய்',
      'logjob_analyzing': 'திரைக்காட்சியை பகுப்பாய்வு செய்கிறது...',
      'logjob_offline': 'ஆஃப்லைன் பயன்முறையில் இயங்குகிறது: வேலை கணக்கீடு வெற்றிகரமாக முடிந்தது!',
      'logjob_offline_note': 'இணைப்பு சிக்கல். ஆஃப்லைன் பயன்முறையைப் பயன்படுத்துகிறது.',

      // Chat
      'chat_title': 'GIGCHAT',
      'chat_subtitle': 'தொழிலாளர் ஊதியம் மற்றும் உரிமைகள் உதவியாளர்',
      'chat_empty_drawer': 'இன்னும் உரையாடல்கள் எதுவும் இல்லை - கீழே தொடங்கவும்',
      'chat_new': '+ புதிய அரட்டை',
      'chat_intro': 'வணக்கம் - உங்கள் ஊதியம், உரிமைகள் அல்லது புகார் அளிப்பது பற்றி எதையும் கேளுங்கள். உங்கள் சமீபத்திய வேலைகளையும் நான் பார்ப்பேன்.',
      'chat_hint': 'உங்கள் கேள்வியை தட்டச்சு செய்யவும்...',
      'chat_disclaimer': 'பொதுவான வழிகாட்டுதல், சட்ட ஆலோசனை அல்ல.',
      'chat_error_loading': 'செய்திகளை ஏற்றுவதில் பிழை.',
      'chat_error_reply': 'பதில் அளிப்பதில் சிக்கல் உள்ளது - ஒரு கணம் கழித்து மீண்டும் முயற்சிக்கவும்.',

      // Quick-reply chips
      'chip_pay_fair': 'எனது ஊதியம் நியாயமானதா?',
      'chip_rights': 'எனது உரிமைகள் என்ன?',
      'chip_complain': 'நான் எப்படி புகார் செய்வது?',

      // Settings / Language picker
      'settings_title': 'அமைப்புகள்',
      'settings_language': 'மொழி',
      'lang_en': 'English',
      'lang_hi': 'हिन्दी (Hindi)',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_ta': 'தமிழ் (Tamil)',
      'lang_te': 'తెలుగు (Telugu)',
      'edit_profile': 'விவரக்குறிப்பை திருத்து',
      'btn_save': 'சேமி',
      'about_gigshield': 'கிக்ஷீல்டு பற்றி',
      'about_desc': 'கிக்ஷீல்டு என்பது இந்தியாவில் ஊதியத்தை சரிபார்ப்பதற்கும் கிக் தொழிலாளர்களின் உரிமைகளை பாதுகாப்பதற்கும் உங்களின் துணையாகும்.',
      'sign_out': 'வெளியேறு',
    },

    // ------------------------------------------------------------------ TELUGU
    // Note: machine-translation pass — review with a fluent speaker before production.
    'te': {
      'app_name': 'GIGSHIELD',
      'tagline': 'సరైన వేతనం, మీ వైపు.',

      // Login
      'login': 'లాగిన్',
      'signup': 'సైన్ అప్',
      'email_address': 'ఇమెయిల్ చిరునామా',
      'password': 'పాస్‌వర్డ్',
      'forgot_password': 'పాస్‌వర్డ్ మర్చిపోయారా?',
      'btn_login': 'లాగిన్ చేయండి',
      'btn_create_account': 'ఖాతాను సృష్టించండి',
      'continue_as_guest': 'అతిథిగా కొనసాగండి',

      // Onboarding
      'onboarding_heading': 'మీ గురించి కొంచెం చెప్పండి',
      'your_name_label': 'మీ పేరు ఏమిటి?',
      'your_name_hint': 'మీ పేరును నమోదు చేయండి',
      'worker_type_label': 'మీరు ఎలాంటి పని చేస్తారు?',
      'worker_delivery': '🛵  డెలివరీ రైడర్',
      'worker_cab': '🚗  క్యాబ్ డ్రైవర్',
      'worker_other': '💼  ఇతర గిగ్ పని',
      'btn_get_started': 'ప్రారంభించండి',

      // Bottom Nav
      'nav_home': 'హోమ్',
      'nav_log_job': 'పని నమోదు',
      'nav_chat': 'చాట్',

      // Home
      'greeting': 'నమస్కారం',
      'ai_insight': 'AI అంతర్దృష్టి',
      'home_empty': 'ఇంకా పనులేవీ నమోదు చేయబడలేదు - కింద నొక్కి మొదటి చెల్లింపును తనిఖీ చేయండి',
      'home_insight_placeholder': 'కొన్ని పనులను నమోదు చేయండి, మీ మొదటి వారపు అంతర్దృష్టిని నేను సిద్ధం చేస్తాను.',
      'home_error': 'డేటాబేస్ సింక్ సమస్య. ఆఫ్‌లైన్ కాష్ ఉపయోగించబడుతోంది.',
      'retry': 'మళ్ళీ ప్రయత్నించు',
      'stat_earnings': 'ఆదాయం',
      'stat_hours': 'గంటలు',
      'stat_flagged': 'ఫ్లాగ్ చేయబడింది',
      'daily_earnings': 'దినసరి ఆదాయం',
      'platform_breakdown': 'ప్లాట్‌ఫారమ్ వివరాలు',

      // Log Job
      'logjob_subtitle': 'మీ పಾವతిని తక్షణమే ధృవీకరించడానికి మీ ప్రయాణాన్ని నమోదు చేయండి.',
      'logjob_platform': 'ప్లాట్‌ఫారమ్',
      'logjob_platform_hint': 'ప్లాట్‌ఫారమ్‌ను ఎంచుకోండి',
      'logjob_fare': 'ఛార్జీ (₹)',
      'logjob_fare_hint': 'ఛార్జీ మొత్తాన్ని నమోదు చేయండి',
      'logjob_fare_required': 'ఛార్జీ అవసరం',
      'logjob_distance': 'దూరం (KM)',
      'logjob_distance_hint': 'ప్రయాణ దూరాన్ని నమోదు చేయండి',
      'logjob_distance_required': 'దూరం అవసరం',
      'logjob_duration': 'సమయం (MIN)',
      'logjob_duration_hint': 'సమయాన్ని నిమిషాలలో నమోదు చేయండి',
      'logjob_duration_required': 'సమయం అవసరం',
      'logjob_positive': 'ధనాత్మక సంఖ్య అయి ఉండాలి',
      'logjob_positive_decimal': 'ధనాత్మక దశాంశం అయి ఉండాలి',
      'logjob_btn': 'పని నమోదు చేయి',
      'logjob_btn_confirm': 'ధృవీకరించి పని నమోదు చేయి',
      'logjob_analyzing': 'స్క్రీన్‌షాట్‌ను విشكలేషిస్తోంది...',
      'logjob_offline': 'ఆఫ్‌లైన్ మోడ్‌లో నడుస్తోంది: పని లెక్కింపు విజయవంతంగా పూర్తయింది!',
      'logjob_offline_note': 'కనెక్షన్ సమస్య. ఆఫ్‌లైన్ మోడ్ ఉపయోగించబడుతోంది.',

      // Chat
      'chat_title': 'GIGCHAT',
      'chat_subtitle': 'కార్మికుల వేతనం & హక్కుల సహాయకుడు',
      'chat_empty_drawer': 'ఇంకా సంభాషణలేవీ లేవు - కింద ప్రారంభించండి',
      'chat_new': '+ కొత్త చాట్',
      'chat_intro': 'నమస్కారం - మీ వేతనం, హక్కులు లేదా ఫిర్యాదు చేయడం గురించి ఏదైనా అడగండి. నేను మీ ఇత్తీచిన పనులను కూడా చూస్తాను.',
      'chat_hint': 'మీ ప్రశ్నను టైప్ చేయండి...',
      'chat_disclaimer': 'సాధారణ మార్గదర్శకత్వం, చట్టపరమైన సలహా కాదు.',
      'chat_error_loading': 'సందేశాలను లోడ్ చేయడంలో లోపం.',
      'chat_error_reply': 'సమాధానం ఇవ్వడంలో సమస్య ఉంది - కాసేపటి తర్వాత మళ్ళీ ప్రయత్నించండి.',

      // Quick-reply chips
      'chip_pay_fair': 'నా వేతనం సరైనదేనా?',
      'chip_rights': 'నా హక్కులు ఏమిటి?',
      'chip_complain': 'నేను ఎలా ఫిర్యాదు చేయాలి?',

      // Settings / Language picker
      'settings_title': 'సెట్టింగులు',
      'settings_language': 'భాష',
      'lang_en': 'English',
      'lang_hi': 'हिन्दी (Hindi)',
      'lang_kn': 'ಕನ್ನಡ (Kannada)',
      'lang_ta': 'தமிழ் (Tamil)',
      'lang_te': 'తెలుగు (Telugu)',
      'edit_profile': 'ప్రొఫైల్ సవరించు',
      'btn_save': 'సేవ్ చేయి',
      'about_gigshield': 'గిగ్‌షీల్డ్ గురించి',
      'about_desc': 'గిగ్‌షీల్డ్ భారతదేశంలో వేతన ధృవీకరణ మరియు గిగ్ కార్మికుల హక్కుల రక్షణ కోసం మీ తోడు.',
      'sign_out': 'సైన్ అవుట్',
    },
  };
}

// ---------------------------------------------------------------------------
// StringsProvider — ChangeNotifier singleton
// Usage:  StringsProvider.instance.t('key')
//         StringsProvider.instance.setLanguage('hi')
// ---------------------------------------------------------------------------
class StringsProvider extends ChangeNotifier {
  StringsProvider._();
  static final StringsProvider instance = StringsProvider._();

  String _lang = 'en';
  String get lang => _lang;

  /// Change language and notify all listeners (triggers full UI rebuild via
  /// ListenableBuilder in main.dart).
  void setLanguage(String code) {
    if (_lang == code) return;
    _lang = code;
    notifyListeners();
  }

  /// Resolve a string key against the current locale.
  /// Falls back to English, then raw key — never crashes, never shows null.
  String t(String key) {
    return AppStrings.all[_lang]?[key] ??
        AppStrings.all['en']?[key] ??
        key;
  }
}
