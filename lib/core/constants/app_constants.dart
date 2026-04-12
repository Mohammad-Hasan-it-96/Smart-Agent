/// Central repository for all application-wide constants.
///
/// Rules:
///  - All magic strings used in more than one file MUST live here.
///  - SharedPreferences keys are prefixed with `k` and grouped by domain.
///  - Never import this file into a test fake/mock — use the constant directly.
class AppConstants {
  AppConstants._(); // prevent instantiation

  // ── App Identity ────────────────────────────────────────────────────────────

  /// App name sent to the backend API as `app_name` in every request.
  static const String appName = 'SmartAgent';

  /// Salt appended to ANDROID_ID before SHA-256 hashing for device identity.
  static const String apiSalt = 'smart_agent_app';

  // ── SharedPreferences Keys ──────────────────────────────────────────────────

  /// Set to `true` after the user completes the onboarding flow once.
  static const String kOnboardingCompleted = 'onboarding_completed';

  /// Set to `true` when the user dismisses the home-screen promotional carousel.
  static const String kHideHomeCarousel = 'hide_home_carousel';

  /// Set to `true` to enable gift-quantity fields when creating orders.
  static const String kEnableGifts = 'enable_gifts';

  /// Integer font-size used when generating PDF invoices (default: 12).
  static const String kPdfFontSize = 'pdf_font_size';
}

