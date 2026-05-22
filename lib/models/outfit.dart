class Outfit {
  final int id;
  final String name;
  final List<int> itemIds;
  final String image;

  Outfit({required this.id, required this.name, required this.itemIds, required this.image});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'itemIds': itemIds.join(','),
        'image': image,
      };

  // Demo/sample outfits for BrowsePage
  static List<Outfit> sampleOutfits() => [
    Outfit(id: 1, name: 'Casual Day', itemIds: [1,2,3], image: 'assets/closetmate.jpg'),
    Outfit(id: 2, name: 'Evening Chic', itemIds: [4,5,6], image: 'assets/closetmate.jpg'),
    Outfit(id: 3, name: 'Sporty', itemIds: [7,8,9], image: 'assets/closetmate.jpg'),
  ];
}
