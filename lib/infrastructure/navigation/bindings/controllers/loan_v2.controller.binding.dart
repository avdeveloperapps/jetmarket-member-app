import 'package:get/get.dart';
import 'package:jetmarket/infrastructure/dal/repository/file_repository_impl.dart';
import 'package:jetmarket/infrastructure/dal/repository/loan_v2_repository_impl.dart';
import 'package:jetmarket/presentation/koperasi_pages/pinjaman_v2/controllers/loan_v2.controller.dart';

class LoanV2ControllerBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoanV2Controller>(
        () => LoanV2Controller(LoanV2RepositoryImpl(), FileRepositoryImpl()));
  }
}
