import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:driver/core/interceptors/header_interceptor.dart';
import 'package:driver/core/preferences/shared_preference_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('updates auth token before returning and makes it available via getAuthorization', () async {
    SharedPreferences.setMockInitialValues({});

    final prefs = await SharedPreferences.getInstance();
    final manager = SharedPreferenceManager(prefs);
    final interceptor = HeaderInterceptor(manager);

    await interceptor.updateAuthToken('test-token');

    expect(manager.getAuthorization(), isNotNull);
    expect(manager.getAuthorization(), isNotEmpty);
    expect(manager.hasAuthorizationToken(), isTrue);
  });
}
