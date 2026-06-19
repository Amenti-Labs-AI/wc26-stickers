import 'package:flutter/foundation.dart';

/// True on iOS/Android (including emulators). False on desktop.
bool get isMobileScanSupported =>
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android);
