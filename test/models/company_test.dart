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
