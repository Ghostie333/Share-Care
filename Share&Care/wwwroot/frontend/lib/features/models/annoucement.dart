class Announcement {

  double? lat; 
  double? lng; 

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
    this.lat,
    this.lng,
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

		({double lat, double lng})? tryParseLatLngString(String raw) {
			final parts = raw.split(',');
			if (parts.length != 2) return null;
			final lat = double.tryParse(parts[0].trim());
			final lng = double.tryParse(parts[1].trim());
			if (lat == null || lng == null) return null;
			if (lat < -90 || lat > 90) return null;
			if (lng < -180 || lng > 180) return null;
			return (lat: lat, lng: lng);
		}

		({double lat, double lng})? parseCoords(dynamic value) {
			if (value == null) return null;

			// GeoJSON: { "type":"Point", "coordinates":[lng, lat] }
			if (value is Map<String, dynamic>) {
				final coords = value['coordinates'];
				if (coords is List && coords.length >= 2) {
					final lng = coords[0];
					final lat = coords[1];
					if (lat is num && lng is num) {
						return (lat: lat.toDouble(), lng: lng.toDouble());
					}
				}
				final lat = value['lat'] ?? value['Lat'];
				final lng = value['lng'] ?? value['Lng'];
				if (lat is num && lng is num) {
					return (lat: lat.toDouble(), lng: lng.toDouble());
				}
			}

			if (value is String) {
				return tryParseLatLngString(value);
			}

			return null;
		}

		final locationText =
			(json['locationText'] ?? json['LocationText'] ?? '').toString().trim();

		final coords = parseCoords(json['location'] ?? json['Location']) ??
			(locationText.isNotEmpty ? tryParseLatLngString(locationText) : null);

		final displayLocation = locationText.isNotEmpty
			? locationText
			: (coords != null ? '${coords.lat},${coords.lng}' : '');

		return Announcement(
			// Obsługa OfferId/offerId/id z backendu.
			id: (json['offerId'] ?? json['OfferId'] ?? json['id'] ?? json['Id'])
					.toString(),
			userId:
				(json['userId'] ?? json['UserId'])?.toString(),
			title: (json['title'] ?? json['Title'] ?? '').toString(),
			description:
				(json['description'] ?? json['Description'] ?? '').toString(),
			location: displayLocation,
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
			lat: coords?.lat,
			lng: coords?.lng,
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
			'LocationText': location,
			'Lat': lat,
			'Lng': lng,
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
