int asInt(dynamic value) {
  if (value is int) return value;
  if (value is BigInt) return value.toInt();
  if (value is num) return value.toInt();
  return int.parse('$value');
}

bool asBool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = '$value'.toLowerCase();
  return text == 'true' || text == 't' || text == '1';
}

bool? parseBool(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final text = value.trim().toLowerCase();
    if (text == 'true' || text == 't' || text == '1') return true;
    if (text == 'false' || text == 'f' || text == '0') return false;
  }
  return null;
}
