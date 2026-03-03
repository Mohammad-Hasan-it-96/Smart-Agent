/// Validates a Syrian phone number.
///
/// Rules:
/// - Must contain only digits (after stripping spaces, dashes, parens, +)
/// - Must start with `09` or `963 9` (i.e. country-code form)
/// - Total digit length: 10 digits for local (09...) or 12 for intl (9639...)
///
/// Returns `null` if valid, or an Arabic error message string if invalid.
/// When [required] is `false`, an empty value is accepted.
String? validatePhone(String? value, {bool required = true}) {
  final raw = value?.trim() ?? '';

  // Allow empty when the field is optional
  if (raw.isEmpty) {
    return required ? 'يرجى إدخال رقم الهاتف' : null;
  }

  // Strip non-digit characters
  final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

  // Must be numeric only (after stripping allowed separators)
  if (digits.length != raw.replaceAll(RegExp(r'[\s\-\(\)\+]'), '').length) {
    return 'رقم الهاتف يجب أن يحتوي على أرقام فقط';
  }

  // Length check: 9–12 digits
  if (digits.length < 9 || digits.length > 12) {
    return 'رقم الهاتف يجب أن يكون بين 9 و 12 رقم';
  }

  // Must start with 09 or 9639
  if (!digits.startsWith('09') && !digits.startsWith('9639')) {
    return 'رقم الهاتف يجب أن يبدأ بـ 09 أو 9639';
  }

  return null;
}

