import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:panini_wc26_tracker/ml/page_scan_service.dart';
import 'package:panini_wc26_tracker/ml/page_template_matcher.dart';

void main() {
  group('PageTemplateMatcher.matchFromText', () {
    test('matches team code in header text', () {
      final m = PageTemplateMatcher();
      m.registerTemplates([
        _template('team_spread_bra', 'BRA', 'Brazil'),
        _template('team_spread_usa', 'USA', 'United States'),
      ]);
      expect(m.matchFromText('GROUP D  BRAZIL'), 'team_spread_bra');
      expect(m.matchFromText('USA squad'), 'team_spread_usa');
    });

    test('matches team name over generic FIFA header', () {
      final m = PageTemplateMatcher();
      m.registerTemplates([
        _template('team_spread_hai', 'HAI', 'Haiti'),
        _template('fwc_intro', 'FWC', 'FIFA World Cup'),
      ]);
      expect(m.matchFromText('FIFA WORLD CUP 2026  HAITI'), 'team_spread_hai');
      expect(m.matchFromText('FIFA WORLD CUP 2026'), isNull);
      expect(m.matchFromText('FWC INTRO'), 'fwc_intro');
    });

    test('matches team name', () {
      final m = PageTemplateMatcher();
      m.registerTemplates([
        _template('team_spread_mex', 'MEX', 'Mexico'),
      ]);
      expect(m.matchFromText('FIFA WORLD CUP  MEXICO'), 'team_spread_mex');
    });

    test('detect ignores FWC OCR when only team spreads are allowed', () async {
      final m = PageTemplateMatcher();
      m.registerTemplates([
        _template('team_spread_bra', 'BRA', 'Brazil'),
        _template('fwc_intro', 'FWC', 'FIFA World Cup'),
      ]);
      final page = img.Image(width: 400, height: 600);
      img.fill(page, color: img.ColorRgb8(40, 40, 40));
      final bytes = Uint8List.fromList(img.encodeJpg(page));
      await expectLater(
        m.detect(bytes, [_template('team_spread_bra', 'BRA', 'Brazil')]),
        completes,
      );
    });
  });
}

PageTemplate _template(String id, String code, String name) => PageTemplate(
      id: id,
      teamCode: code,
      teamName: name,
      slots: [],
    );
