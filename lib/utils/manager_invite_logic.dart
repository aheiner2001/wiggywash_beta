import '../models/company.dart';

enum ClaimPick { none, one, many }

bool isInviteEligible({
  required CompanyStatus companyStatus,
  required String? companyCreatedByUid,
  required String signedInUid,
}) {
  switch (companyStatus) {
    case CompanyStatus.active:
      return true;
    case CompanyStatus.pending:
      return companyCreatedByUid != null &&
          companyCreatedByUid == signedInUid;
    case CompanyStatus.suspended:
      return false;
  }
}

bool canRemoveManager({required int inviteCount}) => inviteCount > 1;

ClaimPick pickClaimTarget(List<String> eligibleCompanyIds) {
  if (eligibleCompanyIds.isEmpty) return ClaimPick.none;
  if (eligibleCompanyIds.length == 1) return ClaimPick.one;
  return ClaimPick.many;
}
