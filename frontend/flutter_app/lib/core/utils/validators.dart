// lib/core/utils/validators.dart

class Validators {
  // Validate Email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  // Validate Password
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  // Validate Name
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters long';
    }
    return null;
  }

  // Validate Pakistani Phone Number
  // Supports: 03001234567, 923001234567, +923001234567, 00923001234567
  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    final cleaned = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final phoneRegExp = RegExp(r'^((\+92)|(92)|(0092)|(0))?3[0-9]{9}$');
    if (!phoneRegExp.hasMatch(cleaned)) {
      return 'Enter a valid Pakistani mobile number (e.g. 03xxxxxxxxx)';
    }
    return null;
  }

  // Validate Positive Integers (e.g. family size, income)
  static String? validatePositiveInteger(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    final number = int.tryParse(value.trim());
    if (number == null || number < 0) {
      return '$fieldName must be a valid positive number';
    }
    return null;
  }
}
