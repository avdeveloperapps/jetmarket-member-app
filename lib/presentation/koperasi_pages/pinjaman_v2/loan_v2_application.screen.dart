import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:jetmarket/components/button/app_button.dart';
import 'package:jetmarket/infrastructure/navigation/routes.dart';
import 'package:jetmarket/infrastructure/theme/app_colors.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/loan_active_liveness_capture.screen.dart';
import 'package:jetmarket/utils/extension/currency.dart';
import 'package:jetmarket/utils/network/action_status.dart';
import 'package:jetmarket/utils/style/app_style.dart';

class LoanV2ApplicationScreen extends StatefulWidget {
  const LoanV2ApplicationScreen({super.key});
  @override
  State<LoanV2ApplicationScreen> createState() =>
      _LoanV2ApplicationScreenState();
}

class _LoanV2ApplicationScreenState extends State<LoanV2ApplicationScreen> {
  final controller = Get.find<LoanV2Controller>();
  final _applicationFormKey = GlobalKey<FormState>();
  final purpose = TextEditingController();
  final amount = TextEditingController();
  final bank = TextEditingController();
  final account = TextEditingController();
  final holder = TextEditingController();
  final guarantorSearch = TextEditingController();
  Timer? _guarantorSearchDebounce;
  String? _confirmedTermsKey;
  Map<String, dynamic>? _confirmedPreview;
  Map<String, dynamic>? _initialApplication;
  bool _attemptedSave = false;
  bool _showKtpError = false;
  int stage = 0;

  @override
  void initState() {
    super.initState();
    _initialApplication = Get.arguments is Map<String, dynamic>
        ? Get.arguments as Map<String, dynamic>
        : null;
    controller.loadHome().then((_) async {
      final existing = _initialApplication;
      controller.prepareDraft(existing);
      if (existing != null) {
        purpose.text = existing['purpose']?.toString() ?? '';
        amount.text = existing['requested_amount']?.toString() ?? '';
        bank.text = existing['bank_name']?.toString() ?? '';
        account.text = existing['bank_account_number']?.toString() ?? '';
        holder.text = existing['bank_account_holder']?.toString() ?? '';
        controller.loadCandidates();
        final status = existing['status']?.toString();
        if (status == 'NEEDS_GUARANTOR_REPLACEMENT' || status == 'DRAFT') {
          stage = 1;
        }
        if (status == 'BORROWER_VERIFICATION_PENDING') {
          stage = 2;
          await controller.restoreLivenessStatus();
        }
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    purpose.dispose();
    amount.dispose();
    bank.dispose();
    account.dispose();
    holder.dispose();
    guarantorSearch.dispose();
    _guarantorSearchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kWhite,
        appBar: AppBar(
            backgroundColor: kWhite,
            elevation: 0,
            title: Text('Ajukan Pinjaman', style: text16BlackSemiBold),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: Get.back)),
        body: Obx(() => controller.loading.value
            ? const Center(
                child: CircularProgressIndicator(color: kPrimaryColor))
            : controller.homeLoadError.value != null &&
                    controller.products.isEmpty
                ? _loadError(controller.homeLoadError.value!)
                : _body()),
      );

  Widget _loadError(String message) => Center(
        child: Padding(
          padding: AppStyle.paddingAll16,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off_outlined, color: kSoftGrey, size: 40),
            Gap(10.h),
            Text(message,
                style: text12HintRegular, textAlign: TextAlign.center),
            Gap(14.h),
            ElevatedButton.icon(
              onPressed: _retryInitialLoad,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
            ),
          ]),
        ),
      );

  Future<void> _retryInitialLoad() async {
    await controller.loadHome();
    if (controller.homeLoadError.value == null) {
      controller.prepareDraft(_initialApplication);
    }
  }

  Widget _body() => ListView(padding: AppStyle.paddingAll16, children: [
        _stepper(),
        Gap(18.h),
        if (stage == 0)
          _form()
        else if (stage == 1)
          _guarantors()
        else
          _verification(),
      ]);

  Widget _stepper() => Row(
      children: List.generate(
          3,
          (index) => Expanded(
              child: Container(
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6.w),
                  height: 5.h,
                  decoration: BoxDecoration(
                      color: index <= stage ? kPrimaryColor : kSofterGrey,
                      borderRadius: BorderRadius.circular(5.r))))));

  Widget _form() => Form(
      key: _applicationFormKey,
      autovalidateMode: _attemptedSave
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Data Pengajuan', style: text14BlackSemiBold),
        if (_initialApplication == null &&
            controller.latestResumableApplication != null) ...[
          Gap(10.h),
          _latestApplicationCard(controller.latestResumableApplication!),
        ],
        Gap(10.h),
        _input(purpose, 'Tujuan Pinjaman',
            maxLines: 3,
            validator: (value) => value == null || value.trim().length < 3
                ? 'Tujuan pinjaman minimal 3 karakter.'
                : null),
        Gap(10.h),
        Obx(() {
          final items = controller.products;
          final selectedId = controller.selectedProductId;
          final selectedValue =
              items.any((item) => item['id'] == selectedId) ? selectedId : null;
          return DropdownButtonFormField<int>(
              key: ValueKey(selectedValue),
              initialValue: selectedValue,
              decoration: _decoration('Produk Pinjaman'),
              items: items
                  .map((product) => DropdownMenuItem<int>(
                      value: product['id'] as int,
                      child: Text(product['name']?.toString() ?? '-',
                          style: text12BlackRegular)))
                  .toList(),
              validator: (value) =>
                  value == null ? 'Produk pinjaman wajib dipilih.' : null,
              onChanged: (value) {
                if (value == null) return;
                final product = controller.chooseProductById(value);
                if (product != null) {
                  amount.text = product['min_amount'].toString();
                  _invalidateTermsConfirmation();
                }
              });
        }),
        Gap(10.h),
        _input(amount, 'Nominal Pinjaman',
            keyboard: TextInputType.number,
            validator: _validateRequestedAmount,
            onChanged: (_) => _invalidateTermsConfirmation()),
        Obx(() {
          final product = controller.selectedProduct.value;
          final minimum = _asInt(product?['min_amount']);
          final maximum = _asInt(product?['max_amount']);
          if (minimum == null || maximum == null) {
            return const SizedBox.shrink();
          }
          return Padding(
              padding: EdgeInsets.only(top: 8.h),
              child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12.r),
                  decoration: BoxDecoration(
                      color: kPrimaryColor2,
                      borderRadius: AppStyle.borderRadius8All),
                  child: Row(children: [
                    const Icon(Icons.account_balance_wallet_outlined,
                        color: kPrimaryColor),
                    Gap(10.w),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text('Batas nominal untuk produk ini',
                              style: text10HintRegular),
                          Gap(3.h),
                          Text(
                              'Minimal ${minimum.toString().toIdrFormat} · Maksimal ${maximum.toString().toIdrFormat}',
                              style: text12PrimarySemiBold)
                        ]))
                  ])));
        }),
        Gap(10.h),
        Obx(() {
          final tenors = <int, Map<String, dynamic>>{};
          for (final item in List<dynamic>.from(
              controller.selectedProduct.value?['tenors'] ?? [])) {
            if (item is! Map) continue;
            final tenor = Map<String, dynamic>.from(item);
            final months = _asInt(tenor['tenor_months']);
            if (months != null) tenors[months] = tenor;
          }
          final selectedTenor =
              tenors.containsKey(controller.selectedTenor.value)
                  ? controller.selectedTenor.value
                  : null;
          return DropdownButtonFormField<int>(
              key: ValueKey(selectedTenor),
              initialValue: selectedTenor,
              decoration: _decoration('Tenor'),
              items: tenors.entries
                  .map((entry) => DropdownMenuItem<int>(
                      value: entry.key,
                      child: Text('${entry.key} Bulan',
                          style: text12BlackRegular)))
                  .toList(),
              validator: (value) =>
                  value == null ? 'Tenor pinjaman wajib dipilih.' : null,
              onChanged: (value) {
                if (value != null) {
                  controller.selectedTenor.value = value;
                  _invalidateTermsConfirmation();
                }
              });
        }),
        Gap(10.h),
        Obx(() {
          final text = _isCurrentTermsConfirmed
              ? 'Lihat Ulang Rincian Pinjaman'
              : 'Lihat dan Konfirmasi Rincian Pinjaman';
          if (!_canPreviewTerms) {
            return AppButton.secondaryGrey(text: text);
          }
          return AppButton.secondary(
              text: text,
              actionStatus: controller.previewLoading.value
                  ? ActionStatus.loading
                  : ActionStatus.initalize,
              onPressed: _showLoanPreview);
        }),
        Gap(6.h),
        _termsConfirmationStatus(),
        Gap(10.h),
        _input(bank, 'Nama Bank',
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nama bank wajib diisi.'
                : null),
        Gap(10.h),
        _input(account, 'Nomor Rekening',
            keyboard: TextInputType.number, validator: _validateAccountNumber),
        Gap(10.h),
        _input(holder, 'Nama Pemilik Rekening',
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Nama pemilik rekening wajib diisi.'
                : null),
        Gap(12.h),
        Obx(() => _imagePicker(
            label: 'Foto KTP',
            path: controller.ktpPath.value,
            hasError: _showKtpError,
            errorText: _showKtpError ? 'Foto KTP wajib diambil.' : null,
            onTap: () async {
              await controller.pickKtp();
              if (mounted && controller.ktpPath.value != null) {
                setState(() => _showKtpError = false);
              }
            })),
        Gap(18.h),
        AppButton.primary(
            text: 'Simpan dan Pilih Penjamin',
            actionStatus: controller.actionStatus.value,
            onPressed: !_isCurrentTermsConfirmed
                ? null
                : () async {
                    FocusScope.of(context).unfocus();
                    setState(() => _attemptedSave = true);
                    final hasKtp =
                        controller.ktpPath.value?.trim().isNotEmpty == true;
                    if (!hasKtp) setState(() => _showKtpError = true);
                    if (!(_applicationFormKey.currentState?.validate() ??
                            false) ||
                        !hasKtp) {
                      Get.snackbar('Data pengajuan belum lengkap',
                          'Lengkapi atau perbaiki field yang ditandai sebelum melanjutkan.');
                      return;
                    }
                    final number = int.tryParse(amount.text) ?? 0;
                    final success = await controller.saveDraft(
                        purpose: purpose.text,
                        requestedAmount: number,
                        bankName: bank.text,
                        accountNumber: account.text,
                        accountHolder: holder.text);
                    if (!success || !mounted) return;
                    if (!_savedApplicationMatchesConfirmedPreview()) {
                      _invalidateTermsConfirmation();
                      Get.snackbar('Rincian pinjaman berubah',
                          'Konfigurasi produk berubah saat draft disimpan. Lihat dan konfirmasi rincian terbaru sebelum melanjutkan.');
                      return;
                    }
                    setState(() => stage = 1);
                  }),
      ]));

  Widget _latestApplicationCard(Map<String, dynamic> application) {
    final awaitingVerification =
        application['status']?.toString() == 'BORROWER_VERIFICATION_PENDING';
    return Container(
        width: double.infinity,
        padding: EdgeInsets.all(13.r),
        decoration: BoxDecoration(
            color: kWarning2Color,
            borderRadius: AppStyle.borderRadius8All,
            border: Border.all(color: kWarningColor.withValues(alpha: .35))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.edit_note_rounded, color: kWarningColor),
            Gap(8.w),
            Expanded(
                child: Text(
                    awaitingVerification
                        ? 'Ada pengajuan yang belum selesai'
                        : 'Ada draft yang belum selesai',
                    style: text12BlackSemiBold))
          ]),
          Gap(7.h),
          Text(
              '${application['product_name'] ?? 'Produk pinjaman'} · ${_money(application['requested_amount'])}',
              style: text12BlackRegular),
          Gap(2.h),
          Text(
              awaitingVerification
                  ? 'Verifikasi wajah atau TTD aplikasi belum selesai'
                  : application['application_number']?.toString() ??
                      'Draft terbaru',
              style: text10HintRegular),
          Gap(10.h),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: const BorderSide(color: kPrimaryColor),
                      shape: RoundedRectangleBorder(
                          borderRadius: AppStyle.borderRadius8All)),
                  onPressed: () => _continueApplication(application),
                  child: Text(
                      awaitingVerification
                          ? 'Lanjutkan Verifikasi dan TTD'
                          : 'Lanjutkan Pengisian',
                      style: text12PrimarySemiBold)))
        ]));
  }

  Future<void> _continueApplication(Map<String, dynamic> application) async {
    controller.prepareDraft(application);
    controller.selectedGuarantorIds.clear();
    controller.candidates.clear();
    controller.loanPreview.value = null;
    purpose.text = application['purpose']?.toString() ?? '';
    amount.text = application['requested_amount']?.toString() ?? '';
    bank.text = application['bank_name']?.toString() ?? '';
    account.text = application['bank_account_number']?.toString() ?? '';
    holder.text = application['bank_account_holder']?.toString() ?? '';
    guarantorSearch.clear();

    if (!mounted) return;
    final status = application['status']?.toString();
    setState(() {
      _initialApplication = application;
      _confirmedTermsKey = null;
      _confirmedPreview = null;
      stage = status == 'BORROWER_VERIFICATION_PENDING' ? 2 : 1;
    });
    if (status == 'BORROWER_VERIFICATION_PENDING') {
      await controller.restoreLivenessStatus();
    } else {
      await controller.loadCandidates();
    }
  }

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  String get _currentTermsKey =>
      '${controller.selectedProductId}:${int.tryParse(amount.text) ?? 0}:${controller.selectedTenor.value}';

  bool get _isCurrentTermsConfirmed =>
      _confirmedTermsKey != null && _confirmedTermsKey == _currentTermsKey;

  bool get _canPreviewTerms {
    final product = controller.selectedProduct.value;
    final requestedAmount = int.tryParse(amount.text) ?? 0;
    final minimum = _asInt(product?['min_amount']) ?? 0;
    final maximum = _asInt(product?['max_amount']) ?? 0;
    return product != null &&
        controller.selectedTenor.value > 0 &&
        requestedAmount >= minimum &&
        requestedAmount <= maximum;
  }

  String? _validateRequestedAmount(String? value) {
    final requestedAmount = int.tryParse(value?.trim() ?? '');
    if (requestedAmount == null || requestedAmount <= 0) {
      return 'Nominal pinjaman wajib diisi dengan angka yang valid.';
    }
    final product = controller.selectedProduct.value;
    if (product == null) return null;
    final minimum = _asInt(product['min_amount']) ?? 0;
    final maximum = _asInt(product['max_amount']) ?? 0;
    if (requestedAmount < minimum || requestedAmount > maximum) {
      return 'Masukkan nominal antara ${_money(minimum)} dan ${_money(maximum)}.';
    }
    return null;
  }

  String? _validateAccountNumber(String? value) {
    final accountNumber = value?.trim() ?? '';
    if (accountNumber.isEmpty) return 'Nomor rekening wajib diisi.';
    if (!RegExp(r'^\d+$').hasMatch(accountNumber)) {
      return 'Nomor rekening hanya boleh berisi angka.';
    }
    return null;
  }

  void _invalidateTermsConfirmation() {
    if (!mounted) return;
    setState(() {
      _confirmedTermsKey = null;
      _confirmedPreview = null;
    });
    controller.loanPreview.value = null;
  }

  Widget _termsConfirmationStatus() => Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
          color: _isCurrentTermsConfirmed ? kSuccessColor2 : kWarning2Color,
          borderRadius: AppStyle.borderRadius8All),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            _isCurrentTermsConfirmed
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: _isCurrentTermsConfirmed ? kSuccessColor : kWarningColor),
        Gap(8.w),
        Expanded(
            child: Text(
                _isCurrentTermsConfirmed
                    ? 'Rincian untuk nominal dan tenor ini sudah dikonfirmasi.'
                    : !_canPreviewTerms
                        ? 'Pilih produk, masukkan nominal sesuai batas, lalu pilih tenor untuk melihat rincian.'
                        : 'Rincian siap dilihat. Wajib konfirmasi sebelum menyimpan pengajuan.',
                style: text10HintRegular))
      ]));

  Future<void> _showLoanPreview() async {
    FocusScope.of(context).unfocus();
    final requestedAmount = int.tryParse(amount.text) ?? 0;
    final product = controller.selectedProduct.value;
    final minimum = _asInt(product?['min_amount']) ?? 0;
    final maximum = _asInt(product?['max_amount']) ?? 0;
    if (product == null || controller.selectedTenor.value <= 0) {
      Get.snackbar('Data belum lengkap',
          'Pilih produk pinjaman dan tenor terlebih dahulu.');
      return;
    }
    if (requestedAmount < minimum || requestedAmount > maximum) {
      Get.snackbar('Nominal di luar batas',
          'Masukkan nominal antara ${_money(minimum)} dan ${_money(maximum)}.');
      return;
    }

    final termsKey = _currentTermsKey;
    final preview = await controller.previewApplication(requestedAmount);
    if (!mounted || preview == null || termsKey != _currentTermsKey) return;
    final confirmed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: kWhite,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(18.r))),
        builder: (sheetContext) => _loanPreviewSheet(sheetContext, preview));
    if (!mounted || confirmed != true || termsKey != _currentTermsKey) return;
    setState(() {
      _confirmedTermsKey = termsKey;
      _confirmedPreview = Map<String, dynamic>.from(preview);
    });
  }

  Widget _loanPreviewSheet(
          BuildContext sheetContext, Map<String, dynamic> preview) =>
      SafeArea(
          child: SizedBox(
              height: MediaQuery.sizeOf(sheetContext).height * .92,
              child: Column(children: [
                Padding(
                    padding: EdgeInsets.fromLTRB(18.w, 12.h, 8.w, 10.h),
                    child: Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Rincian Pinjaman',
                                style: text16BlackSemiBold),
                            Text(
                                '${preview['product_name']} · ${preview['tenor_months']} bulan',
                                style: text12HintRegular)
                          ])),
                      IconButton(
                          onPressed: () => Navigator.pop(sheetContext, false),
                          icon: const Icon(Icons.close_rounded))
                    ])),
                Divider(height: 1, color: kDivider),
                Expanded(
                    child: ListView(
                        padding: EdgeInsets.all(16.r),
                        children: _loanPreviewContent(preview))),
                Container(
                    padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 14.h),
                    decoration: BoxDecoration(
                        color: kWhite,
                        border: Border(top: BorderSide(color: kDivider))),
                    child: AppButton.primary(
                        text: 'Saya Mengerti dan Konfirmasi',
                        onPressed: () => Navigator.pop(sheetContext, true)))
              ])));

  List<Widget> _loanPreviewContent(Map<String, dynamic> preview) {
    final installments = List<dynamic>.from(preview['installments'] ?? [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final interestMonthly = _componentRange(installments, 'interest_amount');
    final installmentMin = _asInt(preview['installment_min_amount']) ?? 0;
    final installmentMax = _asInt(preview['installment_max_amount']) ?? 0;
    final installmentValue = installmentMin == installmentMax
        ? _money(installmentMin)
        : '${_money(installmentMin)} - ${_money(installmentMax)}';
    final description = preview['product_description']?.toString().trim() ?? '';

    return [
      Container(
          padding: EdgeInsets.all(14.r),
          decoration: BoxDecoration(
              color: kPrimaryColor2, borderRadius: AppStyle.borderRadius8All),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ringkasan', style: text14BlackSemiBold),
            Gap(10.h),
            _previewLine(
                'Dana diterima', _money(preview['disbursement_amount']),
                strong: true),
            _previewLine('Tenor', '${preview['tenor_months']} bulan'),
            _previewLine('Cicilan per bulan', installmentValue, strong: true),
            _previewLine('Total biaya', _money(preview['total_cost_amount'])),
            _previewLine(
                'Total pengembalian', _money(preview['total_repayment_amount']),
                strong: true),
            Gap(4.h),
            Text(
                'Dana diterima utuh. Bunga dan biaya dibayarkan melalui cicilan, bukan dipotong saat pencairan.',
                style: text10HintRegular)
          ])),
      Gap(16.h),
      _previewSection('Rincian Pokok, Bunga, dan Biaya', [
        _previewLine('Pokok pinjaman', _money(preview['requested_amount'])),
        _previewLine('Bunga flat total', _money(preview['interest_amount']),
            detail:
                '${_bpsPercent(preview['interest_rate_bps'])} dari pokok untuk seluruh tenor ${preview['tenor_months']} bulan'),
        _previewLine('Bunga per bulan', interestMonthly,
            detail: 'Pembagian tepat dapat berbeda Rp1 karena pembulatan.'),
        _previewLine('Biaya layanan', _money(preview['service_fee_amount']),
            detail: _feeRule(preview['service_fee_type'],
                preview['service_fee_value'], 'pokok pinjaman')),
        _previewLine('Biaya dokumen', _money(preview['document_fee_amount']),
            detail: 'Termasuk biaya dokumen yang dikonfigurasi untuk produk.'),
        _previewLine('Total biaya', _money(preview['total_cost_amount']),
            detail: 'Bunga + biaya layanan + biaya dokumen.'),
        _previewLine(
            'Total pengembalian', _money(preview['total_repayment_amount']),
            strong: true)
      ]),
      Gap(16.h),
      _previewSection('Rincian Setiap Cicilan', [
        Text(
            'Jatuh tempo setiap tanggal ${preview['due_day']}, mulai bulan setelah dana dicairkan.',
            style: text10HintRegular),
        Gap(10.h),
        ...installments.map(_installmentCard)
      ]),
      Gap(16.h),
      _previewSection('Ketentuan Produk', [
        _previewLine('Kode produk', preview['product_code']?.toString() ?? '-'),
        if (description.isNotEmpty)
          _previewLine('Deskripsi produk', description),
        _previewLine('Metode cicilan', _installmentMethod(preview)),
        _previewLine('Nominal produk',
            '${_money(preview['min_amount'])} - ${_money(preview['max_amount'])}'),
        _previewLine('Tenor tersedia',
            '${List<dynamic>.from(preview['allowed_tenors_months'] ?? []).join(', ')} bulan'),
        _previewLine(
            'Tanggal jatuh tempo', 'Setiap tanggal ${preview['due_day']}'),
        _previewLine('Masa tenggang', _gracePeriod(preview)),
        _previewLine('Denda keterlambatan', _lateFeeRule(preview),
            detail:
                'Denda tidak termasuk total pengembalian normal dan hanya berlaku jika cicilan melewati masa tenggang.'),
        _previewLine('Aturan pembulatan',
            'Dibulatkan ke atas per ${_money(preview['rounding_unit'])}',
            detail: 'Berlaku pada total bunga, biaya layanan, dan denda.'),
        _previewLine(
            'Penjamin wajib', '${preview['required_guarantors']} karyawan'),
        _previewLine('Batas pinjaman aktif',
            '${preview['max_active_applications']} pengajuan aktif untuk produk ini'),
        _previewLine('Dana produk tersedia saat ini',
            _money(preview['revolving_fund_available_amount']),
            detail:
                'Bersifat dinamis. Persetujuan tetap mengikuti ketersediaan dana saat diproses.')
      ]),
      Gap(16.h),
      Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
              color: kWarning2Color, borderRadius: AppStyle.borderRadius8All),
          child: Text(
              'Tanggal cicilan yang pasti baru terbentuk setelah pencairan. Rincian ini bukan persetujuan pinjaman; pengajuan tetap melalui konfirmasi penjamin, interview, dan persetujuan admin.',
              style: text10HintRegular))
    ];
  }

  Widget _previewSection(String title, List<Widget> children) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: text14BlackSemiBold),
        Gap(8.h),
        Container(
            width: double.infinity,
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
                border: Border.all(color: kBorder),
                borderRadius: AppStyle.borderRadius8All),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children))
      ]);

  Widget _previewLine(String label, String value,
          {String? detail, bool strong = false}) =>
      Padding(
          padding: EdgeInsets.only(bottom: 9.h),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(label, style: text10HintRegular)),
              Gap(12.w),
              Flexible(
                  child: Text(value,
                      textAlign: TextAlign.right,
                      style: strong ? text12BlackSemiBold : text12BlackRegular))
            ]),
            if (detail != null) ...[
              Gap(2.h),
              Text(detail, style: text10HintRegular)
            ]
          ]));

  Widget _installmentCard(Map<String, dynamic> installment) => Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(11.r),
      decoration: BoxDecoration(
          color: kAccentColor, borderRadius: AppStyle.borderRadius8All),
      child: Column(children: [
        _previewLine('Cicilan ke-${installment['installment_number']}',
            _money(installment['total_amount']),
            strong: true),
        _previewLine('Pokok', _money(installment['principal_amount'])),
        _previewLine('Bunga', _money(installment['interest_amount'])),
        _previewLine(
            'Biaya layanan', _money(installment['service_fee_amount'])),
        _previewLine(
            'Biaya dokumen', _money(installment['document_fee_amount']))
      ]));

  String _componentRange(List<Map<String, dynamic>> installments, String key) {
    if (installments.isEmpty) return _money(0);
    final values = installments.map((item) => _asInt(item[key]) ?? 0).toList();
    final minimum = values.reduce((a, b) => a < b ? a : b);
    final maximum = values.reduce((a, b) => a > b ? a : b);
    return minimum == maximum
        ? _money(minimum)
        : '${_money(minimum)} - ${_money(maximum)}';
  }

  String _money(dynamic value) => (_asInt(value) ?? 0).toString().toIdrFormat;

  String _bpsPercent(dynamic value) {
    final basisPoints = _asInt(value) ?? 0;
    final percentage = basisPoints / 100;
    return '${percentage.toStringAsFixed(percentage.truncateToDouble() == percentage ? 0 : 2)}%';
  }

  String _feeRule(dynamic type, dynamic value, String percentageBase) {
    final amount = _asInt(value) ?? 0;
    if (amount == 0) return 'Tidak ada biaya';
    if (type?.toString() == 'PERCENTAGE') {
      return '${_bpsPercent(amount)} dari $percentageBase';
    }
    return '${_money(amount)} tetap';
  }

  String _lateFeeRule(Map<String, dynamic> preview) {
    final value = _asInt(preview['late_fee_value']) ?? 0;
    if (value == 0) return 'Tidak ada denda';
    if (preview['late_fee_type']?.toString() == 'PERCENTAGE') {
      return '${_bpsPercent(value)} dari sisa tagihan, dikenakan satu kali';
    }
    return '${_money(value)} tetap, dikenakan satu kali';
  }

  String _gracePeriod(Map<String, dynamic> preview) {
    final days = _asInt(preview['grace_period_days']) ?? 0;
    return days == 0 ? 'Tidak ada masa tenggang' : '$days hari';
  }

  String _installmentMethod(Map<String, dynamic> preview) =>
      preview['installment_method']?.toString() == 'FLAT'
          ? 'Flat'
          : preview['installment_method']?.toString() ?? '-';

  bool _savedApplicationMatchesConfirmedPreview() {
    final application = controller.application.value;
    final preview = _confirmedPreview;
    if (application == null || preview == null) return false;
    return _asInt(application['loan_product_id']) ==
            _asInt(preview['product_id']) &&
        _asInt(application['requested_amount']) ==
            _asInt(preview['requested_amount']) &&
        _asInt(application['tenor_months']) ==
            _asInt(preview['tenor_months']) &&
        _asInt(application['principal_amount']) ==
            _asInt(preview['disbursement_amount']) &&
        _asInt(application['interest_amount']) ==
            _asInt(preview['interest_amount']) &&
        _asInt(application['service_fee_amount']) ==
            _asInt(preview['service_fee_amount']) &&
        _asInt(application['document_fee_amount']) ==
            _asInt(preview['document_fee_amount']) &&
        _asInt(application['total_repayment_amount']) ==
            _asInt(preview['total_repayment_amount']);
  }

  Widget _guarantors() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pilih Penjamin', style: text14BlackSemiBold),
        Gap(5.h),
        Text(
            'Pilih tepat ${controller.application.value?['required_guarantors'] ?? 0} rekan karyawan sebagai penjamin.',
            style: text12HintRegular),
        Gap(12.h),
        TextField(
            controller: guarantorSearch,
            onChanged: _searchGuarantors,
            style: text12BlackRegular,
            decoration: _decoration('Cari nama atau email penjamin').copyWith(
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: guarantorSearch.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _clearGuarantorSearch))),
        Gap(10.h),
        Obx(() {
          if (controller.candidatesLoading.value) {
            return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: CircularProgressIndicator(color: kPrimaryColor)));
          }
          if (controller.candidates.isEmpty) {
            return Padding(
                padding: EdgeInsets.symmetric(vertical: 18.h),
                child: Text(
                    guarantorSearch.text.trim().isEmpty
                        ? 'Belum ada penjamin yang memenuhi syarat.'
                        : 'Penjamin tidak ditemukan. Coba nama atau email lain.',
                    style: text12HintRegular));
          }
          return Column(
              children: controller.candidates.map((item) {
            final candidate = Map<String, dynamic>.from(item);
            final id = candidate['customer_id'] as int;
            return CheckboxListTile(
                value: controller.selectedGuarantorIds.contains(id),
                activeColor: kPrimaryColor,
                contentPadding: EdgeInsets.zero,
                title: Text(candidate['name']?.toString() ?? '-',
                    style: text12BlackSemiBold),
                subtitle: Text(
                    '${candidate['employee_number']} · ${candidate['division']}\n${candidate['email'] ?? '-'}',
                    style: text10HintRegular),
                isThreeLine: true,
                onChanged: (selected) {
                  final needed = controller
                          .application.value?['required_guarantors'] as int? ??
                      0;
                  if (selected == true &&
                      controller.selectedGuarantorIds.length < needed) {
                    controller.selectedGuarantorIds.add(id);
                  }
                  if (selected == false) {
                    controller.selectedGuarantorIds.remove(id);
                  }
                });
          }).toList());
        }),
        Gap(18.h),
        AppButton.primary(
            text: 'Lanjut Verifikasi Wajah',
            actionStatus: controller.actionStatus.value,
            onPressed: () async {
              if (await controller.saveGuarantors() && mounted) {
                setState(() => stage = 2);
              }
            }),
      ]);

  void _searchGuarantors(String query) {
    setState(() {});
    _guarantorSearchDebounce?.cancel();
    _guarantorSearchDebounce = Timer(const Duration(milliseconds: 350), () {
      controller.loadCandidates(query.trim());
    });
  }

  void _clearGuarantorSearch() {
    guarantorSearch.clear();
    _searchGuarantors('');
  }

  Widget _verification() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verifikasi dan TTD', style: text14BlackSemiBold),
        Gap(5.h),
        Text(
            'Ikuti verifikasi wajah secara realtime menggunakan kamera depan. Anda akan diminta melihat kiri, kanan, atas, bawah, dan berkedip dalam urutan acak.',
            style: text12HintRegular),
        Gap(14.h),
        Obx(() {
          final verified = controller.isLivenessVerified;
          final submitted = controller.livenessSubmitted.value;
          final statusCheckFailed = controller.livenessStatusCheckFailed;
          if (submitted) {
            return Column(children: [
              Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(13.r),
                  decoration: BoxDecoration(
                      color: verified ? kSuccessColor2 : kWarning2Color,
                      borderRadius: AppStyle.borderRadius8All),
                  child: Row(children: [
                    if (verified)
                      const Icon(Icons.verified_user_outlined,
                          color: kSuccessColor)
                    else if (statusCheckFailed)
                      const Icon(Icons.sync_problem_rounded,
                          color: kWarningColor)
                    else
                      SizedBox(
                          width: 22.r,
                          height: 22.r,
                          child: const CircularProgressIndicator(
                              strokeWidth: 2.5, color: kWarningColor)),
                    Gap(9.w),
                    Expanded(
                        child: Text(
                            verified
                                ? 'Active liveness berhasil diverifikasi.'
                                : statusCheckFailed
                                    ? 'Video sudah diamankan, tetapi status pemeriksaan belum dapat dimuat.'
                                    : 'Video sudah diamankan. Sistem sedang memeriksa wajah, gerakan, dan indikasi manipulasi.',
                            style: text12BlackRegular))
                  ])),
              if (statusCheckFailed) ...[
                Gap(8.h),
                AppButton.secondary(
                    text: 'Periksa Ulang Status',
                    onPressed: controller.retryLivenessStatus),
              ]
            ]);
          }
          return AppButton.primary(
              text: 'Mulai Active Liveness',
              actionStatus:
                  controller.actionStatus.value == ActionStatus.loading
                      ? ActionStatus.loading
                      : ActionStatus.initalize,
              onPressed: _startActiveLiveness);
        }),
        Gap(16.h),
        Obx(() => controller.isLivenessVerified
            ? _imagePicker(
                label: 'TTD Dokumen Aplikasi',
                path: controller.signaturePath.value,
                onTap: controller.pickSignature)
            : Text(
                controller.livenessSubmitted.value
                    ? 'TTD tersedia setelah pemeriksaan active liveness berhasil.'
                    : 'TTD tersedia setelah active liveness berhasil diverifikasi.',
                style: text12HintRegular)),
        Gap(10.h),
        Obx(() => AppButton.primary(
            text: 'TTD dan Kirim Pengajuan',
            actionStatus: controller.actionStatus.value,
            onPressed: !controller.isLivenessVerified ||
                    controller.signaturePath.value == null
                ? null
                : () async {
                    final success = await controller.sign('APPLICATION');
                    if (success && mounted) await _openLoanHome();
                  })),
      ]);

  Future<void> _openLoanHome() async {
    // Pop before binding another loan route. Otherwise GetX can reuse the
    // controller owned by this form and dispose it during the transition.
    Get.back(result: true);
    await Future<void>.delayed(Duration.zero);
    if (Get.currentRoute == Routes.LOAN_V2) return;

    if (Get.currentRoute == Routes.LOAN_V2_DETAIL) {
      Get.back(result: true);
      await Future<void>.delayed(Duration.zero);
      if (Get.currentRoute == Routes.LOAN_V2) return;
    }

    // The legacy loan menu opens this form directly. Remove this route first
    // so GetX disposes its route-scoped controller before binding loan home.
    Get.toNamed(Routes.LOAN_V2);
  }

  Future<void> _startActiveLiveness() async {
    final videoPath = await Navigator.of(context).push<String>(
        MaterialPageRoute<String>(
            fullscreenDialog: true,
            builder: (_) =>
                LoanActiveLivenessCaptureScreen(controller: controller)));
    if (!mounted || videoPath == null) return;
    controller.livenessVideoPath.value = videoPath;
    final submitted = await controller.submitLivenessEvidence();
    if (!mounted || submitted) return;
    Get.snackbar('Active liveness gagal dikirim',
        'Rekaman tidak dapat dikirim. Periksa koneksi lalu coba kembali.');
  }

  Widget _imagePicker(
          {required String label,
          required String? path,
          required VoidCallback onTap,
          bool hasError = false,
          String? errorText}) =>
      InkWell(
          onTap: onTap,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: double.infinity,
                padding: EdgeInsets.all(14.r),
                decoration: BoxDecoration(
                    border: Border.all(color: hasError ? Colors.red : kBorder),
                    borderRadius: AppStyle.borderRadius8All),
                child: Row(children: [
                  Icon(
                      path == null
                          ? Icons.camera_alt_outlined
                          : Icons.check_circle_outline,
                      color: path == null
                          ? (hasError ? Colors.red : kSoftBlack)
                          : kSuccessColor),
                  Gap(10.w),
                  Expanded(
                      child: Text(
                          path == null
                              ? '$label: ambil dengan kamera'
                              : '$label sudah dipilih',
                          style: text12BlackRegular)),
                  const Icon(Icons.chevron_right_rounded)
                ])),
            if (errorText != null) ...[
              Gap(5.h),
              Text(errorText,
                  style: text10HintRegular.copyWith(color: Colors.red))
            ]
          ]));

  InputDecoration _decoration(String label) => InputDecoration(
      labelText: label,
      labelStyle: text12HintRegular,
      border: OutlineInputBorder(
          borderRadius: AppStyle.borderRadius8All,
          borderSide: BorderSide(color: kBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: AppStyle.borderRadius8All,
          borderSide: BorderSide(color: kBorder)));
  Widget _input(TextEditingController value, String label,
          {int maxLines = 1,
          TextInputType? keyboard,
          ValueChanged<String>? onChanged,
          String? Function(String?)? validator}) =>
      TextFormField(
          controller: value,
          maxLines: maxLines,
          keyboardType: keyboard,
          onChanged: onChanged,
          validator: validator,
          style: text12BlackRegular,
          decoration: _decoration(label));
}
