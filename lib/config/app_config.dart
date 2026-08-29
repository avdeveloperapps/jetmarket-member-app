import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:jetmarket/utils/app_preference/app_preferences.dart';

import '../infrastructure/dal/daos/provider/remote/remote_provider.dart';
// import '../infrastructure/dal/services/firebase/firebase_api.dart';
import '../infrastructure/dal/services/firebase/deeplink_service.dart';
import '../infrastructure/dal/services/firebase/firebase_service.dart';
import '../infrastructure/dal/services/firebase/firebase_options.dart';
import '../utils/path/environment.dart';

class AppConfig {
  static Future<void> init() async {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    await GetStorage.init();
    await dotenv.load(fileName: environmentPath.staging).then((value) {
      kBaseUrl = dotenv.env['BASE_URL']!;
      apiKey = dotenv.env['API_KEY']!;
      kApiUrl = dotenv.env['MAPS_URL']!;
      // Google Maps API key is now available as dotenv.env['GOOGLE_MAPS_API_KEY']
    });

    await Firebase.initializeApp(
      name: 'jetmarket',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    //  DeeplinkService.getLink();
    DeeplinkService.initDeepLinkListener();
    await FirebaseService.getInitialMessage();
    await FirebaseService().initNotification();
    await AppPreference.init();
    await RemoteProvider.init();
  }
}
