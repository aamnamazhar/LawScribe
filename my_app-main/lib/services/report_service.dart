import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/clause_info.dart';
import 'api_service.dart';

/// Builds a shareable PDF "Contract Analysis Report" for a document, bundling
/// the plain-English summary, a risk overview of detected clauses, and the
/// per-clause insights — all fetched from the existing AI endpoints.
class ReportService {
  // Brand palette (matches the app's gold/purple accents).
  static const _gold = PdfColor.fromInt(0xFFD4AF6A);
  static const _ink = PdfColor.fromInt(0xFF1A1A2E);
  static const _muted = PdfColor.fromInt(0xFF6B6B7B);
  static const _red = PdfColor.fromInt(0xFFD64545);
  static const _amber = PdfColor.fromInt(0xFFD49A2A);
  static const _green = PdfColor.fromInt(0xFF3C9A6A);

  /// Fetch analysis for [docId] and build the report PDF bytes.
  /// Network/build errors propagate to the caller so it can show a message.
  static Future<Uint8List> generateBytes({
    required String docId,
    required String docName,
    String? blockchainTx,
  }) async {
    // Two calls: summary, and insights (which also yields the detected clauses).
    final summary = await ApiService.getSummary(docId);
    final insights = await ApiService.getInsights(docId);

    return _buildPdf(
      docName: docName,
      summary: summary,
      insights: insights,
      docId: docId,
      blockchainTx: blockchainTx,
    );
  }

  /// Safe download filename for a report (e.g. LawScribe_Report_2nd_doc.pdf).
  static String fileName(String docName) {
    final safe = docName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return 'LawScribe_Report_$safe.pdf';
  }

  /// Save the report to the device — opens the system "Save as PDF" dialog,
  /// landing the file in the user's Downloads. The saved file can then be
  /// opened or shared from the device's file manager.
  static Future<void> download(Uint8List bytes, String filename) =>
      Printing.layoutPdf(name: filename, onLayout: (_) async => bytes);

  /// Open the share sheet for the report.
  static Future<void> share(Uint8List bytes, String filename) =>
      Printing.sharePdf(bytes: bytes, filename: filename);

  static PdfColor _riskColor(String risk) {
    switch (risk) {
      case 'high':
        return _red;
      case 'medium':
        return _amber;
      default:
        return _green;
    }
  }

  static Future<Uint8List> _buildPdf({
    required String docName,
    required String summary,
    required List<dynamic> insights,
    required String docId,
    String? blockchainTx,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();
    final generated =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}'
        ' ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Split detected clauses (from insights) into high-risk vs the rest.
    final redFlags = <Map<String, dynamic>>[];
    final others = <Map<String, dynamic>>[];
    for (final i in insights) {
      final type = i['clause_type'] as String;
      final info = clauseInfo[type];
      final entry = {'type': type, 'info': info, 'confidence': i['confidence']};
      if (info?.risk == 'high') {
        redFlags.add(entry);
      } else {
        others.add(entry);
      }
    }

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 44),
          // Embed a full Unicode font so em-dashes, curly quotes, etc. render
          // instead of showing as missing-glyph boxes (the default Helvetica
          // can't draw them).
          theme: pw.ThemeData.withFont(
            base: await PdfGoogleFonts.notoSansRegular(),
            bold: await PdfGoogleFonts.notoSansBold(),
            italic: await PdfGoogleFonts.notoSansItalic(),
            boldItalic: await PdfGoogleFonts.notoSansBoldItalic(),
          ),
        ),
        header: (ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(bottom: 8),
                child: pw.Text('LawScribe — Contract Analysis Report',
                    style: pw.TextStyle(fontSize: 9, color: _muted)),
              ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
              style: pw.TextStyle(fontSize: 9, color: _muted)),
        ),
        build: (ctx) => [
          _titleBlock(docName, generated),
          pw.SizedBox(height: 16),
          _disclaimer(),
          pw.SizedBox(height: 20),
          _sectionTitle('Summary'),
          pw.SizedBox(height: 6),
          pw.Text(summary.trim(),
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 2)),
          pw.SizedBox(height: 20),
          _sectionTitle('Risk overview'),
          pw.SizedBox(height: 6),
          _riskOverview(insights.length, redFlags, others),
          pw.SizedBox(height: 20),
          _sectionTitle('Clause insights'),
          pw.SizedBox(height: 6),
          if (insights.isEmpty)
            pw.Text('No specific clauses were detected in this document.',
                style: pw.TextStyle(fontSize: 11, color: _muted))
          else
            ...insights.map((i) => _insightCard(i)),
          pw.SizedBox(height: 24),
          _verificationBlock(docId, blockchainTx),
        ],
      ),
    );

    return doc.save();
  }

  // ── Building blocks ─────────────────────────────────────────────────────

  static pw.Widget _titleBlock(String docName, String generated) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text('LawScribe',
                style: pw.TextStyle(
                    fontSize: 26, fontWeight: pw.FontWeight.bold, color: _ink)),
            pw.Text('Generated $generated',
                style: pw.TextStyle(fontSize: 9, color: _muted)),
          ],
        ),
        pw.Container(height: 3, width: 60, color: _gold, margin: const pw.EdgeInsets.only(top: 4)),
        pw.SizedBox(height: 12),
        pw.Text('Contract Analysis Report',
            style: pw.TextStyle(fontSize: 15, color: _muted)),
        pw.SizedBox(height: 4),
        pw.Text(docName,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _ink)),
      ],
    );
  }

  static pw.Widget _disclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFFBF6EA),
        border: pw.Border.all(color: _gold, width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Text(
        'This report is AI-generated for informational purposes only and does not '
        'constitute legal advice. Review important contracts with a qualified lawyer.',
        style: pw.TextStyle(fontSize: 9.5, color: _muted, fontStyle: pw.FontStyle.italic),
      ),
    );
  }

  static pw.Widget _sectionTitle(String label) {
    return pw.Row(children: [
      pw.Container(width: 4, height: 16, color: _gold),
      pw.SizedBox(width: 8),
      pw.Text(label,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _ink)),
    ]);
  }

  static pw.Widget _riskOverview(
    int count,
    List<Map<String, dynamic>> redFlags,
    List<Map<String, dynamic>> others,
  ) {
    final verdict = redFlags.isEmpty
        ? 'Looks clean — $count clauses found, nothing high-risk.'
        : 'Found $count clauses — ${redFlags.length} need your attention.';

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(verdict,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
        if (redFlags.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Watch out for:',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _red)),
          pw.SizedBox(height: 4),
          ...redFlags.map((e) => _clauseLine(e, _red)),
        ],
        if (others.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Text('Also found:',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 4),
          ...others.map((e) => _clauseLine(e, _riskColor((e['info'] as ClauseInfo?)?.risk ?? 'low'))),
        ],
      ],
    );
  }

  static pw.Widget _clauseLine(Map<String, dynamic> e, PdfColor dot) {
    final info = e['info'] as ClauseInfo?;
    final name = info?.plainName ?? e['type'] as String;
    final desc = info?.layExplanation ?? '';
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
              width: 7, height: 7, margin: const pw.EdgeInsets.only(top: 3, right: 8),
              decoration: pw.BoxDecoration(color: dot, shape: pw.BoxShape.circle)),
          pw.Expanded(
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                      text: name,
                      style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _ink)),
                  if (desc.isNotEmpty)
                    pw.TextSpan(
                        text: ' — $desc',
                        style: const pw.TextStyle(fontSize: 10.5, color: _muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _insightCard(dynamic i) {
    final type = i['clause_type'] as String;
    final info = clauseInfo[type];
    final name = info?.plainName ?? type;
    final confidence = i['confidence'];
    final body = (i['insight'] as String?)?.trim() ?? '';

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 10),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E2E8), width: 0.5),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Text(name,
                    style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: _ink)),
              ),
              if (confidence != null)
                pw.Text('$confidence% match',
                    style: pw.TextStyle(fontSize: 9, color: _muted)),
            ],
          ),
          if (info != null)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 1),
              child: pw.Text(type, style: pw.TextStyle(fontSize: 8.5, color: _muted)),
            ),
          pw.SizedBox(height: 5),
          // The insight body is a multi-line "What it means / Why it matters /
          // Risk level" block — render each line on its own.
          ...body.split('\n').where((l) => l.trim().isNotEmpty).map(
                (line) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 2),
                  child: pw.Text(line.trim(),
                      style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.5)),
                ),
              ),
        ],
      ),
    );
  }

  static pw.Widget _verificationBlock(String docId, String? blockchainTx) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF4F1FA),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('Document verification',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _ink)),
          pw.SizedBox(height: 4),
          pw.Text('SHA-256: $docId',
              style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
          if (blockchainTx != null && blockchainTx.isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 2),
              child: pw.Text('On-chain tx: $blockchainTx',
                  style: const pw.TextStyle(fontSize: 8.5, color: _muted)),
            ),
        ],
      ),
    );
  }
}
