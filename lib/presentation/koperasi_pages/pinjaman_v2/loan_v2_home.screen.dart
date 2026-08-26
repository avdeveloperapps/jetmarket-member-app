import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:get/get.dart';
import 'package:jetmarket/infrastructure/navigation/routes.dart';
import 'package:jetmarket/infrastructure/theme/app_colors.dart';
import 'package:jetmarket/infrastructure/theme/app_text.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';
import 'package:jetmarket/utils/extension/currency.dart';
import 'package:jetmarket/utils/style/app_style.dart';

class LoanV2HomeScreen extends StatefulWidget {
  const LoanV2HomeScreen({super.key});

  @override
  State<LoanV2HomeScreen> createState() => _LoanV2HomeScreenState();
}

class _LoanV2HomeScreenState extends State<LoanV2HomeScreen> {
  final controller = Get.find<LoanV2Controller>();

  @override
  void initState() {
    super.initState();
    controller.loadHome();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kWhite,
      appBar: AppBar(
        backgroundColor: kWhite,
        elevation: 0,
        title: Text('Pinjaman', style: text16BlackSemiBold),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: Get.back),
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor));
        }
        final canApply = controller.eligibility['eligible'] == true;
        final reasons =
            List<dynamic>.from(controller.eligibility['reasons'] ?? []);
        return RefreshIndicator(
          color: kPrimaryColor,
          onRefresh: controller.loadHome,
          child: ListView(padding: AppStyle.paddingAll16, children: [
            _hero(canApply, reasons),
            Gap(20.h),
            Text('Pengajuan Saya', style: text14BlackSemiBold),
            Gap(10.h),
            if (controller.applications.isEmpty)
              _empty()
            else
              ...controller.applications.map(
                  (item) => _applicationCard(Map<String, dynamic>.from(item))),
          ]),
        );
      }),
    );
  }

  Widget _hero(bool canApply, List<dynamic> reasons) => Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
            color: kPrimaryColor2, borderRadius: AppStyle.borderRadius8All),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pinjaman Karyawan', style: text16PrimarySemiBold),
          Gap(6.h),
          Text(
              canApply
                  ? 'Ajukan pinjaman dan pantau prosesnya langsung dari aplikasi.'
                  : (reasons.isEmpty
                      ? 'Data karyawan belum memenuhi syarat pengajuan.'
                      : reasons.join('\n')),
              style: text12HintRegular),
          Gap(14.h),
          SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kSecondaryColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r))),
                onPressed: canApply
                    ? () => Get.toNamed(Routes.LOAN_V2_APPLICATION)
                    : null,
                child: Text('Ajukan Pinjaman', style: text12WhiteMedium),
              )),
        ]),
      );

  Widget _empty() => Container(
        padding: EdgeInsets.all(20.r),
        decoration: BoxDecoration(
            color: kWhite,
            borderRadius: AppStyle.borderRadius8All,
            boxShadow: [AppStyle.boxShadow]),
        child: Column(children: [
          const Icon(Icons.description_outlined, color: kSoftGrey, size: 36),
          Gap(8.h),
          Text('Belum ada pengajuan pinjaman.', style: text12HintRegular)
        ]),
      );

  Widget _applicationCard(Map<String, dynamic> item) => Padding(
        padding: EdgeInsets.only(bottom: 10.h),
        child: InkWell(
          borderRadius: AppStyle.borderRadius8All,
          onTap: () =>
              Get.toNamed(Routes.LOAN_V2_DETAIL, arguments: item['id']),
          child: Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
                color: kWhite,
                borderRadius: AppStyle.borderRadius8All,
                boxShadow: [AppStyle.boxShadow]),
            child: Row(children: [
              const CircleAvatar(
                  backgroundColor: kSecondaryColor2,
                  child: Icon(Icons.account_balance_outlined,
                      color: kPrimaryColor)),
              Gap(12.w),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item['application_number']?.toString() ?? 'Pengajuan',
                        style: text12BlackSemiBold),
                    Gap(3.h),
                    Text(item['product_name']?.toString() ?? '-',
                        style: text10HintRegular),
                    Gap(5.h),
                    Text(
                        (item['requested_amount'] as num? ?? 0)
                            .toInt()
                            .toString()
                            .toIdrFormat,
                        style: text12PrimarySemiBold)
                  ])),
              _status(item['status']?.toString() ?? ''),
            ]),
          ),
        ),
      );

  Widget _status(String status) {
    final success = ['DISBURSED', 'COMPLETED'].contains(status);
    final failed = ['REJECTED', 'CANCELLED', 'EXPIRED'].contains(status);
    return Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
        decoration: BoxDecoration(
            color: success
                ? kSuccessColor2
                : failed
                    ? kPrimaryColor2
                    : kWarning2Color,
            borderRadius: BorderRadius.circular(6.r)),
        child: Text(status.replaceAll('_', ' '),
            style: text8GreyRegular.copyWith(
                color: success
                    ? kSuccessColor
                    : failed
                        ? kPrimaryColor
                        : kWarningColor)));
  }
}
