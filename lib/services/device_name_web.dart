import 'dart:html' as html;

String currentDeviceName() {
  final ua = html.window.navigator.userAgent;
  if (ua.contains('Edg/')) return 'Edge';
  if (ua.contains('Chrome/') || ua.contains('CriOS/')) return 'Chrome';
  return 'Web';
}
