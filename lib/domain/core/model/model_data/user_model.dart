class UserModel {
  int? trxId;
  String? token;
  User? user;

  UserModel({this.trxId, this.token, this.user});

  UserModel.fromJson(Map<String, dynamic> json) {
    trxId = json['trx_id'];
    token = json['token'];
    final user = json['user'];
    this.user = user is Map ? User.fromJson(Map<String, dynamic>.from(user)) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['trx_id'] = trxId;
    data['token'] = token;
    if (user != null) {
      data['user'] = user!.toJson();
    }
    return data;
  }
}

class User {
  int? id;
  String? name;
  String? gender;
  String? birthDate;
  String? phone;
  String? referral;
  String? email;
  String? image;
  bool? isEmployee;
  bool? isVerified;
  String? activatedAt;

  User(
      {this.id,
      this.name,
      this.gender,
      this.birthDate,
      this.phone,
      this.referral,
      this.email,
      this.image,
      this.isEmployee,
      this.isVerified,
      this.activatedAt});

  User.fromJson(Map<String, dynamic> json) {
    id = json['id'];
    name = json['name'];
    gender = json['gender'];
    birthDate = json['birth_date'];
    phone = json['phone'];
    referral = json['referral'];
    email = json['email'];
    image = json['image'];
    isEmployee = json['is_employee'];
    isVerified = json['is_verified'];
    activatedAt = json['activated_at'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['gender'] = gender;
    data['birth_date'] = birthDate;
    data['phone'] = phone;
    data['referral'] = referral;
    data['email'] = email;
    data['image'] = image;
    data['is_employee'] = isEmployee;
    data['is_verified'] = isVerified;
    data['activated_at'] = activatedAt;
    return data;
  }
}
