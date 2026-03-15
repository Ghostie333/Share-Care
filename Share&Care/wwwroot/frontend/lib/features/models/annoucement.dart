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
	}) : imageUrls = imageUrls ?? [];

	factory Announcement.fromJson(Map<String, dynamic> json) {
		return Announcement(
			// Obsługa OfferId/offerId/id z backendu.
			id: (json['offerId'] ?? json['OfferId'] ?? json['id'] ?? json['Id'])
					.toString(),
			userId:
				(json['userId'] ?? json['UserId'])?.toString(),
			title: (json['title'] ?? json['Title'] ?? '').toString(),
			description:
				(json['description'] ?? json['Description'] ?? '').toString(),
			location: (json['location'] ?? json['Location'] ?? '').toString(),
			deposit: json['deposit'] != null
					? double.tryParse(json['deposit'].toString())
					: null,
			ownerName:
				(json['ownerName'] ?? json['OwnerName'] ?? json['contactName'] ?? json['ContactName'] ?? '')
						.toString(),
			isActive: (json['isActive'] ?? json['IsActive'] ?? true) as bool,
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
		};
	}
}
