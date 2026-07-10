import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/company.dart';
import 'package:wiggywash/utils/manager_invite_logic.dart';

void main() {
  test('active company invite is eligible', () {
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.active,
        companyCreatedByUid: 'owner',
        signedInUid: 'other',
      ),
      isTrue,
    );
  });

  test('pending only eligible for creator', () {
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.pending,
        companyCreatedByUid: 'owner',
        signedInUid: 'owner',
      ),
      isTrue,
    );
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.pending,
        companyCreatedByUid: 'owner',
        signedInUid: 'other',
      ),
      isFalse,
    );
  });

  test('suspended never eligible', () {
    expect(
      isInviteEligible(
        companyStatus: CompanyStatus.suspended,
        companyCreatedByUid: 'owner',
        signedInUid: 'owner',
      ),
      isFalse,
    );
  });

  test('cannot remove last manager', () {
    expect(canRemoveManager(inviteCount: 1), isFalse);
    expect(canRemoveManager(inviteCount: 2), isTrue);
  });

  test('pickClaimTarget: zero / one / many', () {
    expect(pickClaimTarget([]), ClaimPick.none);
    expect(pickClaimTarget(['c1']), ClaimPick.one);
    expect(pickClaimTarget(['c1', 'c2']), ClaimPick.many);
  });
}
