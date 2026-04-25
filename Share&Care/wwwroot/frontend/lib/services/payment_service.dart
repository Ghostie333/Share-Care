import '../features/models/annoucement.dart';

class InvoiceData {
  final String firstName;
  final String lastName;
  final String email;
  final String phoneNumber;
  final String city;
  final String postalCode;
  final String street;
  final String buildingNumber;
  final String apartmentNumber;
  final String companyName;
  final String taxId;

  const InvoiceData({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phoneNumber,
    required this.city,
    required this.postalCode,
    required this.street,
    required this.buildingNumber,
    required this.apartmentNumber,
    required this.companyName,
    required this.taxId,
  });

  InvoiceData copyWith({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? city,
    String? postalCode,
    String? street,
    String? buildingNumber,
    String? apartmentNumber,
    String? companyName,
    String? taxId,
  }) {
    return InvoiceData(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      city: city ?? this.city,
      postalCode: postalCode ?? this.postalCode,
      street: street ?? this.street,
      buildingNumber: buildingNumber ?? this.buildingNumber,
      apartmentNumber: apartmentNumber ?? this.apartmentNumber,
      companyName: companyName ?? this.companyName,
      taxId: taxId ?? this.taxId,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'firstName': firstName,
      'lastName': lastName,
      'email': email,
      'phoneNumber': phoneNumber,
      'city': city,
      'postalCode': postalCode,
      'street': street,
      'buildingNumber': buildingNumber,
      'apartmentNumber': apartmentNumber,
      'companyName': companyName,
      'taxId': taxId,
    };
  }
}

class PaymentDraft {
  final String announcementId;
  final String announcementTitle;
  final String authorizationCode;
  final double amount;
  final InvoiceData invoiceData;
  final DateTime createdAt;

  const PaymentDraft({
    required this.announcementId,
    required this.announcementTitle,
    required this.authorizationCode,
    required this.amount,
    required this.invoiceData,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'announcementId': announcementId,
      'announcementTitle': announcementTitle,
      'authorizationCode': authorizationCode,
      'amount': amount,
      'invoiceData': invoiceData.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class PaymentService {
  PaymentService._();

  static String _buildAuthorizationCode(String announcementId, DateTime now) {
    final idPart = announcementId.isEmpty
        ? 'NO-ID'
        : announcementId.substring(
            0,
            announcementId.length > 6 ? 6 : announcementId.length,
          );
    final datePart =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final timePart =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'AUTH-$idPart-$datePart-$timePart';
  }

  /// Przygotowuje lokalny szkic autoryzacji płatności.
  ///
  /// Bez wywołania backendu: warstwa wizualna i dane do dalszej integracji.
  static PaymentDraft preparePayment({
    required Announcement announcement,
    required InvoiceData invoiceData,
  }) {
    final now = DateTime.now();
    return PaymentDraft(
      announcementId: announcement.id,
      announcementTitle: announcement.title,
      authorizationCode: _buildAuthorizationCode(announcement.id, now),
      amount: announcement.deposit ?? 0,
      invoiceData: invoiceData,
      createdAt: now,
    );
  }
}
