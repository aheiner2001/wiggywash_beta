import 'package:flutter_test/flutter_test.dart';
import 'package:wiggywash/models/request_preset.dart';

void main() {
  test('RequestPreset.fromMap parses fields', () {
    final p = RequestPreset.fromMap('p1', {
      'label': 'Out of soap',
      'sortOrder': 2,
      'createdByUid': 'u1',
    });
    expect(p.id, 'p1');
    expect(p.label, 'Out of soap');
    expect(p.sortOrder, 2);
    expect(p.createdByUid, 'u1');
  });

  test('toMap includes label and sortOrder', () {
    const p = RequestPreset(id: 'p1', label: 'Need towels', sortOrder: 0);
    final m = p.toMap();
    expect(m['label'], 'Need towels');
    expect(m['sortOrder'], 0);
  });
}
