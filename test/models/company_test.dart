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

  test('parses purchasedSeats default 1 when missing', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy',
      'companyCode': 'WIGGY',
      'status': 'active',
    });
    expect(c.purchasedSeats, 1);
  });

  test('parses purchasedSeats', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy',
      'companyCode': 'WIGGY',
      'status': 'active',
      'purchasedSeats': 12,
    });
    expect(c.purchasedSeats, 12);
  });

  test('parses stripe ids and billingStatus', () {
    final c = Company.fromMap('abc', {
      'name': 'Wiggy',
      'companyCode': 'WIGGY',
      'status': 'active',
      'purchasedSeats': 10,
      'stripeCustomerId': 'cus_x',
      'stripeSubscriptionId': 'sub_y',
      'billingStatus': 'ok',
    });
    expect(c.stripeCustomerId, 'cus_x');
    expect(c.stripeSubscriptionId, 'sub_y');
    expect(c.billingStatus, 'ok');
  });
}
