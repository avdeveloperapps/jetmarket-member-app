// ignore_for_file: unnecessary_nullable_for_final_variable_declarations, avoid_print, deprecated_member_use

import 'dart:convert';
import 'dart:developer';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jetmarket/infrastructure/dal/repository/notification_repository_impl.dart';
import 'package:jetmarket/infrastructure/dal/services/firebase/firebase_controller.dart';
import 'package:jetmarket/infrastructure/navigation/routes.dart';
import 'package:jetmarket/utils/app_preference/app_preferences.dart';
import '../../../../domain/core/model/argument/chat_room_argument.dart';
import '../../../../utils/global/constant.dart';

Future<void> handleBackgroundMessage(RemoteMessage message) async {
  log(message.notification?.title ?? '');
  log(message.notification?.body ?? '');
  log("Data : ${message.data}");
  updateUnreadNotification();
}

Future<void> updateUnreadNotification() async {
  final controller = Get.put(FirebaseController(NotificationRepositoryImpl()));
  await controller.getUnreadNotification();
}

void toDirectPagelink(String path, int pathId, String? refId) {
  notificationArgument = {'path': path, 'pathId': pathId, 'refId': refId};
  switch (path) {
    case 'chat':
      Get.toNamed(Routes.DETAIL_CHAT,
          arguments: ChatRoomArgument(
            chatId: pathId,
            fromRole: 'customer',
          ));
    case 'order':
      Get.toNamed(Routes.DETAIL_ORDER, arguments: [pathId, null, null, refId]);
    case 'withdraw':
      Get.toNamed(Routes.DETAIL_WITHDRAW, arguments: [refId, null]);
    case 'topup':
      Get.toNamed(Routes.DETAIL_TOPUP, arguments: [refId, null]);
    case 'loan-propose':
      Get.toNamed(Routes.DETAIL_PENGAJUAN_PINJAMAN, arguments: [pathId, null]);
    case 'loan-bill':
      Get.toNamed(Routes.DETAIL_TAGIHAN_BULANAN, arguments: [pathId, null]);
    case 'loans':
      Get.toNamed(Routes.LOAN_V2_DETAIL, arguments: pathId);
    case 'saving':
      Get.toNamed(Routes.DETAIL_MENABUNG, arguments: [pathId, null]);
    case 'referral':
      Get.toNamed(Routes.REFERRAL);
    case 'transaction':
      Get.toNamed(Routes.ORDER_LIST_TRANSACTION, arguments: [refId, null]);
    case 'paylater':
      Get.toNamed(Routes.PAYLATER_CUSTOMER);
    default:
      break;
  }
}

void toDirectPagelinkPayment(String path, int pathId, String? refId) {
  notificationArgument = {'path': path, 'pathId': pathId, 'refId': refId};
  switch (path) {
    case 'topup':
      Get.offNamed(Routes.DETAIL_TOPUP, arguments: [refId, null]);
    case 'saving':
      Get.offNamed(Routes.DETAIL_MENABUNG, arguments: [pathId, null]);
    case 'paylater':
      Get.offNamed(Routes.PAYLATER_CUSTOMER);
    default:
      break;
  }
}

Future<String?> _base64encodeImage(String? url) async {
  try {
    if (url == null || url.isEmpty) {
      print("Error fetching image: URL is null or empty");
      return null;
    }

    final response = await Dio().get(
      url,
      options: Options(responseType: ResponseType.bytes),
    );

    if (response.statusCode == 200 && response.data != null) {
      final String base64Data = base64Encode(response.data!);
      return base64Data;
    } else {
      print("Error fetching image: Invalid URL or empty response");
      return null;
    }
  } catch (e) {
    print("Error fetching image: $e");
    return null;
  }
}

settingShowNotification(RemoteMessage message) async {
  String? showImage;
  if (message.data['image'] != null && message.data['image'] != '') {
    showImage = await _base64encodeImage(message.data['image']);
  }

  BigPictureStyleInformation? bigPictureStyleInformation;
  if (showImage != null) {
    bigPictureStyleInformation = BigPictureStyleInformation(
      ByteArrayAndroidBitmap.fromBase64String(showImage),
      contentTitle: message.notification?.title,
      htmlFormatContent: true,
      summaryText: message.notification?.body,
      htmlFormatSummaryText: true,
    );
  }

  var androidDetails = AndroidNotificationDetails(
    'high_importance_channel',
    'high_importance_channel_name',
    priority: Priority.high,
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    styleInformation: bigPictureStyleInformation,
    sound: const RawResourceAndroidNotificationSound('notif'),
  );
  var platformDetails = NotificationDetails(android: androidDetails);

  // Tampilkan notifikasi
  await FirebaseService._local.show(
    -2,
    message.notification?.title?.capitalizeFirst,
    message.notification?.body?.capitalizeFirst,
    platformDetails,
    payload: message.data.toString(),
  );
  log("DATA : ${message.data}");
  log("TITLE :${message.notification?.title}");
  log("BODY : ${message.notification?.body}");
  log("PAGELINK :${message.data['pagelink']}");
  List<String> parts = message.data['pagelink'].split('/');
  parts.removeAt(0);
  log("Parts : $parts");
  if (parts.length >= 2) {
    notificationArgument = {'path': parts[0], 'pathId': 0, 'refId': parts[1]};
  } else {}

  if (isPayment) {
    String value = parts[1];
    if (value.startsWith('TOP#')) {
      toDirectPagelinkPayment(parts[0], 0, value);
    } else {
      toDirectPagelinkPayment(parts[0], int.parse(value), null);
    }

    isPayment = false;
  } else {
    if (parts[0] == 'main') {
      AppPreference().clearOnSuccessPayment();
      Get.offAllNamed(Routes.MAIN_PAGES);
    } else if (parts[0] == 'payment_method') {
      AppPreference().removetrxId();
      Get.offAllNamed(Routes.PAYMENT_REGISTER);
    } else if (parts[0] == 'loan' && parts[1] == 'bill') {
      Get.toNamed(Routes.DETAIL_TAGIHAN_BULANAN,
          arguments: [int.parse(parts[2]), 'from-notificatiion', null, null]);
    } else if (parts[0] == 'loans' && parts.length > 1) {
      toDirectPagelink(parts[0], int.parse(parts[1]), null);
    } else if (parts[0] == 'transaction') {
      Get.offNamed(Routes.ORDER_LIST_TRANSACTION,
          arguments: [parts[1], 'from-notification']);
    } else if (parts[0] == 'paylater') {
      Get.offNamed(Routes.PAYLATER_CUSTOMER, arguments: 'from-notification');
    } else {
      await updateUnreadNotification();
    }
  }
}

class FirebaseService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  static FirebaseMessaging get firebaseMessaging =>
      FirebaseService._firebaseMessaging;
  static FlutterLocalNotificationsPlugin get local => FirebaseService._local;

  final box = GetStorage();
  bool appForeground = true;

  handleMessage(RemoteMessage? message) {
    if (message != null) return;
  }

  openMessage(RemoteMessage? message) {
    updateUnreadNotification();
    final pagelink = message?.data['pagelink']?.toString() ?? '';
    final parts = pagelink.split('/')..removeWhere((part) => part.isEmpty);
    if (parts.length > 1 && parts[0] == 'loans') {
      final applicationId = int.tryParse(parts[1]);
      if (applicationId != null && applicationId > 0) {
        Get.toNamed(Routes.LOAN_V2_DETAIL, arguments: applicationId);
      }
    }
  }

  static Future<void> handleForegroundNotification(
    RemoteMessage message,
  ) async {
    settingShowNotification(message);
  }

  static Future<void> getInitialMessage() async {
    RemoteMessage? message =
        await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) {
      List<String> parts = message.data['pagelink'].split('/');
      parts.removeAt(0);

      if (parts[0] == 'main' || parts[0] == 'payment_method') {
        if (parts[0] == 'main') {
          notificationArgument = {'path': parts[0], 'lifecycle': 'terminate'};
        } else if (parts[0] == 'payment_method') {
          notificationArgument = {'path': parts[0], 'lifecycle': 'terminate'};
        }
      } else if (parts[0] == 'withdraw' ||
          parts[0] == 'topup' ||
          parts[0] == 'transaction') {
        notificationArgument = {
          'path': parts[0],
          'pathId': 0,
          'refId': parts[1],
          'lifecycle': 'terminate'
        };
      } else if (parts[0] == 'loan' && parts[1] == 'bill' ||
          parts[0] == 'loan' && parts[1] == 'propose') {
        notificationArgument = {
          'path': "${parts[0]}-${parts[1]}",
          'pathId': int.parse(parts[2]),
          'refId': "",
          'lifecycle': 'terminate'
        };
      } else if (parts[0] == 'loans' && parts.length > 1) {
        notificationArgument = {
          'path': parts[0],
          'pathId': int.tryParse(parts[1]) ?? 0,
          'refId': '',
          'lifecycle': 'terminate'
        };
      } else if (parts[0] == 'order') {
        String value = parts[1];
        if (value.startsWith('ORD#')) {
          notificationArgument = {
            'path': parts[0],
            'pathId': 0,
            'refId': value,
            'lifecycle': 'terminate'
          };
        } else {
          notificationArgument = {
            'path': parts[0],
            'pathId': int.parse(value),
            'refId': null,
            'lifecycle': 'terminate'
          };
        }
      } else if (parts[0] == 'chat') {
        notificationArgument = {
          'path': parts[0],
          'pathId': int.parse(parts[1]),
          'refId': null,
          'lifecycle': 'terminate'
        };
      }
    }
  }

  Future<void> initNotification() async {
    await _firebaseMessaging.requestPermission();
    final tokenFcm = await _firebaseMessaging.getToken();
    fcmToken = tokenFcm ?? '';
    await box.write('fcm_token', tokenFcm);
    log("TOKEN : $tokenFcm");
    var androidInitialize =
        const AndroidInitializationSettings("@mipmap/ic_launcher");
    var initializeSetting = InitializationSettings(android: androidInitialize);
    _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .requestNotificationsPermission();
    _local.initialize(
      initializeSetting,
      onDidReceiveNotificationResponse: (details) {
        try {
          if (details.payload != null) {
            String payloadString = details.payload ?? '';
            log("Payload : $payloadString");
            payloadString =
                payloadString.replaceAll('{', '').replaceAll('}', '');
            List<String> part = payloadString.split(RegExp(r',|:'));
            List<String> parts = part.last.trim().split('/');

            parts.removeAt(0);
            if (parts[0] == 'main' || parts[0] == 'payment_method') {
              if (parts[0] == 'main') {
                notificationArgument = {'path': parts[0]};
                Get.offAllNamed(Routes.MAIN_PAGES);
              } else if (parts[0] == 'payment_method') {
                notificationArgument = {'path': parts[0]};
                Get.offAllNamed(Routes.PAYMENT_REGISTER);
              }
            } else if (parts[0] == 'withdraw' ||
                parts[0] == 'topup' ||
                parts[0] == 'transaction') {
              toDirectPagelink(parts[0], 0, parts[1]);
            } else if (parts[0] == 'loan' && parts[1] == 'bill' ||
                parts[0] == 'loan' && parts[1] == 'propose') {
              toDirectPagelink(
                  "${parts[0]}-${parts[1]}", int.parse(parts[2]), "");
            } else if (parts[0] == 'loans' && parts.length > 1) {
              toDirectPagelink(parts[0], int.parse(parts[1]), null);
            } else if (parts[0] == 'order') {
              String value = parts[1];

              if (value.startsWith('ORD#')) {
                toDirectPagelink(parts[0], 0, value);
              } else {
                toDirectPagelink(parts[0], int.parse(value), null);
              }
            } else if (parts[0] == 'chat') {
              toDirectPagelink(parts[0], int.parse(parts[1]), null);
            }
          } else {}
        } catch (e) {
          throw Exception(e);
        }
        return;
      },
    );

    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
            alert: true, sound: true, badge: true);

    await _firebaseMessaging.getInitialMessage().then(handleMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(openMessage);
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
    FirebaseMessaging.onMessage.listen(handleForegroundNotification);
  }
}
