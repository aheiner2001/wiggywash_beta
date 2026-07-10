import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/manager_invite.dart';

void main() {
  test('normalizeEmail trims and lowercases', () {
    expect(ManagerInvite.normalizeEmail('  Pat@Gmail.COM '), 'pat@gmail.com');
  });

  test('normalizeEmail returns empty for blank', () {
    expect(ManagerInvite.normalizeEmail('   '), '');
  });

  test('fromMap parses fields', () {
    final m = ManagerInvite.fromMap('inv1', {
      'email': 'a@b.com',
      'displayName': 'Alex',
      'invitedByUid': 'u1',
      'invitedByEmail': 'boss@b.com',
      'claimedUid': 'u2',
    }, companyId: 'c1');
    expect(m.id, 'inv1');
    expect(m.companyId, 'c1');
    expect(m.email, 'a@b.com');
    expect(m.displayName, 'Alex');
    expect(m.claimedUid, 'u2');
    expect(m.isClaimed, isTrue);
  });
}
