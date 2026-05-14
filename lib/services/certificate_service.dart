import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/hydro_test_model.dart';

/// Responsable único de generar y compartir certificados de prueba hidrostática.
///
/// FASE 2: Este archivo será reemplazado por un formato personalizado.
/// No mezcles lógica de certificado en las pantallas.
class CertificateService {
  CertificateService._();

  // ── Punto de entrada público ──────────────────────────────────────────────

  /// Genera el PDF del certificado, lo muestra para compartir/imprimir,
  /// y actualiza Firestore con [certificadoGenerado], [fechaCertificado]
  /// y [numeroCertificado].
  static Future<void> generateAndShare({
    required HydroTest test,
    required String clientId,
    required String equipmentName,
    String? clientName,
  }) async {
    // 1. Asignar número de certificado
    final certNumber =
        test.numeroCertificado ?? _buildCertNumber(test);
    final now = DateTime.now();

    // 2. Actualizar Firestore antes de mostrar el PDF
    await FirebaseFirestore.instance
        .collection('clients')
        .doc(clientId)
        .collection('equipments')
        .doc(test.equipmentId)
        .collection('hydraulicTests')
        .doc(test.id)
        .update({
      'certificadoGenerado': true,
      'fechaCertificado': Timestamp.fromDate(now),
      'numeroCertificado': certNumber,
      'actualizadoEn': FieldValue.serverTimestamp(),
    });

    // 3. Construir documento PDF
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(
            horizontal: 48, vertical: 48),
        build: (pw.Context ctx) => _buildPage(
          test: test,
          equipmentName: equipmentName,
          clientName: clientName,
          certNumber: certNumber,
          emissionDate: now,
        ),
      ),
    );

    // 4. Mostrar diálogo de impresión / compartir (funciona en móvil y web)
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: '$certNumber.pdf',
    );
  }

  // ── Construcción del PDF ──────────────────────────────────────────────────

  static pw.Widget _buildPage({
    required HydroTest test,
    required String equipmentName,
    required String certNumber,
    required DateTime emissionDate,
    String? clientName,
  }) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final testDate = dateFmt.format(test.fechaPrueba);
    final emitDate = dateFmt.format(emissionDate);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        // ── Encabezado ────────────────────────────────────────────────
        _header(certNumber),
        pw.SizedBox(height: 24),

        // ── Datos del equipo ──────────────────────────────────────────
        _sectionTitle('Datos del Equipo'),
        pw.SizedBox(height: 8),
        _table([
          if (clientName != null && clientName.isNotEmpty)
            ['Cliente', clientName],
          ['Equipo', equipmentName],
          ['Fecha de Prueba', testDate],
        ]),
        pw.SizedBox(height: 20),

        // ── Datos de la prueba ────────────────────────────────────────
        _sectionTitle('Datos de la Prueba Hidrostática'),
        pw.SizedBox(height: 8),
        _table([
          if (test.presionPrueba != null)
            [
              'Presión de Prueba (PMTA)',
              '${test.presionPrueba!.toStringAsFixed(2)} ${test.unidadPresion}'
            ],
          if (test.phMultiplier != null)
            [
              'Factor PH/PMTA',
              '${test.phMultiplier!.toStringAsFixed(2)}x'
            ],
          if (test.presionCalculada != null)
            [
              'Presión Hidrostática (PH)',
              '${test.presionCalculada!.toStringAsFixed(2)} ${test.unidadPresion}'
            ],
          if (test.duracionMinutos != null)
            ['Duración de la Prueba', '${test.duracionMinutos} minutos'],
        ]),
        pw.SizedBox(height: 20),

        // ── Resultado (destacado) ─────────────────────────────────────
        _resultBlock(),
        pw.SizedBox(height: 20),

        // ── Observaciones ─────────────────────────────────────────────
        if (test.observaciones != null &&
            test.observaciones!.isNotEmpty) ...[
          _sectionTitle('Observaciones'),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text(test.observaciones!,
                style: const pw.TextStyle(fontSize: 11)),
          ),
          pw.SizedBox(height: 20),
        ],

        // ── Técnico ────────────────────────────────────────────────────
        if (test.tecnicoNombre != null &&
            test.tecnicoNombre!.isNotEmpty) ...[
          _sectionTitle('Responsable'),
          pw.SizedBox(height: 8),
          _table([
            ['Técnico', test.tecnicoNombre!],
          ]),
          pw.SizedBox(height: 20),
        ],

        pw.Spacer(),

        // ── Pie: número y fecha de emisión ────────────────────────────
        _footer(certNumber, emitDate),
      ],
    );
  }

  // ── Bloques de construcción PDF ───────────────────────────────────────────

  static pw.Widget _header(String certNumber) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue800,
        borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'CERTIFICADO DE PRUEBA HIDROSTÁTICA',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            certNumber,
            style: pw.TextStyle(
              color: PdfColors.blue100,
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: const pw.BoxDecoration(
        color: PdfColors.blue50,
        border: pw.Border(
            left: pw.BorderSide(color: PdfColors.blue800, width: 3)),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontWeight: pw.FontWeight.bold,
          fontSize: 12,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  static pw.Widget _table(List<List<String>> rows) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(2),
        1: const pw.FlexColumnWidth(3),
      },
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      children: rows.asMap().entries.map((entry) {
        final isEven = entry.key.isEven;
        final row = entry.value;
        return pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isEven ? PdfColors.grey100 : PdfColors.white,
          ),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: pw.Text(
                row[0],
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold, fontSize: 11),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 6),
              child: pw.Text(row[1],
                  style: const pw.TextStyle(fontSize: 11)),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _resultBlock() {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: PdfColors.green50,
        border: pw.Border.all(color: PdfColors.green800, width: 1.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Text(
            'RESULTADO: ',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
              color: PdfColors.green900,
            ),
          ),
          pw.Text(
            'APROBADO',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 14,
              color: PdfColors.green900,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _footer(String certNumber, String emitDate) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 12),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('N° $certNumber',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
          pw.Text('Fecha de emisión: $emitDate',
              style: const pw.TextStyle(
                  fontSize: 9, color: PdfColors.grey600)),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _buildCertNumber(HydroTest test) {
    final year = test.fechaPrueba.year;
    final seq = test.numeroPrueba != null
        ? test.numeroPrueba!.toString().padLeft(3, '0')
        : DateTime.now().millisecondsSinceEpoch.remainder(10000).toString();
    return 'CERT-$year-$seq';
  }
}
