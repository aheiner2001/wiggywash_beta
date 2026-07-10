import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/utils/firestore_user_error.dart';

void main() {
  test('permission-denied maps clearly', () {
    expect(
      mapFirestoreUserError(
        'ignored',
        code: 'permission-denied',
        fallback: 'Could not add manager.',
      ),
      'You do not have permission to invite managers.',
    );
  });

  test('unavailable maps to network message', () {
    expect(
      mapFirestoreUserError(
        'x',
        code: 'unavailable',
        fallback: 'Could not add manager.',
      ),
      'Network error — try again.',
    );
  });

  test('unknown uses fallback', () {
    expect(
      mapFirestoreUserError(
        'weird',
        code: null,
        fallback: 'Could not add manager.',
      ),
      'Could not add manager.',
    );
  });
}
