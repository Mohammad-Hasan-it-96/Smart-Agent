import 'package:flutter/foundation.dart';

/// Minimal, zero-dependency debug logger.
///
/// All output is routed through Flutter's [debugPrint], which means:
///   • Active only in debug builds — compiled out in profile/release.
///   • Automatically throttled to prevent log flooding.
///   • Safe to call from any context (no BuildContext needed).
///
/// Levels:
///   [e] — unexpected errors that should never happen in production.
///   [w] — expected-but-notable failures (e.g. network calls that may be
///          retried, optional operations that can be skipped).
///   [d] — informational / diagnostic (only for active development).
///
/// Usage:
/// ```dart
/// AppLogger.e('HomeController', 'load failed', error);
/// AppLogger.w('SettingsController', 'server sync failed', error);
/// ```
class AppLogger {
  AppLogger._(); // not instantiable

  /// Logs an unexpected error.
  static void e(String tag, String message, [Object? error]) {
    debugPrint('❌ [$tag] $message${error != null ? ': $error' : ''}');
  }

  /// Logs a notable but recoverable warning.
  static void w(String tag, String message, [Object? error]) {
    debugPrint('⚠️  [$tag] $message${error != null ? ': $error' : ''}');
  }

  /// Logs a diagnostic / informational message.
  static void d(String tag, String message) {
    debugPrint('🔵 [$tag] $message');
  }
}

