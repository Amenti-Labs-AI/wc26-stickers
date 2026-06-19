import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;

import 'page_scan_service.dart';
import 'scan_thresholds.dart';
import '../core/oriented_image.dart';
import 'ocr_speed.dart';
import 'ocr_text_line.dart';
import 'template_ocr.dart';

/// Detects which album page template is in view via header OCR and slot scoring.
class PageTemplateMatcher {
  PageTemplateMatcher({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  TextRecognizer get textRecognizer => _recognizer;

  final Map<String, String> _nameToTemplateId = {};
  final Map<String, String> _codeToTemplateId = {};

  void registerTemplates(List<PageTemplate> templates) {
    _nameToTemplateId.clear();
    _codeToTemplateId.clear();
    for (final t in templates) {
      _codeToTemplateId[t.teamCode.toUpperCase()] = t.id;
      _nameToTemplateId[t.teamName.toUpperCase()] = t.id;
      if (t.teamCode == 'USA') {
        _nameToTemplateId['UNITED STATES'] = t.id;
        _nameToTemplateId['UNITED STATES OF AMERICA'] = t.id;
      }
      if (t.teamCode == 'KOR') {
        _nameToTemplateId['SOUTH KOREA'] = t.id;
        _nameToTemplateId['KOREA REPUBLIC'] = t.id;
      }
      if (t.teamCode == 'CZE') {
        _nameToTemplateId['CZECHIA'] = t.id;
        _nameToTemplateId['CZECH REPUBLIC'] = t.id;
      }
      if (t.teamCode == 'CUW') {
        _nameToTemplateId['CURACAO'] = t.id;
        _nameToTemplateId['CURAÇAO'] = t.id;
      }
    }
    _codeToTemplateId['FWC'] = 'fwc_intro';
  }

  /// Match template id from OCR text on the page header.
  String? matchFromText(String text) {
    final upper = text.toUpperCase();

    // 1. Team codes (longest first to avoid partial matches).
    final codes = _codeToTemplateId.keys.where((c) => c != 'FWC').toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final code in codes) {
      if (_containsToken(upper, code)) return _codeToTemplateId[code];
    }

    // 2. Team names (longest first; skip generic FWC label).
    final names = _nameToTemplateId.keys
        .where((n) => n != 'FIFA WORLD CUP')
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final name in names) {
      if (upper.contains(name)) return _nameToTemplateId[name];
    }

    // 3. FWC intro section — require explicit FWC token (not generic FIFA header).
    if (_containsToken(upper, 'FWC')) {
      return _codeToTemplateId['FWC'];
    }
    return null;
  }

  bool _containsToken(String upper, String token) {
    var start = 0;
    while (true) {
      final i = upper.indexOf(token, start);
      if (i == -1) return false;
      final before = i == 0 ? ' ' : upper[i - 1];
      final afterIdx = i + token.length;
      final after = afterIdx >= upper.length ? ' ' : upper[afterIdx];
      final beforeOk = !RegExp(r'[A-Z0-9]').hasMatch(before);
      final afterOk = !RegExp(r'[A-Z0-9]').hasMatch(after);
      if (beforeOk && afterOk) return true;
      start = i + 1;
    }
  }

  /// Match team spread from header-region OCR lines (no extra ML Kit call).
  PageTemplate? matchTemplateFromHeaderLines(
    List<OcrTextLine> lines,
    List<PageTemplate> templates, {
    double headerMaxY = 0.28,
  }) {
    if (templates.isEmpty || lines.isEmpty) return null;

    final headerText = lines
        .where((l) => l.centerY < headerMaxY)
        .map((l) => l.text)
        .join('\n');
    if (headerText.trim().isEmpty) return null;

    final id = matchFromText(headerText);
    if (id == null) return null;
    for (final t in templates) {
      if (t.id == id) return t;
    }
    return null;
  }

  /// Header crop OCR on an already-decoded page (avoids re-encoding full frame).
  Future<PageTemplate?> matchTemplateFromHeaderCrop(
    img.Image page,
    List<PageTemplate> templates, {
    OcrSpeed ocrSpeed = OcrSpeed.standard,
  }) async {
    if (templates.isEmpty || page.width <= 0 || page.height <= 0) {
      return null;
    }

    final headerH = (page.height * 0.28).round().clamp(1, page.height);
    final header = img.copyCrop(
      page,
      x: 0,
      y: 0,
      width: page.width,
      height: headerH,
    );

    try {
      final text = await ocrHeaderText(_recognizer, header, speed: ocrSpeed);
      if (text == null || text.trim().isEmpty) return null;
      final id = matchFromText(text);
      if (id == null) return null;
      for (final t in templates) {
        if (t.id == id) return t;
      }
    } catch (_) {}
    return null;
  }

  /// Header OCR only — no slot-variance fallback (all team grids share layout).
  Future<PageTemplateMatch?> detectHeaderOcr(
    Uint8List imageBytes,
    List<PageTemplate> templates,
  ) async {
    if (templates.isEmpty) return null;

    final decoded = decodeOrientedJpeg(imageBytes) ?? img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final headerH = (decoded.height * 0.28).round().clamp(1, decoded.height);
    final header = img.copyCrop(decoded, x: 0, y: 0, width: decoded.width, height: headerH);

    try {
      final text = await ocrHeaderText(_recognizer, header);
      if (text == null) return null;
      final fromOcr = matchFromText(text);
      if (fromOcr == null) return null;
      for (final t in templates) {
        if (t.id == fromOcr) {
          return PageTemplateMatch(
            template: t,
            confidence: ScanThresholds.ocrMatchConfidence,
            method: 'ocr',
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Full detection: OCR header, then slot-variance fallback across templates.
  Future<PageTemplateMatch?> detect(
    Uint8List imageBytes,
    List<PageTemplate> templates,
  ) async {
    if (templates.isEmpty) return null;

    final decoded = decodeOrientedJpeg(imageBytes) ?? img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final headerH = (decoded.height * 0.28).round().clamp(1, decoded.height);
    final header = img.copyCrop(decoded, x: 0, y: 0, width: decoded.width, height: headerH);

    try {
      final text = await ocrHeaderText(_recognizer, header);
      if (text != null) {
        final fromOcr = matchFromText(text);
        if (fromOcr != null) {
          PageTemplate? template;
          for (final t in templates) {
            if (t.id == fromOcr) {
              template = t;
              break;
            }
          }
          if (template != null) {
            return PageTemplateMatch(
              template: template,
              confidence: ScanThresholds.ocrMatchConfidence,
              method: 'ocr',
            );
          }
        }
      }
    } catch (_) {
      // OCR failed — fall through to slot scoring.
    }

    PageTemplate? best;
    double bestScore = 0;
    double secondScore = 0;
    for (final template in templates) {
      final score = _scoreTemplate(decoded, template);
      if (score > bestScore) {
        secondScore = bestScore;
        bestScore = score;
        best = template;
      } else if (score > secondScore) {
        secondScore = score;
      }
    }
    if (best == null || bestScore < ScanThresholds.templateDetectMin) return null;
    if (bestScore - secondScore < 0.02 &&
        bestScore < ScanThresholds.templateDetectAmbiguous) {
      return null;
    }
    return PageTemplateMatch(
      template: best,
      confidence: bestScore,
      method: 'slots',
    );
  }

  /// Weaker match for manual / fallback scanning when strict detect fails.
  Future<PageTemplateMatch?> bestGuess(
    Uint8List imageBytes,
    List<PageTemplate> templates,
  ) async {
    if (templates.isEmpty) return null;
    final decoded = decodeOrientedJpeg(imageBytes) ?? img.decodeImage(imageBytes);
    if (decoded == null) return null;

    PageTemplate? best;
    double bestScore = 0;
    for (final template in templates) {
      final score = _scoreTemplate(decoded, template);
      if (score > bestScore) {
        bestScore = score;
        best = template;
      }
    }
    if (best == null || bestScore < ScanThresholds.templateWeakMin) return null;
    return PageTemplateMatch(
      template: best,
      confidence: bestScore,
      method: 'weak',
    );
  }

  double _scoreTemplate(img.Image page, PageTemplate template) {
    var clear = 0;
    for (final slot in template.slots) {
      final x = (slot.x * page.width).round().clamp(0, page.width - 1);
      final y = (slot.y * page.height).round().clamp(0, page.height - 1);
      final w = (slot.w * page.width).round().clamp(1, page.width);
      final h = (slot.h * page.height).round().clamp(1, page.height);
      final variance = _slotVariance(page, x, y, w, h);
      if (variance > 200 || variance < 80) clear++;
    }
    return clear / template.slots.length;
  }

  double _slotVariance(img.Image page, int x, int y, int w, int h) {
    final x2 = (x + w).clamp(0, page.width);
    final y2 = (y + h).clamp(0, page.height);
    double sum = 0, sumSq = 0;
    var count = 0;
    for (var py = y; py < y2; py += 3) {
      for (var px = x; px < x2; px += 3) {
        final p = page.getPixel(px, py);
        final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        sum += lum;
        sumSq += lum * lum;
        count++;
      }
    }
    if (count == 0) return 0;
    final mean = sum / count;
    return (sumSq / count) - mean * mean;
  }

  void dispose() => _recognizer.close();
}

class PageTemplateMatch {
  const PageTemplateMatch({
    required this.template,
    required this.confidence,
    required this.method,
  });

  final PageTemplate template;
  final double confidence;
  final String method;
}
