import '../models/location_access.dart';

bool locationAllowsWrites(LocationAccessStatus status) =>
    status == LocationAccessStatus.active ||
    status == LocationAccessStatus.trial ||
    status == LocationAccessStatus.comp;

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

/// Only paid `active` locations consume a seat (trial/comp/read_only do not).
int seatsUsed(Iterable<LocationAccessStatus> statuses) =>
    statuses.where((s) => s == LocationAccessStatus.active).length;

bool canActivateAnother({
  required int purchasedSeats,
  required int seatsUsed,
}) =>
    seatsUsed < purchasedSeats;

bool isOverAllocated({
  required int purchasedSeats,
  required int seatsUsed,
}) =>
    seatsUsed > purchasedSeats;
