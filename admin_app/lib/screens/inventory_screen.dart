import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/github_service.dart';
import '../theme/app_colors.dart';
import 'settings_dialog.dart';
import 'product_edit_dialog.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final GitHubService _githubService = GitHubService();

  List<Product> _allProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  String _stockFilter = 'all'; // all, in_stock, out_of_stock, modified

  bool _isPublishing = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _githubService.loadSettings();
      final products = await _githubService.fetchProducts();
      if (mounted) {
        setState(() {
          _allProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<Product> get _modifiedProducts => _allProducts.where((p) => p.isModified).toList();

  List<Product> get _filteredProducts {
    return _allProducts.where((p) {
      final matchesCategory = _selectedCategory == 'Tümü' || p.category == _selectedCategory;

      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty ||
          p.sku.toLowerCase().contains(query) ||
          p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);

      bool matchesStock = true;
      if (_stockFilter == 'in_stock') {
        matchesStock = p.isInStock;
      } else if (_stockFilter == 'out_of_stock') {
        matchesStock = !p.isInStock;
      } else if (_stockFilter == 'modified') {
        matchesStock = p.isModified;
      }

      return matchesCategory && matchesSearch && matchesStock;
    }).toList();
  }

  List<String> get _categories {
    final set = {'Tümü', ..._allProducts.map((p) => p.category)};
    return set.toList();
  }

  void _updatePrice(Product product, double newPrice) {
    setState(() {
      product.price = newPrice;
    });
  }

  void _updateStock(Product product, int delta) {
    setState(() {
      final newStock = product.stock + delta;
      product.stock = newStock < 0 ? 0 : newStock;
    });
  }

  void _setStock(Product product, int exactStock) {
    setState(() {
      product.stock = exactStock < 0 ? 0 : exactStock;
    });
  }

  void _revertProduct(Product product) {
    setState(() {
      product.price = product.initialPrice;
      product.stock = product.initialStock;
    });
  }

  void _revertAllChanges() {
    setState(() {
      for (final p in _allProducts) {
        p.price = p.initialPrice;
        p.stock = p.initialStock;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tüm yerel değişiklikler geri alındı.')),
    );
  }

  Future<void> _publishToGitHub() async {
    final modified = _modifiedProducts;
    if (modified.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek bir değişiklik bulunmuyor.')),
      );
      return;
    }

    if (!_githubService.hasToken) {
      _openSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GitHub token girilmemiş. Lütfen ayarlar ekranından token tanımlayın.')),
      );
      return;
    }

    final commitController = TextEditingController(
      text: 'stok ve fiyat güncellemesi: ${modified.length} ürün güncellendi',
    );

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.cloud_upload, color: AppColors.emerald700),
            SizedBox(width: 10),
            Text('Değişiklikleri GitHub\'a Yayınla'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${modified.length} adet ürünün stok veya fiyat bilgisi GitHub reposuna push edilecek ve sitede hemen güncellenecek.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.stone100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView(
                shrinkWrap: true,
                children: modified.map((p) => Text(
                  '• ${p.sku} - ${p.name}: Fiyat ₺${p.initialPrice} ➔ ₺${p.price} | Stok ${p.initialStock} ➔ ${p.stock}',
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: commitController,
              decoration: const InputDecoration(
                labelText: 'Commit Mesajı',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald700,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yayınla & Push Et'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isPublishing = true);

    try {
      final commitHash = await _githubService.pushProducts(
        _allProducts,
        customMessage: commitController.text,
      );

      if (mounted) {
        setState(() => _isPublishing = false);
        await _loadProducts();

        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.emerald600),
                  SizedBox(width: 8),
                  Text('Başarıyla Yayınlandı!'),
                ],
              ),
              content: Text(
                'Değişiklikler GitHub reposuna ($commitHash) commit edildi.\n'
                'Siteniz (GitHub Pages) 1-2 dakika içinde güncel verilerle yenilenecektir.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Tamam'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Yayınlama Hatası'),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Kapat'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(
        githubService: _githubService,
        onSaved: _loadProducts,
      ),
    );
  }

  void _openProductEditDialog([Product? product]) {
    showDialog(
      context: context,
      builder: (ctx) => ProductEditDialog(
        product: product,
        existingCategories: _categories,
        onSave: (saved) {
          setState(() {
            final index = _allProducts.indexWhere((p) => p.sku == saved.sku);
            if (index > -1) {
              _allProducts[index] = saved;
            } else {
              _allProducts.add(saved);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modifiedCount = _modifiedProducts.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.eco, color: AppColors.emerald700, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Yıldırımlar Manav - Stok & Fiyat Masası',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Repo: ${_githubService.owner}/${_githubService.repo} (${_githubService.branch})',
                    style: const TextStyle(fontSize: 11, color: Colors.black45, fontFamily: 'monospace'),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black54),
            tooltip: 'GitHub Bağlantı Ayarları',
            onPressed: _openSettings,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'GitHub\'dan Yeniden Yükle',
            onPressed: _isLoading ? null : _loadProducts,
          ),
          const SizedBox(width: 8),

          OutlinedButton.icon(
            onPressed: () => _openProductEditDialog(),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Yeni Ürün'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.emerald800,
              side: const BorderSide(color: AppColors.emerald300),
            ),
          ),
          const SizedBox(width: 8),

          FilledButton.icon(
            onPressed: modifiedCount > 0 && !_isPublishing ? _publishToGitHub : null,
            icon: _isPublishing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload_outlined, size: 16),
            label: Text(modifiedCount > 0 ? 'Yayınla ($modifiedCount)' : 'Yayınla'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald700,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: modifiedCount > 0 ? _buildModifiedFloatingBar(modifiedCount) : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.emerald600),
            SizedBox(height: 16),
            Text('GitHub\'dan ürünler çekiliyor...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 14),
              const Text(
                'GitHub Bağlantı Hatası',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _openSettings,
                    child: const Text('Ayarları Kontrol Et'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _loadProducts,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final totalCount = _allProducts.length;
    final inStockCount = _allProducts.where((p) => p.isInStock).length;
    final outOfStockCount = totalCount - inStockCount;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              _buildMetricCard('Toplam Ürün', '$totalCount', Icons.inventory_2_outlined, Colors.blue),
              const SizedBox(width: 12),
              _buildMetricCard('Sitede Yayında (Stok > 0)', '$inStockCount', Icons.check_circle_outline, AppColors.emerald600),
              const SizedBox(width: 12),
              _buildMetricCard('Tükendi / Sitede Gizli', '$outOfStockCount', Icons.visibility_off_outlined, AppColors.stone600),
              const SizedBox(width: 12),
              _buildMetricCard(
                'Değiştirilen Ürünler',
                '${_modifiedProducts.length}',
                Icons.edit_note,
                _modifiedProducts.isNotEmpty ? Colors.amber.shade800 : Colors.grey,
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.stone200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Stok Kodu (SKU), Ürün veya Kategori ara...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
                    ),
                  ),
                  const VerticalDivider(width: 24, thickness: 1),

                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      icon: const Icon(Icons.filter_list, size: 18),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedCategory = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'all', label: Text('Tümü', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'in_stock', label: Text('Stokta', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'out_of_stock', label: Text('Tükenen', style: TextStyle(fontSize: 12))),
                      ButtonSegment(value: 'modified', label: Text('Değişenler', style: TextStyle(fontSize: 12))),
                    ],
                    selected: {_stockFilter},
                    onSelectionChanged: (val) => setState(() => _stockFilter = val.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(
                  child: Text('Kriterlere uygun ürün bulunamadı.', style: TextStyle(color: Colors.black45)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                  itemCount: _filteredProducts.length,
                  separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _buildProductRow(_filteredProducts[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.stone200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                Text(
                  value,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductRow(Product p) {
    final isModified = p.isModified;
    final isHidden = !p.isInStock;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isModified ? Colors.amber.shade50.withValues(alpha: 0.5) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isModified ? Colors.amber.shade300 : (isHidden ? AppColors.stone300 : AppColors.stone200),
          width: isModified ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.stone100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              p.sku,
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.bold, fontSize: 11),
            ),
          ),
          const SizedBox(width: 14),

          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isHidden ? AppColors.stone600 : Colors.black87,
                  ),
                ),
                Text(
                  '${p.category} • 1 ${p.unit}',
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: p.isInStock ? AppColors.emerald50 : AppColors.stone100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: p.isInStock ? AppColors.emerald200 : AppColors.stone300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  p.isInStock ? Icons.check_circle : Icons.visibility_off,
                  size: 13,
                  color: p.isInStock ? AppColors.emerald700 : AppColors.stone600,
                ),
                const SizedBox(width: 5),
                Text(
                  p.isInStock ? 'Sitede Yayında' : 'Sitede Gizli (Stok: 0)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: p.isInStock ? AppColors.emerald800 : AppColors.stone700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),

          SizedBox(
            width: 140,
            child: Row(
              children: [
                const Text('₺ ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${p.sku}_price_${p.price}'),
                    initialValue: p.price.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onFieldSubmitted: (val) {
                      final parsed = double.tryParse(val.replaceAll(',', '.'));
                      if (parsed != null && parsed >= 0) {
                        _updatePrice(p, parsed);
                      }
                    },
                  ),
                ),
                Text(' /${p.unit}', style: const TextStyle(fontSize: 10, color: Colors.black45)),
              ],
            ),
          ),
          const SizedBox(width: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.stone100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: p.stock > 0 ? () => _updateStock(p, -5) : null,
                  tooltip: 'Stoğu 5 Azalt',
                ),
                SizedBox(
                  width: 50,
                  child: TextFormField(
                    key: ValueKey('${p.sku}_stock_${p.stock}'),
                    initialValue: p.stock.toString(),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: p.stock == 0 ? Colors.red : Colors.black87,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                      border: InputBorder.none,
                    ),
                    onFieldSubmitted: (val) {
                      final parsed = int.tryParse(val);
                      if (parsed != null && parsed >= 0) {
                        _setStock(p, parsed);
                      }
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 16),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _updateStock(p, 5),
                  tooltip: 'Stoğu 5 Artır',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          IconButton(
            icon: Icon(
              Icons.block,
              size: 18,
              color: p.stock > 0 ? AppColors.stone400 : Colors.red.shade300,
            ),
            tooltip: 'Stoğu 0 Yap (Sitede Gizle)',
            onPressed: p.stock > 0 ? () => _setStock(p, 0) : null,
          ),

          if (isModified)
            IconButton(
              icon: const Icon(Icons.undo, size: 18, color: Colors.amber),
              tooltip: 'Değişikliği Geri Al (Fiyat: ₺${p.initialPrice}, Stok: ${p.initialStock})',
              onPressed: () => _revertProduct(p),
            ),

          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.black45),
            tooltip: 'Ürünü Düzenle',
            onPressed: () => _openProductEditDialog(p),
          ),
        ],
      ),
    );
  }

  Widget _buildModifiedFloatingBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, size: 16, color: Colors.black87),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              '$count adet üründe henüz yayınlanmamış stok/fiyat değişikliği var.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: _revertAllChanges,
            style: TextButton.styleFrom(foregroundColor: AppColors.stone400),
            child: const Text('Tümünü İptal Et'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isPublishing ? null : _publishToGitHub,
            icon: _isPublishing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.cloud_upload, size: 18),
            label: const Text('GitHub\'a Kaydet ve Sitede Yayınla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
