import 'dart:typed_data';
import 'package:printing/printing.dart';

Future<void> downloadFileImpl(Uint8List bytes, String filename) async {
  await Printing.sharePdf(bytes: bytes, filename: filename);
}

void downloadUrlImpl(String url, String filename) {}

