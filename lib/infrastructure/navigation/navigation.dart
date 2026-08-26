import 'package:get/get.dart';

import 'package:jetmarket/infrastructure/middleware/deeplink_middleware.dart';

import '../../presentation/screens.dart';
import '../middleware/notification_middleware.dart';
import '../middleware/onboarding_middleware.dart';
import 'bindings/controllers/controllers_bindings.dart';
import 'routes.dart';

// class EnvironmentsBadge extends StatelessWidget {
//   final Widget child;
//   const EnvironmentsBadge({super.key, required this.child});
//   @override
//   Widget build(BuildContext context) {
//     var env = ConfigEnvironments.getEnvironments()['env'];
//     return env != Environments.PRODUCTION
//         ? Banner(
//             location: BannerLocation.topStart,
//             message: env!,
//             color: env == Environments.QAS ? Colors.blue : Colors.purple,
//             child: child,
//           )
//         : SizedBox(child: child);
//   }
// }

class Nav {
  static List<GetPage> routes = [
    GetPage(
      name: Routes.HOME,
      page: () => const HomeScreen(),
      binding: HomeControllerBinding(),
    ),
    GetPage(
        name: Routes.SPLASH_SCREEN,
        page: () => const SplashScreenScreen(),
        binding: SplashScreenControllerBinding()),
    GetPage(
      name: Routes.ONBOARDING,
      page: () => const OnboardingScreen(),
      binding: OnboardingControllerBinding(),
    ),
    GetPage(
        name: Routes.LOGIN,
        page: () => const LoginScreen(),
        binding: LoginControllerBinding(),
        middlewares: [OnboardingMiddleware()]),
    GetPage(
      name: Routes.REGISTER,
      page: () => const RegisterScreen(),
      binding: RegisterControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYMENT_REGISTER,
      page: () => const PaymentRegisterScreen(),
      binding: PaymentRegisterControllerBinding(),
    ),
    GetPage(
      name: Routes.FORGOT_PASSWORD,
      page: () => const ForgotPasswordScreen(),
      binding: ForgotPasswordControllerBinding(),
    ),
    GetPage(
      name: Routes.OTP,
      page: () => const OtpScreen(),
      binding: OtpControllerBinding(),
    ),
    GetPage(
      name: Routes.RESET_PASSWORD,
      page: () => const ResetPasswordScreen(),
      binding: ResetPasswordControllerBinding(),
    ),
    GetPage(
      name: Routes.ORDER,
      page: () => const OrderScreen(),
      binding: OrderControllerBinding(),
    ),
    GetPage(
      name: Routes.KOPERASI,
      page: () => const KoperasiScreen(),
      binding: KoperasiControllerBinding(),
    ),
    GetPage(
      name: Routes.ACCOUNT,
      page: () => const AccountScreen(),
      binding: AccountControllerBinding(),
    ),
    GetPage(
      name: Routes.E_WALLET,
      page: () => const EWalletScreen(),
      binding: EWalletControllerBinding(),
    ),
    GetPage(
        name: Routes.MAIN_PAGES,
        page: () => const MainPagesScreen(),
        binding: MainPagesControllerBinding()),
    GetPage(
      name: Routes.DETAIL_PAYMENT_REGISTER,
      page: () => const DetailPaymentRegisterScreen(),
      binding: DetailPaymentRegisterControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYMENT_STATUS,
      page: () => const PaymentStatusScreen(),
      binding: PaymentStatusControllerBinding(),
    ),
    GetPage(
      name: Routes.RESET_SUCESS,
      page: () => const ResetSucessScreen(),
      binding: ResetSucessControllerBinding(),
    ),
    GetPage(
      name: Routes.NOTIFICATION,
      page: () => const NotificationScreen(),
      binding: NotificationControllerBinding(),
    ),
    GetPage(
      name: Routes.CART,
      page: () => const CartScreen(),
      binding: CartControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_PRODUCT,
      page: () => const DetailProductScreen(),
      binding: DetailProductControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_STORE,
      page: () => const DetailStoreScreen(),
      binding: DetailStoreControllerBinding(),
    ),
    GetPage(
      name: Routes.PRODUCT_BYCATEGORY,
      page: () => const ProductBycategoryScreen(),
      binding: ProductBycategoryControllerBinding(),
    ),
    GetPage(
      name: Routes.CHECKOUT,
      page: () => const CheckoutScreen(),
      binding: CheckoutControllerBinding(),
    ),
    GetPage(
      name: Routes.ADDRESS,
      page: () => const AddressScreen(),
      binding: AddressControllerBinding(),
    ),
    GetPage(
      name: Routes.EDIT_ADDRESS,
      page: () => const EditAddressScreen(),
      binding: EditAddressControllerBinding(),
    ),
    GetPage(
      name: Routes.LOCATION,
      page: () => const LocationScreen(),
      binding: LocationControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_ADDRESS,
      page: () => const DetailAddressScreen(),
      binding: DetailAddressControllerBinding(),
    ),
    GetPage(
      name: Routes.VOUCHER,
      page: () => const VoucherScreen(),
      binding: VoucherControllerBinding(),
    ),
    GetPage(
      name: Routes.CHECKOUT_PAYMENT,
      page: () => const CheckoutPaymentScreen(),
      binding: CheckoutPaymentControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_CHECKOUT,
      page: () => const DetailCheckoutScreen(),
      binding: DetailCheckoutControllerBinding(),
    ),
    GetPage(
      name: Routes.ADD_ADDRESS,
      page: () => const AddAddressScreen(),
      binding: AddAddressControllerBinding(),
    ),
    GetPage(
      name: Routes.LIST_ADDRESS,
      page: () => const ListAddressScreen(),
      binding: ListAddressControllerBinding(),
    ),
    GetPage(
      name: Routes.CHOICE_PAYMENT,
      page: () => const ChoicePaymentScreen(),
      binding: ChoicePaymentControllerBinding(),
    ),
    GetPage(
      name: Routes.CHECKOUT_PAYMENT_RETAIL,
      page: () => const CheckoutPaymentRetailScreen(),
      binding: CheckoutPaymentRetailControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYMENT_SUCCESS_RETAIL,
      page: () => const PaymentSuccessRetailScreen(),
      binding: PaymentSuccessRetailControllerBinding(),
    ),
    GetPage(
      name: Routes.WAITING_PAYMENT,
      page: () => const WaitingPaymentScreen(),
      binding: WaitingPaymentControllerBinding(),
    ),
    GetPage(
      name: Routes.CARA_BAYAR,
      page: () => const CaraBayarScreen(),
      binding: CaraBayarControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_ORDER,
      page: () => const DetailOrderScreen(),
      binding: DetailOrderControllerBinding(),
    ),
    GetPage(
      name: Routes.TRACKING_RETURN_ORDER,
      page: () => const TrackingReturnOrderScreen(),
      binding: TrackingReturnOrderControllerBinding(),
    ),
    GetPage(
      name: Routes.KOMPLAIN,
      page: () => const KomplainScreen(),
      binding: KomplainControllerBinding(),
    ),
    GetPage(
      name: Routes.REVIEW_ORDER,
      page: () => const ReviewOrderScreen(),
      binding: ReviewOrderControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_RETURN,
      page: () => const DetailReturnScreen(),
      binding: DetailReturnControllerBinding(),
    ),
    GetPage(
      name: Routes.TRACKING_RETURN,
      page: () => const TrackingReturnScreen(),
      binding: TrackingReturnControllerBinding(),
    ),
    GetPage(
      name: Routes.REGISTER_OTP,
      page: () => const RegisterOtpScreen(),
      binding: RegisterOtpControllerBinding(),
    ),
    GetPage(
      name: Routes.SUCCESS_VERIFY_OTP,
      page: () => const SuccessVerifyOtpScreen(),
      binding: SuccessVerifyOtpControllerBinding(),
    ),
    GetPage(
      name: Routes.EDIT_ACCOUNT,
      page: () => const EditAccountScreen(),
      binding: EditAccountControllerBinding(),
    ),
    GetPage(
      name: Routes.CHANGE_PASSWORD,
      page: () => const ChangePasswordScreen(),
      binding: ChangePasswordControllerBinding(),
    ),
    GetPage(
      name: Routes.SUCCESS_CHANGE_PASSWORD,
      page: () => const SuccessChangePasswordScreen(),
      binding: SuccessChangePasswordControllerBinding(),
    ),
    GetPage(
      name: Routes.ALL_CATEGORY,
      page: () => const AllCategoryScreen(),
      binding: AllCategoryControllerBinding(),
    ),
    GetPage(
      name: Routes.REFERRAL,
      page: () => const ReferralScreen(),
      binding: ReferralControllerBinding(),
    ),
    GetPage(
      name: Routes.REVIEW_PRODUCT,
      page: () => const ReviewProductScreen(),
      binding: ReviewProductControllerBinding(),
    ),
    GetPage(
      name: Routes.TABUNGAN,
      page: () => const TabunganScreen(),
      binding: TabunganControllerBinding(),
    ),
    GetPage(
      name: Routes.PINJAMAN,
      page: () => const PinjamanScreen(),
      binding: PinjamanControllerBinding(),
    ),
    GetPage(
      name: Routes.LOAN_V2,
      page: () => const LoanV2HomeScreen(),
      binding: LoanV2ControllerBinding(),
    ),
    GetPage(
      name: Routes.LOAN_V2_APPLICATION,
      page: () => const LoanV2ApplicationScreen(),
      binding: LoanV2ControllerBinding(),
    ),
    GetPage(
      name: Routes.LOAN_V2_DETAIL,
      page: () => const LoanV2DetailScreen(),
      binding: LoanV2ControllerBinding(),
    ),
    GetPage(
      name: Routes.HISTORY_TABUNGAN,
      page: () => const HistoryTabunganScreen(),
      binding: HistoryTabunganControllerBinding(),
    ),
    GetPage(
      name: Routes.ADD_TABUNGAN,
      page: () => const AddTabunganScreen(),
      binding: AddTabunganControllerBinding(),
    ),
    GetPage(
      name: Routes.ADD_TABUNGAN_MANUAL,
      page: () => const AddTabunganManualScreen(),
      binding: AddTabunganManualControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYMENT_TABUNGAN_SUCCESS,
      page: () => const PaymentTabunganSuccessScreen(),
      binding: PaymentTabunganSuccessControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_MENABUNG,
      page: () => const DetailMenabungScreen(),
      binding: DetailMenabungControllerBinding(),
    ),
    GetPage(
      name: Routes.TABUNGAN_PAYMENT,
      page: () => const TabunganPaymentScreen(),
      binding: TabunganPaymentControllerBinding(),
    ),
    GetPage(
      name: Routes.AJUKAN_PINJAMAN,
      page: () => const AjukanPinjamanScreen(),
      binding: AjukanPinjamanControllerBinding(),
    ),
    GetPage(
      name: Routes.PENGAJUAN_PROSES_PINJAMAN,
      page: () => const PengajuanProsesPinjamanScreen(),
      binding: PengajuanProsesPinjamanControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_PENGAJUAN_PINJAMAN,
      page: () => const DetailPengajuanPinjamanScreen(),
      binding: DetailPengajuanPinjamanControllerBinding(),
    ),
    GetPage(
      name: Routes.WITHDRAW,
      page: () => const WithdrawScreen(),
      binding: WithdrawControllerBinding(),
    ),
    GetPage(
      name: Routes.WITHDRAW_STATUS,
      page: () => const WithdrawStatusScreen(),
      binding: WithdrawStatusControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_WITHDRAW,
      page: () => const DetailWithdrawScreen(),
      binding: DetailWithdrawControllerBinding(),
    ),
    GetPage(
      name: Routes.TOPUP_SALDO,
      page: () => const TopupSaldoScreen(),
      binding: TopupSaldoControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYMENT_TOPUP_SALDO,
      page: () => const PaymentTopupSaldoScreen(),
      binding: PaymentTopupSaldoControllerBinding(),
    ),
    GetPage(
      name: Routes.CHOICE_DELIVERY,
      page: () => const ChoiceDeliveryScreen(),
      binding: ChoiceDeliveryControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_PAYMENT_CUSTOMER,
      page: () => const DetailPaymentCustomerScreen(),
      binding: DetailPaymentCustomerControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYMENT_PAYLETTER,
      page: () => const PaymentPayletterScreen(),
      binding: PaymentPayletterControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYLETTER_SUCCESS,
      page: () => const PayletterSuccessScreen(),
      binding: PayletterSuccessControllerBinding(),
    ),
    GetPage(
      name: Routes.ORDER_LIST_TRANSACTION,
      page: () => const OrderListTransactionScreen(),
      binding: OrderListTransactionControllerBinding(),
    ),
    GetPage(
      name: Routes.RINCIAN_REFUND,
      page: () => const RincianRefundScreen(),
      binding: RincianRefundControllerBinding(),
    ),
    GetPage(
      name: Routes.SET_REFUND,
      page: () => const SetRefundScreen(),
      binding: SetRefundControllerBinding(),
    ),
    GetPage(
      name: Routes.CHOICE_DELIVERY_REFUND,
      page: () => const ChoiceDeliveryRefundScreen(),
      binding: ChoiceDeliveryRefundControllerBinding(),
    ),
    GetPage(
      name: Routes.TRACKING_ORDER,
      page: () => const TrackingOrderScreen(),
      binding: TrackingOrderControllerBinding(),
    ),
    GetPage(
      name: Routes.DAFTAR_PENGAJUAN_PINJAMAN,
      page: () => const DaftarPengajuanPinjamanScreen(),
      binding: DaftarPengajuanPinjamanControllerBinding(),
    ),
    GetPage(
      name: Routes.TAGIHAN_BULANAN_PINJAMAN,
      page: () => const TagihanBulananPinjamanScreen(),
      binding: TagihanBulananPinjamanControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_CHAT,
      page: () => const DetailChatScreen(),
      binding: DetailChatControllerBinding(),
    ),
    GetPage(
      name: Routes.CHATS,
      page: () => const ChatsScreen(),
      binding: ChatsControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_TAGIHAN_BULANAN,
      page: () => const DetailTagihanBulananScreen(),
      binding: DetailTagihanBulananControllerBinding(),
    ),
    GetPage(
      name: Routes.CHECK_EXISTING_CHAT,
      page: () => const CheckExistingChatScreen(),
      binding: CheckExistingChatControllerBinding(),
    ),
    GetPage(
      name: Routes.CHOICE_PAYMENT_TOPUP,
      page: () => const ChoicePaymentTopupScreen(),
      binding: ChoicePaymentTopupControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_TOPUP,
      page: () => const DetailTopupScreen(),
      binding: DetailTopupControllerBinding(),
    ),
    GetPage(
      name: Routes.PAYLATER_CUSTOMER,
      page: () => const PaylaterCustomerScreen(),
      binding: PaylaterCustomerControllerBinding(),
    ),
    GetPage(
      name: Routes.BILL_PAYLATER,
      page: () => const BillPaylaterScreen(),
      binding: BillPaylaterControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_BILL_PAYLATER,
      page: () => const DetailBillPaylaterScreen(),
      binding: DetailBillPaylaterControllerBinding(),
    ),
    GetPage(
      name: Routes.CHOICE_PAYMENT_PAYLATER,
      page: () => const ChoicePaymentPaylaterScreen(),
      binding: ChoicePaymentPaylaterControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_PAYMENT_PAYLATER,
      page: () => const DetailPaymentPaylaterScreen(),
      binding: DetailPaymentPaylaterControllerBinding(),
    ),
    GetPage(
        name: Routes.CHECK_EXTERNAL_LINK,
        page: () => const CheckExternalLinkScreen(),
        binding: CheckExternalLinkControllerBinding(),
        middlewares: [DeeplinkMiddleware(), NotificationMiddleware()]),
    GetPage(
      name: Routes.CHOICE_PAYMENT_TAGIHAN,
      page: () => const ChoicePaymentTagihanScreen(),
      binding: ChoicePaymentTagihanControllerBinding(),
    ),
    GetPage(
      name: Routes.TAGIHAN_PAYMENT_BILL,
      page: () => const TagihanPaymentBillScreen(),
      binding: TagihanPaymentBillControllerBinding(),
    ),
    GetPage(
      name: Routes.REORDER,
      page: () => const ReorderScreen(),
      binding: ReorderControllerBinding(),
    ),
    GetPage(
      name: Routes.DETAIL_NOTIFICATION,
      page: () => const DetailNotificationScreen(),
      binding: DetailNotificationControllerBinding(),
    ),
    GetPage(
      name: Routes.TABUNGAN_WAJIB,
      page: () => const TabunganWajibScreen(),
      binding: TabunganWajibControllerBinding(),
    ),
    GetPage(
      name: Routes.PRIVACY_POLICY,
      page: () => const PrivacyPolicyScreen(),
      binding: PrivacyPolicyControllerBinding(),
    ),
  ];
}
