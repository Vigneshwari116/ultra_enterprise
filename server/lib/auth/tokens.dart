import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 32 random bytes, base64url without padding. This string is the only form
/// returned to the client. Callers must store [sha256Hex] of it, never the token.
String newSessionToken() {
  final bytes = List<int>.generate(32, (_) => Random.secure().nextInt(256));
  return base64Url.encode(bytes).replaceAll('=', '');
}

String sha256Hex(String value) => sha256.convert(utf8.encode(value)).toString();
