import 'package:dio/dio.dart';
import 'package:jetmarket/domain/core/interfaces/loan_v2_repository.dart';
import 'package:jetmarket/utils/network/code_response.dart';
import 'package:jetmarket/utils/network/custom_exception.dart';
import 'package:jetmarket/utils/network/data_state.dart';

import '../daos/provider/remote/remote_provider.dart';

class LoanV2RepositoryImpl implements LoanV2Repository {
  DataState<T> _state<T>(Response response, T value) => DataState<T>(
        result: value,
        status: StatusCodeResponse.cek(response: response),
        message: response.data['message'],
      );

  @override
  Future<DataState<Map<String, dynamic>>> eligibility() async {
    try {
      final response =
          await RemoteProvider.get(path: 'loan-applications/eligibility');
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<List<dynamic>>> products() async {
    try {
      final response = await RemoteProvider.get(path: 'loan-products');
      return _state(response, List<dynamic>.from(response.data['data'] ?? []));
    } on DioException catch (error) {
      return CustomException<List<dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> previewApplication(
      int productId, int requestedAmount, int tenorMonths) async {
    try {
      final response =
          await RemoteProvider.post(path: 'loan-applications/preview', data: {
        'loan_product_id': productId,
        'requested_amount': requestedAmount,
        'tenor_months': tenorMonths
      });
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> createApplication(
          Map<String, dynamic> body) =>
      _applicationMutation('loan-applications', body, false);

  @override
  Future<DataState<Map<String, dynamic>>> updateApplication(
          int id, Map<String, dynamic> body) =>
      _applicationMutation('loan-applications/$id', body, true);

  Future<DataState<Map<String, dynamic>>> _applicationMutation(
      String path, Map<String, dynamic> body, bool update) async {
    try {
      final response = update
          ? await RemoteProvider.put(path: path, data: body)
          : await RemoteProvider.post(path: path, data: body);
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> application(int id) async {
    try {
      final response = await RemoteProvider.get(path: 'loan-applications/$id');
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> applications(
      {int page = 1, int size = 20}) async {
    try {
      final response = await RemoteProvider.get(
          path: 'loan-applications',
          queryParameters: {'page': page, 'size': size});
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<List<dynamic>>> guarantorCandidates(int applicationId,
      {String search = ''}) async {
    try {
      final response = await RemoteProvider.get(
          path: 'loan-guarantor-candidates',
          queryParameters: {
            'application_id': applicationId,
            'search': search,
            'page': 1,
            'size': 20
          });
      final data = Map<String, dynamic>.from(response.data['data'] ?? {});
      return _state(response, List<dynamic>.from(data['items'] ?? []));
    } on DioException catch (error) {
      return CustomException<List<dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<List<dynamic>>> selectGuarantors(
      int applicationId, List<int> customerIds) async {
    try {
      final response = await RemoteProvider.post(
          path: 'loan-applications/$applicationId/guarantors',
          data: {'guarantor_customer_ids': customerIds});
      return _state(response, List<dynamic>.from(response.data['data'] ?? []));
    } on DioException catch (error) {
      return CustomException<List<dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> uploadBorrowerFace(
          int applicationId, String path) =>
      _upload('loan-applications/$applicationId/face-upload', 'face', path);

  @override
  Future<DataState<Map<String, dynamic>>> uploadSignature(
          int applicationId, String documentType, String path) =>
      _upload('loan-applications/$applicationId/signature-upload', 'signature',
          path,
          fields: {'document_type': documentType});

  Future<DataState<Map<String, dynamic>>> _upload(
      String endpoint, String field, String path,
      {Map<String, dynamic>? fields, Options? options}) async {
    try {
      final data = <String, dynamic>{
        ...?fields,
        field: await MultipartFile.fromFile(path)
      };
      final response = await RemoteProvider.post(
          path: endpoint, data: FormData.fromMap(data), options: options);
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> createBorrowerVerification(
          int applicationId, Map<String, dynamic> body) =>
      _postMap('loan-applications/$applicationId/borrower-verification', body);

  @override
  Future<DataState<Map<String, dynamic>>> createLivenessChallenge(
          int applicationId) =>
      _postMap('loan-applications/$applicationId/liveness-challenge', const {});

  @override
  Future<DataState<Map<String, dynamic>>> uploadLivenessEvidence(
          int applicationId, int sessionId, String nonce, String path) =>
      _upload(
          'loan-applications/$applicationId/liveness-evidence', 'video', path,
          fields: {'session_id': sessionId.toString(), 'nonce': nonce},
          // Evidence is encrypted and stored before the backend returns 202.
          // Object storage can take substantially longer than ordinary API
          // calls, especially over a development tunnel.
          options: Options(
            sendTimeout: const Duration(seconds: 90),
            receiveTimeout: const Duration(seconds: 90),
          ));

  @override
  Future<DataState<Map<String, dynamic>>> livenessStatus(
      int applicationId) async {
    try {
      final response = await RemoteProvider.get(
          path: 'loan-applications/$applicationId/liveness-status');
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> signApplication(
          int applicationId, Map<String, dynamic> body) =>
      _postMap('loan-applications/$applicationId/application-signature', body);

  @override
  Future<DataState<Map<String, dynamic>>> signFinalAgreement(
          int applicationId, Map<String, dynamic> body) =>
      _postMap('loan-applications/$applicationId/final-signature', body);

  @override
  Future<DataState<Map<String, dynamic>>> submit(
          int applicationId, int rowVersion) =>
      _postMap('loan-applications/$applicationId/submit',
          {'row_version': rowVersion});

  Future<DataState<Map<String, dynamic>>> _postMap(
      String path, Map<String, dynamic> body) async {
    try {
      final response = await RemoteProvider.post(path: path, data: body);
      return _state(
          response, Map<String, dynamic>.from(response.data['data'] ?? {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<List<dynamic>>> timeline(int applicationId) async {
    try {
      final response = await RemoteProvider.get(
          path: 'loan-applications/$applicationId/timeline');
      // The timeline endpoint returns a detail object.  The list rendered by
      // the member app lives under `status_history`, unlike installments
      // which returns a list directly.
      final data = response.data['data'];
      final history = data is Map ? data['status_history'] : data;
      final items =
          history is List ? List<dynamic>.from(history) : const <dynamic>[];
      return _state(response, items);
    } on DioException catch (error) {
      return CustomException<List<dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<Map<String, dynamic>>> timelineDetail(
      int applicationId) async {
    try {
      final response = await RemoteProvider.get(
          path: 'loan-applications/$applicationId/timeline');
      return _state(response,
          Map<String, dynamic>.from(response.data['data'] ?? const {}));
    } on DioException catch (error) {
      return CustomException<Map<String, dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<List<int>>> downloadDocument(
      int applicationId, int documentId) async {
    try {
      final response = await RemoteProvider.get(
          path:
              'loan-applications/$applicationId/documents/$documentId/download',
          options: Options(
              responseType: ResponseType.bytes,
              headers: {'Accept': 'application/pdf'}));
      return DataState<List<int>>(
          result: List<int>.from(response.data as List),
          status: StatusCodeResponse.cek(response: response));
    } on DioException catch (error) {
      return CustomException<List<int>>().dio(error);
    }
  }

  @override
  Future<DataState<List<dynamic>>> installments(int applicationId) =>
      _getList('loan-applications/$applicationId/installments');

  Future<DataState<List<dynamic>>> _getList(String path) async {
    try {
      final response = await RemoteProvider.get(path: path);
      return _state(response, List<dynamic>.from(response.data['data'] ?? []));
    } on DioException catch (error) {
      return CustomException<List<dynamic>>().dio(error);
    }
  }

  @override
  Future<DataState<void>> cancel(int applicationId, String reason) async {
    try {
      final response = await RemoteProvider.post(
          path: 'loan-applications/$applicationId/cancel',
          data: {'reason': reason});
      return _state<void>(response, null);
    } on DioException catch (error) {
      return CustomException<void>().dio(error);
    }
  }
}
