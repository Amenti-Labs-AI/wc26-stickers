import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Keeps the screen awake during album scanning without a third-party plugin.
///
/// Uses platform channels so we avoid `wakelock_plus` (still applies legacy KGP).
class ScanWakelock {
  ScanWakelock._();

  static const _channel = MethodChannel(
    'com.amentilabs.wc26stickers/wakelock',
  );

  static Future<void> toggle({required bool enable}) async {
    if (kIsWeb) return;
    try {
      await _channel.invokeMethod<void>(enable ? 'enable' : 'disable');
    } catch (e) {
      if (kDebugMode) debugPrint('ScanWakelock toggle failed: $e');
    }
  }
}
