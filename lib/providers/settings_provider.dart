import 'package:flutter/foundation.dart';

import '../core/services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  bool isDarkMode = false;

  Future<void> load() async {
    isDarkMode = await StorageService.instance.getDarkMode();
    notifyListeners();
  }

  Future<void> setDarkMode(bool enabled) async {
    isDarkMode = enabled;
    notifyListeners();
    await StorageService.instance.saveDarkMode(enabled);
  }
}
