import 'dart:io';

String currentDeviceName() {
  if (Platform.isAndroid) return 'Android';
  if (Platform.isWindows) return 'Windows desktop';
  if (Platform.isIOS) return 'iOS';
  if (Platform.isMacOS) return 'macOS desktop';
  if (Platform.isLinux) return 'Linux desktop';
  return 'Desktop';
}
