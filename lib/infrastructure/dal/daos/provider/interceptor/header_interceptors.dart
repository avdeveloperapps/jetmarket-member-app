import 'dart:io';

import 'package:dio/dio.dart';
import 'package:get/get.dart';

import '../../../../../utils/app_preference/app_preferences.dart';
import '../../../../navigation/routes.dart';

InterceptorsWrapper headerInterceptor({required bool logs}) {
  return InterceptorsWrapper(
    onRequest: (options, handler) {
      // Some endpoints (notably encrypted liveness-video upload) need a
      // longer timeout supplied by the caller. Keep that explicit value and
      // only provide the normal API default when none was configured.
      options.connectTimeout ??= 8.seconds;
      options.receiveTimeout ??= 8.seconds;
      options.sendTimeout ??= 8.seconds;

      options.headers[HttpHeaders.contentTypeHeader] = 'application/json';
      var accessToken = AppPreference().getAccessToken();
      if (accessToken != null && options.path != 'referral/claim') {
        options.headers[HttpHeaders.authorizationHeader] =
            'Bearer $accessToken';
      }

      return handler.next(options);
    },
    onResponse: (response, handler) {
      return handler.next(response);
    },
    onError: (err, handler) {
      if (err.response?.statusCode == 401) {
        AppPreference().clearAccessToken();
        Get.offAllNamed(Routes.LOGIN);
      }
      return handler.reject(err);
    },
  );
}
