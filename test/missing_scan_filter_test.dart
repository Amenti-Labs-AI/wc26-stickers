import 'package:flutter_test/flutter_test.dart';
import 'package:panini_wc26_tracker/ml/missing_scan_filter.dart';
import 'package:panini_wc26_tracker/ml/portrait_text_matcher.dart';

PortraitTextMatch _match(String code, {String team = 'MEX'}) => PortraitTextMatch(
      teamCode: team,
      slotNumber: int.parse(code.replaceAll(RegExp(r'^[A-Z]+'), '')),
      stickerCode: code,
      overlayX: 0.1,
      overlayY: 0.2,
      overlayW: 0.1,
      overlayH: 0.15,
      readX: 0.1,
      readY: 0.2,
      readW: 0.05,
      readH: 0.04,
    );

void main() {
  group('missing_scan_filter', () {
    test('confirmedMissingStickerCodes keeps catalog codes only', () {
      expect(
        confirmedMissingStickerCodes(['MEX4', 'footer', 'mex9']),
        ['MEX4', 'MEX9'],
      );
    });

    test('filterMatchesToTeam keeps only locked team', () {
      final matches = [_match('MEX4'), _match('RSA11', team: 'RSA')];
      final filtered = filterMatchesToTeam(matches, teamCode: 'MEX');
      expect(filtered.map((m) => m.stickerCode), ['MEX4']);
    });

    test('resolveActiveTeamCode locks and switches on unanimous team', () {
      final matcher = PortraitTextMatcher();
      final locked = resolveActiveTeamCode(
        currentTeam: 'MEX',
        matches: [_match('RSA11', team: 'RSA'), _match('RSA13', team: 'RSA')],
        matcher: matcher,
      );
      expect(locked, 'RSA');

      final unchanged = resolveActiveTeamCode(
        currentTeam: 'MEX',
        matches: [_match('MEX4'), _match('RSA11', team: 'RSA')],
        matcher: matcher,
      );
      expect(unchanged, 'MEX');
    });

    test('resolveActiveTeamCode switches when locked team has zero matches', () {
      final matcher = PortraitTextMatcher();
      final switched = resolveActiveTeamCode(
        currentTeam: 'MEX',
        matches: [_match('FWC4', team: 'FWC')],
        matcher: matcher,
      );
      expect(switched, 'FWC');
    });

    test('resolveActiveTeamCode switches when new team dominates', () {
      final matcher = PortraitTextMatcher();
      final switched = resolveActiveTeamCode(
        currentTeam: 'MEX',
        matches: [
          _match('KOR10', team: 'KOR'),
          _match('KOR11', team: 'KOR'),
          _match('MEX4'),
        ],
        matcher: matcher,
      );
      expect(switched, 'KOR');
    });
  });
}
