import '../models/location_access.dart';

bool locationAllowsWrites(LocationAccessStatus status) =>
    status == LocationAccessStatus.active || status == LocationAccessStatus.trial;

LocationAccessStatus effectiveAccess(
  LocationAccessStatus status, {
  DateTime? trialEndsAt,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  if (status == LocationAccessStatus.trial &&
      trialEndsAt != null &&
      !trialEndsAt.isAfter(n)) {
    return LocationAccessStatus.readOnly;
  }
  return status;
}

int seatsUsed(Iterable<LocationAccessStatus> statuses) =>
    statuses.where(locationAllowsWrites).length;

bool canActivateAnother({
  required int purchasedSeats,
  required int seatsUsed,
}) =>
    seatsUsed < purchasedSeats;
