import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jetmarket/domain/core/interfaces/file_repository.dart';
import 'package:jetmarket/domain/core/interfaces/loan_v2_repository.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';
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
  })  : _eligibility = eligibility,
        _products = products,
        _applications = applications;

  final Future<DataState<Map<String, dynamic>>> Function() _eligibility;
  final Future<DataState<List<dynamic>>> Function() _products;
  final Future<DataState<Map<String, dynamic>>> Function() _applications;

  @override
  Future<DataState<Map<String, dynamic>>> eligibility() => _eligibility();

  @override
  Future<DataState<List<dynamic>>> products() => _products();

  @override
  Future<DataState<Map<String, dynamic>>> applications(
          {int page = 1, int size = 20}) =>
      _applications();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FileRepositoryFake implements FileRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
