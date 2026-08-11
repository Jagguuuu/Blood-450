/// In-memory only — resets on every app start and hot restart (Shift+R).
class AppLaunchGate {
  AppLaunchGate._();

  /// True until user finishes or skips onboarding this run.
  static bool showOnboardingAfterSplash = true;

  static void markOnboardingDoneForThisRun() {
    showOnboardingAfterSplash = false;
  }

  static void resetForNewRun() {
    showOnboardingAfterSplash = true;
  }
}
