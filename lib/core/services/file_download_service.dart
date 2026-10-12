import 'dart:typed_data';
import 'file_download_service_stub.dart'
    if (dart.library.js_interop) 'file_download_service_web.dart'
    if (dart.library.io) 'file_download_service_io.dart';

class FileDownloadService {
  static Future<void> downloadPdf(Uint8List bytes, String filename) async {
    await downloadFileImpl(bytes, filename);
  }
}

