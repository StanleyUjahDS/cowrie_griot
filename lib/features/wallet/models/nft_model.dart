class NftModel {
  final String network;
  final String owner;
  final String contractAddress;
  final String tokenId;
  final String standard;
  final String quantity;
  final String name;
  final String collectionName;
  final String description;
  final String? imageUrl;
  final String? animationUrl;
  final NftClassification classification;
  final Map<String, String> externalLinks;

  const NftModel({
    required this.network,
    required this.owner,
    required this.contractAddress,
    required this.tokenId,
    required this.standard,
    required this.quantity,
    required this.name,
    required this.collectionName,
    required this.description,
    this.imageUrl,
    this.animationUrl,
    required this.classification,
    this.externalLinks = const {},
  });

  String get identity => '$network:$contractAddress:$tokenId';

  factory NftModel.fromJson(Map<String, dynamic> json) {
    return NftModel(
      network: json['network']?.toString() ?? '',
      owner: json['owner']?.toString() ?? '',
      contractAddress: json['contractAddress']?.toString() ?? '',
      tokenId: json['tokenId']?.toString() ?? '',
      standard: json['standard']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '1',
      name: json['name']?.toString() ?? '',
      collectionName: json['collectionName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      imageUrl: json['imageUrl']?.toString(),
      animationUrl: json['animationUrl']?.toString(),
      classification: NftClassification.fromJson(
        Map<String, dynamic>.from(json['classification'] ?? {}),
      ),
      externalLinks: Map<String, String>.from(json['externalLinks'] ?? {}),
    );
  }
}

class NftClassification {
  final String status;
  final bool isSpam;
  final bool isTradeable;
  final List<String> reasons;

  const NftClassification({
    required this.status,
    this.isSpam = false,
    this.isTradeable = false,
    this.reasons = const [],
  });

  factory NftClassification.fromJson(Map<String, dynamic> json) {
    return NftClassification(
      status: json['status']?.toString() ?? 'unknown',
      isSpam: json['isSpam'] == true,
      isTradeable: json['isTradeable'] == true,
      reasons: List<String>.from(json['reasons'] ?? []),
    );
  }
}
