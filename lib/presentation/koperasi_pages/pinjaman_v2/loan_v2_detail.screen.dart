import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:jetmarket/components/button/app_button.dart';
import 'package:jetmarket/infrastructure/navigation/routes.dart';
import 'package:jetmarket/infrastructure/theme/app_colors.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';
import 'package:jetmarket/utils/extension/currency.dart';
import 'package:jetmarket/utils/loan_v2_status.dart';
import 'package:jetmarket/utils/network/action_status.dart';
import 'package:jetmarket/utils/style/app_style.dart';

class LoanV2DetailScreen extends StatefulWidget {
  const LoanV2DetailScreen({super.key});
  @override
  State<LoanV2DetailScreen> createState() => _LoanV2DetailScreenState();
}

class _LoanV2DetailScreenState extends State<LoanV2DetailScreen> {
  final controller = Get.find<LoanV2Controller>();
  late final int id;

  @override
  void initState() {
    super.initState();
    id = Get.arguments as int;
    controller.loadDetail(id);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kWhite,
        appBar: AppBar(
            backgroundColor: kWhite,
            elevation: 0,
            title: Text('Detail Pinjaman', style: text16BlackSemiBold),
            leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                onPressed: Get.back),
            actions: [
              IconButton(
                  onPressed: () => controller.loadDetail(id),
                  icon: const Icon(Icons.refresh_rounded, color: kPrimaryColor))
            ]),
        body: Obx(() {
          if (controller.loading.value) {
            return const Center(
                child: CircularProgressIndicator(color: kPrimaryColor));
          }
          final app = controller.application.value;
          if (app == null) {
            return const Center(child: Text('Data pengajuan tidak ditemukan.'));
          }
          return ListView(padding: AppStyle.paddingAll16, children: [
            _summary(app),
            Gap(14.h),
            _status(app),
            Gap(14.h),
            if (controller.interview.value != null) ...[
              _interview(),
              Gap(14.h),
            ],
            if (controller.latestFinalAgreement != null) ...[
              _agreement(),
              Gap(14.h),
            ],
            _timeline(),
            Gap(14.h),
            _installments(),
            Gap(18.h),
            _action(app)
          ]);
        }),
      );

  Widget _summary(Map<String, dynamic> app) => Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
          color: kWhite,
          borderRadius: AppStyle.borderRadius8All,
          boxShadow: [AppStyle.boxShadow]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(app['application_number']?.toString() ?? '-',
            style: text14BlackSemiBold),
        Gap(8.h),
        _line('Produk', app['product_name']?.toString() ?? '-'),
        _line(
            'Nominal',
            (app['requested_amount'] as num? ?? 0)
                .toInt()
                .toString()
                .toIdrFormat),
        _line('Tenor', '${app['tenor_months'] ?? 0} bulan'),
        _line(
            'Total Pengembalian',
            (app['total_repayment_amount'] as num? ?? 0)
                .toInt()
                .toString()
                .toIdrFormat)
      ]));

  Widget _agreement() {
    final document = controller.latestFinalAgreement!;
    final version = (document['version'] as num? ?? 1).toInt();
    final isExecuted = version >= 2 && document['status'] == 'SIGNED';
    return _section('Dokumen Perjanjian', [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isExecuted ? Icons.verified_rounded : Icons.description_rounded,
            color: isExecuted ? Colors.green : kPrimaryColor, size: 22),
        Gap(10.w),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isExecuted ? 'Perjanjian Final' : 'Draf Perjanjian',
              style: text12BlackSemiBold),
          Gap(3.h),
          Text(
              isExecuted
                  ? 'Telah ditandatangani oleh Anda dan Finance.'
                  : 'Baca dokumen ini sebelum memberikan TTD.',
              style: text10HintRegular),
        ]))
      ]),
      Gap(12.h),
      AppButton.secondary(
          text: isExecuted
              ? 'Buka / Unduh Perjanjian Final'
              : 'Buka / Unduh Draf Perjanjian',
          actionStatus: controller.actionStatus.value == ActionStatus.loading
              ? ActionStatus.loading
              : ActionStatus.initalize,
          onPressed: controller.openFinalAgreement)
    ]);
  }

  Widget _status(Map<String, dynamic> app) {
    final status = app['status']?.toString() ?? '-';
    return Container(
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
            color: kPrimaryColor2, borderRadius: AppStyle.borderRadius8All),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Status Pengajuan', style: text12BlackSemiBold),
          Gap(5.h),
          Text(loanV2StatusLabel(status), style: text14PrimarySemiBold),
          Gap(5.h),
          Text(_statusMessage(status), style: text12HintRegular)
        ]));
  }

  Widget _interview() {
    final interview = controller.interview.value!;
    final status = interview['status']?.toString() ?? '';
    final isCompleted = status == 'COMPLETED';
    return _section('Rincian Wawancara', [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isCompleted ? Icons.check_circle_rounded : Icons.event_rounded,
            color: isCompleted ? Colors.green : kPrimaryColor, size: 22),
        Gap(10.w),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isCompleted ? 'Wawancara telah selesai' : 'Wawancara dijadwalkan',
              style: text12BlackSemiBold),
          Gap(3.h),
          Text(
              isCompleted
                  ? 'Hasil wawancara sedang menjadi bagian peninjauan pengajuan.'
                  : 'Silakan hadir sesuai jadwal berikut. Penjamin juga diundang melalui email.',
              style: text10HintRegular),
        ]))
      ]),
      Gap(12.h),
      _line('Jadwal', _dateTime(interview['scheduled_at']?.toString())),
      _line('Peserta', 'Peminjam dan seluruh penjamin'),
      if (isCompleted && (interview['summary']?.toString().trim().isNotEmpty ?? false))
        _line('Ringkasan', interview['summary'].toString()),
    ]);
  }

  Widget _timeline() => _section(
      'Timeline',
      controller.timeline.isEmpty
          ? [Text('Belum ada pembaruan status.', style: text12HintRegular)]
          : controller.timeline.map((item) {
              final value = Map<String, dynamic>.from(item);
              final nextStatus = value['to_status']?.toString();
              return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.circle,
                            size: 10, color: kPrimaryColor),
                        Gap(9.w),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(
                                  nextStatus == null || nextStatus.isEmpty
                                      ? 'Pembaruan'
                                      : loanV2StatusLabel(nextStatus),
                                  style: text12BlackSemiBold),
                              Text(value['reason']?.toString() ?? '',
                                  style: text10HintRegular),
                              Text(_date(value['created_at']?.toString()),
                                  style: text10HintRegular)
                            ]))
                      ]));
            }).toList());
  Widget _installments() => _section(
      'Jadwal Angsuran',
      controller.installments.isEmpty
          ? [
              Text('Jadwal angsuran tersedia setelah pencairan.',
                  style: text12HintRegular)
            ]
          : controller.installments.map((item) {
              final value = Map<String, dynamic>.from(item);
              return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Angsuran ${value['installment_number']}',
                            style: text12BlackRegular),
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                  (value['total_amount'] as num? ?? 0)
                                      .toInt()
                                      .toString()
                                      .toIdrFormat,
                                  style: text12BlackSemiBold),
                              Text(_date(value['due_at']?.toString()),
                                  style: text10HintRegular)
                            ])
                      ]));
            }).toList());
  Widget _section(String title, List<Widget> children) => Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
          color: kWhite,
          borderRadius: AppStyle.borderRadius8All,
          boxShadow: [AppStyle.boxShadow]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: text14BlackSemiBold),
        Gap(12.h),
        ...children
      ]));
  Widget _action(Map<String, dynamic> app) {
    final status = app['status']?.toString() ?? '';
    if (status == 'BORROWER_VERIFICATION_PENDING') {
      return AppButton.primary(
          text: 'Lanjutkan Verifikasi dan TTD',
          onPressed: () =>
              Get.toNamed(Routes.LOAN_V2_APPLICATION, arguments: app));
    }
    if (status == 'DRAFT' || status == 'NEEDS_GUARANTOR_REPLACEMENT') {
      return AppButton.primary(
          text: 'Lanjutkan Pengajuan',
          onPressed: () =>
              Get.toNamed(Routes.LOAN_V2_APPLICATION, arguments: app));
    }
    if (status == 'APPROVED_AWAITING_FINAL_SIGNATURES') {
      if (!controller.borrowerFinalSignatureExists.value) {
        if (!controller.finalAgreementReadyForBorrowerSignature.value) {
          return AppButton.secondary(
              text: 'Menunggu Pengesahan Finance', onPressed: null);
        }
        return AppButton.primary(
            text: 'Tandatangani Perjanjian Akhir',
            actionStatus: controller.actionStatus.value,
            onPressed: controller.signFinalAgreementFromDetail);
      }
      final total = controller.guarantorSignatureTotal.value;
      final signed = controller.guarantorSignatureSigned.value;
      if (total > 0 && signed < total) {
        return AppButton.secondary(
            text: 'TTD Tersimpan · Menunggu TTD Penjamin ($signed/$total)',
            onPressed: null);
      }
      return AppButton.secondary(
          text: 'TTD Tersimpan · Menunggu Finance', onPressed: null);
    }
    if ([
      'DRAFT',
      'WAITING_GUARANTOR_CONFIRMATION',
      'PENDING_ADMIN_REVIEW',
      'WAITING_INTERVIEW'
    ].contains(status)) {
      return AppButton.secondary(
          text: 'Batalkan Pengajuan', onPressed: controller.cancel);
    }
    return const SizedBox.shrink();
  }

  Widget _line(String label, String value) => Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: text12HintRegular),
        Flexible(
            child:
                Text(value, textAlign: TextAlign.end, style: text12BlackMedium))
      ]));
  String _date(String? value) {
    if (value == null || value.isEmpty) return '-';
    final date = DateTime.tryParse(value);
    return date == null
        ? '-'
        : DateFormat('dd MMM yyyy', 'id_ID').format(date.toLocal());
  }

  String _dateTime(String? value) {
    if (value == null || value.isEmpty) return '-';
    final date = DateTime.tryParse(value);
    return date == null
        ? '-'
        : DateFormat('EEEE, dd MMM yyyy • HH:mm', 'id_ID')
            .format(date.toLocal());
  }

  String _statusMessage(String status) {
    const messages = {
      'DRAFT': 'Lengkapi data dan pilih penjamin untuk melanjutkan.',
      'BORROWER_VERIFICATION_PENDING':
          'Foto wajah dan active liveness sedang diverifikasi.',
      'WAITING_GUARANTOR_CONFIRMATION':
          'Menunggu konfirmasi dari seluruh penjamin.',
      'PENDING_ADMIN_REVIEW': 'Pengajuan menunggu proses admin.',
      'WAITING_INTERVIEW': 'Interview wajib sedang dijadwalkan.',
      'APPROVED_AWAITING_FINAL_SIGNATURES':
          'Baca dan tandatangani perjanjian akhir. Setelah itu Finance akan memberikan TTD akhir.',
      'AWAITING_DISBURSEMENT': 'Dokumen lengkap. Menunggu pencairan manual.',
      'DISBURSED': 'Pinjaman telah dicairkan.'
    };
    return messages[status] ??
        'Pantau pembaruan pengajuan melalui halaman ini.';
  }
}
