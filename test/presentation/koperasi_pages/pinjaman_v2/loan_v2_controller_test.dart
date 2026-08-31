import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetmarket/domain/core/interfaces/file_repository.dart';
import 'package:jetmarket/domain/core/interfaces/loan_v2_repository.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';
import 'package:jetmarket/utils/network/action_status.dart';
import 'package:jetmarket/utils/network/data_state.dart';
import 'package:jetmarket/utils/network/status_response.dart';

void main() {
  test('loadHome always releases loading when a repository throws', () async {
    final eligibility = Completer<DataState<Map<String, dynamic>>>();
    final controller = LoanV2Controller(
      _LoanRepositoryFake(
        eligibility: () => eligibility.future,
        products: () async => _success(<dynamic>[]),
        applications: () async => _success(<String, dynamic>{'items': []}),
      ),
      _FileRepositoryFake(),
    );

    final loading = controller.loadHome();
    expect(controller.loading.value, isTrue);

    eligibility.completeError(StateError('invalid response payload'));
    await loading;

    expect(controller.loading.value, isFalse);
    expect(controller.homeLoadError.value, isNotNull);
  });

  test('loadHome tolerates a malformed application items value', () async {
    final controller = LoanV2Controller(
      _LoanRepositoryFake(
        eligibility: () async =>
            _success(<String, dynamic>{'eligible': false, 'reasons': []}),
        products: () async => _success(<dynamic>[]),
        applications: () async =>
            _success(<String, dynamic>{'items': 'not-a-list'}),
      ),
      _FileRepositoryFake(),
    );

    await controller.loadHome();

    expect(controller.loading.value, isFalse);
    expect(controller.homeLoadError.value, isNull);
    expect(controller.applications, isEmpty);
  });

  test('submitLivenessEvidence recovers when server already verified evidence',
      () async {
    final controller = LoanV2Controller(
      _LoanRepositoryFake(
        eligibility: () async => _success(<String, dynamic>{}),
        products: () async => _success(<dynamic>[]),
        applications: () async => _success(<String, dynamic>{'items': []}),
        uploadLivenessEvidence: (_, __, ___, ____) async =>
            DataState<Map<String, dynamic>>(
          status: StatusResponse.failed,
          message: 'sesi active liveness tidak ditemukan',
        ),
        livenessStatus: (_) async => _success(<String, dynamic>{
          'status': 'VERIFIED',
          'liveness_session_status': 'VERIFIED',
        }),
      ),
      _FileRepositoryFake(),
    );
    controller.application.value = <String, dynamic>{'id': 5};
    controller.livenessChallenge.value = <String, dynamic>{
      'session_id': 14,
      'nonce': 'nonce',
    };
    controller.livenessVideoPath.value = '/tmp/liveness.mp4';

    final submitted = await controller.submitLivenessEvidence();

    expect(submitted, isTrue);
    expect(controller.isLivenessVerified, isTrue);
    expect(controller.livenessSubmitted.value, isTrue);
    expect(controller.actionStatus.value, ActionStatus.success);
  });

  test(
      'restoreLivenessStatus preserves submitted state while session row is still CREATED',
      () async {
    final controller = LoanV2Controller(
      _LoanRepositoryFake(
        eligibility: () async => _success(<String, dynamic>{}),
        products: () async => _success(<dynamic>[]),
        applications: () async => _success(<String, dynamic>{'items': []}),
        uploadLivenessEvidence: (_, __, ___, ____) async => _success(
          <String, dynamic>{'session_id': 14, 'status': 'SUBMITTED'},
        ),
        livenessStatus: (_) async => _success(<String, dynamic>{
          'status': 'PENDING',
          'liveness_session_status': 'CREATED',
        }),
      ),
      _FileRepositoryFake(),
    );
    controller.application.value = <String, dynamic>{'id': 5};
    controller.livenessChallenge.value = <String, dynamic>{
      'session_id': 14,
      'nonce': 'nonce',
    };
    controller.livenessVideoPath.value = '/tmp/liveness.mp4';

    final submitted = await controller.submitLivenessEvidence();
    expect(submitted, isTrue);

    await controller.restoreLivenessStatus();

    expect(controller.livenessSubmitted.value, isTrue);
    expect(controller.livenessVerificationStatus.value, 'PENDING');
  });
}

DataState<T> _success<T>(T result) => DataState<T>(
      status: StatusResponse.success,
      result: result,
    );

class _LoanRepositoryFake implements LoanV2Repository {
  _LoanRepositoryFake({
    required Future<DataState<Map<String, dynamic>>> Function() eligibility,
    required Future<DataState<List<dynamic>>> Function() products,
    required Future<DataState<Map<String, dynamic>>> Function() applications,
    Future<DataState<Map<String, dynamic>>> Function(
            int applicationId, int sessionId, String nonce, String path)?
        uploadLivenessEvidence,
    Future<DataState<Map<String, dynamic>>> Function(int applicationId)?
        livenessStatus,
  })  : _eligibility = eligibility,
        _products = products,
        _applications = applications,
        _uploadLivenessEvidence = uploadLivenessEvidence,
        _livenessStatus = livenessStatus;

  final Future<DataState<Map<String, dynamic>>> Function() _eligibility;
  final Future<DataState<List<dynamic>>> Function() _products;
  final Future<DataState<Map<String, dynamic>>> Function() _applications;
  final Future<DataState<Map<String, dynamic>>> Function(
          int applicationId, int sessionId, String nonce, String path)?
      _uploadLivenessEvidence;
  final Future<DataState<Map<String, dynamic>>> Function(int applicationId)?
      _livenessStatus;

  @override
  Future<DataState<Map<String, dynamic>>> eligibility() => _eligibility();

  @override
  Future<DataState<List<dynamic>>> products() => _products();

  @override
  Future<DataState<Map<String, dynamic>>> applications(
          {int page = 1, int size = 20}) =>
      _applications();

  @override
  Future<DataState<Map<String, dynamic>>> uploadLivenessEvidence(
      int applicationId, int sessionId, String nonce, String path) {
    final handler = _uploadLivenessEvidence;
    if (handler == null) {
      return super.noSuchMethod(Invocation.method(#uploadLivenessEvidence, [
        applicationId,
        sessionId,
        nonce,
        path,
      ]));
    }
    return handler(applicationId, sessionId, nonce, path);
  }

  @override
  Future<DataState<Map<String, dynamic>>> livenessStatus(int applicationId) {
    final handler = _livenessStatus;
    if (handler == null) {
      return super
          .noSuchMethod(Invocation.method(#livenessStatus, [applicationId]));
    }
    return handler(applicationId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FileRepositoryFake implements FileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
