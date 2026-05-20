// lib/core/services/file_upload_service.dart

import 'dart:convert';
import 'api_service.dart';
import '../constants/api_constants.dart';

class FileUploadService {
  final ApiService _apiService;

  FileUploadService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  // Upload spreadsheet and yield progress events line-by-line
  Stream<Map<String, dynamic>> uploadSpreadsheet({
    required List<int> fileBytes,
    required String fileName,
  }) async* {
    try {
      final streamedResponse = await _apiService.sendMultipart(
        ApiConstants.submitSpreadsheet,
        fileBytes: fileBytes,
        fileName: fileName,
      );

      if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        // Stream lines from the response body
        final lineStream = streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter());

        await for (final line in lineStream) {
          if (line.trim().isNotEmpty) {
            try {
              final parsed = jsonDecode(line);
              yield parsed;
            } catch (_) {
              yield {
                'status': 'error',
                'error': 'Failed to parse progress update: $line',
              };
            }
          }
        }
      } else {
        // Handle error responses directly if stream fails to start
        final errorText = await streamedResponse.stream.bytesToString();
        String errorMessage = 'Upload failed with status ${streamedResponse.statusCode}';
        try {
          final errorJson = jsonDecode(errorText);
          if (errorJson is Map && errorJson.containsKey('detail')) {
            errorMessage = errorJson['detail'].toString();
          }
        } catch (_) {
          if (errorText.isNotEmpty) {
            errorMessage = errorText;
          }
        }
        yield {
          'status': 'error',
          'error': errorMessage,
        };
      }
    } catch (e) {
      yield {
        'status': 'error',
        'error': e.toString(),
      };
    }
  }
}
