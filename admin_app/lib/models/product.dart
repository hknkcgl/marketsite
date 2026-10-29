class Product {
  final String sku;
  String name;
  String category;
  double price;
  String unit;
  int stock;
  String image;
  String description;

  // Track original values to detect changes
  final double initialPrice;
  final int initialStock;

  Product({
    required this.sku,
    required this.name,
    required this.category,
    required this.price,
    required this.unit,
    required this.stock,
    required this.image,
    required this.description,
    double? initialPrice,
    int? initialStock,
  })  : initialPrice = initialPrice ?? price,
        initialStock = initialStock ?? stock;

  bool get isModified => price != initialPrice || stock != initialStock;
  bool get isInStock => stock > 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final priceVal = json['price'];
    final double parsedPrice = priceVal is int ? priceVal.toDouble() : (priceVal as num).toDouble();
    final stockVal = json['stock'] ?? 0;
    final int parsedStock = stockVal is double ? stockVal.toInt() : (stockVal as int);

    return Product(
      sku: json['sku'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Genel',
      price: parsedPrice,
      unit: json['unit'] as String? ?? 'adet',
      stock: parsedStock,
      image: json['image'] as String? ?? '',
      description: json['description'] as String? ?? '',
      initialPrice: parsedPrice,
      initialStock: parsedStock,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sku': sku,
      'name': name,
      'category': category,
      'price': price,
      'unit': unit,
      'stock': stock,
      'image': image,
      'description': description,
    };
  }

  Product copyWith({
    String? name,
    String? category,
    double? price,
    String? unit,
    int? stock,
    String? image,
    String? description,
  }) {
    return Product(
      sku: sku,
      name: name ?? this.name,
      category: category ?? this.category,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      stock: stock ?? this.stock,
      image: image ?? this.image,
      description: description ?? this.description,
      initialPrice: initialPrice,
      initialStock: initialStock,
    );
  }
}
