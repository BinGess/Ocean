import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/app_entry_flow.dart';

void main() {
  test('shows onboarding before account entry when both are pending', () {
    expect(
      AppEntryFlow.visibleStep(
        showSplash: false,
        showOnboarding: true,
        showAccountEntry: true,
      ),
      AppEntryStep.onboarding,
    );
  });

  test('shows account entry after onboarding is complete', () {
    expect(
      AppEntryFlow.visibleStep(
        showSplash: false,
        showOnboarding: false,
        showAccountEntry: true,
      ),
      AppEntryStep.accountEntry,
    );
  });

  test('bumps main navigation generation after account data changes', () {
    expect(AppEntryFlow.nextMainGeneration(0), 1);
    expect(AppEntryFlow.nextMainGeneration(4), 5);
  });

  test('does not show account entry when a signed-in session is restored', () {
    expect(
      AppEntryFlow.shouldShowAccountEntry(
        restoredSignedInSession: true,
        skippedLoginGuide: false,
        hasLocalDataToProtect: true,
        dataProtectionPromptShown: false,
      ),
      isFalse,
    );
  });

  test('shows account entry when login guide has not been skipped', () {
    expect(
      AppEntryFlow.shouldShowAccountEntry(
        restoredSignedInSession: false,
        skippedLoginGuide: false,
        hasLocalDataToProtect: false,
        dataProtectionPromptShown: false,
      ),
      isTrue,
    );
  });

  test('shows data protection prompt once for skipped users with local data',
      () {
    expect(
      AppEntryFlow.shouldShowAccountEntry(
        restoredSignedInSession: false,
        skippedLoginGuide: true,
        hasLocalDataToProtect: true,
        dataProtectionPromptShown: false,
      ),
      isTrue,
    );
    expect(
      AppEntryFlow.shouldShowAccountEntry(
        restoredSignedInSession: false,
        skippedLoginGuide: true,
        hasLocalDataToProtect: true,
        dataProtectionPromptShown: true,
      ),
      isFalse,
    );
  });
}
