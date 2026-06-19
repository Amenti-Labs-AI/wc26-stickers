import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'page_template_matcher.dart';

/// Page template loaded from JSON assets.
class PageTemplate {
  PageTemplate({
    required this.id,
    required this.teamCode,
    required this.teamName,
    required this.slots,
  });

  factory PageTemplate.fromJson(Map<String, dynamic> json) {
    final slotsJson = json['slots'] as List<dynamic>;
    return PageTemplate(
      id: json['id'] as String,
      teamCode: json['team_code'] as String,
      teamName: json['team_name'] as String,
      slots: slotsJson
          .map((s) => TemplateSlot.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  final String id;
  final String teamCode;
  final String teamName;
  final List<TemplateSlot> slots;
}

class TemplateSlot {
  TemplateSlot({
    required this.index,
    required this.stickerCode,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  factory TemplateSlot.fromJson(Map<String, dynamic> json) => TemplateSlot(
        index: json['index'] as int,
        stickerCode: json['sticker_code'] as String,
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        w: (json['w'] as num).toDouble(),
        h: (json['h'] as num).toDouble(),
      );

  final int index;
  final String stickerCode;
  final double x;
  final double y;
  final double w;
  final double h;
}

/// Shared template catalog and ML Kit OCR backend for scan pipelines.
///
/// Live Scan uses [PortraitOcrScanner] via [ScanPageSession]; see `docs/ml/strategy.md`.
class PageScanService {
  PageScanService({PageTemplateMatcher? matcher})
      : _matcher = matcher ?? PageTemplateMatcher();

  final PageTemplateMatcher _matcher;
  List<PageTemplate>? _templates;
  bool _disposed = false;

  List<PageTemplate> get templates => List.unmodifiable(_templates ?? []);

  PageTemplateMatcher get matcher => _matcher;

  Future<void> initialize() async {
    _templates = await _loadTemplates();
    _matcher.registerTemplates(_templates ?? []);
  }

  /// Unit tests: inject templates without loading assets.
  @visibleForTesting
  void bindForTest({required List<PageTemplate> templates}) {
    _templates = templates;
    _matcher.registerTemplates(templates);
  }

  Future<List<PageTemplate>> _loadTemplates() async {
    final paths = await _listTemplateAssetPaths();
    final templates = <PageTemplate>[];
    for (final path in paths) {
      final raw = await rootBundle.loadString(path);
      templates.add(PageTemplate.fromJson(jsonDecode(raw) as Map<String, dynamic>));
    }
    return templates;
  }

  Future<List<String>> _listTemplateAssetPaths() async {
    try {
      final indexRaw = await rootBundle.loadString('assets/page_templates/index.json');
      final index = jsonDecode(indexRaw) as Map<String, dynamic>;
      return (index['templates'] as List<dynamic>).cast<String>();
    } catch (_) {
      // Fallback for older Flutter asset manifest formats.
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest
          .listAssets()
          .where(
            (k) =>
                k.startsWith('assets/page_templates/') &&
                k.endsWith('.json') &&
                !k.endsWith('index.json') &&
                !k.endsWith('schema.json'),
          )
          .toList();
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _matcher.dispose();
  }
}
