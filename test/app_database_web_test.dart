import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/data/models/sticker.dart';

void main() {
  test('Sticker.fromCatalogJson normalizes code', () {
    final s = Sticker.fromCatalogJson({
      'code': 'bra14',
      'team_code': 'BRA',
      'team_name': 'Brazil',
      'slot_number': 14,
      'player_name': 'Test',
      'category': 'player',
      'group': 'Group D',
    });
    expect(s.code, 'bra14');
  });
}
