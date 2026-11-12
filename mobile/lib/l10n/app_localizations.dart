/// Translations for OilMitra-Supplier.
///
/// Three languages: English (en), Hindi (hi), Gujarati (gu).
///
/// Usage:
///   import 'package:oil_mitra/l10n/app_localizations.dart';
///   AppLocalizations.of(context).t('home')
///
/// The language is controlled by LanguageService. When it changes, rebuild
/// the affected widgets (HomeShell listens globally).
import 'package:flutter/material.dart';
import '../services/language_service.dart';

/// Translation maps: key -> {languageCode: translation}.
final Map<String, Map<String, String>> _translations = {
  // ---------- Brand ----------
  'app.title': {
    'en': 'OilMitra',
    'hi': 'ऑयलमित्रा',
    'gu': 'ઓઈલમિત્રા',
  },
  'tagline': {
    'en': 'Used oil. Real value.',
    'hi': 'पुराना तेल। असली कीमत।',
    'gu': 'ઉપયોગ કરેલ તેલ। પ્રામાણિક મૂલ્ય।',
  },
  'subtitle': {
    'en':
        'Hotels, restaurants, marriage halls and homes — list your used cooking oil. Our pickup team collects it, and you get paid on the spot.',
    'hi':
        'होटल, रेस्तरां, विवाह घर और घर — अपना इस्तेमाल किया गया खाना पकाने का तेल सूचीबद्ध करें। हमारी पिकअप टीम इसे इकट्ठा करती है, और आपको तुरंत भुगतान मिलता है।',
    'gu':
        'હોટેલ, રેસ્ટોરન્ટ, લગ્ન ઘર અને ઘર — તમારો વપરાયો રસોઈગૃહ તેલ સૂચિબદ્ધ કરો। અમારી પિકઅપ ટીમ તે એકત્ર કરે છે, અને તમને તરત ચૂકવણી મળે છે.',
  },

  // ---------- Login ----------
  'login.language': {
    'en': 'Language',
    'hi': 'भाषा',
    'gu': 'ભાષા',
  },
  'home.benchmark': {
    'en': 'Benchmark',
    'hi': 'बेंचमार्क',
    'gu': 'બેન્ચમાર્ક',
  },
  'home.per_litre': {
    'en': 'litre',
    'hi': 'लीटर',
    'gu': 'લિટર',
  },
  'home.pickup_scheduled': {
    'en': 'Pickup scheduled',
    'hi': 'पिकअप निर्धारित',
    'gu': 'પિકઅપ નિર્ધારિત',
  },
  'home.pickup_completed': {
    'en': 'Pickup completed',
    'hi': 'पिकअप पूरा हुआ',
    'gu': 'પિકઅપ પૂર્ણ',
  },
  'wallet.unit_litres': {
    'en': 'L',
    'hi': 'लीटर',
    'gu': 'લિટર',
  },
  'impact.kept_out': {
    'en': 'kept out of the drain',
    'hi': 'नाली से बाहर रखा गया',
    'gu': 'નાલીમાંથી બહાર રાખવામાં આવ્યું',
  },
  'impact.biodiesel': {
    'en': 'of biodiesel waiting to happen',
    'hi': 'बायोडीजल बनने की प्रतीक्षा कर रहा है',
    'gu': 'બાયોડીઝલ બનવાની રાહ જોઈ રહ્યું છે',
  },
  'listings.oil_radar': {
    'en': 'Oil radar',
    'hi': 'तेल रडार',
    'gu': 'તેલ રડાર',
  },
  'listings.search_all': {
    'en': 'Search every load',
    'hi': 'हर लोड खोजें',
    'gu': 'દરેક લોડ શોધો',
  },
  'listings.no_loads_found': {
    'en': 'No loads found',
    'hi': 'कोई लोड नहीं मिला',
    'gu': 'કોઈ લોડ મળ્યો નથી',
  },
  'listings.radar_clear': {
    'en': 'Radar is clear',
    'hi': 'रडार साफ है',
    'gu': 'રડાર્ સૌફ છે',
  },
  'listings.try_another': {
    'en': 'Try another status or search — or pull down to refresh.',
    'hi': 'दूसरी स्थिति या खोज आज़माएं — या नीचे खींचकर रिफ्रेश करें।',
    'gu': 'અન્ય સ્થિતિ અથવા શોધ પ્રયાસ કરો — અથવા નીચે ખેંચીને રિફ્રેશ કરો.',
  },
  'listings.no_open_matches': {
    'en': 'No open loads match this search. Pull down to refresh.',
    'hi': 'इस खोज से कोई खुला लोड मेल नहीं खाता। नीचे खींचकर रिफ्रेश करें।',
    'gu': 'આ શોધ સાથે કોઈ ખુલ્લો લોડ મેળ ખાતું નથી. નીચે ખેંચીને રિફ્રેશ કરો.',
  },
  'oil.and_other': {
    'en': 'and other oil',
    'hi': 'और अन्य तेल',
    'gu': 'અને અન્ય તેલ',
  },
  'login.tab.login': {
    'en': 'Log in',
    'hi': 'लॉग इन',
    'gu': 'લોગ ઇન',
  },
  'login.tab.create': {
    'en': 'Create account',
    'hi': 'खाता बनाएं',
    'gu': 'ખાતો બનાવો',
  },
  'login.shop_name': {
    'en': 'Shop, hotel or home name',
    'hi': 'दुकान, होटल या घर का नाम',
    'gu': 'દુકાન, હોટેલ અથવા ઘરનું નામ',
  },
  'login.username': {
    'en': 'Username',
    'hi': 'उपयोगकर्ता नाम',
    'gu': 'વપરાશકર્તાનું નામ',
  },
  'login.password': {
    'en': 'Password',
    'hi': 'पासवर्ड',
    'gu': 'પાસવર્ડ',
  },
  'login.create_account': {
    'en': 'Create account',
    'hi': 'खाता बनाएं',
    'gu': 'ખાતો બનાવો',
  },
  'login.log_in': {
    'en': 'Log in',
    'hi': 'लॉग इन',
    'gu': 'લોગ ઇન',
  },
  'login.welcome_back': {
    'en': 'Welcome back — checking today\'s loads.',
    'hi': 'वापस स्वागत है — आज के लोड देख रहे हैं।',
    'gu': 'ફરીથી સ્વાગત છે — આજના લોડ જોવા રહ્યા છે.',
  },
  'login.your_oil': {
    'en': 'Your oil, your rate, your pickup.',
    'hi': 'आपका तेल, आपका दर, आपका पिकअप।',
    'gu': 'તમારો તેલ, તમારો દર, તમારું પિકઅપ.',
  },

  // ---------- Bottom nav ----------
  'nav.home': {
    'en': 'Home',
    'hi': 'होम',
    'gu': 'હોમ',
  },
  'nav.my_oil': {
    'en': 'My oil',
    'hi': 'मेरा तेल',
    'gu': 'મારું તેલ',
  },
  'nav.impact': {
    'en': 'Impact',
    'hi': 'प्रभाव',
    'gu': 'અસર',
  },
  'nav.profile': {
    'en': 'Profile',
    'hi': 'प्रोफाइल',
    'gu': 'પ્રોફાઇલ',
  },

  // ---------- Home screen ----------
  'home.list_oil': {
    'en': 'List oil',
    'hi': 'तेल सूचीबद्ध करें',
    'gu': 'તેલ સૂચિબદ્ધ કરો',
  },
  'home.list_oil_available': {
    'en': 'List oil available',
    'hi': 'उपलब्ध तेल सूचीबद्ध करें',
    'gu': 'ઉપલબ્ધ તેલ સૂચિબદ્ધ કરો',
  },
  'home.open_loads': {
    'en': 'Open loads',
    'hi': 'खुले लोड',
    'gu': 'ખુલ્લા લોડ',
  },
  'home.scheduled': {
    'en': 'Scheduled',
    'hi': 'निर्धारित',
    'gu': 'નિર્ધારિત',
  },
  'home.pickups': {
    'en': 'Pickups',
    'hi': 'पिकअप',
    'gu': 'પિકઅપ',
  },
  'home.rate_board': {
    'en': "Today's rate board",
    'hi': "आज का दर बोर्ड",
    'gu': "આજનું દર બોર્ડ",
  },
  'home.your_oil_section': {
    'en': 'Your oil',
    'hi': 'आपका तेल',
    'gu': 'તમારું તેલ',
  },
  'home.see_all': {
    'en': 'See all',
    'hi': 'सब देखें',
    'gu': 'બધા જુઓ',
  },
  'home.recent_pickups': {
    'en': 'Recent pickups',
    'hi': 'हाल के पिकअप',
    'gu': 'હાલના પિકઅપ',
  },
  'home.oil_ready': {
    'en': 'Oil ready after service?',
    'hi': 'सेवा के बाद तेल तैयार है?',
    'gu': 'સેવા પછી તેલ તૈયાર છે?',
  },
  'home.list_once': {
    'en': 'List it once — our pickup team arranges collection.',
    'hi': 'इसे एक बार सूचीबद्ध करें — हमारी पिकअप टीम संग्रह की व्यवस्था करती है।',
    'gu': 'તે એકવાર સૂચિબદ્ધ કરો — અમારી પિકઅપ ટીમ સંગ્રહની વ્યવસ્થા કરે છે.',
  },
  'home.no_connection': {
    'en': 'No connection',
    'hi': 'कोई कनेक्शन नहीं',
    'gu': 'કોઈ કનેક્શન નથી',
  },
  'home.try_again': {
    'en': 'Try again',
    'hi': 'फिर से कोशिश करें',
    'gu': 'ફરથી પ્રયાસ કરો',
  },

  // ---------- Wallet ----------
  'wallet.title': {
    'en': 'OIL WALLET',
    'hi': 'तेल वॉलेट',
    'gu': 'તેલ વોલેટ',
  },
  'wallet.this_month': {
    'en': 'THIS MONTH',
    'hi': 'इस महीने',
    'gu': 'આ માસ',
  },
  'wallet.earned': {
    'en': 'earned',
    'hi': 'कमाया',
    'gu': 'કમાવ્યું',
  },
  'wallet.collected': {
    'en': 'collected from your kitchen',
    'hi': 'आपकी रसोई से एकत्र किया गया',
    'gu': 'તમારી રસોડેથી એકત્ર કરવામાં આવ્યું',
  },
  'wallet.total_litres': {
    'en': 'Total litres',
    'hi': 'कुल लीटर',
    'gu': 'કુલ લિટર',
  },
  'wallet.co2_avoided': {
    'en': 'CO₂ avoided',
    'hi': 'CO₂ बचाया',
    'gu': 'CO₂ બચાવ્યું',
  },

  // ---------- Listings ----------
  'listings.search_nearby': {
    'en': 'Search oil, area or city',
    'hi': 'तेल, क्षेत्र या शहर खोजें',
    'gu': 'તેલ, વિસ્તાર અથવા શહેર શોધો',
  },
  'listings.search_my': {
    'en': 'Search your loads',
    'hi': 'अपने लोड खोजें',
    'gu': 'તમારા લોડ શોધો',
  },
  'listings.all_loads': {
    'en': 'All loads',
    'hi': 'सभी लोड',
    'gu': 'બધા લોડ',
  },
  'listings.status_all': {
    'en': 'All',
    'hi': 'सभी',
    'gu': 'બધા',
  },
  'listings.no_loads': {
    'en': 'No loads yet',
    'hi': 'अभी तक कोई लोड नहीं',
    'gu': 'હજી સુધી કોઈ લોડ નથી',
  },
  'listings.list_your_oil': {
    'en': 'List your used oil — our pickup team will arrange collection.',
    'hi': 'अपना इस्तेमाल किया गया तेल सूचीबद्ध करें — हमारी पिकअप टीम संग्रह की व्यवस्था करेगी।',
    'gu': 'તમારો વપરાયો તેલ સૂચિબદ્ધ કરો — અમારી પિકઅપ ટીમ સંગ્રહની વ્યવસ્થા કરશે.',
  },

  // ---------- Profile ----------
  'profile.title': {
    'en': 'Profile',
    'hi': 'प्रोफाइल',
    'gu': 'પ્રોફાઇલ',
  },
  'profile.edit_details': {
    'en': 'Edit details',
    'hi': 'विवरण संपादित करें',
    'gu': 'વિવરણ સુધારો',
  },
  'profile.change_photo': {
    'en': 'Change profile photo',
    'hi': 'प्रोफ़ाइल फ़ोटो बदलें',
    'gu': 'પ્રોફાઇલ ફોટો બદલો',
  },
  'profile.server_address': {
    'en': 'Server address',
    'hi': 'सर्वर पता',
    'gu': 'સર્વર સરનામું',
  },
  'profile.rate_board': {
    'en': 'Rate board',
    'hi': 'दर बोर्ड',
    'gu': 'દર બોર્ડ',
  },
  'profile.log_out': {
    'en': 'Log out',
    'hi': 'लॉग आउट',
    'gu': 'લોગ આઉટ',
  },
  'profile.not_signed_in': {
    'en': 'Not signed in',
    'hi': 'साइन इन नहीं किया',
    'gu': 'સાઇન ઇન કરવામાં આવ્યું નથી',
  },
  'profile.litres_saved': {
    'en': 'Litres saved',
    'hi': 'लीटर बचाए गए',
    'gu': 'લિટર બચાવવામાં આવ્યા',
  },
  'profile.earned_label': {
    'en': 'Earned',
    'hi': 'कमाया',
    'gu': 'કમાવ્યું',
  },
  'profile.paid_out': {
    'en': 'Paid out',
    'hi': 'भुगतान किया गया',
    'gu': 'ચુકવણી કરવામાં આવી',
  },

  // ---------- Common ----------
  'common.cancel': {
    'en': 'Cancel',
    'hi': 'रद्द करें',
    'gu': 'રદ્દ કરો',
  },
  'common.save': {
    'en': 'Save',
    'hi': 'सहेजें',
    'gu': 'સેવ કરો',
  },
  'common.ok': {
    'en': 'OK',
    'hi': 'ठीक है',
    'gu': 'ઠીક છે',
  },
  'common.logout_confirm': {
    'en': 'Log out?',
    'hi': 'लॉग आउट करें?',
    'gu': 'લોગ આઉટ કરવું છે?',
  },
  'common.logout_msg': {
    'en': 'Your listings and pickups stay safe on the server.',
    'hi': 'आपकी सूचियां और पिकअप सर्वर पर सुरक्षित रहेंगे।',
    'gu': 'તમારી સૂચિઓ અને પિકઅપ સર્વર પર સુરક્ષિત રહેશે.',
  },
};

/// Provides translations for the current language.
class AppLocalizations {
  final Locale locale;
  const AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    final lang = LanguageService.instance.locale;
    return AppLocalizations(Locale(lang));
  }

  /// Translate a key for the current language. Falls back to English, then
  /// returns the key itself if no translation exists.
  String t(String key) {
    final map = _translations[key];
    if (map == null) return key;
    final code = locale.languageCode;
    if (map.containsKey(code)) return map[code]!;
    return map['en'] ?? key;
  }
}
