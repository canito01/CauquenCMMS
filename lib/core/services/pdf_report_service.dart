import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/checklist_item_model.dart';
import '../models/work_order_model.dart';
import 'file_download_service.dart';

class PdfReportService {
  static Future<Uint8List> generateWorkOrderReport(WorkOrderModel order) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnly = DateFormat('dd/MM/yyyy');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CAUQUÉN CMMS - GESTIÓN INDUSTRIAL',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'INFORME TÉCNICO OFICIAL DE MANTENIMIENTO',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.blue100,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text(
                        'OT: ${order.orderNumber}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Emisión: ${dateFormat.format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
        footer: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Cauquén CMMS • Documento válido para entrega y auditoría técnica de planta',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
                pw.Text(
                  'Página ${context.pageNumber} de ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                ),
              ],
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 12),

            // Título de la Orden
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          order.title,
                          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: pw.BoxDecoration(
                          color: order.status == WorkOrderStatus.finalizada
                              ? PdfColors.green100
                              : PdfColors.orange100,
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        child: pw.Text(
                          order.status.name.toUpperCase(),
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: order.status == WorkOrderStatus.finalizada
                                ? PdfColors.green900
                                : PdfColors.orange900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    order.description,
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 14),

            // Grilla de Datos Técnicos y Activo
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Columna 1: Activo y Planta
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'DATOS DEL ACTIVO / MÁQUINA',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                        ),
                        pw.SizedBox(height: 6),
                        _buildPdfKeyValue('Código Activo:', order.asset.code),
                        _buildPdfKeyValue('Nombre:', order.asset.name),
                        _buildPdfKeyValue('Ubicación:', order.asset.location),
                        _buildPdfKeyValue('Criticidad:', order.asset.criticality),
                        _buildPdfKeyValue('Tipo Mantenimiento:', order.type.name.toUpperCase()),
                        _buildPdfKeyValue('Prioridad:', order.priority.name.toUpperCase()),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 12),
                // Columna 2: Cuadrilla y Tiempos
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'PERSONAL & TIEMPOS DE INTERVENCIÓN',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                        ),
                        pw.SizedBox(height: 6),
                        _buildPdfKeyValue('Responsable:', order.technicianName),
                        _buildPdfKeyValue('Legajo:', order.technicianBadge),
                        _buildPdfKeyValue('Cuadrilla Asignada:', order.assignedCrew ?? 'Cuadrilla de Planta'),
                        _buildPdfKeyValue('Fecha Programada:', dateOnly.format(order.scheduledDate)),
                        _buildPdfKeyValue(
                          'Inicio Real:',
                          order.startedAt != null ? dateFormat.format(order.startedAt!) : 'Sin registro',
                        ),
                        _buildPdfKeyValue(
                          'Finalización Real:',
                          order.completedAt != null ? dateFormat.format(order.completedAt!) : 'En ejecución',
                        ),
                        _buildPdfKeyValue(
                          'Tiempo Total Empleado:',
                          '${order.elapsedMinutes} min (${(order.elapsedMinutes / 60).toStringAsFixed(1)} hs)',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            pw.SizedBox(height: 16),

            // Protocolo Paso a Paso Ejecutado
            pw.Text(
              'PROTOCOLO Y TAREAS PASO A PASO EJECUTADAS',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            ),
            pw.SizedBox(height: 6),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(0.8),
                1: const pw.FlexColumnWidth(4.5),
                2: const pw.FlexColumnWidth(1.8),
                3: const pw.FlexColumnWidth(2.0),
                4: const pw.FlexColumnWidth(1.5),
              },
              children: [
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  children: [
                    _buildTableHeader('#'),
                    _buildTableHeader('Procedimiento / Tarea Técnica'),
                    _buildTableHeader('Tipo Paso'),
                    _buildTableHeader('Medición / Valor'),
                    _buildTableHeader('Resultado'),
                  ],
                ),
                ...order.checklist.asMap().entries.map((entry) {
                  final idx = entry.key + 1;
                  final item = entry.value;

                  String tipoStr = 'Inspección';
                  String valorStr = '-';
                  if (item.type == ChecklistItemType.numericMeasurement) {
                    tipoStr = 'Medición';
                    valorStr = item.numericValue != null
                        ? '${item.numericValue} ${item.unit ?? ""}'
                        : 'Nominal (${item.minAcceptable ?? ""}-${item.maxAcceptable ?? ""} ${item.unit ?? ""})';
                  } else if (item.type == ChecklistItemType.photoRequired) {
                    tipoStr = item.minPhotos > 1 ? 'Fotos (${item.minPhotos})' : 'Foto';
                    valorStr = item.allPhotos.isNotEmpty
                        ? '${item.allPhotos.length}/${item.minPhotos} registradas'
                        : (item.isCompleted ? 'Registrada' : 'Pendiente');
                  } else if (item.type == ChecklistItemType.photoBeforeAfter) {
                    tipoStr = 'Foto Antes/Después';
                    valorStr = item.isCompleted ? 'Ambas registradas' : 'Incompleto';
                  } else if (item.type == ChecklistItemType.textObservation) {
                    tipoStr = 'Observación';
                    valorStr = item.textValue ?? '-';
                  } else if (item.type == ChecklistItemType.singleChoice) {
                    tipoStr = 'Selección';
                    valorStr = item.selectedOption ?? '-';
                  } else if (item.type == ChecklistItemType.multipleChoice) {
                    tipoStr = 'Múltiple';
                    valorStr = item.selectedOptions.isNotEmpty ? item.selectedOptions.join(', ') : '-';
                  }

                  final resultadoStr = item.isCompleted ? 'CONFORME' : (item.isRequired ? 'PENDIENTE (Req)' : 'OPCIONAL');

                  final titleWithStage = item.stageName.isNotEmpty && item.stageName != 'Etapa 1: Procedimientos Iniciales'
                      ? '[${item.stageName}]\n${item.title}'
                      : item.title;

                  return pw.TableRow(
                    children: [
                      _buildTableCell(idx.toString(), align: pw.TextAlign.center),
                      _buildTableCell(titleWithStage),
                      _buildTableCell(tipoStr, align: pw.TextAlign.center),
                      _buildTableCell(valorStr, align: pw.TextAlign.center),
                      _buildTableCell(
                        resultadoStr,
                        align: pw.TextAlign.center,
                        isBold: true,
                        color: item.isCompleted ? PdfColors.green800 : (item.isRequired ? PdfColors.red800 : PdfColors.orange800),
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 16),

            // Materiales y Repuestos Utilizados
            if (order.spareParts.isNotEmpty) ...[
              pw.Text(
                'REPUESTOS Y MATERIALES EXTRAÍDOS DE ALMACÉN',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FlexColumnWidth(2.0),
                  1: const pw.FlexColumnWidth(4.5),
                  2: const pw.FlexColumnWidth(1.5),
                  3: const pw.FlexColumnWidth(3.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                    children: [
                      _buildTableHeader('Código Repuesto'),
                      _buildTableHeader('Descripción del Material'),
                      _buildTableHeader('Cantidad'),
                      _buildTableHeader('Ubicación Almacén'),
                    ],
                  ),
                  ...order.spareParts.map((part) {
                    final qty = part.consumedQuantity > 0 ? part.consumedQuantity : 1;
                    return pw.TableRow(
                      children: [
                        _buildTableCell(part.code, isBold: true),
                        _buildTableCell(part.description),
                        _buildTableCell('$qty ${part.unit}', align: pw.TextAlign.center),
                        _buildTableCell(part.locationWarehouse),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 16),
            ],

            // Diagnóstico y Observaciones Técnicas
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DIAGNÓSTICO TÉCNICO Y OBSERVACIONES DE CIERRE',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800),
                  ),
                  pw.SizedBox(height: 6),
                  _buildPdfKeyValue(
                    'Causa Raíz / Hallazgo:',
                    order.rootCause ?? 'Desgaste operacional normal dentro de vida útil de componentes.',
                  ),
                  pw.SizedBox(height: 4),
                  _buildPdfKeyValue(
                    'Dictamen del Responsable:',
                    order.technicianNotes ??
                        'Intervención ejecutada de acuerdo con las normativas de seguridad y procedimientos de planta. El equipo queda en servicio 100% operativo sin observaciones.',
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 28),

            // Bloque de Firmas y Certificación de Entrega
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 170,
                        height: 40,
                        alignment: pw.Alignment.center,
                        child: order.supervisorSignature != null && order.supervisorSignature!.isNotEmpty
                            ? pw.Text('FIRMADO DIGITALMENTE EN PLANTA', style: const pw.TextStyle(fontSize: 8, color: PdfColors.blue800))
                            : pw.SizedBox(),
                      ),
                      pw.Container(height: 1, width: 170, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'TÉCNICO / LÍDER INTERVINIENTE',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${order.technicianName} (${order.technicianBadge})',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 30),
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Container(height: 40),
                      pw.Container(height: 1, width: 170, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'SUPERVISOR / CONFORMIDAD EMPRESA',
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'Firma, Sello y Recepción Conforme',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static Future<String> downloadOrPrintReport(WorkOrderModel order) async {
    final pdfBytes = await generateWorkOrderReport(order);
    final filename = 'Informe_Mantenimiento_${order.orderNumber}.pdf';
    await FileDownloadService.downloadPdf(pdfBytes, filename);
    return filename;
  }

  static pw.Widget _buildPdfKeyValue(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              key,
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableHeader(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  static pw.Widget _buildTableCell(
    String text, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isBold = false,
    PdfColor color = PdfColors.black,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 7.5,
          fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
        textAlign: align,
      ),
    );
  }
}
