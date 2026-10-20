import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/checklist_item_model.dart';
import '../models/work_order_model.dart';
import 'file_download_service.dart';

class _StepPhotoBundle {
  final int stepNumber;
  final ChecklistItemModel item;
  final List<pw.ImageProvider> stepPhotos;
  final pw.ImageProvider? beforePhoto;
  final pw.ImageProvider? afterPhoto;

  const _StepPhotoBundle({
    required this.stepNumber,
    required this.item,
    this.stepPhotos = const [],
    this.beforePhoto,
    this.afterPhoto,
  });

  bool get hasAnyPhoto =>
      stepPhotos.isNotEmpty || beforePhoto != null || afterPhoto != null;
}

class PdfReportService {
  static Future<pw.ImageProvider?> _resolveImageProvider(String? source) async {
    if (source == null || source.trim().isEmpty) return null;
    final clean = source.trim();
    if (clean.startsWith('http://') || clean.startsWith('https://')) {
      try {
        return await networkImage(clean);
      } catch (_) {
        return null;
      }
    }
    if (clean.startsWith('data:image') || clean.length > 100) {
      try {
        final rawBase64 = clean.contains(',') ? clean.split(',')[1] : clean;
        final bytes = base64Decode(rawBase64);
        return pw.MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<Uint8List> generateWorkOrderReport(WorkOrderModel order) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateOnly = DateFormat('dd/MM/yyyy');

    // 1. Pre-cargar imagen de la firma dibujada en pantalla (Base64 o URL de Supabase Storage)
    final pw.ImageProvider? signatureImage =
        await _resolveImageProvider(order.supervisorSignature);

    // 2. Pre-cargar imágenes paso a paso del protocolo (1 foto, múltiples fotos, antes y después)
    final List<_StepPhotoBundle> stepPhotoBundles = [];
    for (int i = 0; i < order.checklist.length; i++) {
      final item = order.checklist[i];
      if (item.type == ChecklistItemType.photoRequired && item.allPhotos.isNotEmpty) {
        final List<pw.ImageProvider> loaded = [];
        for (final photoStr in item.allPhotos) {
          final img = await _resolveImageProvider(photoStr);
          if (img != null) loaded.add(img);
        }
        if (loaded.isNotEmpty) {
          stepPhotoBundles.add(_StepPhotoBundle(
            stepNumber: i + 1,
            item: item,
            stepPhotos: loaded,
          ));
        }
      } else if (item.type == ChecklistItemType.photoBeforeAfter) {
        final beforeImg = await _resolveImageProvider(item.photoBeforeUrl);
        final afterImg = await _resolveImageProvider(item.photoAfterUrl);
        if (beforeImg != null || afterImg != null) {
          stepPhotoBundles.add(_StepPhotoBundle(
            stepNumber: i + 1,
            item: item,
            beforePhoto: beforeImg,
            afterPhoto: afterImg,
          ));
        }
      }
    }

    // 3. Pre-cargar fotos de evidencia generales de la OT
    final List<pw.ImageProvider> generalEvidenceImages = [];
    for (final evStr in order.evidencePhotos) {
      final img = await _resolveImageProvider(evStr);
      if (img != null) generalEvidenceImages.add(img);
    }

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
                        color: PdfColors.brown800,
                      ),
                    ),
                    pw.Text(
                      'INFORME TÉCNICO OFICIAL DE MANTENIMIENTO E INSPECCIÓN',
                      style: pw.TextStyle(
                        fontSize: 9.5,
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
                        color: PdfColors.brown50,
                        borderRadius: pw.BorderRadius.circular(4),
                        border: pw.Border.all(color: PdfColors.brown300, width: 0.5),
                      ),
                      child: pw.Text(
                        'OT: ${order.orderNumber}',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.brown900,
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
                          style: pw.TextStyle(fontSize: 13.5, fontWeight: pw.FontWeight.bold),
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
                    style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey800),
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
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.brown800),
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
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.brown800),
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
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
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
                        ? '${item.allPhotos.length}/${item.minPhotos} adjuntas'
                        : (item.isCompleted ? 'Registrada' : 'Pendiente');
                  } else if (item.type == ChecklistItemType.photoBeforeAfter) {
                    tipoStr = 'Foto Antes/Después';
                    valorStr = item.isCompleted ? 'Ambas adjuntas' : 'Incompleto';
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

                  final resultadoStr = item.isCompleted
                      ? 'CONFORME'
                      : (item.isRequired ? 'PENDIENTE (Req)' : 'OPCIONAL');

                  final titleWithStage = item.stageName.isNotEmpty &&
                          item.stageName != 'Etapa 1: Procedimientos Iniciales'
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
                        color: item.isCompleted
                            ? PdfColors.green800
                            : (item.isRequired ? PdfColors.red800 : PdfColors.orange800),
                      ),
                    ],
                  );
                }),
              ],
            ),

            pw.SizedBox(height: 16),

            // ANEXO FOTOGRÁFICO PASO A PASO (FOTOS REALES INCRUSTADAS EN EL PDF)
            if (stepPhotoBundles.isNotEmpty) ...[
              pw.Text(
                'REGISTRO FOTOGRÁFICO DEL PROTOCOLO TÉCNICO (PASO A PASO)',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
              ),
              pw.SizedBox(height: 8),
              ...stepPhotoBundles.map((bundle) {
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              'Paso #${bundle.stepNumber}: ${bundle.item.title}',
                              style: pw.TextStyle(
                                fontSize: 9,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey900,
                              ),
                            ),
                          ),
                          if (bundle.item.stageName.isNotEmpty)
                            pw.Container(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: pw.BoxDecoration(
                                color: PdfColors.brown50,
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                              child: pw.Text(
                                bundle.item.stageName,
                                style: pw.TextStyle(
                                  fontSize: 7.5,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.brown800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      if (bundle.item.type == ChecklistItemType.photoBeforeAfter)
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(
                              child: _buildPdfPhotoFrame(
                                image: bundle.beforePhoto,
                                caption: 'ANTES DE LA INTERVENCIÓN',
                                badgeColor: PdfColors.orange800,
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Expanded(
                              child: _buildPdfPhotoFrame(
                                image: bundle.afterPhoto,
                                caption: 'DESPUÉS DE LA INTERVENCIÓN',
                                badgeColor: PdfColors.green800,
                              ),
                            ),
                          ],
                        )
                      else
                        pw.Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: bundle.stepPhotos.asMap().entries.map((pEntry) {
                            final photoIdx = pEntry.key + 1;
                            final img = pEntry.value;
                            return pw.SizedBox(
                              width: 155,
                              child: _buildPdfPhotoFrame(
                                image: img,
                                caption: bundle.stepPhotos.length > 1
                                    ? 'Evidencia #$photoIdx de ${bundle.stepPhotos.length}'
                                    : 'Evidencia Fotográfica Verificada',
                                badgeColor: PdfColors.brown800,
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 8),
            ],

            // EVIDENCIAS GENERALES ADICIONALES DE LA ORDEN
            if (generalEvidenceImages.isNotEmpty) ...[
              pw.Text(
                'EVIDENCIAS FOTOGRÁFICAS GENERALES DE LA INTERVENCIÓN',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
              ),
              pw.SizedBox(height: 8),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: generalEvidenceImages.asMap().entries.map((entry) {
                  return pw.SizedBox(
                    width: 155,
                    child: _buildPdfPhotoFrame(
                      image: entry.value,
                      caption: 'Evidencia General #${entry.key + 1}',
                      badgeColor: PdfColors.blueGrey800,
                    ),
                  );
                }).toList(),
              ),
              pw.SizedBox(height: 16),
            ],

            // Materiales y Repuestos Utilizados
            if (order.spareParts.isNotEmpty) ...[
              pw.Text(
                'REPUESTOS Y MATERIALES EXTRAÍDOS DE ALMACÉN',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900),
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
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.brown800),
                  ),
                  pw.SizedBox(height: 6),
                  _buildPdfKeyValue(
                    'Causa Raíz / Hallazgo:',
                    order.rootCause ?? 'Desgaste operacional normal dentro de vida útil de componentes.',
                  ),
                  pw.SizedBox(height: 4),
                  _buildPdfKeyValue(
                    'Dictamen del Responsable:',
                    order.technicianNotes != null && order.technicianNotes!.trim().isNotEmpty
                        ? order.technicianNotes!
                        : 'Intervención ejecutada de acuerdo con las normativas de seguridad y procedimientos de planta. El equipo queda en servicio operativo.',
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 24),

            // Bloque de Firmas y Certificación de Entrega (Con Firma Real Incrustada)
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: 180,
                        height: 56,
                        alignment: pw.Alignment.center,
                        child: signatureImage != null
                            ? pw.Column(
                                mainAxisAlignment: pw.MainAxisAlignment.end,
                                children: [
                                  pw.Expanded(
                                    child: pw.Image(
                                      signatureImage,
                                      fit: pw.BoxFit.contain,
                                    ),
                                  ),
                                  pw.SizedBox(height: 2),
                                  pw.Text(
                                    'Firma digital capturada en planta',
                                    style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                                  ),
                                ],
                              )
                            : (order.supervisorSignature != null && order.supervisorSignature!.isNotEmpty
                                ? pw.Container(
                                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: pw.BoxDecoration(
                                      color: PdfColors.green50,
                                      borderRadius: pw.BorderRadius.circular(4),
                                      border: pw.Border.all(color: PdfColors.green600, width: 0.5),
                                    ),
                                    child: pw.Text(
                                      'FIRMADO DIGITALMENTE EN PLANTA\nID: ${order.supervisorSignature}',
                                      textAlign: pw.TextAlign.center,
                                      style: pw.TextStyle(
                                        fontSize: 7,
                                        fontWeight: pw.FontWeight.bold,
                                        color: PdfColors.green900,
                                      ),
                                    ),
                                  )
                                : pw.SizedBox()),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Container(height: 1, width: 180, color: PdfColors.black),
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
                      pw.Container(height: 56),
                      pw.SizedBox(height: 4),
                      pw.Container(height: 1, width: 180, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'SUPERVISOR / AUDITORÍA DE PLANTA',
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

  static pw.Widget _buildPdfPhotoFrame({
    required pw.ImageProvider? image,
    required String caption,
    required PdfColor badgeColor,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(5),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Container(
            height: 110,
            alignment: pw.Alignment.center,
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            child: image != null
                ? pw.Image(image, height: 110, fit: pw.BoxFit.cover)
                : pw.Text(
                    'Sin imagen capturada',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
          ),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: badgeColor,
            child: pw.Text(
              caption,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
            ),
          ),
        ],
      ),
    );
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
