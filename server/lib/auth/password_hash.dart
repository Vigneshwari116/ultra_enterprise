import 'dart:convert';

import 'package:hashlib/hashlib.dart';

/// Bcrypt ($2b$) via hashlib, which is pure Dart and allows Dart 3.5.4.
///
/// Published `dbcrypt` 2.0.0 declares `sdk: ">=2.12.0-0 <3.0.0"`, so
/// `dart pub get` fails in the `dart:3.5.4` image used by server/Dockerfile.
const int passwordBcryptCost = 10;

/// bcrypt uses the first 72 bytes of the password.
const int passwordMaxBytes = 72;

String hashPassword(String password) {
  return bcrypt(
    utf8.encode(password),
    bcryptSalt(nb: passwordBcryptCost),
  );
}

bool verifyPassword(String password, String encoded) {
  try {
    return bcryptVerify(encoded, utf8.encode(password));
  } catch (_) {
    return false;
  }
}

int passwordByteLength(String password) => utf8.encode(password).length;
