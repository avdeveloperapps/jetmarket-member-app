import 'package:dio/dio.dart';
import 'custom_logger.dart';
import 'status_response.dart';

class StatusCodeResponse {
  static StatusResponse cek(
      {required Response<dynamic> response,
      bool? showLogs,
      bool? queryParams}) {
    final statusCode = response.statusCode;
    if (statusCode != null && statusCode >= 200 && statusCode < 300) {
      CustomLogger.onResponseLogger(
          response: response, logRequest: showLogs, queryParams: queryParams);
      return StatusResponse.success;
    } else {
      return StatusResponse.failed;
    }
  }
}
