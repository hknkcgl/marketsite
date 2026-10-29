import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_colors.dart';

class ProductEditDialog extends StatefulWidget {
  final Product? product; // null ise Yeni Ürün
  final List<String> existingCategories;
  final Function(Product) onSave;

  const ProductEditDialog({
    super.key,
    this.product,
    required this.existingCategories,
    required this.onSave,
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

  final List<String> _units = ['kg', 'demet', 'adet', 'kutu', 'file', 'kasa', 'bağ'];

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _nameController = TextEditingController(text: p?.name ?? '');
    _categoryController = TextEditingController(text: p?.category ?? 'Taze Sebzeler');
    _priceController = TextEditingController(text: p?.price.toStringAsFixed(2) ?? '');
    _stockController = TextEditingController(text: p?.stock.toString() ?? '10');
    _unitController = TextEditingController(text: p?.unit ?? 'kg');
    _descriptionController = TextEditingController(text: p?.description ?? '');
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
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final String sku = _skuController.text.trim().toUpperCase();
    final String name = _nameController.text.trim();
    final String category = _categoryController.text.trim();
    final double price = double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0.0;
    final int stock = int.tryParse(_stockController.text) ?? 0;
    final String unit = _unitController.text.trim();
    final String description = _descriptionController.text.trim();

    final product = Product(
      sku: sku,
      name: name,
      category: category,
      price: price,
      unit: unit,
      stock: stock,
      image: widget.product?.image ?? 'assets/images/products/$sku.jpg',
      description: description,
      initialPrice: widget.product?.initialPrice ?? price,
      initialStock: widget.product?.initialStock ?? stock,
    );

    widget.onSave(product);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.product == null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
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
                        isNew ? 'Yeni Manav Ürünü Ekle' : 'Ürün Düzenle (${widget.product!.sku})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

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
                          validator: (val) => val == null || val.trim().isEmpty ? 'Gerekli' : null,
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
                          validator: (val) => val == null || val.trim().isEmpty ? 'Gerekli' : null,
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
                          validator: (val) => val == null || val.trim().isEmpty ? 'Gerekli' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          initialValue: _units.contains(_unitController.text) ? _unitController.text : _units.first,
                          decoration: const InputDecoration(
                            labelText: 'Birim *',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: _units.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
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
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Birim Fiyat (₺) *',
                            prefixText: '₺ ',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Gerekli';
                            if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Geçersiz sayı';
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
                            if (val == null || val.trim().isEmpty) return 'Gerekli';
                            if (int.tryParse(val) == null) return 'Geçersiz tam sayı';
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
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
}
