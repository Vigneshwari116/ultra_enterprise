/// Best-effort detection of PostgreSQL unique violations for HTTP 409 responses.
bool isPostgresUniqueViolation(Object error) {
  final text = error.toString().toLowerCase();
  return text.contains('unique') ||
      text.contains('duplicate key') ||
      text.contains('23505');
}
