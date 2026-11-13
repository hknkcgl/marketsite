import 'dart:typed_data';

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
  double initialPrice;
  int initialStock;
  String initialImage;

  // Yeni seçilen ve GitHub'a push edilmeyi bekleyen görsel verisi
  Uint8List? pendingImageBytes;
  String? pendingImageExt;
  String? pendingImageLocalPath;

  /// Yeni eklenen ve henüz GitHub'a commit edilmemiş ürün bayrağı
  bool isNew;

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
    String? initialImage,
    this.pendingImageBytes,
    this.pendingImageExt,
    this.pendingImageLocalPath,
    this.isNew = false,
  }) : initialPrice = initialPrice ?? price,
       initialStock = initialStock ?? stock,
       initialImage = initialImage ?? image;

  bool get hasPendingImage => pendingImageBytes != null;
  bool get isModified =>
      isNew ||
      price != initialPrice ||
      stock != initialStock ||
      hasPendingImage ||
      image != initialImage;
  bool get isInStock => stock > 0;

  /// Değişiklikler başarıyla yayınlandığında yerel başlangıç durumunu günceller
  void commitChanges() {
    isNew = false;
    initialPrice = price;
    initialStock = stock;
    initialImage = image;
    pendingImageBytes = null;
    pendingImageExt = null;
    pendingImageLocalPath = null;
  }

  /// Tüm yerel değişiklikleri ilk haline geri alır
  void revertChanges() {
    price = initialPrice;
    stock = initialStock;
    image = initialImage;
    pendingImageBytes = null;
    pendingImageExt = null;
    pendingImageLocalPath = null;
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return parseNumber(v) ?? 0.0;
    return 0.0;
  }

  /// Türkçe/İngilizce yazımlı sayıyı çözer: "12,5", "12.5", "1.250,50", "1,250.50".
  /// Hem nokta hem virgül varsa sondaki ondalık ayracıdır. Tek ayraçta 3 haneli
  /// belirsiz durum ("1.250") ve negatif değerler için null döner.
  static double? parseNumber(String input) {
    var t = input.trim().replaceAll(' ', '');
    if (t.isEmpty || t.startsWith('-')) return null;
    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma != -1 && lastDot != -1) {
      final dec = lastComma > lastDot ? ',' : '.';
      final thou = dec == ',' ? '.' : ',';
      if (t.indexOf(dec) != t.lastIndexOf(dec)) return null;
      t = t.replaceAll(thou, '').replaceAll(dec, '.');
    } else if (lastComma != -1 || lastDot != -1) {
      final sep = lastComma != -1 ? ',' : '.';
      final parts = t.split(sep);
      if (parts.length > 2) return null; // 1.250.500 gibi belirsiz
      if (parts[1].length == 3 && parts[0].isNotEmpty && parts[0] != '0') return null; // 1.250 belirsiz
      t = t.replaceAll(sep, '.');
    }
    return double.tryParse(t);
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    final double parsedPrice = _toDouble(json['price']);
    final int parsedStock = _toDouble(json['stock']).toInt();
    final img = json['image'] as String? ?? '';

    return Product(
      sku: json['sku'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? 'Genel',
      price: parsedPrice,
      unit: json['unit'] as String? ?? 'adet',
      stock: parsedStock,
      image: img,
      description: json['description'] as String? ?? '',
      initialPrice: parsedPrice,
      initialStock: parsedStock,
      initialImage: img,
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
    Uint8List? pendingImageBytes,
    String? pendingImageExt,
    String? pendingImageLocalPath,
    bool? isNew,
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
      initialImage: initialImage,
      pendingImageBytes: pendingImageBytes ?? this.pendingImageBytes,
      pendingImageExt: pendingImageExt ?? this.pendingImageExt,
      pendingImageLocalPath:
          pendingImageLocalPath ?? this.pendingImageLocalPath,
      isNew: isNew ?? this.isNew,
    );
  }
}
