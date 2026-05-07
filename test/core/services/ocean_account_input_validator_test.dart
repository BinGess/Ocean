import 'package:flutter_test/flutter_test.dart';
import 'package:mindflow/core/services/ocean_account_input_validator.dart';

void main() {
  group('OceanAccountInputValidator', () {
    test('rejects invalid email before sending auth request', () {
      expect(
        OceanAccountInputValidator.validateEmailAndPassword(
          email: 'not-an-email',
          password: '12345678',
        ),
        '请输入有效的邮箱地址',
      );
    });

    test('rejects password shorter than 8 characters', () {
      expect(
        OceanAccountInputValidator.validateEmailAndPassword(
          email: 'user@example.com',
          password: '1234567',
        ),
        '密码至少需要 8 位',
      );
    });

    test('accepts valid email and password', () {
      expect(
        OceanAccountInputValidator.validateEmailAndPassword(
          email: 'user@example.com',
          password: '12345678',
        ),
        isNull,
      );
    });
  });
}
