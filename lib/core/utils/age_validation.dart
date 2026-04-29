/// Validación de edad a partir de la fecha de nacimiento.
class AgeValidation {
  AgeValidation._();

  /// `true` si cumple al menos [minYears] años a la fecha de hoy.
  static bool isAtLeastYearsOld(DateTime birthDate, int minYears) {
    final today = DateTime.now();
    var age = today.year - birthDate.year;
    final birthdayThisYear = DateTime(
      today.year,
      birthDate.month,
      birthDate.day,
    );
    if (today.isBefore(birthdayThisYear)) {
      age--;
    }
    return age >= minYears;
  }

  /// Último día de nacimiento posible para tener hoy al menos 18 años.
  static DateTime maxBirthDateForMinimumAge(int minYears) {
    final n = DateTime.now();
    return DateTime(n.year - minYears, n.month, n.day);
  }
}
