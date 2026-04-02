class Announcement {
	/// Id of the offer/announcement (maps to OfferId in backend).
	final String id;

	/// Id użytkownika (UserId z backendu / MongoDB).
	final String? userId;

	String title;
	String description;
	String location;
	double? deposit;
	String ownerName;
	bool isActive;
	DateTime createdAt;
	List<String> imageUrls;
	bool isOwner;

	/// Dodatkowe pola odpowiadające modelowi Offer w .NET.
	String? category;
	String? contactName;
	String? contactNumber;
	bool isUrgent;
	DateTime? expiresAt;

	Announcement({
		required this.id,
		this.userId,
		required this.title,
		required this.description,
		required this.location,
		this.deposit,
		required this.ownerName,
		required this.isActive,
		required this.createdAt,
		List<String>? imageUrls,
		this.isOwner = true,
		this.category,
		this.contactName,
		this.contactNumber,
		this.isUrgent = false,
		this.expiresAt,
	}) : imageUrls = imageUrls ?? [];

	factory Announcement.fromJson(Map<String, dynamic> json) {
		final rawStatus = (json['status'] ?? json['Status'])?.toString();
		final computedIsActive = rawStatus != null
			? rawStatus.toLowerCase() == 'active'
			: (() {
					final v = (json['isActive'] ?? json['IsActive']);
					if (v is bool) return v;
					if (v is String) return v.toLowerCase() == 'active';
					return true;
				})();

		String parseLocation(dynamic value) {
			if (value == null) return '';
			if (value is String) return value;

			// GeoJSON point - typowo: { "type": "Point", "coordinates": [lng, lat] }
			if (value is Map<String, dynamic>) {
				final coords = value['coordinates'];
				if (coords is List && coords.length >= 2) {
					final lng = coords[0];
					final lat = coords[1];
					return '$lat,$lng';
				}
				final lat = value['lat'] ?? value['Lat'];
				final lng = value['lng'] ?? value['Lng'];
				if (lat != null && lng != null) {
					return '${lat.toString()},${lng.toString()}';
				}
			}

			return value.toString();
		}

			// Najpierw spróbuj odczytać pole Location/LocationText, które może być
			// albo GeoJSON-em, albo zwykłym stringiem z miastem.
			final dynamic locationRaw =
				json['location'] ?? json['Location'] ?? json['locationText'] ?? json['LocationText'];

			return Announcement(
			// Obsługa OfferId/offerId/id z backendu.
			id: (json['offerId'] ?? json['OfferId'] ?? json['id'] ?? json['Id'])
					.toString(),
			userId:
				(json['userId'] ?? json['UserId'])?.toString(),
			title: (json['title'] ?? json['Title'] ?? '').toString(),
			description:
				(json['description'] ?? json['Description'] ?? '').toString(),
				location: parseLocation(locationRaw),
			deposit: json['deposit'] != null
					? double.tryParse(json['deposit'].toString())
					: null,
			ownerName:
				(json['ownerName'] ?? json['OwnerName'] ?? json['contactName'] ?? json['ContactName'] ?? '')
						.toString(),
			isActive: computedIsActive,
			createdAt: DateTime.tryParse(
					(json['createdAt'] ?? json['CreatedAt'] ?? '').toString(),
				) ??
					DateTime.now(),
			// Backend może zwracać ImageIds/ImagesIds zamiast imageUrls.
			imageUrls: (json['imageUrls'] ??
					json['ImageUrls'] ??
					json['imageIds'] ??
					json['ImageIds'] ??
					[])
					.cast<String>()
					.toList(),
			isOwner: (json['isOwner'] ?? json['IsOwner'] ?? false) as bool,
			category:
				(json['category'] ?? json['Category'])?.toString(),
			contactName:
				(json['contactName'] ?? json['ContactName'])?.toString(),
			contactNumber:
					(json['contactNumber'] ?? json['ContactNumber'])?.toString(),
				isUrgent:
					(json['isUrgent'] ?? json['IsUrgent'] ?? false) as bool,
				expiresAt: DateTime.tryParse(
						(json['expiresAt'] ?? json['ExpiresAt'] ?? '').toString(),
					),
		);
	}

	Map<String, dynamic> toJson() {
		return <String, dynamic>{
			// Wysyłamy OfferId jako id oferty.
			'OfferId': id,
			'UserId': userId,
			'Title': title,
			'Description': description,
			'Location': location,
			'Category': category,
			'ContactName': contactName ?? ownerName,
			'ContactNumber': contactNumber,
			'deposit': deposit,
			'ownerName': ownerName,
			'IsActive': isActive,
			'CreatedAt': createdAt.toIso8601String(),
			'ImageIds': imageUrls,
			'IsOwner': isOwner,
			'IsUrgent': isUrgent,
			'ExpiresAt': expiresAt?.toIso8601String(),
		};
	}
}
