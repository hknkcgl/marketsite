import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/github_service.dart';
import '../services/native_file_picker.dart';
import '../theme/app_colors.dart';
import '../widgets/product_thumbnail.dart';

class ProductEditDialog extends StatefulWidget {
  final Product? product; // null ise Yeni Ürün
  final GitHubService? githubService;
  final List<String> existingCategories;
  final Function(Product) onSave;
  final void Function(Product)? onDelete;

  const ProductEditDialog({
    super.key,
    this.product,
    this.githubService,
    required this.existingCategories,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<ProductEditDialog> createState() => _ProductEditDialogState();
}

class _ProductEditDialogState extends State<ProductEditDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _skuController;
  late final TextEditingController _nameController;
  late final TextEditingController _categoryController;
  late final TextEditingController _priceController;
  late final TextEditingController _stockController;
  late final TextEditingController _unitController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _imageController;

  Uint8List? _newImageBytes;
  String? _newImageExt;
  String? _newImageLocalPath;
  bool _showAdvancedPath = false;

  final List<String> _units = [
    'kg',
    'demet',
    'adet',
    'kutu',
    'file',
    'kasa',
    'bağ',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _categoryController = TextEditingController(
      text: p?.category ?? 'Taze Sebzeler',
    );
    _priceController = TextEditingController(
      text: p?.price.toStringAsFixed(2) ?? '',
    );
    _stockController = TextEditingController(text: p?.stock.toString() ?? '10');
    _unitController = TextEditingController(text: p?.unit ?? 'kg');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _imageController = TextEditingController(text: p?.image ?? '');

    _newImageBytes = p?.pendingImageBytes;
    _newImageExt = p?.pendingImageExt;
    _newImageLocalPath = p?.pendingImageLocalPath;
  }

  @override
  void dispose() {
    _skuController.dispose();
    _nameController.dispose();
    _categoryController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _unitController.dispose();
    _descriptionController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await NativeFilePicker.pickImage();
    if (file != null) {
      try {
        final bytes = await file.readAsBytes();
        final ext = NativeFilePicker.extractExtension(file.path);
        final currentSku = _skuController.text.trim().toUpperCase();
        final effectiveSku = currentSku.isNotEmpty ? currentSku : 'URUN';

        setState(() {
          _newImageBytes = bytes;
          _newImageExt = ext;
          _newImageLocalPath = file.path;
          _imageController.text = 'assets/images/products/$effectiveSku.$ext';
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Görsel okunamadı: $e')));
        }
      }
    }
  }

  void _clearImage() {
    setState(() {
      _newImageBytes = null;
      _newImageExt = null;
      _newImageLocalPath = null;
      _imageController.text = '';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final String sku = _skuController.text.trim().toUpperCase();
    final String name = _nameController.text.trim();
    final String category = _categoryController.text.trim();
    final double price =
        Product.parseNumber(_priceController.text) ?? 0.0;
    final int stock = int.tryParse(_stockController.text) ?? 0;
    final String unit = _unitController.text.trim();
    final String description = _descriptionController.text.trim();

    String finalImagePath = _imageController.text.trim();
    if (finalImagePath.isEmpty) {
      if (_newImageExt != null) {
        finalImagePath = 'assets/images/products/$sku.$_newImageExt';
      } else if (widget.product != null && widget.product!.image.isNotEmpty) {
        finalImagePath = widget.product!.image;
      } else {
        finalImagePath = 'assets/images/products/$sku.jpg';
      }
    }

    final isNew = widget.product == null;

    final product = Product(
      sku: sku,
      name: name,
      category: category,
      price: price,
      unit: unit,
      stock: stock,
      image: finalImagePath,
      description: description,
      initialPrice: widget.product?.initialPrice ?? price,
      initialStock: widget.product?.initialStock ?? stock,
      initialImage: widget.product?.initialImage ?? finalImagePath,
      isNew: isNew,
      pendingImageBytes: _newImageBytes,
      pendingImageExt: _newImageExt,
      pendingImageLocalPath: _newImageLocalPath,
    );

    widget.onSave(product);
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.delete_forever, color: Colors.red),
            SizedBox(width: 8),
            Text('Ürünü Sil'),
          ],
        ),
        content: Text(
          '${widget.product!.name} (${widget.product!.sku}) ürününü silmek istediğinize emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      widget.onDelete?.call(widget.product!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.emerald50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.eco,
                          color: AppColors.emerald800,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        isNew
                            ? 'Yeni Manav Ürünü Ekle'
                            : 'Ürün Düzenle (${widget.product!.sku})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // GÖRSEL SEÇİM ALANI
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.stone50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.stone200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Sabit Kare Görsel Önizleme Kutusu (Asla Büyümez, Tam Sığar)
                        Container(
                          width: 90,
                          height: 90,
                          constraints: const BoxConstraints.tightFor(
                            width: 90,
                            height: 90,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _newImageBytes != null
                                  ? AppColors.emerald500
                                  : AppColors.stone300,
                              width: _newImageBytes != null ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _buildImagePreview(),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Görsel Butonları ve Bilgisi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: _pickImage,
                                    icon: const Icon(
                                      Icons.add_photo_alternate_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      _newImageBytes != null ||
                                              (widget
                                                      .product
                                                      ?.image
                                                      .isNotEmpty ==
                                                  true)
                                          ? 'Görseli Değiştir'
                                          : 'Görsel Seç',
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      foregroundColor: AppColors.emerald800,
                                      side: const BorderSide(
                                        color: AppColors.emerald300,
                                      ),
                                    ),
                                  ),
                                  if (_newImageBytes != null ||
                                      _imageController.text.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                        color: Colors.red,
                                      ),
                                      tooltip: 'Görseli Kaldır',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _clearImage,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _newImageBytes != null
                                    ? '✓ Yeni görsel hazır (Yayınla dediğinizde GitHub\'a push edilecek)'
                                    : 'JPG, PNG veya WEBP formatında ürün fotoğrafı seçebilirsiniz.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _newImageBytes != null
                                      ? AppColors.emerald800
                                      : Colors.black54,
                                  fontWeight: _newImageBytes != null
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () => setState(
                                  () => _showAdvancedPath = !_showAdvancedPath,
                                ),
                                child: Text(
                                  _showAdvancedPath
                                      ? '▲ Manuel yolu gizle'
                                      : '▼ Dosya yolunu düzenle (${_imageController.text.isNotEmpty ? _imageController.text : 'otomatik'})',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.blueGrey,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_showAdvancedPath) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _imageController,
                      decoration: const InputDecoration(
                        labelText: 'Repo İçi Görsel Yolu veya Web URL',
                        hintText: 'assets/images/products/SEB-001.jpg',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // SKU & İsim
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: _skuController,
                          enabled: isNew,
                          decoration: const InputDecoration(
                            labelText: 'Stok Kodu (SKU) *',
                            hintText: 'SEB-006',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Gerekli'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Ürün Adı *',
                            hintText: 'Köy Biberi',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Gerekli'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Kategori & Birim
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _categoryController,
                          decoration: const InputDecoration(
                            labelText: 'Kategori *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) => val == null || val.trim().isEmpty
                              ? 'Gerekli'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: _units.contains(_unitController.text)
                              ? _unitController.text
                              : _units.first,
                          decoration: const InputDecoration(
                            labelText: 'Birim *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _units
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) _unitController.text = val;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Fiyat & Stok
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Birim Fiyat (₺) *',
                            prefixText: '₺ ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Gerekli';
                            if (Product.parseNumber(val) == null)
                              return 'Geçersiz sayı (örn: 12,50 — binlik ayracı kullanmayın)';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Stok Miktarı *',
                            helperText: '0 olursa sitede otomatik gizlenir',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty)
                              return 'Gerekli';
                            if (int.tryParse(val) == null)
                              return 'Geçersiz tam sayı';
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Açıklama
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Ürün Açıklaması',
                      hintText: 'Taze günlük köy hasadı...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Butonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isNew && widget.onDelete != null) ...[
                        TextButton.icon(
                          onPressed: _confirmDelete,
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Colors.red,
                          ),
                          label: const Text(
                            'Ürünü Sil',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                        const Spacer(),
                      ],
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('İptal'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 12,
                          ),
                        ),
                        child: Text(isNew ? 'Ürünü Ekle' : 'Güncelle'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_newImageBytes != null) {
      return Image.memory(
        _newImageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildPlaceholderIcon(),
      );
    }
    if (widget.product != null) {
      return ProductThumbnail(
        product: widget.product!,
        githubService: widget.githubService,
        size: 90,
        borderRadius: 10,
      );
    }
    return _buildPlaceholderIcon();
  }

  Widget _buildPlaceholderIcon() {
    return Container(
      color: AppColors.stone100,
      child: const Center(
        child: Icon(
          Icons.camera_alt_outlined,
          color: AppColors.stone400,
          size: 32,
        ),
      ),
    );
  }
}
