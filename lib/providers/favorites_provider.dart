import 'package:flutter/foundation.dart';

import '../core/services/storage_service.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> donorIds = {};

  Future<void> load() async {
    donorIds
      ..clear()
      ..addAll(await StorageService.instance.getFavoriteDonorIds());
    notifyListeners();
  }

  bool isFavorite(String donorId) => donorIds.contains(donorId);

  Future<void> toggle(String donorId) async {
    if (!donorIds.add(donorId)) donorIds.remove(donorId);
    await StorageService.instance.saveFavoriteDonorIds(donorIds);
    notifyListeners();
  }
}
