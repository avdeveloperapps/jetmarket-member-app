import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/core/model/model_data/address_model.dart';
import '../../domain/core/model/model_data/user_model.dart';
import '../../domain/core/model/model_data/user_profile.dart';

class AppPreference {
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  final String _authTokenKey = 'auth_token';
  final String _userDataKey = 'user_data';
  final String _userProfile = 'user_profile';
  final String _onboarding = 'intro';
  final String _isRegistered = 'registered';
  final String _isVerified = 'is_verified';
  final String _isActivated = 'activated_at';
  final String _isPaid = 'paid';
  final String _isReferal = 'referal';
  final String _phoneNumber = 'phone';
  final String _email = 'email';
  final String _countDown = 'count_down';
  final String _countDownPaymentSaving = 'count_down_payment_saving';
  final String _countDownPaymentTopupWallet = 'count_down_payment_topup_wallet';
  final String _countDownPaylaterPayment = 'count_down_paylater_payment';
  final String _countDownOrder = 'count_down_order';
  final String _countDownPaymentBill = 'count_down_payment_bill';
  final String _trxId = 'trx_id';
  final String _address = 'address';
  final String _registerComplite = 'register_complite';
  final String _currentPage = 'current-page';
  // final String _paymentRegisterSuccess = 'payment_register_success';
  final String _biayaRegistrasi = 'biaya_registrasi';
  final String _biayaRegistrasiPromo = 'biaya_registrasi_promo';

  /// Baca JSON map dari storage secara self-healing: entri korup
  /// (string bukan JSON, atau bukan object) dikarantina (dihapus) dan
  /// dibaca sebagai null, bukan melempar crash ke pemanggil. Ini akar
  /// dari bug "harus hapus data biar tidak crash".
  Map<String, dynamic>? _readJsonMap(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null) return null;
    try {
      final decoded = json.decode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (error) {
      developer.log('Corrupt storage entry quarantined',
          name: 'AppPreference', error: '$key: $error');
    }
    unawaited(_prefs?.remove(key));
    return null;
  }

  Future<void> setCurrentPage(String? page) async {
    await _prefs?.setString(_currentPage, page ?? 'no-define');
  }

  Future<void> saveEmail(String? email) async {
    await _prefs?.setString(_email, email ?? '');
  }

  Future<void> savePaymentRegisterSuccess(String? email) async {
    await _prefs?.setString(_email, email ?? '');
  }

  String? getCurrentPage() {
    return _prefs?.getString(_currentPage);
  }

  String? getEmail() {
    return _prefs?.getString(_email);
  }

  Future<void> saveCountDown(int countDown) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    await _prefs?.setInt(_countDown, startTime);
  }

  Future<void> saveCountDownOrder(int countDown, int id) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    final countDownMap = _readJsonMap(_countDownOrder) ?? {};
    countDownMap[id.toString()] = startTime;
    await _prefs?.setString(_countDownOrder, json.encode(countDownMap));
  }

  Future<void> saveCountDownSavingPayment(int countDown, String id) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    final countDownMap = _readJsonMap(_countDownPaymentSaving) ?? {};
    countDownMap[id] = startTime;
    await _prefs?.setString(_countDownPaymentSaving, json.encode(countDownMap));
  }

  Future<void> saveCountDownPaymentTopupWallet(int countDown, String id) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    final countDownMap = _readJsonMap(_countDownPaymentTopupWallet) ?? {};
    countDownMap[id] = startTime;
    await _prefs?.setString(
        _countDownPaymentTopupWallet, json.encode(countDownMap));
  }

  Future<void> saveCountDownPaymentPaylater(int countDown, String id) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    final countDownMap = _readJsonMap(_countDownPaylaterPayment) ?? {};
    countDownMap[id] = startTime;
    await _prefs?.setString(
        _countDownPaylaterPayment, json.encode(countDownMap));
  }

  Future<void> saveCountDownPaymentBill(int countDown, String id) async {
    int startTime = DateTime.now().millisecondsSinceEpoch;
    final countDownMap = _readJsonMap(_countDownPaymentBill) ?? {};
    countDownMap[id] = startTime;
    await _prefs?.setString(_countDownPaymentBill, json.encode(countDownMap));
  }

  int? getCountDownOrder(int id) {
    final countDownMap = _readJsonMap(_countDownOrder);
    if (countDownMap != null && countDownMap.containsKey(id.toString())) {
      return (countDownMap[id.toString()] as num?)?.toInt();
    }

    return null;
  }

  int? getCountDownSavingPayment(String id) {
    final countDownMap = _readJsonMap(_countDownPaymentSaving);
    if (countDownMap != null && countDownMap.containsKey(id)) {
      return (countDownMap[id] as num?)?.toInt();
    }

    return null;
  }

  int? getCountDownPaymentTopupWallet(String id) {
    final countDownMap = _readJsonMap(_countDownPaymentTopupWallet);
    if (countDownMap != null && countDownMap.containsKey(id)) {
      return (countDownMap[id] as num?)?.toInt();
    }

    return null;
  }

  int? getCountDownPaymentPaylater(String id) {
    final countDownMap = _readJsonMap(_countDownPaylaterPayment);
    if (countDownMap != null && countDownMap.containsKey(id)) {
      return (countDownMap[id] as num?)?.toInt();
    }

    return null;
  }

  int? getCountDownPaymentBill(String id) {
    final countDownMap = _readJsonMap(_countDownPaymentBill);
    if (countDownMap != null && countDownMap.containsKey(id)) {
      return (countDownMap[id] as num?)?.toInt();
    }

    return null;
  }

  Future<void> registerComplite() async {
    await _prefs?.setBool(_registerComplite, true);
  }

  int? getCountDown() {
    return _prefs?.getInt(_countDown);
  }

  Future<void> deleteCountDown() async {
    await _prefs?.remove(_countDown);
  }

  Future<void> savePhoneNumber(String phoneNumber) async {
    await _prefs?.setString(_phoneNumber, phoneNumber);
  }

  Future<void> saveAccessToken({int? status, String? token}) async {
    if (status == 200) {
      await _prefs?.setString(_authTokenKey, token!);
    }
  }

  Future<void> saveUserData({int? status, Map<String, dynamic>? data}) async {
    if (status == 200 && data != null) {
      String userDataJson = json.encode(data);
      await _prefs?.setString(_userDataKey, userDataJson);
      if (data['trx_id'] != null) {
        saveTrxId(data['trx_id']);
      }
      final user = data['user'];
      if (user is Map && user['email'] is String) {
        saveEmail(user['email'] as String);
      }
    }
  }

  Future<void> saveUserProfile(
      {int? status, Map<String, dynamic>? data}) async {
    if (status == 200 && data != null) {
      String userDataJson = json.encode(data);
      await _prefs?.setString(_userProfile, userDataJson);
    }
  }

  UserModel? getUserData() {
    final userDataMap = _readJsonMap(_userDataKey);
    if (userDataMap == null) return null;
    try {
      return UserModel.fromJson(userDataMap);
    } catch (error) {
      developer.log('Corrupt user_data quarantined',
          name: 'AppPreference', error: error);
      unawaited(_prefs?.remove(_userDataKey));
      return null;
    }
  }

  UserProfile? getUserProfile() {
    final userDataMap = _readJsonMap(_userProfile);
    if (userDataMap == null) return null;
    try {
      return UserProfile.fromJson(userDataMap);
    } catch (error) {
      developer.log('Corrupt user_profile quarantined',
          name: 'AppPreference', error: error);
      unawaited(_prefs?.remove(_userProfile));
      return null;
    }
  }

  void updateUserData(UserModel newUserData) {
    final existingUserDataMap = _readJsonMap(_userDataKey);

    if (existingUserDataMap != null) {
      existingUserDataMap.forEach((key, value) {
        if (newUserData.toJson().containsKey(key)) {
          existingUserDataMap[key] = newUserData.toJson()[key];
        }
      });
      String updatedUserDataJson = json.encode(existingUserDataMap);
      _prefs?.setString(_userDataKey, updatedUserDataJson);
    }
  }

  void updateUserProfile(UserProfile newUserData) {
    final existingUserDataMap = _readJsonMap(_userProfile);

    if (existingUserDataMap != null) {
      existingUserDataMap.forEach((key, value) {
        if (newUserData.toJson().containsKey(key)) {
          existingUserDataMap[key] = newUserData.toJson()[key];
        }
      });
      String updatedUserDataJson = json.encode(existingUserDataMap);
      _prefs?.setString(_userProfile, updatedUserDataJson);
    }
  }

  Future<void> removeUserData() async {
    await _prefs?.remove(_userDataKey);
  }

  Future<void> referalSuccess() async {
    await _prefs?.setBool(_isReferal, true);
  }

  bool? cekReferal() {
    return _prefs?.getBool(_isReferal);
  }

  Future<void> setBiayaRegis(String value) async {
    await _prefs?.setString(_biayaRegistrasi, value);
  }

  String? getBiayaRegis() {
    return _prefs?.getString(_biayaRegistrasi);
  }

  Future<void> setBiayaRegisPromo(String value) async {
    await _prefs?.setString(_biayaRegistrasiPromo, value);
  }

  String? getBiayaRegisPromo() {
    return _prefs?.getString(_biayaRegistrasiPromo);
  }

  bool? registerCompleted() {
    return _prefs?.getBool(_registerComplite);
  }

  String? getPhoneNumber() {
    return _prefs?.getString(_phoneNumber);
  }

  Future<void> registerSuccess() async {
    await _prefs?.setBool(_isRegistered, true);
  }

  Future<void> verifySuccess() async {
    await _prefs?.setBool(_isVerified, true);
  }

  Future<void> activatedAt() async {
    await _prefs?.setBool(_isActivated, true);
  }

  bool? cekActivated() {
    return _prefs?.getBool(_isActivated);
  }

  Future<void> paidSuccess() async {
    await _prefs?.setBool(_isPaid, true);
  }

  String? getAccessToken() {
    return _prefs?.getString(_authTokenKey);
  }

  Future<void> skipOnboarding(bool onboarding) async {
    await _prefs?.setBool(_onboarding, true);
  }

  bool? cekSkipOnboarding() {
    return _prefs?.getBool(_onboarding);
  }

  bool? cekRegistered() {
    return _prefs?.getBool(_isRegistered);
  }

  bool? cekVerify() {
    return _prefs?.getBool(_isVerified);
  }

  bool? cekPaid() {
    return _prefs?.getBool(_isPaid);
  }

  Future<void> saveTrxId(int trxId) async {
    await _prefs?.setInt(_trxId, trxId);
  }

  int? getTrxId() {
    return _prefs?.getInt(_trxId);
  }

  Future<void> saveAddress(AddressModel address) async {
    String addressJson = json.encode(address);
    await _prefs?.setString(_address, addressJson);
  }

  AddressModel? getAddress() {
    final addressMap = _readJsonMap(_address);
    if (addressMap == null) return null;
    try {
      return AddressModel.fromJson(addressMap);
    } catch (error) {
      developer.log('Corrupt address quarantined',
          name: 'AppPreference', error: error);
      unawaited(_prefs?.remove(_address));
      return null;
    }
  }

  Future<void> clearAccessToken() async {
    await _prefs?.remove(_authTokenKey);
  }

  Future<void> cleanCurrentPage() async {
    await _prefs?.remove(_currentPage);
  }

  Future<void> removetrxId() async {
    await _prefs?.remove(_trxId);
  }

  Future<void> clearOnLogout() async {
    await _prefs?.remove(_authTokenKey);
    await _prefs?.remove(_userDataKey);
    await _prefs?.remove(_isPaid);
    await _prefs?.remove(_isReferal);
    await _prefs?.remove(_isRegistered);
    await _prefs?.remove(_isVerified);
    await _prefs?.remove(_phoneNumber);
    await _prefs?.remove(_trxId);
  }

  Future<void> clearOnSuccessPayment() async {
    await _prefs?.remove(_isPaid);
    await _prefs?.remove(_isReferal);
    await _prefs?.remove(_isRegistered);
    await _prefs?.remove(_isVerified);
    await _prefs?.remove(_phoneNumber);
    await _prefs?.remove(_trxId);
    await _prefs?.remove(_countDown);
  }
}
