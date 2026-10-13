import 'package:flutter/foundation.dart' show debugPrint;

/// Single logging choke-point for the app (replaces scattered `debugPrint`
/// calls with inconsistent ad hoc tags).
///
/// Forwards to [debugPrint] deliberately: this project's actual debugging
/// workflow is `adb logcat` against an installed release APK (there is no
/// crash-reporting/remote-logging backend), so logs must stay visible in
/// release and profile builds, not just debug. `debugPrint` also chunks
/// long lines safely for Android's logcat buffer, unlike a raw `print`.
void log(String message) => debugPrint(message);
