class OceanAccountInputValidator {
  const OceanAccountInputValidator._();

  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String? validateEmailAndPassword({
    required String email,
    required String password,
  }) {
    final normalizedEmail = email.trim();
    if (!_emailPattern.hasMatch(normalizedEmail)) {
      return '请输入有效的邮箱地址';
    }
    if (password.length < 8) {
      return '密码至少需要 8 位';
    }
    return null;
  }
}
