import 'package:flutter/widgets.dart';

class AppStrings {
  AppStrings(this.languageCode);

  final String languageCode;

  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context).languageCode);

  String text(String key) =>
      (languageCode == 'bn' ? _bangla[key] : null) ?? _english[key] ?? key;

  static const Map<String, String> _english = {
    'bloodRequests': 'Blood Requests',
    'searchDonors': 'Search Donors',
    'findNearby': 'Find Nearby',
    'directRequests': 'Direct Requests',
    'requests': 'Requests',
    'donors': 'Donors',
    'nearby': 'Nearby',
    'direct': 'Direct',
    'notifications': 'Notifications',
    'settings': 'Settings',
    'pushNotifications': 'Push notifications',
    'pushDescription': 'Allow alerts for nearby blood requests',
    'pushNotConfigured': 'Push notifications are not configured on this build',
    'configureOneSignal': 'Configure OneSignal for this app build first.',
    'pushEnabled': 'Push notifications enabled',
    'permissionNotGranted': 'Notification permission was not granted',
    'darkMode': 'Dark mode',
    'darkModeDescription': 'Use a darker appearance throughout the app',
    'language': 'Language',
    'english': 'English',
    'bangla': 'Bangla',
    'aboutBloodLink': 'About BloodLink',
    'aboutDescription': 'Connecting donors with people who need them.',
    'detectingLocation': 'Detecting your location…',
    'locationNeeded': 'Location Needed',
    'tryAgain': 'Try Again',
    'noNearbyDonors': 'No available donors found near you',
    'widerSearch': 'Try the Donors tab to search a wider area',
    'refreshLocation': 'Refresh location',
    'donorsWithinRadius': 'Donors within {radius} km',
    'offlineMode':
        'Offline mode · showing saved donor details. New requests need an internet connection.',
    'signIn': 'Sign In',
    'register': 'Register',
    'verifyOrForgot': 'Verify email or forgot password?',
    'accountRecovery': 'Account recovery',
    'searchArea': 'Filter by location',
    'chooseArea': 'Choose your area',
    'sendRequest': 'Send Direct Request',
    'createAccount': 'Create Account',
    'email': 'Email',
    'password': 'Password',
    'confirmPassword': 'Confirm password',
    'fullName': 'Full Name',
  };

  static const Map<String, String> _bangla = {
    'bloodRequests': 'রক্তের অনুরোধ',
    'searchDonors': 'রক্তদাতা খুঁজুন',
    'findNearby': 'কাছের রক্তদাতা',
    'directRequests': 'সরাসরি অনুরোধ',
    'requests': 'অনুরোধ',
    'donors': 'রক্তদাতা',
    'nearby': 'কাছাকাছি',
    'direct': 'সরাসরি',
    'notifications': 'নোটিফিকেশন',
    'settings': 'সেটিংস',
    'pushNotifications': 'পুশ নোটিফিকেশন',
    'pushDescription': 'কাছের রক্তের অনুরোধের সতর্কতা চালু করুন',
    'pushNotConfigured': 'এই অ্যাপ বিল্ডে পুশ নোটিফিকেশন কনফিগার করা নেই',
    'configureOneSignal': 'আগে এই অ্যাপ বিল্ডের জন্য OneSignal কনফিগার করুন।',
    'pushEnabled': 'পুশ নোটিফিকেশন চালু হয়েছে',
    'permissionNotGranted': 'নোটিফিকেশনের অনুমতি দেওয়া হয়নি',
    'darkMode': 'ডার্ক মোড',
    'darkModeDescription': 'অ্যাপের গাঢ় রঙের থিম ব্যবহার করুন',
    'language': 'ভাষা',
    'english': 'ইংরেজি',
    'bangla': 'বাংলা',
    'aboutBloodLink': 'BloodLink পরিচিতি',
    'aboutDescription':
        'রক্তদাতাদের সঙ্গে রক্তের প্রয়োজন এমন মানুষদের যুক্ত করে।',
    'detectingLocation': 'আপনার অবস্থান শনাক্ত করা হচ্ছে…',
    'locationNeeded': 'লোকেশন প্রয়োজন',
    'tryAgain': 'আবার চেষ্টা করুন',
    'noNearbyDonors': 'কাছাকাছি কোনো উপলভ্য রক্তদাতা পাওয়া যায়নি',
    'widerSearch': 'বিস্তৃত এলাকায় খুঁজতে Donors ট্যাব ব্যবহার করুন',
    'refreshLocation': 'লোকেশন রিফ্রেশ করুন',
    'donorsWithinRadius': '{radius} কিলোমিটারের মধ্যে রক্তদাতা',
    'offlineMode':
        'অফলাইন · সংরক্ষিত রক্তদাতার তথ্য দেখানো হচ্ছে। নতুন অনুরোধে ইন্টারনেট লাগবে।',
    'signIn': 'সাইন ইন',
    'register': 'নিবন্ধন',
    'verifyOrForgot': 'ইমেইল যাচাই বা পাসওয়ার্ড পুনরুদ্ধার',
    'accountRecovery': 'অ্যাকাউন্ট পুনরুদ্ধার',
    'searchArea': 'এলাকা দিয়ে খুঁজুন',
    'chooseArea': 'আপনার এলাকা নির্বাচন করুন',
    'sendRequest': 'সরাসরি অনুরোধ পাঠান',
    'createAccount': 'অ্যাকাউন্ট তৈরি করুন',
    'email': 'ইমেইল',
    'password': 'পাসওয়ার্ড',
    'confirmPassword': 'পাসওয়ার্ড নিশ্চিত করুন',
    'fullName': 'পুরো নাম',
  };
}
