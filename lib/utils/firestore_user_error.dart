/// Maps Firebase/Firestore failures to short UI strings.
String mapFirestoreUserError(
  Object error, {
  String? code,
  required String fallback,
}) {
  final c = (code ?? _codeFrom(error))?.toLowerCase();
  switch (c) {
    case 'permission-denied':
      return 'You do not have permission to do that.';
    case 'unavailable':
    case 'deadline-exceeded':
      return 'Network error — try again.';
    case 'already-exists':
      return 'That email is already invited.';
    default:
      return fallback;
  }
}

String? _codeFrom(Object error) {
  try {
    final dynamic e = error;
    final code = e.code;
    if (code is String) return code;
  } catch (_) {}
  final s = error.toString().toLowerCase();
  if (s.contains('permission-denied')) return 'permission-denied';
  if (s.contains('unavailable')) return 'unavailable';
  return null;
}
