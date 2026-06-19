import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:panini_wc26_tracker/features/scan_page/scan_page_session.dart';
import 'package:panini_wc26_tracker/ml/ocr_speed.dart';

import '../test/helpers/portrait_ocr_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Portrait OCR — MEX', () {
    late ScanPageSession session;

    setUp(() async {
      session = await createOcrSession();
      session.resetTeamLock();
    });

    tearDown(() => session.dispose());

    testWidgets('page_8 full half-page', (tester) async {
      final page = await loadMexHalfPage(8);
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page8ExpectedMissing);
    });

    testWidgets('page_9 full half-page', (tester) async {
      final page = await loadMexHalfPage(9);
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page9ExpectedMissing);
    });

    testWidgets('page_8 zoom MEX4 slot', (tester) async {
      final full = await loadMexHalfPage(8);
      final crop = cropForSlot(full, 'MEX4');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'MEX4'}, forbidden: {'MEX5'});
    });

    testWidgets('page_8 zoom MEX5 slot', (tester) async {
      final full = await loadMexHalfPage(8);
      final crop = cropForSlot(full, 'MEX5');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'MEX5'});
    });

    testWidgets('page_9 zoom MEX11 slot', (tester) async {
      final full = await loadMexHalfPage(9);
      final crop = cropForSlot(full, 'MEX11');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'MEX11'});
    });

    testWidgets('page_9 zoom MEX13 slot', (tester) async {
      final full = await loadMexHalfPage(9);
      final crop = cropForSlot(full, 'MEX13');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'MEX13'});
    });

    testWidgets('page_8 grayscale', (tester) async {
      final page = toGrayscale(await loadMexHalfPage(8));
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page8ExpectedMissing);
    });

    testWidgets('page_9 grayscale', (tester) async {
      final page = toGrayscale(await loadMexHalfPage(9));
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page9ExpectedMissing);
    });
  });

  group('Portrait OCR — QAT', () {
    late ScanPageSession session;

    setUp(() async {
      session = await createOcrSession();
      session.resetTeamLock();
    });

    tearDown(() => session.dispose());

    testWidgets('page_20 full half-page', (tester) async {
      final page = await loadTrainPage(20);
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page20ExpectedMissing);
    });

    testWidgets('page_21 full half-page', (tester) async {
      final page = await loadTrainPage(21);
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page21ExpectedMissing);
    });

    testWidgets('page_20 zoom QAT3 slot', (tester) async {
      session.lockTeam(qatTeamCode);
      final full = await loadTrainPage(20);
      final crop = cropForSlot(full, 'QAT3');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'QAT3'});
    });

    testWidgets('page_20 zoom QAT8 slot', (tester) async {
      session.lockTeam(qatTeamCode);
      final full = await loadTrainPage(20);
      final crop = cropForSlot(full, 'QAT8');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'QAT8'});
    });

    testWidgets('page_21 zoom QAT11 slot', (tester) async {
      session.lockTeam(qatTeamCode);
      final full = await loadTrainPage(21);
      final crop = cropForSlot(full, 'QAT11');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'QAT11'});
    });

    testWidgets('page_21 zoom QAT14 slot', (tester) async {
      session.lockTeam(qatTeamCode);
      final full = await loadTrainPage(21);
      final crop = cropForSlot(full, 'QAT14');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'QAT14'});
    });

    testWidgets('page_20 grayscale', (tester) async {
      final page = toGrayscale(await loadTrainPage(20));
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page20ExpectedMissing);
    });

    testWidgets('page_21 grayscale', (tester) async {
      final page = toGrayscale(await loadTrainPage(21));
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page21ExpectedMissing);
    });
  });

  group('Portrait OCR — FWC', () {
    late ScanPageSession session;

    setUp(() async {
      session = await createOcrSession();
      session.resetTeamLock();
      session.lockTeam(fwcTeamCode);
    });

    tearDown(() => session.dispose());

    testWidgets('page_1 full spread', (tester) async {
      final page = await loadFwcPage1();
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page1FwcExpectedMissing);
    });

    testWidgets('page_1 zoom FWC4 landscape', (tester) async {
      // Pre-cropped from train page_1 slot bbox — landscape label not readable
      // from full-spread norm crops on this fixture.
      final crop = await loadFwc4ZoomCrop();
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'FWC4'});
    });

    testWidgets('page_1 zoom FWC1 portrait', (tester) async {
      final full = await loadFwcPage1();
      final crop = cropForSlot(full, 'FWC1');
      final result = await scanStill(session, crop, speed: OcrSpeed.crop);
      expectContainsCodes(result, {'FWC1'});
    });

    testWidgets('page_1 grayscale', (tester) async {
      final page = toGrayscale(await loadFwcPage1());
      final result = await scanStill(session, page, speed: OcrSpeed.standard);
      expectExactCodes(result, page1FwcExpectedMissing);
    });
  });

  group('Portrait OCR — team lock on page turn', () {
    testWidgets('MEX page_8 then QAT page_20 switches team', (tester) async {
      final session = await createOcrSession();
      addTearDown(session.dispose);

      final mex = await loadMexHalfPage(8);
      final mexResult = await scanStill(session, mex, speed: OcrSpeed.standard);
      expectExactCodes(mexResult, page8ExpectedMissing);
      expect(mexResult.teamSwitched, isFalse);
      expect(session.activeTeamCode, mexTeamCode);

      final qat = await loadTrainPage(20);
      final qatResult = await scanStill(session, qat, speed: OcrSpeed.standard);
      expect(qatResult.teamSwitched, isTrue);
      expect(session.activeTeamCode, qatTeamCode);
      expectExactCodes(qatResult, page20ExpectedMissing);
      for (final code in page8ExpectedMissing) {
        expect(qatResult.missingCodes, isNot(contains(code)));
      }
    });
  });
}
