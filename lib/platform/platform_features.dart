import 'package:flutter/foundation.dart';

bool get isWeb => kIsWeb;

bool get isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
bool get isWindows =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
bool get isLinux => !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
bool get isMacOs => !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

bool get supportsLocalDb => isWindows || isLinux || isMacOs;
bool get supportsAdsUpload => true;
bool get supportsAdminPush => isAndroid;

String get adminAppType =>
    isAndroid ? 'admin_android' : (isWindows ? 'admin_windows' : 'admin_web');

String get adminDeviceName =>
    isAndroid ? 'Android Admin' : (isWindows ? 'Windows Admin' : 'Admin Web');
