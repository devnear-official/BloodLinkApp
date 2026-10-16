import 'package:flutter/foundation.dart';

import '../core/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool isDarkMode = false;
  String languageCode = 'en';

  Future<void> load() async {
    isDarkMode = await StorageService.instance.getDarkMode();
    languageCode = await StorageService.instance.getLanguage();
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    isDarkMode = enabled;
    notifyListeners();
    await StorageService.instance.saveDarkMode(enabled);
  }

  Future<void> setLanguage(String value) async {
    if (value != 'en' && value != 'bn') {
      throw ArgumentError.value(value, 'value', 'Unsupported language');
    }
    languageCode = value;
    notifyListeners();
    await StorageService.instance.saveLanguage(value);
  }
}
