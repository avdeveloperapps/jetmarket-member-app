import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:jetmarket/components/button/app_button.dart';
import 'package:jetmarket/infrastructure/navigation/routes.dart';
import 'package:jetmarket/infrastructure/theme/app_colors.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';
import 'package:jetmarket/utils/style/app_style.dart';

class LoanV2ApplicationScreen extends StatefulWidget {
  const LoanV2ApplicationScreen({super.key});
  @override
  State<LoanV2ApplicationScreen> createState() =>
      _LoanV2ApplicationScreenState();
}

class _LoanV2ApplicationScreenState extends State<LoanV2ApplicationScreen> {
  final controller = Get.find<LoanV2Controller>();
  final purpose = TextEditingController();
  final amount = TextEditingController();
  final bank = TextEditingController();
  final account = TextEditingController();
  final holder = TextEditingController();
  int stage = 0;

  @override
  void initState() {
    super.initState();
    controller.loadHome().then((_) {
      final existing = Get.arguments is Map<String, dynamic>
          ? Get.arguments as Map<String, dynamic>
          : null;
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
        }
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
            : _body()),
      );

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

  Widget _form() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Data Pengajuan', style: text14BlackSemiBold),
        Gap(10.h),
        _input(purpose, 'Tujuan Pinjaman', maxLines: 3),
        Gap(10.h),
        Obx(() {
          final items = controller.products;
          final selectedId = controller.selectedProductId;
          final selectedValue = items.any((item) => item['id'] == selectedId)
              ? selectedId
              : null;
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
              onChanged: (value) {
                if (value == null) return;
                final product = controller.chooseProductById(value);
                if (product != null) {
                  amount.text = product['min_amount'].toString();
                }
              });
        }),
        Gap(10.h),
        _input(amount, 'Nominal Pinjaman', keyboard: TextInputType.number),
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
          final selectedTenor = tenors.containsKey(controller.selectedTenor.value)
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
              onChanged: (value) {
                if (value != null) controller.selectedTenor.value = value;
              });
        }),
        Gap(10.h),
        _input(bank, 'Nama Bank'),
        Gap(10.h),
        _input(account, 'Nomor Rekening', keyboard: TextInputType.number),
        Gap(10.h),
        _input(holder, 'Nama Pemilik Rekening'),
        Gap(12.h),
        Obx(() => _imagePicker(
            label: 'Foto KTP',
            path: controller.ktpPath.value,
            onTap: controller.pickKtp)),
        Gap(18.h),
        AppButton.primary(
            text: 'Simpan dan Pilih Penjamin',
            actionStatus: controller.actionStatus.value,
            onPressed: () async {
              final number = int.tryParse(amount.text) ?? 0;
              final success = await controller.saveDraft(
                  purpose: purpose.text,
                  requestedAmount: number,
                  bankName: bank.text,
                  accountNumber: account.text,
                  accountHolder: holder.text);
              if (success && mounted) setState(() => stage = 1);
            }),
      ]);

  int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value?.toString() ?? '');
  }

  Widget _guarantors() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pilih Penjamin', style: text14BlackSemiBold),
        Gap(5.h),
        Text(
            'Pilih tepat ${controller.application.value?['required_guarantors'] ?? 0} rekan karyawan sebagai penjamin.',
            style: text12HintRegular),
        Gap(12.h),
        Obx(() => Column(
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
                      '${candidate['employee_number']} · ${candidate['division']}',
                      style: text10HintRegular),
                  onChanged: (selected) {
                    final needed = controller.application
                            .value?['required_guarantors'] as int? ??
                        0;
                    if (selected == true &&
                        controller.selectedGuarantorIds.length < needed) {
                      controller.selectedGuarantorIds.add(id);
                    }
                    if (selected == false) {
                      controller.selectedGuarantorIds.remove(id);
                    }
                  });
            }).toList())),
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

  Widget _verification() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Verifikasi dan TTD', style: text14BlackSemiBold),
        Gap(5.h),
        Text(
            'Ambil foto wajah, lalu ikuti tantangan active liveness dengan kamera depan. Video liveness dan gambar TTD dikirim melalui jalur terenkripsi.',
            style: text12HintRegular),
        Gap(14.h),
        Obx(() => _imagePicker(
            label: 'Foto Wajah',
            path: controller.facePath.value,
            onTap: controller.pickFace)),
        Gap(10.h),
        AppButton.secondary(
            text: 'Kirim Verifikasi Wajah',
            actionStatus: controller.actionStatus.value,
            onPressed: controller.facePath.value == null
                ? null
                : () async {
                    final success = await controller.submitFaceVerification();
                    if (success && mounted) setState(() {});
                  }),
        Gap(14.h),
        Obx(() {
          final challenge = controller.livenessChallenge.value;
          if (challenge == null) return const SizedBox.shrink();
          final actions = List<dynamic>.from(challenge['actions'] ?? []);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tantangan active liveness', style: text14BlackSemiBold),
                Gap(5.h),
                Text(
                    'Rekam satu video sambil mengikuti urutan ini: ${actions.map(_livenessLabel).join(' → ')}.',
                    style: text12HintRegular),
                Gap(10.h),
                _imagePicker(
                    label: 'Video active liveness',
                    path: controller.livenessVideoPath.value,
                    onTap: controller.pickLivenessVideo),
                Gap(10.h),
                AppButton.secondary(
                    text: 'Kirim Video Active Liveness',
                    actionStatus: controller.actionStatus.value,
                    onPressed: controller.livenessVideoPath.value == null
                        ? null
                        : () async {
                            await controller.submitLivenessEvidence();
                          }),
              ]);
        }),
        Gap(16.h),
        Obx(() => controller.livenessSubmitted.value
            ? _imagePicker(
                label: 'Gambar TTD Dokumen Aplikasi',
                path: controller.signaturePath.value,
                onTap: controller.pickSignature)
            : Text(
                'TTD tersedia setelah video active liveness berhasil dikirim.',
                style: text12HintRegular)),
        Gap(10.h),
        Obx(() => AppButton.primary(
            text: 'TTD dan Kirim Pengajuan',
            actionStatus: controller.actionStatus.value,
            onPressed: !controller.livenessSubmitted.value ||
                    controller.signaturePath.value == null
                ? null
                : () async {
                    final success = await controller.sign('APPLICATION');
                    if (success) Get.offAllNamed(Routes.LOAN_V2);
                  })),
      ]);

  Widget _imagePicker(
          {required String label,
          required String? path,
          required VoidCallback onTap}) =>
      InkWell(
          onTap: onTap,
          child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(14.r),
              decoration: BoxDecoration(
                  border: Border.all(color: kBorder),
                  borderRadius: AppStyle.borderRadius8All),
              child: Row(children: [
                Icon(
                    path == null
                        ? Icons.camera_alt_outlined
                        : Icons.check_circle_outline,
                    color: path == null ? kSoftBlack : kSuccessColor),
                Gap(10.w),
                Expanded(
                    child: Text(
                        path == null
                            ? '$label: ambil dengan kamera'
                            : '$label sudah dipilih',
                        style: text12BlackRegular)),
                const Icon(Icons.chevron_right_rounded)
              ])));

  String _livenessLabel(dynamic action) => switch (action.toString()) {
        'TURN_LEFT' => 'lihat kiri',
        'TURN_RIGHT' => 'lihat kanan',
        'LOOK_UP' => 'lihat atas',
        'LOOK_DOWN' => 'lihat bawah',
        'BLINK' => 'kedip',
        _ => action.toString(),
      };
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
          {int maxLines = 1, TextInputType? keyboard}) =>
      TextField(
          controller: value,
          maxLines: maxLines,
          keyboardType: keyboard,
          style: text12BlackRegular,
          decoration: _decoration(label));
}
