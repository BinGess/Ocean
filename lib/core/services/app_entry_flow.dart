enum AppEntryStep {
  splash,
  onboarding,
  accountEntry,
  main,
}

class AppEntryFlow {
  const AppEntryFlow._();

  static AppEntryStep visibleStep({
    required bool showSplash,
    required bool showOnboarding,
    required bool showAccountEntry,
  }) {
    if (showSplash) return AppEntryStep.splash;
    if (showOnboarding) return AppEntryStep.onboarding;
    if (showAccountEntry) return AppEntryStep.accountEntry;
    return AppEntryStep.main;
  }

  static bool shouldShowAccountEntry({
    required bool restoredSignedInSession,
    required bool skippedLoginGuide,
    required bool hasLocalDataToProtect,
    required bool dataProtectionPromptShown,
  }) {
    if (restoredSignedInSession) return false;
    if (!skippedLoginGuide) return true;
    return hasLocalDataToProtect && !dataProtectionPromptShown;
  }

  static int nextMainGeneration(int current) => current + 1;
}
