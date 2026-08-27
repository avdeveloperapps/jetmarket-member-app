import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jetmarket/domain/core/interfaces/file_repository.dart';
import 'package:jetmarket/domain/core/interfaces/loan_v2_repository.dart';
import 'package:jetmarket/infrastructure/navigation/routes.dart';
import 'package:jetmarket/utils/network/action_status.dart';
import 'package:jetmarket/utils/network/status_response.dart';
import 'package:jetmarket/utils/services/loan_mobilefacenet.service.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  final application = Rxn<Map<String, dynamic>>();
  final selectedProduct = Rxn<Map<String, dynamic>>();
  final selectedTenor = 0.obs;
  final loading = false.obs;
  final actionStatus = ActionStatus.initalize.obs;
  final ktpPath = RxnString();
  final facePath = RxnString();
  final livenessVideoPath = RxnString();
  final livenessChallenge = Rxn<Map<String, dynamic>>();
  final livenessSubmitted = false.obs;
  final signaturePath = RxnString();
  final signatureReceipt = Rxn<Map<String, dynamic>>();
  final faceReceipt = Rxn<Map<String, dynamic>>();

  Future<void> loadHome() async {
    loading(true);
    final results = await Future.wait([
      _repository.eligibility(),
      _repository.products(),
      _repository.applications()
    ]);
    final eligibilityResult = results[0] as dynamic;
    final productResult = results[1] as dynamic;
    final applicationsResult = results[2] as dynamic;
    if (eligibilityResult.status == StatusResponse.success) {
      eligibility.assignAll(eligibilityResult.result ?? {});
    }
    if (productResult.status == StatusResponse.success) {
      final uniqueProducts = <int, Map<String, dynamic>>{};
      for (final item in List<dynamic>.from(productResult.result ?? [])) {
        if (item is! Map) continue;
        final product = Map<String, dynamic>.from(item);
        final productId = _asInt(product['id']);
        if (productId != null) {
          product['id'] = productId;
          uniqueProducts[productId] = product;
        }
      }
      products.assignAll(uniqueProducts.values);
    }
    if (applicationsResult.status == StatusResponse.success) {
      applications.assignAll(
          (applicationsResult.result?['items'] ?? []) as List<dynamic>);
    }
    loading(false);
  }

  Future<void> loadDetail(int id) async {
    loading(true);
    final results = await Future.wait([
      _repository.application(id),
      _repository.timeline(id),
      _repository.installments(id)
    ]);
    final applicationResult = results[0] as dynamic;
    final timelineResult = results[1] as dynamic;
    final installmentResult = results[2] as dynamic;
    if (applicationResult.status == StatusResponse.success) {
      application.value =
          Map<String, dynamic>.from(applicationResult.result ?? {});
    }
    if (timelineResult.status == StatusResponse.success) {
      timeline.assignAll(timelineResult.result ?? []);
    }
    if (installmentResult.status == StatusResponse.success) {
      installments.assignAll(installmentResult.result ?? []);
    }
    loading(false);
  }

  void prepareDraft([Map<String, dynamic>? existing]) {
    application.value = existing;
    if (existing == null) return;
    selectedTenor.value = _asInt(existing['tenor_months']) ?? 0;
    final productId = _asInt(existing['loan_product_id']);
    selectedProduct.value = productId == null
        ? null
        : _productById(productId);
  }

  int? get selectedProductId => _asInt(selectedProduct.value?['id']);

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

  Future<void> pickFace() async {
    final image = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 85);
    if (image != null) facePath.value = image.path;
  }

  Future<void> pickSignature() async {
    final image =
        await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (image != null) signaturePath.value = image.path;
  }

  Future<void> pickLivenessVideo() async {
    if (livenessChallenge.value == null) {
      Get.snackbar(
          'Active liveness', 'Buat tantangan active liveness terlebih dahulu.');
      return;
    }
    final video = await _picker.pickVideo(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxDuration: const Duration(seconds: 25));
    if (video != null) livenessVideoPath.value = video.path;
  }

  Future<bool> saveDraft(
      {required String purpose,
      required int requestedAmount,
      required String bankName,
      required String accountNumber,
      required String accountHolder}) async {
    if (selectedProduct.value == null ||
        selectedTenor.value <= 0 ||
        ktpPath.value == null) {
      Get.snackbar('Data pengajuan belum lengkap',
          'Pilih produk, tenor, dan unggah foto KTP terlebih dahulu.');
      return false;
    }
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
    final current = application.value;
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

  Future<void> loadCandidates([String search = '']) async {
    final current = application.value;
    if (current == null) return;
    loading(true);
    final response =
        await _repository.guarantorCandidates(current['id'], search: search);
    if (response.status == StatusResponse.success) {
      candidates.assignAll(response.result ?? []);
    }
    loading(false);
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
    final current = application.value;
    final challenge = livenessChallenge.value;
    if (current == null ||
        challenge == null ||
        livenessVideoPath.value == null) {
      return false;
    }
    actionStatus(ActionStatus.loading);
    final response = await _repository.uploadLivenessEvidence(
        current['id'],
        challenge['session_id'] as int,
        challenge['nonce'] as String,
        livenessVideoPath.value!);
    actionStatus(response.status == StatusResponse.success
        ? ActionStatus.success
        : ActionStatus.failed);
    if (response.status == StatusResponse.success) {
      livenessSubmitted.value = true;
    }
    return response.status == StatusResponse.success;
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
    if (response.status != StatusResponse.success) {
      actionStatus(ActionStatus.failed);
      return false;
    }
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
      final submitted = await _repository.submit(
          current['id'], application.value!['row_version'] as int);
      actionStatus(submitted.status == StatusResponse.success
          ? ActionStatus.success
          : ActionStatus.failed);
      return submitted.status == StatusResponse.success;
    }
    actionStatus(ActionStatus.success);
    return true;
  }

  Future<void> cancel() async {
    final current = application.value;
    if (current == null) return;
    await _repository.cancel(
        current['id'], 'Dibatalkan oleh peminjam melalui Member App');
    Get.offAllNamed(Routes.LOAN_V2);
  }

  Future<String> _deviceFingerprint() async {
    final box = GetStorage();
    var installationId = box.read<String>('loan_v2_installation_id');
    if (installationId == null) {
      installationId =
          '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      box.write('loan_v2_installation_id', installationId);
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
