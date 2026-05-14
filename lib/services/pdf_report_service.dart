import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_extended_model.dart';

class PdfReportService {
  static final _dateFormat = DateFormat('dd/MM/yyyy', 'es');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm', 'es');
  static final _timeFormat = DateFormat('HH:mm:ss');

  // ─── Colores corporativos ───────────────────────────────────────────────────
  static const _primaryBlue = PdfColor.fromInt(0xFF1565C0);
  static const _lightBlue = PdfColor.fromInt(0xFFE3F2FD);
  static const _green = PdfColor.fromInt(0xFF2E7D32);
  static const _orange = PdfColor.fromInt(0xFFE65100);
  static const _red = PdfColor.fromInt(0xFFC62828);
  static const _grey100 = PdfColor.fromInt(0xFFF5F5F5);
  static const _grey600 = PdfColor.fromInt(0xFF757575);
  static const _divider = PdfColor.fromInt(0xFFBDBDBD);

  /// Genera y muestra el PDF de un mantenimiento individual.
  static Future<void> printMaintenanceReport({
    required MaintenanceRecordExtended maintenance,
    required String clientName,
    required String equipmentName,
    String? valveName,
    String? componentName,
  }) async {
    final pdf = await _buildMaintenancePdf(
      maintenance: maintenance,
      clientName: clientName,
      equipmentName: equipmentName,
      valveName: valveName,
      componentName: componentName,
    );
    await Printing.layoutPdf(onLayout: (_) async => pdf);
  }

  /// Comparte el PDF de un mantenimiento.
  static Future<void> shareMaintenanceReport({
    required MaintenanceRecordExtended maintenance,
    required String clientName,
    required String equipmentName,
    String? valveName,
    String? componentName,
  }) async {
    final pdf = await _buildMaintenancePdf(
      maintenance: maintenance,
      clientName: clientName,
      equipmentName: equipmentName,
      valveName: valveName,
      componentName: componentName,
    );
    final dateStr = _dateFormat.format(maintenance.dateTime).replaceAll('/', '-');
    final fileName = 'mantencion_${clientName.replaceAll(' ', '_')}_$dateStr.pdf';
    await Printing.sharePdf(bytes: pdf, filename: fileName);
  }

  // ─── Builder principal ──────────────────────────────────────────────────────
  static Future<Uint8List> _buildMaintenancePdf({
    required MaintenanceRecordExtended maintenance,
    required String clientName,
    required String equipmentName,
    String? valveName,
    String? componentName,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(fontBold, maintenance, clientName),
        footer: (context) => _buildFooter(font, context),
        build: (context) => [
          pw.SizedBox(height: 16),
          _buildInfoSection(font, fontBold, maintenance, clientName,
              equipmentName, valveName, componentName),
          pw.SizedBox(height: 12),
          _buildWorkSection(font, fontBold, maintenance),
          if (maintenance.pressureReadings.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _buildPressureSection(font, fontBold, maintenance),
          ],
          if (maintenance.replacements.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _buildReplacementsSection(font, fontBold, maintenance),
          ],
          if (maintenance.nextScheduledMaintenance != null) ...[
            pw.SizedBox(height: 12),
            _buildNextMaintenanceSection(font, fontBold, maintenance),
          ],
          pw.SizedBox(height: 24),
          _buildSignatureSection(font, fontBold, maintenance),
        ],
      ),
    );

    return pdf.save();
  }

  // ─── Encabezado ─────────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
    pw.Font fontBold,
    MaintenanceRecordExtended maintenance,
    String clientName,
  ) {
    final typeColor = _typeColor(maintenance.type);
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: _divider, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('INGETERM',
                  style: pw.TextStyle(
                      font: fontBold,
                      fontSize: 20,
                      color: _primaryBlue)),
              pw.Text('Sistema de Mantención Industrial',
                  style: const pw.TextStyle(fontSize: 9, color: _grey600)),
            ],
          ),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: pw.BoxDecoration(
              color: typeColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(
              '${maintenance.type.emoji} ${maintenance.type.label.toUpperCase()}',
              style: pw.TextStyle(
                  font: fontBold, fontSize: 11, color: PdfColors.white),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Pie de página ───────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(pw.Font font, pw.Context context) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _divider, width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Ingeterm – Mantención Industrial  |  Reporte generado: ${_dateTimeFormat.format(DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 8, color: _grey600),
          ),
          pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(font: font, fontSize: 8, color: _grey600),
          ),
        ],
      ),
    );
  }

  // ─── Información general ─────────────────────────────────────────────────────
  static pw.Widget _buildInfoSection(
    pw.Font font,
    pw.Font fontBold,
    MaintenanceRecordExtended maintenance,
    String clientName,
    String equipmentName,
    String? valveName,
    String? componentName,
  ) {
    return _card(
      fontBold: fontBold,
      title: 'INFORMACIÓN GENERAL',
      color: _lightBlue,
      child: pw.Column(
        children: [
          _infoRow(font, fontBold, 'Fecha', _dateTimeFormat.format(maintenance.dateTime)),
          _infoRow(font, fontBold, 'Cliente', clientName),
          _infoRow(font, fontBold, 'Equipo', equipmentName),
          if (valveName != null) _infoRow(font, fontBold, 'Válvula / Componente', valveName),
          if (componentName != null) _infoRow(font, fontBold, 'Componente', componentName),
          _infoRow(font, fontBold, 'Técnico responsable', maintenance.technicianName),
          if (maintenance.durationHours != null)
            _infoRow(font, fontBold, 'Duración', '${maintenance.durationHours!.toStringAsFixed(1)} horas'),
          if (maintenance.partNumber != null && maintenance.partNumber!.isNotEmpty)
            _infoRow(font, fontBold, 'N° Parte / OT', maintenance.partNumber!),
        ],
      ),
    );
  }

  // ─── Trabajo realizado ───────────────────────────────────────────────────────
  static pw.Widget _buildWorkSection(
    pw.Font font,
    pw.Font fontBold,
    MaintenanceRecordExtended maintenance,
  ) {
    return _card(
      fontBold: fontBold,
      title: 'TRABAJO REALIZADO',
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (maintenance.description.isNotEmpty) ...[
            pw.Text('Descripción',
                style: pw.TextStyle(
                    font: fontBold, fontSize: 10, color: _grey600)),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(
                  color: _grey100,
                  borderRadius:
                      pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Text(maintenance.description,
                  style: pw.TextStyle(font: font, fontSize: 10)),
            ),
            pw.SizedBox(height: 10),
          ],
          if (maintenance.problemsFound.isNotEmpty) ...[
            pw.Text('Problemas encontrados',
                style: pw.TextStyle(
                    font: fontBold, fontSize: 10, color: _red)),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFFFEBEE),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFEF9A9A)),
              ),
              child: pw.Text(maintenance.problemsFound,
                  style: pw.TextStyle(font: font, fontSize: 10)),
            ),
            pw.SizedBox(height: 10),
          ],
          if (maintenance.solutionApplied.isNotEmpty) ...[
            pw.Text('Solución aplicada',
                style: pw.TextStyle(
                    font: fontBold, fontSize: 10, color: _green)),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE8F5E9),
                borderRadius:
                    const pw.BorderRadius.all(pw.Radius.circular(4)),
                border: pw.Border.all(color: const PdfColor.fromInt(0xFFA5D6A7)),
              ),
              child: pw.Text(maintenance.solutionApplied,
                  style: pw.TextStyle(font: font, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Lecturas de presión ─────────────────────────────────────────────────────
  static pw.Widget _buildPressureSection(
    pw.Font font,
    pw.Font fontBold,
    MaintenanceRecordExtended maintenance,
  ) {
    return _card(
      fontBold: fontBold,
      title: 'LECTURAS DE PRESIÓN / PRUEBA HIDROSTÁTICA',
      child: pw.TableHelper.fromTextArray(
        headers: ['#', 'Hora', 'Presión (bar)', 'Temperatura (°C)', 'Observación'],
        data: maintenance.pressureReadings.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          return [
            '${i + 1}',
            _timeFormat.format(r.timestamp),
            r.pressure.toStringAsFixed(2),
            r.temperature != null ? r.temperature!.toStringAsFixed(1) : '-',
            r.label ?? '',
          ];
        }).toList(),
        headerStyle: pw.TextStyle(font: fontBold, fontSize: 9, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: _primaryBlue),
        cellStyle: pw.TextStyle(font: font, fontSize: 9),
        rowDecoration: const pw.BoxDecoration(color: _grey100),
        oddRowDecoration: const pw.BoxDecoration(color: PdfColors.white),
        border: pw.TableBorder.all(color: _divider, width: 0.5),
        cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
    );
  }

  // ─── Reemplazos de componentes ───────────────────────────────────────────────
  static pw.Widget _buildReplacementsSection(
    pw.Font font,
    pw.Font fontBold,
    MaintenanceRecordExtended maintenance,
  ) {
    return _card(
      fontBold: fontBold,
      title: 'COMPONENTES REEMPLAZADOS',
      child: pw.Column(
        children: maintenance.replacements.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          final testColor = r.functionalTest == TestResult.passed
              ? _green
              : r.functionalTest == TestResult.failed
                  ? _red
                  : _orange;
          return pw.Container(
            margin: pw.EdgeInsets.only(bottom: i < maintenance.replacements.length - 1 ? 8 : 0),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _divider),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(r.componentName,
                        style: pw.TextStyle(font: fontBold, fontSize: 11)),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                        color: testColor,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
                      ),
                      child: pw.Text(r.functionalTest.label,
                          style: pw.TextStyle(
                              font: fontBold, fontSize: 9, color: PdfColors.white)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Row(
                  children: [
                    _miniInfo(font, fontBold, 'Serial anterior', r.oldSerialNumber ?? 'No registrado'),
                    pw.SizedBox(width: 16),
                    _miniInfo(font, fontBold, 'Serial nuevo', r.newSerialNumber ?? 'No registrado'),
                    pw.SizedBox(width: 16),
                    _miniInfo(font, fontBold, 'Modelo nuevo', r.newModel),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Text('Razón: ${r.replacementReason}',
                    style: pw.TextStyle(font: font, fontSize: 9, color: _grey600)),
                if (r.notes != null && r.notes!.isNotEmpty)
                  pw.Text('Notas: ${r.notes}',
                      style: pw.TextStyle(font: font, fontSize: 9, color: _grey600)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─── Próxima mantención ──────────────────────────────────────────────────────
  static pw.Widget _buildNextMaintenanceSection(
    pw.Font font,
    pw.Font fontBold,
    MaintenanceRecordExtended maintenance,
  ) {
    final next = maintenance.nextScheduledMaintenance!;
    final daysUntil = next.difference(DateTime.now()).inDays;
    final isOverdue = daysUntil < 0;
    final bgColor = isOverdue
        ? const PdfColor.fromInt(0xFFFFEBEE)
        : const PdfColor.fromInt(0xFFE8F5E9);
    final borderColor = isOverdue
        ? const PdfColor.fromInt(0xFFEF9A9A)
        : const PdfColor.fromInt(0xFFA5D6A7);
    final textColor = isOverdue ? _red : _green;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: bgColor,
        border: pw.Border.all(color: borderColor, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('PRÓXIMA MANTENCIÓN PROGRAMADA',
                  style: pw.TextStyle(font: fontBold, fontSize: 10, color: textColor)),
              pw.SizedBox(height: 4),
              pw.Text(_dateFormat.format(next),
                  style: pw.TextStyle(font: fontBold, fontSize: 14, color: textColor)),
              pw.Text(
                isOverdue
                    ? 'VENCIDA hace ${-daysUntil} días'
                    : 'En $daysUntil días',
                style: pw.TextStyle(font: font, fontSize: 9, color: textColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Firma ───────────────────────────────────────────────────────────────────
  static pw.Widget _buildSignatureSection(
    pw.Font font,
    pw.Font fontBold,
    MaintenanceRecordExtended maintenance,
  ) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        _signatureBox(font, fontBold, 'Firma del Técnico', maintenance.technicianName),
        _signatureBox(font, fontBold, 'V°B° Supervisor', ''),
        _signatureBox(font, fontBold, 'Firma del Cliente', ''),
      ],
    );
  }

  static pw.Widget _signatureBox(
      pw.Font font, pw.Font fontBold, String title, String name) {
    return pw.Container(
      width: 150,
      child: pw.Column(
        children: [
          pw.Container(
            height: 40,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(color: _divider, width: 1)),
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(title,
              style: pw.TextStyle(font: fontBold, fontSize: 9, color: _grey600)),
          if (name.isNotEmpty)
            pw.Text(name,
                style: pw.TextStyle(font: font, fontSize: 8, color: _grey600)),
          pw.Text('Fecha: ___________',
              style: pw.TextStyle(font: font, fontSize: 8, color: _grey600)),
        ],
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────
  static pw.Widget _card({
    required pw.Font fontBold,
    required String title,
    required pw.Widget child,
    PdfColor color = PdfColors.white,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: color,
        border: pw.Border.all(color: _divider, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: const pw.BoxDecoration(
              color: _primaryBlue,
              borderRadius: pw.BorderRadius.only(
                topLeft: pw.Radius.circular(5),
                topRight: pw.Radius.circular(5),
              ),
            ),
            child: pw.Text(title,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 10, color: PdfColors.white)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }

  static pw.Widget _infoRow(
      pw.Font font, pw.Font fontBold, String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 140,
            child: pw.Text(label,
                style: pw.TextStyle(font: fontBold, fontSize: 10, color: _grey600)),
          ),
          pw.Expanded(
            child: pw.Text(value,
                style: pw.TextStyle(font: font, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  static pw.Widget _miniInfo(
      pw.Font font, pw.Font fontBold, String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label,
              style: pw.TextStyle(font: fontBold, fontSize: 8, color: _grey600)),
          pw.Text(value,
              style: pw.TextStyle(font: font, fontSize: 9)),
        ],
      ),
    );
  }

  static PdfColor _typeColor(MaintenanceTypeExtended type) {
    switch (type) {
      case MaintenanceTypeExtended.preventivo:
        return _green;
      case MaintenanceTypeExtended.correctivo:
        return _orange;
      case MaintenanceTypeExtended.urgente:
        return _red;
    }
  }
}
