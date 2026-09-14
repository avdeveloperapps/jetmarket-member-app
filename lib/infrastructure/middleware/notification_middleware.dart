import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jetmarket/utils/global/constant.dart';
import '../../domain/core/model/argument/chat_room_argument.dart';
import '../navigation/routes.dart';

class NotificationMiddleware extends GetMiddleware {
  @override
  int? get priority => 2;

  @override
  RouteSettings? redirect(String? route) {
    if (notificationArgument != null) {
      return toDirectPage(
          notificationArgument['path'],
          notificationArgument['pathId'],
          notificationArgument['refId'],
          notificationArgument['lifecycle']);
    } else {
      return null;
    }
  }

  RouteSettings toDirectPage(
      String path, int pathId, String? refId, String lifecycle) {
    switch (path) {
      case 'main':
        return const RouteSettings(name: Routes.MAIN_PAGES);
      case 'payment_method':
        return const RouteSettings(name: Routes.PAYMENT_REGISTER);
      case 'chat':
        return RouteSettings(
            name: Routes.DETAIL_CHAT,
            arguments: ChatRoomArgument(
                chatId: pathId, fromRole: 'customer', lifecycle: lifecycle));
      case 'order':
        // 300
        return RouteSettings(
            name: Routes.DETAIL_ORDER,
            arguments: [pathId, null, lifecycle, refId]);
      case 'withdraw':
        return RouteSettings(
            name: Routes.DETAIL_WITHDRAW, arguments: [refId, lifecycle]);
      case 'topup':
        // TOP%23N05YD5af4W
        return RouteSettings(
            name: Routes.DETAIL_TOPUP, arguments: [refId, lifecycle]);
      case 'loan-propose':
        return RouteSettings(
            name: Routes.DETAIL_PENGAJUAN_PINJAMAN,
            arguments: [pathId, lifecycle]);
      case 'loan-bill':
        return RouteSettings(
            name: Routes.DETAIL_TAGIHAN_BULANAN,
            arguments: [pathId, lifecycle]);
      case 'loans':
        return RouteSettings(name: Routes.LOAN_V2_DETAIL, arguments: pathId);
      case 'saving':
        return RouteSettings(
            name: Routes.DETAIL_MENABUNG, arguments: [pathId, lifecycle]);
      case 'referral':
        return const RouteSettings(name: Routes.REFERRAL);
      case 'transaction':
        return RouteSettings(
            name: Routes.ORDER_LIST_TRANSACTION, arguments: [refId, lifecycle]);
      default:
        return const RouteSettings(name: '/');
    }
  }
}
