import 'package:flutter_test/flutter_test.dart';
import 'package:app/i18n/strings.dart';

void main() {
  test('AppStrings localization translation check', () {
    final s = StringsProvider.instance;
    s.setLanguage('en');
    expect(s.t('app_name'), 'GIGLY');
    expect(s.t('tagline'), 'Fair pay, on your side.');
  });
}
