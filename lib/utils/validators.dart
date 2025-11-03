// lib/utils/validators.dart
// Common form validators (returns null when valid — suitable for TextFormField.validator)

String? validateRequired(String? value, {String fieldName = 'This field'}) {
  if (value == null || value.trim().isEmpty) {
    return '$fieldName is required';
  }
  return null;
}

String? validateEmail(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email is required';
  final email = value.trim();
  // simple email regex (covers typical cases)
  final reg = RegExp(r"^[\w-\.]+@([\w-]+\.)+[\w-]{2,}$");
  if (!reg.hasMatch(email)) return 'Enter a valid email';
  return null;
}

/// Password rules:
/// - at least 6 characters (adjust per your security needs)
String? validatePassword(String? value, {int minLen = 6}) {
  if (value == null || value.isEmpty) return 'Password is required';
  if (value.length < minLen) return 'Password must be at least $minLen characters';
  return null;
}

/// Confirm password validator — pass original password as `original`
String? validateConfirmPassword(String? value, String original) {
  if (value == null || value.isEmpty) return 'Please confirm password';
  if (value != original) return 'Passwords do not match';
  return null;
}

/// Validate that a numeric amount is present and positive
String? validateAmount(String? value) {
  if (value == null || value.trim().isEmpty) return 'Amount is required';
  final cleaned = value.replaceAll(',', '').trim();
  final parsed = double.tryParse(cleaned);
  if (parsed == null) return 'Enter a valid number';
  if (parsed <= 0) return 'Amount must be greater than zero';
  return null;
}

/// Optional: validate a display name (not just spaces, and length limit)
String? validateDisplayName(String? value, {int min = 2, int max = 40}) {
  if (value == null || value.trim().isEmpty) return 'Name is required';
  final t = value.trim();
  if (t.length < min) return 'Name should be at least $min characters';
  if (t.length > max) return 'Name is too long';
  return null;
}
