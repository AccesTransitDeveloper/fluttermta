import 'package:driver/core/preferences/shared_preference_manager.dart';
import 'package:driver/models/responses/auth/entity_detail_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferenceManager manager;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    manager = SharedPreferenceManager(await SharedPreferences.getInstance());
  });

  test('existing accounts without a pending signup are not redirected', () async {
    await manager.setEntity(Entity(id: 'test-account', type: 3));
    expect(manager.hasPendingHostedOnboarding, isFalse);
  });

  test('pending account is isolated from a different signed-in driver', () async {
    await manager.requireHostedOnboarding('test-account-a');
    await manager.setEntity(Entity(id: 'test-account-b', type: 3));
    expect(manager.hasPendingHostedOnboarding, isFalse);
    await manager.setEntity(Entity(id: 'test-account-a', type: 3));
    expect(manager.hasPendingHostedOnboarding, isTrue);
  });

  test('confirmed CRM ID does not replace the operational account ID', () async {
    await manager.setEntity(Entity(id: 'test-account', type: 3));
    await manager.requireHostedOnboarding('test-account');
    await manager.setLanguage('es');
    await manager.completeHostedOnboarding('test-account', 'test-crm-application');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('hosted_onboarding_crm_test-account'), 'test-crm-application');
    expect(manager.getEntity()?.id, 'test-account');
    expect(manager.getLanguage(), 'es');
    expect(manager.hasPendingHostedOnboarding, isFalse);
  });

  test('completion for a different account does not clear pending registration', () async {
    await manager.setEntity(Entity(id: 'test-account-a', type: 3));
    await manager.requireHostedOnboarding('test-account-a');
    await manager.completeHostedOnboarding('test-account-b', 'test-crm-b');
    expect(manager.hasPendingHostedOnboarding, isTrue);
  });

  test('signup without a fetched profile resumes only for its email', () async {
    await manager.requireHostedOnboardingForSignup(email: 'NEW@example.invalid');
    expect(manager.getEntity(), isNull);
    expect(manager.hasPendingHostedOnboarding, isFalse);
    await manager.setEntity(Entity(id: 'other-account', email: 'other@example.invalid', type: 3));
    expect(manager.hasPendingHostedOnboarding, isFalse);
    await manager.setEntity(Entity(id: 'new-account', email: 'new@example.invalid', type: 3));
    expect(manager.hasPendingHostedOnboarding, isTrue);
    await manager.requireHostedOnboarding('new-account');
    await manager.completeHostedOnboarding('new-account', 'test-crm-new');
    expect(manager.hasPendingHostedOnboarding, isFalse);
  });

  test('phone signup resumes for the matching account after sign-in', () async {
    await manager.requireHostedOnboardingForSignup(phone: '5550000000');
    await manager.setEntity(Entity(id: 'new-account', phone: '5550000000', type: 3));
    expect(manager.hasPendingHostedOnboarding, isTrue);
  });
}