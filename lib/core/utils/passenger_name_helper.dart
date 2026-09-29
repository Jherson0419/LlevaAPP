/// Deriva el primer nombre desde `profiles.full_name` (p. ej. "Adriana Rodríguez Castillo" → "Adriana").
String passengerFirstNameFromFullName(String? fullName) {
  final t = (fullName ?? '').trim();
  if (t.isEmpty) return '';
  final parts = t.split(RegExp(r'\s+'));
  return parts.isEmpty ? '' : parts.first;
}
