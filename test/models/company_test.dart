import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/company.dart';

void main() {
  test('Company.fromMap parses status and code', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
    });
    expect(c.id, 'abc');
    expect(c.companyCode, 'WIGGY');
    expect(c.status, CompanyStatus.active);
    expect(c.isActive, isTrue);
    expect(c.googleReviewUrl, isNull);
    expect(c.themeId, 'classic');
  });

  test('themeId defaults to classic when missing', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
    });
    expect(c.themeId, 'classic');
  });

  test('unknown themeId falls back to classic', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
      'themeId': 'neon-purple',
    });
    expect(c.themeId, 'classic');
  });

  test('parses forest themeId', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
      'themeId': 'forest',
    });
    expect(c.themeId, 'forest');
  });

  test('Company.fromMap parses googleReviewUrl', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy Wash',
      'companyCode': 'WIGGY',
      'status': 'active',
      'googleReviewUrl': '  https://g.page/r/example  ',
    });
    expect(c.googleReviewUrl, 'https://g.page/r/example');
  });

  test('normalizeCode uppercases and trims', () {
    expect(Company.normalizeCode('  wiggy '), 'WIGGY');
  });
}
