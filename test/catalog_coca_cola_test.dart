import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog has 12 US Coca-Cola stickers with correct CC5–CC12', () {
    final raw = File('assets/catalog/wc26_catalog.json').readAsStringSync();
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final cc = (data['stickers'] as List)
        .cast<Map<String, dynamic>>()
        .where((s) => s['category'] == 'coca_cola')
        .toList()
      ..sort((a, b) =>
          (a['slot_number'] as int).compareTo(b['slot_number'] as int));

    expect(data['total_stickers'], 992);
    expect(cc.length, 12);
    expect(cc.map((s) => s['code']).toList(), [
      'CC1',
      'CC2',
      'CC3',
      'CC4',
      'CC5',
      'CC6',
      'CC7',
      'CC8',
      'CC9',
      'CC10',
      'CC11',
      'CC12',
    ]);
    expect(cc[4]['player_name'], 'Antonee Robinson');
    expect(cc[4]['team_name'], 'USA');
    expect(cc[11]['player_name'], 'Gabriel Magalhães');
  });
}
