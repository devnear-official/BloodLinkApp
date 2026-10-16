import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bloodlink/providers/favorites_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('favorites persist and reload from local storage', () async {
    SharedPreferences.setMockInitialValues({});
    final favorites = FavoritesProvider();

    await favorites.load();
    expect(favorites.isFavorite('donor-1'), isFalse);

    await favorites.toggle('donor-1');
    expect(favorites.isFavorite('donor-1'), isTrue);

    final restoredFavorites = FavoritesProvider();
    await restoredFavorites.load();
    expect(restoredFavorites.isFavorite('donor-1'), isTrue);

    favorites.dispose();
    restoredFavorites.dispose();
  });
}
