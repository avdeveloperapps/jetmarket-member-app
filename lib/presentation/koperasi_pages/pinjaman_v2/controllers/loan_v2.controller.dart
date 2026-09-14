import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jetmarket/domain/core/interfaces/file_repository.dart';
import 'package:jetmarket/domain/core/interfaces/loan_v2_repository.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/loan_signature_pad.screen.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/loan_agreement_preview.screen.dart';
import 'package:jetmarket/utils/network/action_status.dart';
import 'package:jetmarket/utils/network/status_response.dart';
import 'package:jetmarket/utils/services/loan_mobilefacenet.service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

class LoanV2Controller extends GetxController {
  LoanV2Controller(this._repository, this._fileRepository);

  final LoanV2Repository _repository;
  final FileRepository _fileRepository;
  final ImagePicker _picker = ImagePicker();
  final _mobileFaceNet = LoanMobileFaceNetService();
  final eligibility = <String, dynamic>{}.obs;
  final products = <Map<String, dynamic>>[].obs;
  final applications = <dynamic>[].obs;
  final candidates = <dynamic>[].obs;
  final selectedGuarantorIds = <int>[].obs;
  final timeline = <dynamic>[].obs;
  final installments = <dynamic>[].obs;
  final documents = <dynamic>[].obs;
  final interview = Rxn<Map<String, dynamic>>();
  final borrowerFinalSignatureExists = false.obs;
  final finalAgreementReadyForBorrowerSignature = false.obs;
  final application = Rxn<Map<String, dynamic>>();
  final selectedProduct = Rxn<Map<String, dynamic>>();
  final selectedTenor = 0.obs;
  final loading = false.obs;
  final homeLoadError = RxnString();
  final candidatesLoading = false.obs;
  final previewLoading = false.obs;
  final actionStatus = ActionStatus.initalize.obs;
  final ktpPath = RxnString();
  final facePath = RxnString();
  final livenessVideoPath = RxnString();
  final livenessChallenge = Rxn<Map<String, dynamic>>();
  final livenessSubmitted = false.obs;
  final livenessVerificationStatus = ''.obs;
  final signaturePath = RxnString();
  final signatureReceipt = Rxn<Map<String, dynamic>>();
  final faceReceipt = Rxn<Map<String, dynamic>>();
  final loanPreview = Rxn<Map<String, dynamic>>();
  int _homeLoadSequence = 0;
  int _candidateRequestSequence = 0;
  int _livenessPollSequence = 0;
  bool _livenessEvidenceSubmitting = false;

  Future<void> loadHome() async {
    final loadSequence = ++_homeLoadSequence;
    loading(true);
    homeLoadError.value = null;
    try {
      final results = await Future.wait([
        _repository.eligibility(),
        _repository.products(),
        _repository.applications()
      ]).timeout(const Duration(seconds: 15));
      if (loadSequence != _homeLoadSequence) return;
      final eligibilityResult = results[0] as dynamic;
      final productResult = results[1] as dynamic;
      final applicationsResult = results[2] as dynamic;
      if (eligibilityResult.status != StatusResponse.success ||
          productResult.status != StatusResponse.success ||
          applicationsResult.status != StatusResponse.success) {
        homeLoadError.value = eligibilityResult.message?.toString() ??
            productResult.message?.toString() ??
            applicationsResult.message?.toString() ??
            'Data pinjaman belum dapat dimuat.';
        return;
      }

      eligibility.assignAll(Map<String, dynamic>.from(
          eligibilityResult.result is Map
              ? eligibilityResult.result as Map
              : const {}));
      final uniqueProducts = <int, Map<String, dynamic>>{};
      final productItems = productResult.result is List
          ? List<dynamic>.from(productResult.result as List)
          : const <dynamic>[];
      for (final item in productItems) {
        if (item is! Map) continue;
        final product = Map<String, dynamic>.from(item);
        final productId = _asInt(product['id']);
        if (productId != null) {
          product['id'] = productId;
          uniqueProducts[productId] = product;
        }
      }
      products.assignAll(uniqueProducts.values);
      final applicationResult = applicationsResult.result;
      final applicationItems =
          applicationResult is Map && applicationResult['items'] is List
              ? List<dynamic>.from(applicationResult['items'] as List)
              : const <dynamic>[];
      applications.assignAll(applicationItems);
    } catch (error, stackTrace) {
      if (loadSequence != _homeLoadSequence) return;
      developer.log('Failed to load loan home',
          name: 'LoanV2Controller', error: error, stackTrace: stackTrace);
      homeLoadError.value = 'Data pinjaman belum dapat dimuat.';
    } finally {
      if (loadSequence == _homeLoadSequence) loading(false);
    }
  }

  Future<void> loadDetail(int id) async {
    loading(true);
    application.value = null;
    timeline.clear();
    installments.clear();
    documents.clear();
    interview.value = null;
    borrowerFinalSignatureExists(false);
    finalAgreementReadyForBorrowerSignature(false);
    // The application-form signature and the final-agreement signature are
    // separate legal actions. Never carry a previously drawn image into the
    // detail flow.
    signaturePath.value = null;
    signatureReceipt.value = null;
    try {
      // Load the application first: optional timeline/installment data must
      // never hide a valid application detail from the member.
      final applicationResult = await _repository.application(id);
      if (applicationResult.status == StatusResponse.success) {
        application.value =
            Map<String, dynamic>.from(applicationResult.result ?? {});
      }

      final results = await Future.wait(
          [_repository.timelineDetail(id), _repository.installments(id)]);
      final detailResult = results[0] as dynamic;
      final installmentResult = results[1] as dynamic;
      if (detailResult.status == StatusResponse.success &&
          detailResult.result is Map) {
        final detail = Map<String, dynamic>.from(detailResult.result as Map);
        timeline.assignAll(List<dynamic>.from(detail['status_history'] ?? []));
        documents.assignAll(List<dynamic>.from(detail['documents'] ?? []));
        if (detail['interview'] is Map) {
          interview.value =
              Map<String, dynamic>.from(detail['interview'] as Map);
        }
        borrowerFinalSignatureExists(
            detail['borrower_final_signature_exists'] == true);
        finalAgreementReadyForBorrowerSignature(
            detail['final_agreement_ready_for_borrower_signature'] == true);
      }
      if (installmentResult.status == StatusResponse.success) {
        installments.assignAll(installmentResult.result ?? []);
      }
    } catch (error, stackTrace) {
      developer.log('Failed to load loan detail',
          name: 'LoanV2Controller', error: error, stackTrace: stackTrace);
    } finally {
      loading(false);
    }
  }

  Map<String, dynamic>? get latestFinalAgreement {
    final matches = documents
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) => item['document_type'] == 'FINAL_AGREEMENT')
        .toList();
    matches.sort((left, right) => (_asInt(right['version']) ?? 0)
        .compareTo(_asInt(left['version']) ?? 0));
    return matches.isEmpty ? null : matches.first;
  }

  Future<void> openFinalAgreement() async {
    final current = application.value;
    final document = latestFinalAgreement;
    final applicationId = _asInt(current?['id']);
    final documentId = _asInt(document?['id']);
    if (applicationId == null || documentId == null) return;
    actionStatus(ActionStatus.loading);
    try {
      final response =
          await _repository.downloadDocument(applicationId, documentId);
      if (response.status != StatusResponse.success ||
          response.result == null) {
        actionStatus(ActionStatus.failed);
        Get.snackbar('Dokumen belum dapat diunduh',
            response.message ?? 'Silakan coba lagi.');
        return;
      }
      final directory = await getTemporaryDirectory();
      final number =
          current?['application_number']?.toString() ?? applicationId;
      final version = _asInt(document?['version']) ?? 1;
      final file = File('${directory.path}/$number-perjanjian-v$version.pdf');
      await file.writeAsBytes(response.result!, flush: true);
      actionStatus(ActionStatus.success);
      await Get.to(() => LoanAgreementPreviewScreen(
          file: file,
          title: version >= 2 ? 'Perjanjian Final' : 'Draf Perjanjian'));
    } catch (error, stackTrace) {
      developer.log('Failed to download final loan agreement',
          name: 'LoanV2Controller', error: error, stackTrace: stackTrace);
      actionStatus(ActionStatus.failed);
      Get.snackbar('Dokumen belum dapat diunduh', 'Silakan coba lagi.');
    }
  }

  Future<void> signFinalAgreementFromDetail() async {
    if (!finalAgreementReadyForBorrowerSignature.value) {
      Get.snackbar('Perjanjian belum siap',
          'Finance masih menyiapkan pengesahan internal dokumen.');
      return;
    }
    // Only continue when this invocation actually produced a new signature.
    // A cancelled canvas must never fall back to an older signaturePath.
    final path = await pickSignature();
    if (path == null) return;
    final signed = await sign('FINAL_AGREEMENT');
    final applicationId = _asInt(application.value?['id']);
    if (signed && applicationId != null) {
      await loadDetail(applicationId);
      Get.snackbar('Perjanjian ditandatangani',
          'TTD tersimpan. Dokumen menunggu TTD Finance.');
    } else if (!signed) {
      Get.snackbar('TTD belum tersimpan', 'Silakan coba lagi.');
    }
  }

  void prepareDraft([Map<String, dynamic>? existing]) {
    _livenessPollSequence++;
    livenessSubmitted.value = false;
    livenessVerificationStatus.value = '';
    livenessChallenge.value = null;
    livenessVideoPath.value = null;
    facePath.value = null;
    faceReceipt.value = null;
    signaturePath.value = null;
    signatureReceipt.value = null;
    ktpPath.value = null;
    loanPreview.value = null;
    application.value = existing;
    if (existing == null) {
      // A new form can be opened from Home immediately after a submission.
      // Do not carry the previous application's product selection into it.
      selectedProduct.value = null;
      selectedTenor.value = 0;
      selectedGuarantorIds.clear();
      candidates.clear();
      return;
    }
    syncDraftProductSelection(existing);
  }

  // Product data is loaded asynchronously when the application screen opens.
  // Re-applying the product/tenor selection after that load must not reset the
  // in-progress liveness capture or stop its status polling.
  void syncDraftProductSelection([Map<String, dynamic>? draft]) {
    final existing = draft ?? application.value;
    if (existing == null) return;
    selectedTenor.value = _asInt(existing['tenor_months']) ?? 0;
    final productId = _asInt(existing['loan_product_id']);
    selectedProduct.value = productId == null ? null : _productById(productId);
  }

  int? get selectedProductId => _asInt(selectedProduct.value?['id']);

  static const _resumableApplicationStatuses = {
    'DRAFT',
    'BORROWER_VERIFICATION_PENDING',
  };

  Map<String, dynamic>? get latestResumableApplication {
    final resumable = applications
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((item) =>
            _resumableApplicationStatuses.contains(item['status']?.toString()))
        .toList();
    resumable.sort((left, right) {
      final leftDate = DateTime.tryParse(left['created_at']?.toString() ?? '');
      final rightDate =
          DateTime.tryParse(right['created_at']?.toString() ?? '');
      if (leftDate == null && rightDate == null) {
        return (_asInt(right['id']) ?? 0).compareTo(_asInt(left['id']) ?? 0);
      }
      if (leftDate == null) return 1;
      if (rightDate == null) return -1;
      return rightDate.compareTo(leftDate);
    });
    return resumable.isEmpty ? null : resumable.first;
  }

  Map<String, dynamic>? _productById(int productId) {
    for (final product in products) {
      if (_asInt(product['id']) == productId) return product;
    }

    return null;
  }

  Map<String, dynamic>? chooseProductById(int productId) {
    final product = _productById(productId);
    if (product == null) return null;
    chooseProduct(product);

    return product;
  }

  void chooseProduct(Map<String, dynamic> product) {
    selectedProduct.value = product;
    final tenors = List<dynamic>.from(product['tenors'] ?? []);
    final firstTenor = tenors.isEmpty || tenors.first is! Map
        ? null
        : _asInt((tenors.first as Map)['tenor_months']);
    selectedTenor.value = firstTenor ?? 0;
    update();
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  Future<void> pickKtp() async {
    final image =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image != null) ktpPath.value = image.path;
  }

  Future<Map<String, dynamic>?> previewApplication(int requestedAmount) async {
    final productId = selectedProductId;
    if (productId == null || requestedAmount <= 0 || selectedTenor.value <= 0) {
      Get.snackbar('Rincian belum dapat dihitung',
          'Pilih produk, isi nominal, dan pilih tenor terlebih dahulu.');
      return null;
    }

    previewLoading(true);
    try {
      final response = await _repository.previewApplication(
          productId, requestedAmount, selectedTenor.value);
      if (response.status != StatusResponse.success ||
          response.result == null) {
        Get.snackbar('Rincian pinjaman gagal dimuat',
            response.message ?? 'Periksa nominal dan tenor lalu coba lagi.');
        return null;
      }

      loanPreview.value = Map<String, dynamic>.from(response.result!);
      return loanPreview.value;
    } catch (error, stackTrace) {
      developer.log('Failed to preview loan application',
          name: 'LoanV2Controller', error: error, stackTrace: stackTrace);
      Get.snackbar(
          'Rincian pinjaman gagal dimuat', 'Periksa koneksi lalu coba lagi.');
      return null;
    } finally {
      previewLoading(false);
    }
  }

  Future<void> pickFace() async {
    final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85);
    if (image != null) facePath.value = image.path;
  }

  Future<String?> pickSignature() async {
    final path = await Get.to<String>(() => const LoanSignaturePadScreen());
    if (path == null || path.isEmpty) return null;
    signaturePath.value = path;
    signatureReceipt.value = null;
    return path;
  }

  Future<bool> saveDraft(
      {required String purpose,
      required int requestedAmount,
      required String bankName,
      required String accountNumber,
      required String accountHolder}) async {
    final validationMessage = _validateDraftInput(
      purpose: purpose,
      requestedAmount: requestedAmount,
      bankName: bankName,
      accountNumber: accountNumber,
      accountHolder: accountHolder,
    );
    if (validationMessage != null) {
      Get.snackbar('Data pengajuan belum lengkap', validationMessage);
      return false;
    }
    // A draft is resumed only when the member explicitly taps the resume
    // action. Starting from Ajukan Pinjaman must never inherit another
    // application's guarantors, verification, or signature state.
    final current = application.value;
    actionStatus(ActionStatus.loading);
    final file = File(ktpPath.value!);
    final uploaded =
        await _fileRepository.uploadFile(name: 'loan-ktp', image: file.path);
    if (uploaded.status != StatusResponse.success || uploaded.result == null) {
      actionStatus(ActionStatus.failed);
      Get.snackbar('Foto KTP gagal diunggah',
          uploaded.message ?? 'Silakan periksa koneksi lalu coba lagi.');
      return false;
    }
    final body = {
      'loan_product_id': selectedProduct.value!['id'],
      'purpose': purpose.trim(),
      'requested_amount': requestedAmount,
      'tenor_months': selectedTenor.value,
      'bank_name': bankName.trim(),
      'bank_account_number': accountNumber.trim(),
      'bank_account_holder': accountHolder.trim(),
      'ktp_image_object_key': uploaded.result,
      'ktp_image_sha256': sha256.convert(await file.readAsBytes()).toString(),
    };
    if (current != null) body['row_version'] = current['row_version'];
    final response = current == null
        ? await _repository.createApplication(body)
        : await _repository.updateApplication(current['id'], body);
    actionStatus(response.status == StatusResponse.success
        ? ActionStatus.success
        : ActionStatus.failed);
    if (response.status == StatusResponse.success) {
      application.value = Map<String, dynamic>.from(response.result ?? {});
      await loadCandidates();
      return true;
    }
    Get.snackbar('Pengajuan gagal disimpan',
        response.message ?? 'Silakan periksa data pengajuan lalu coba lagi.');
    return false;
  }

  String? _validateDraftInput({
    required String purpose,
    required int requestedAmount,
    required String bankName,
    required String accountNumber,
    required String accountHolder,
  }) {
    final product = selectedProduct.value;
    if (purpose.trim().length < 3) {
      return 'Tujuan pinjaman minimal 3 karakter.';
    }
    if (product == null) return 'Produk pinjaman wajib dipilih.';
    if (selectedTenor.value <= 0) return 'Tenor pinjaman wajib dipilih.';

    final minimum = _asInt(product['min_amount']) ?? 0;
    final maximum = _asInt(product['max_amount']) ?? 0;
    if (requestedAmount < minimum || requestedAmount > maximum) {
      return 'Nominal harus berada pada batas produk yang dipilih.';
    }
    if (bankName.trim().isEmpty ||
        accountNumber.trim().isEmpty ||
        accountHolder.trim().isEmpty) {
      return 'Nama bank dan data rekening pencairan wajib lengkap.';
    }
    if (!RegExp(r'^\d+$').hasMatch(accountNumber.trim())) {
      return 'Nomor rekening hanya boleh berisi angka.';
    }
    if (ktpPath.value?.trim().isEmpty ?? true) {
      return 'Foto KTP wajib diambil terlebih dahulu.';
    }
    return null;
  }

  Future<void> loadCandidates([String search = '']) async {
    final current = application.value;
    if (current == null) return;
    final requestSequence = ++_candidateRequestSequence;
    candidatesLoading(true);
    try {
      final response =
          await _repository.guarantorCandidates(current['id'], search: search);
      if (requestSequence != _candidateRequestSequence) return;
      if (response.status == StatusResponse.success) {
        candidates.assignAll(response.result ?? []);
      }
    } catch (error, stackTrace) {
      developer.log('Failed to load guarantor candidates',
          name: 'LoanV2Controller', error: error, stackTrace: stackTrace);
    } finally {
      if (requestSequence == _candidateRequestSequence) {
        candidatesLoading(false);
      }
    }
  }

  Future<bool> saveGuarantors() async {
    final current = application.value;
    if (current == null ||
        selectedGuarantorIds.length != (current['required_guarantors'] ?? 0)) {
      return false;
    }
    actionStatus(ActionStatus.loading);
    final response =
        await _repository.selectGuarantors(current['id'], selectedGuarantorIds);
    actionStatus(response.status == StatusResponse.success
        ? ActionStatus.success
        : ActionStatus.failed);
    return response.status == StatusResponse.success;
  }

  Future<bool> submitLivenessEvidence() async {
    if (_livenessEvidenceSubmitting) return false;
    final current = application.value;
    final challenge = livenessChallenge.value;
    final applicationId = _asInt(current?['id']);
    final sessionId = _asInt(challenge?['session_id']);
    final nonce = challenge?['nonce']?.toString();
    if (applicationId == null ||
        sessionId == null ||
        nonce == null ||
        nonce.isEmpty ||
        livenessVideoPath.value == null) {
      return false;
    }
    _livenessEvidenceSubmitting = true;
    actionStatus(ActionStatus.loading);
    try {
      final response = await _repository.uploadLivenessEvidence(
          applicationId, sessionId, nonce, livenessVideoPath.value!);
      if (response.status == StatusResponse.success) {
        actionStatus(ActionStatus.success);
        _markLivenessEvidenceSubmitted(applicationId);
        return true;
      }

      final recovered = await _recoverSubmittedLiveness(applicationId);
      actionStatus(recovered ? ActionStatus.success : ActionStatus.failed);
      return recovered;
    } finally {
      _livenessEvidenceSubmitting = false;
    }
  }

  void _markLivenessEvidenceSubmitted(int applicationId) {
    livenessSubmitted.value = true;
    livenessVerificationStatus.value = 'PENDING';
    unawaited(_pollLivenessStatus(applicationId));
  }

  Future<bool> _recoverSubmittedLiveness(int applicationId) async {
    // A client may lose the upload response while the backend is still
    // encrypting and storing the evidence. In that case the latest session is
    // briefly CREATED even though the original request will shortly mark it
    // SUBMITTED. Do not let the user start another challenge during that gap.
    for (var attempt = 0; attempt < 15; attempt++) {
      final status = await _repository.livenessStatus(applicationId);
      if (status.status == StatusResponse.success && status.result != null) {
        final result = Map<String, dynamic>.from(status.result!);
        _applyLivenessStatus(result);
        final verificationStatus = result['status']?.toString();
        final sessionStatus = result['liveness_session_status']?.toString();
        if (verificationStatus == 'VERIFIED') {
          return true;
        }
        if (verificationStatus == 'PENDING' && sessionStatus == 'SUBMITTED') {
          livenessSubmitted.value = true;
          unawaited(_pollLivenessStatus(applicationId));
          return true;
        }

        final stillStoringEvidence = verificationStatus == 'PENDING' &&
            (sessionStatus == null ||
                sessionStatus.isEmpty ||
                sessionStatus == 'CREATED');
        if (!stillStoringEvidence) return false;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    return false;
  }

  Future<void> _pollLivenessStatus(int applicationId) async {
    final sequence = ++_livenessPollSequence;
    var consecutiveFailures = 0;
    for (var attempt = 0; attempt < 150; attempt++) {
      if (sequence != _livenessPollSequence) return;
      final response = await _repository.livenessStatus(applicationId);
      if (response.status == StatusResponse.success &&
          response.result != null) {
        consecutiveFailures = 0;
        final result = Map<String, dynamic>.from(response.result!);
        final status = result['status']?.toString() ?? 'PENDING';
        _applyLivenessStatus(result);
        if (status == 'VERIFIED') return;
        if (status == 'FAILED') {
          Get.snackbar('Active liveness belum berhasil',
              'Wajah atau gerakan belum dapat diverifikasi. Silakan rekam ulang dengan pencahayaan yang lebih baik.');
          return;
        }
      } else {
        consecutiveFailures++;
        if (consecutiveFailures >= 5) {
          livenessVerificationStatus.value = 'STATUS_CHECK_FAILED';
          return;
        }
      }
      await Future<void>.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> retryLivenessStatus() async {
    final applicationId = _asInt(application.value?['id']);
    if (applicationId == null) return;
    livenessVerificationStatus.value = 'PENDING';
    await _pollLivenessStatus(applicationId);
  }

  Future<void> restoreLivenessStatus() async {
    final applicationId = _asInt(application.value?['id']);
    if (applicationId == null) return;
    final response = await _repository.livenessStatus(applicationId);
    if (response.status != StatusResponse.success || response.result == null) {
      return;
    }
    final result = Map<String, dynamic>.from(response.result!);
    _applyLivenessStatus(result);
    final status = result['status']?.toString();
    final sessionStatus = result['liveness_session_status']?.toString();
    final sessionNotYetVisible = sessionStatus == null ||
        sessionStatus.isEmpty ||
        sessionStatus == 'CREATED';
    final shouldPoll = status == 'PENDING' &&
        (sessionStatus == 'SUBMITTED' ||
            sessionStatus == 'VERIFIED' ||
            (livenessSubmitted.value && sessionNotYetVisible));
    if (shouldPoll) {
      unawaited(_pollLivenessStatus(applicationId));
    }
  }

  void _applyLivenessStatus(Map<String, dynamic> result) {
    final status = result['status']?.toString() ?? '';
    final sessionStatus = result['liveness_session_status']?.toString() ?? '';
    livenessVerificationStatus.value = status;
    if (status == 'VERIFIED' ||
        (status == 'PENDING' && sessionStatus == 'SUBMITTED')) {
      livenessSubmitted.value = true;
    } else if (status == 'FAILED') {
      livenessSubmitted.value = false;
    }
    // PENDING + CREATED/null/session-VERIFIED dibiarkan: jika user sudah
    // mengirim evidence, submitted tetap true; jika belum, tetap false.
    if (status == 'FAILED') {
      livenessChallenge.value = null;
      livenessVideoPath.value = null;
    }
  }

  bool get isLivenessVerified => livenessVerificationStatus.value == 'VERIFIED';

  bool get livenessStatusCheckFailed =>
      livenessVerificationStatus.value == 'STATUS_CHECK_FAILED';

  Future<bool> prepareLivenessChallenge(String selfiePath) async {
    final applicationId = _asInt(application.value?['id']);
    if (applicationId == null) return false;
    facePath.value = selfiePath;

    final statusResponse = await _repository.livenessStatus(applicationId);
    if (statusResponse.status == StatusResponse.success &&
        statusResponse.result != null) {
      final status = statusResponse.result?['status']?.toString();
      final sessionStatus =
          statusResponse.result?['liveness_session_status']?.toString();
      if (status == 'VERIFIED') {
        _applyLivenessStatus(Map<String, dynamic>.from(statusResponse.result!));
        return false;
      }
      if (status == 'PENDING' && sessionStatus == 'SUBMITTED') {
        _applyLivenessStatus(Map<String, dynamic>.from(statusResponse.result!));
        unawaited(_pollLivenessStatus(applicationId));
        return false;
      }
      if (status == 'PENDING') {
        actionStatus(ActionStatus.loading);
        final challenge =
            await _repository.createLivenessChallenge(applicationId);
        actionStatus(challenge.status == StatusResponse.success
            ? ActionStatus.success
            : ActionStatus.failed);
        if (challenge.status != StatusResponse.success) return false;
        livenessChallenge.value =
            Map<String, dynamic>.from(challenge.result ?? {});
        return true;
      }
    }
    return submitFaceVerification();
  }

  Future<bool> submitFaceVerification() async {
    final current = application.value;
    if (current == null || facePath.value == null) return false;
    actionStatus(ActionStatus.loading);
    late LoanMobileFaceNetPreflight preflight;
    try {
      preflight = await _mobileFaceNet.preflight(facePath.value!);
    } on LoanMobileFaceNetException catch (error) {
      Get.snackbar('Verifikasi wajah', error.message);
      actionStatus(ActionStatus.failed);
      return false;
    } catch (_) {
      Get.snackbar('Verifikasi wajah',
          'Model MobileFaceNet belum siap. Silakan coba lagi.');
      actionStatus(ActionStatus.failed);
      return false;
    }
    final upload =
        await _repository.uploadBorrowerFace(current['id'], facePath.value!);
    if (upload.status != StatusResponse.success) {
      actionStatus(ActionStatus.failed);
      return false;
    }
    faceReceipt.value = Map<String, dynamic>.from(upload.result ?? {});
    final receipt = faceReceipt.value!;
    final response =
        await _repository.createBorrowerVerification(current['id'], {
      'face_object_key': receipt['face_object_key'],
      'face_sha256': receipt['face_sha256'],
      'device_fingerprint_hash': await _deviceFingerprint(),
      'device_metadata': {
        'capture': 'member_app',
        'recognition_model': LoanMobileFaceNetPreflight.modelName,
        'mobilefacenet_preflight': {
          'embedding_dimensions':
              LoanMobileFaceNetPreflight.embeddingDimensions,
          'embedding_sha256': preflight.embeddingSha256,
          'image_sha256': preflight.imageSha256,
        }
      },
      'consent_accepted': true,
    });
    final pendingAttemptExists = response.message
            ?.toLowerCase()
            .contains('verifikasi peminjam sebelumnya masih diproses') ==
        true;
    if (response.status != StatusResponse.success && !pendingAttemptExists) {
      actionStatus(ActionStatus.failed);
      return false;
    }
    // A PENDING verification can already exist when the app was closed after
    // creating a challenge. In that case the backend rotates the unfinished
    // challenge and lets this device resume without creating another identity
    // verification attempt.
    final challenge = await _repository.createLivenessChallenge(current['id']);
    if (challenge.status != StatusResponse.success) {
      actionStatus(ActionStatus.failed);
      return false;
    }
    livenessChallenge.value = Map<String, dynamic>.from(challenge.result ?? {});
    actionStatus(ActionStatus.success);
    return true;
  }

  Future<bool> sign(String documentType) async {
    final current = application.value;
    if (current == null || signaturePath.value == null) return false;
    actionStatus(ActionStatus.loading);
    try {
      final upload = await _repository.uploadSignature(
          current['id'], documentType, signaturePath.value!);
      if (upload.status != StatusResponse.success) {
        actionStatus(ActionStatus.failed);
        return false;
      }
      signatureReceipt.value = Map<String, dynamic>.from(upload.result ?? {});
      final receipt = signatureReceipt.value!;
      final body = {
        'signature_image_object_key': receipt['signature_image_object_key'],
        'signature_image_sha256': receipt['signature_image_sha256'],
        'device_fingerprint_hash': await _deviceFingerprint(),
        'client_signed_at': DateTime.now().toUtc().toIso8601String(),
        'consent_accepted': true,
        'idempotency_key': _idempotencyKey(),
      };
      final response = documentType == 'APPLICATION'
          ? await _repository.signApplication(current['id'], body)
          : await _repository.signFinalAgreement(current['id'], body);
      if (response.status != StatusResponse.success) {
        actionStatus(ActionStatus.failed);
        return false;
      }
      if (documentType == 'APPLICATION') {
        final latest = await _repository.application(current['id']);
        if (latest.status != StatusResponse.success) {
          actionStatus(ActionStatus.failed);
          return false;
        }
        application.value = Map<String, dynamic>.from(latest.result ?? {});
        final rowVersion = _asInt(application.value!['row_version']);
        if (rowVersion == null) {
          actionStatus(ActionStatus.failed);
          return false;
        }
        final submitted = await _repository.submit(current['id'], rowVersion);
        actionStatus(submitted.status == StatusResponse.success
            ? ActionStatus.success
            : ActionStatus.failed);
        return submitted.status == StatusResponse.success;
      }
      actionStatus(ActionStatus.success);
      return true;
    } catch (error, stackTrace) {
      developer.log('Failed to sign or submit loan application',
          name: 'LoanV2Controller', error: error, stackTrace: stackTrace);
      actionStatus(ActionStatus.failed);
      Get.snackbar('Pengajuan belum berhasil dikirim',
          'Terjadi kendala pada aplikasi. Silakan coba lagi.');
      return false;
    }
  }

  Future<void> cancel() async {
    final current = application.value;
    if (current == null) return;
    final response = await _repository.cancel(
        current['id'], 'Dibatalkan oleh peminjam melalui Member App');
    if (response.status == StatusResponse.success) {
      Get.back(result: true);
      return;
    }
    Get.snackbar(
        'Pengajuan belum dibatalkan', response.message ?? 'Silakan coba lagi.');
  }

  Future<String> _deviceFingerprint() async {
    final box = GetStorage();
    var installationId = box.read<String>('loan_v2_installation_id');
    if (installationId == null) {
      installationId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      await box.write('loan_v2_installation_id', installationId);
    }
    final package = await PackageInfo.fromPlatform();
    return sha256
        .convert(utf8.encode(
            '$installationId|${Platform.operatingSystem}|${package.packageName}|${package.version}'))
        .toString();
  }

  String _idempotencyKey() => sha256
      .convert(utf8.encode(
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}'))
      .toString();

  @override
  void onClose() {
    _mobileFaceNet.dispose();
    super.onClose();
  }
}
