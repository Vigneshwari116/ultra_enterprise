import 'dart:io';

import 'package:shelf/shelf.dart';

/// First `X-Forwarded-For` value, then `X-Real-IP`, then the socket address.
String clientIp(Request request) {
  final forwarded = request.headers['x-forwarded-for'];
  if (forwarded != null && forwarded.trim().isNotEmpty) {
    final first = forwarded.split(',').first.trim();
    if (first.isNotEmpty) return first;
  }
  final real = request.headers['x-real-ip'];
  if (real != null && real.trim().isNotEmpty) return real.trim();
  final info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) {
    final address = info.remoteAddress.address.trim();
    if (address.isNotEmpty) return address;
  }
  return '';
}
