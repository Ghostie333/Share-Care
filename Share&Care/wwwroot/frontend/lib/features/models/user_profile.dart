class UserProfile {
  final String? userId;
  String? email;
  String? password;
  String? firstName;
  String? lastName;
  String? phoneNumber;
  String? brithday;
  String? city;
  String? postalCode;
  String? street;
  String? buildingNumber;
  String? type;
  int? offersAmount;
  double? raiting;

  UserProfile({
    this.userId,
    this.email,
    this.password,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.brithday,
    this.city,
    this.postalCode,
    this.street,
    this.buildingNumber,
    this.type,
    this.offersAmount,
    this.raiting,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: (json['userId'] ?? json['UserId'])?.toString(),
      email: (json['email'] ?? json['Email'])?.toString(),
      password: (json['password'] ?? json['Password'])?.toString(),
      firstName: (json['firstName'] ?? json['FirstName'])?.toString(),
      lastName: (json['lastName'] ?? json['LastName'])?.toString(),
      phoneNumber: (json['phoneNumber'] ?? json['PhoneNumber'])?.toString(),
      brithday: (json['brithday'] ?? json['Brithday'])?.toString(),
      city: (json['city'] ?? json['City'])?.toString(),
      postalCode: (json['postalCode'] ?? json['PostalCode'])?.toString(),
      street: (json['street'] ?? json['Street'])?.toString(),
      buildingNumber: (json['buildingNumber'] ?? json['BuildingNumber'])
          ?.toString(),
      type: (json['type'] ?? json['Type'])?.toString(),
      offersAmount: json['offersAmount'] ?? json['OffersAmount'],
      raiting: (json['raiting'] ?? json['Raiting']) != null
          ? double.tryParse((json['raiting'] ?? json['Raiting']).toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'UserId': userId,
      'Email': email,
      'Password': password,
      'FirstName': firstName,
      'LastName': lastName,
      'PhoneNumber': phoneNumber,
      'Brithday': brithday,
      'City': city,
      'PostalCode': postalCode,
      'Street': street,
      'BuildingNumber': buildingNumber,
      'Type': type,
      'OffersAmount': offersAmount,
      'Raiting': raiting,
    };
  }
}
