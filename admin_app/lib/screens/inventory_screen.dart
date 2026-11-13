import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../services/github_service.dart';
import '../theme/app_colors.dart';
import '../widgets/product_thumbnail.dart';
import 'settings_dialog.dart';
import 'product_edit_dialog.dart';

class InventoryScreen extends StatefulWidget {
  final GitHubService? githubService;
  final List<Product>? initialProducts;

  const InventoryScreen({super.key, this.githubService, this.initialProducts});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  late final GitHubService _githubService;

  List<Product> _allProducts = [];
  final List<Product> _deletedProducts = [];
  bool _isLoading = true;
  String? _errorMessage;

  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  String _stockFilter = 'all'; // all, in_stock, out_of_stock, modified

  bool _isPublishing = false;
  bool _isSyncingGit = false;

  Future<void> _syncLocalGitPull({bool isAuto = false}) async {
    setState(() => _isSyncingGit = true);
    try {
      final output = await _githubService.gitPullLocalRepo();
      _githubService.clearImageCache();
      if (mounted) {
        setState(() => _isSyncingGit = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.deepPurple.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                const Icon(Icons.terminal, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAuto
                        ? 'Otomatik Yerel Senkronizasyon: $output'
                        : 'Yerel Git Pull Başarılı: $output',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSyncingGit = false);
        if (!isAuto) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.red.shade700,
              content: Text(
                'Yerel Git Pull Hatası: ${e.toString().replaceAll('Exception: ', '')}',
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _githubService = widget.githubService ?? GitHubService();
    if (widget.initialProducts != null) {
      _allProducts = List.from(widget.initialProducts!);
      _isLoading = false;
    } else {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _deletedProducts.clear();
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

  List<Product> get _modifiedProducts =>
      _allProducts.where((p) => p.isModified).toList();
  int get _totalChangesCount =>
      _modifiedProducts.length + _deletedProducts.length;
  bool get _hasChanges => _totalChangesCount > 0;

  List<Product> get _filteredProducts {
    return _allProducts.where((p) {
      final matchesCategory =
          _selectedCategory == 'Tümü' || p.category == _selectedCategory;

      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch =
          query.isEmpty ||
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

  Future<void> _deleteProduct(Product product) async {
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
          '${product.name} (${product.sku}) ürününü silmek istediğinize emin misiniz?\n\nDeğişiklikleri kaydedip yayınladığınızda ürün siteden kaldırılacaktır.',
          style: const TextStyle(fontSize: 13),
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
      setState(() {
        _allProducts.removeWhere((p) => p.sku == product.sku);
        if (!product.isNew) {
          _deletedProducts.add(product);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} silinmek üzere işaretlendi.'),
          action: SnackBarAction(
            label: 'Geri Al',
            onPressed: () {
              setState(() {
                _deletedProducts.removeWhere((p) => p.sku == product.sku);
                _allProducts.add(product);
              });
            },
          ),
        ),
      );
    }
  }

  void _revertProduct(Product product) {
    setState(() {
      if (product.isNew) {
        _allProducts.removeWhere((p) => p.sku == product.sku);
      } else {
        product.revertChanges();
      }
    });
  }

  void _revertAllChanges() {
    setState(() {
      for (final p in _deletedProducts) {
        _allProducts.add(p);
      }
      _deletedProducts.clear();
      _allProducts.removeWhere((p) => p.isNew);
      for (final p in _allProducts) {
        p.revertChanges();
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tüm yerel değişiklikler geri alındı.')),
    );
  }

  Future<void> _saveAndPublish() async {
    final modified = _modifiedProducts;
    final deleted = List<Product>.from(_deletedProducts);

    if (!_hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaydedilecek bir değişiklik bulunmuyor.'),
        ),
      );
      return;
    }

    if (!_githubService.hasToken) {
      if (kDebugMode) _openSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Yayınlama yapılandırması eksik. Lütfen yöneticinize başvurun.',
          ),
        ),
      );
      return;
    }

    final commitMessage =
        'envanter güncellemesi: ${modified.length} ürün güncellendi, ${deleted.length} ürün silindi';

    setState(() => _isPublishing = true);

    try {
      // 1. Bekleyen yeni ürün görsellerini GitHub'a push et
      int uploadedImagesCount = 0;
      for (final p in _allProducts) {
        if (p.hasPendingImage) {
          await _githubService.pushImageFile(
            repoFilePath: p.image,
            bytes: p.pendingImageBytes!,
          );
          uploadedImagesCount++;
        }
      }

      // 2. Güncellenmiş ürün listesini GitHub'a push et
      await _githubService.pushProducts(
        _allProducts,
        customMessage: commitMessage,
      );

      // 3. Silinen ürünlerin varsa özel görsellerini GitHub'dan ve yerel diskten temizle
      for (final d in deleted) {
        final sharedByOther = _allProducts.any((p) => p.image == d.image);
        if (d.image.isNotEmpty &&
            !d.image.contains('placeholder') &&
            !sharedByOther) {
          try {
            await _githubService.deleteImageFile(repoFilePath: d.image);
          } catch (_) {}
        }
      }

      // Yerel ortamda data/products.json dosyası mevcutsa onu da güncelle (desync önlemi)
      try {
        final candidates = [
          File('data/products.json'),
          File('../data/products.json'),
          File('../../data/products.json'),
        ];
        for (final candidate in candidates) {
          if (candidate.existsSync()) {
            const encoder = JsonEncoder.withIndent('  ');
            final jsonStr = encoder.convert(
              _allProducts.map((p) => p.toJson()).toList(),
            );
            await candidate.writeAsString(jsonStr);
            break;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isPublishing = false;
          _deletedProducts.clear();
          // Başkasının bu arada eklediği ürünleri listeye al
          _allProducts.addAll(_githubService.lastMergedRemoteAdditions);
          // Tüm ürünlerin başlangıç durumunu güncelleyerek "Değiştirildi" bayraklarını sıfırla
          for (final p in _allProducts) {
            p.commitChanges();
          }
        });

        // Ekranı komple silip yeniden yüklemek yerine akıcı ve güvenli SnackBar bildirimi ver
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Değişiklikler kaydedildi!${uploadedImagesCount > 0 ? " • $uploadedImagesCount görsel yüklendi" : ""} - Siteniz 1-2 dk içinde güncellenecektir.',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        // Geliştirici/Test ortamında yayınlama sonrası yerel repoyu otomatik senkronize et
        if (kDebugMode) {
          _syncLocalGitPull(isAuto: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPublishing = false);
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Yayınlama Hatası'),
              ],
            ),
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
      builder: (ctx) =>
          SettingsDialog(githubService: _githubService, onSaved: _loadProducts),
    );
  }

  void _openProductEditDialog([Product? product]) {
    showDialog(
      context: context,
      builder: (ctx) => ProductEditDialog(
        product: product,
        githubService: _githubService,
        existingCategories: _categories,
        onDelete: (p) => _deleteProduct(p),
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
    final totalChanges = _totalChangesCount;

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
              child: const Icon(
                Icons.eco,
                color: AppColors.emerald700,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Yıldırımlar Manav - Stok & Fiyat Masası',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: _isSyncingGit
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.deepPurple,
                      ),
                    )
                  : const Icon(Icons.sync, size: 20, color: Colors.deepPurple),
              tooltip: 'Dev: Yerel Git Pull (origin/main senkronizasyonu)',
              onPressed: _isSyncingGit
                  ? null
                  : () => _syncLocalGitPull(isAuto: false),
            ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.black54),
              tooltip: 'Bağlantı Ayarları',
              onPressed: _openSettings,
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Yeniden Yükle',
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
            onPressed: totalChanges > 0 && !_isPublishing
                ? _saveAndPublish
                : null,
            icon: _isPublishing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 16),
            label: Text(
              totalChanges > 0 ? 'Yayınla ($totalChanges)' : 'Yayınla',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.emerald700,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: totalChanges > 0
          ? _buildModifiedFloatingBar(totalChanges)
          : null,
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
            Text('Ürünler yükleniyor...'),
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
                'Bağlantı Hatası',
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
                  if (kDebugMode) ...[
                    OutlinedButton(
                      onPressed: _openSettings,
                      child: const Text('Ayarları Kontrol Et'),
                    ),
                    const SizedBox(width: 12),
                  ],
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
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final card1 = _buildMetricCard(
                'Toplam Ürün',
                '$totalCount',
                Icons.inventory_2_outlined,
                Colors.blue,
              );
              final card2 = _buildMetricCard(
                'Sitede Yayında (Stok > 0)',
                '$inStockCount',
                Icons.check_circle_outline,
                AppColors.emerald600,
              );
              final card3 = _buildMetricCard(
                'Tükendi / Sitede Gizli',
                '$outOfStockCount',
                Icons.visibility_off_outlined,
                AppColors.stone600,
              );
              final card4 = _buildMetricCard(
                'Değiştirilen Ürünler',
                '${_modifiedProducts.length}',
                Icons.edit_note,
                _modifiedProducts.isNotEmpty
                    ? Colors.amber.shade800
                    : Colors.grey,
              );

              if (constraints.maxWidth >= 950) {
                return Row(
                  children: [
                    Expanded(child: card1),
                    const SizedBox(width: 12),
                    Expanded(child: card2),
                    const SizedBox(width: 12),
                    Expanded(child: card3),
                    const SizedBox(width: 12),
                    Expanded(child: card4),
                  ],
                );
              } else if (constraints.maxWidth >= 550) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: card1),
                        const SizedBox(width: 12),
                        Expanded(child: card2),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: card3),
                        const SizedBox(width: 12),
                        Expanded(child: card4),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    card1,
                    const SizedBox(height: 8),
                    card2,
                    const SizedBox(height: 8),
                    card3,
                    const SizedBox(height: 8),
                    card4,
                  ],
                );
              }
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppColors.stone200),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 850;

                  final searchField = TextField(
                    decoration: const InputDecoration(
                      hintText: 'Stok Kodu (SKU), Ürün veya Kategori ara...',
                      prefixIcon: Icon(Icons.search, size: 20),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  );

                  final categoryDropdown = DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCategory,
                      isDense: true,
                      icon: const Icon(Icons.filter_list, size: 18),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedCategory = val);
                        }
                      },
                    ),
                  );

                  final segmentedFilter = SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'all',
                        label: Text('Tümü', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 'in_stock',
                        label: Text('Stokta', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 'out_of_stock',
                        label: Text('Tükenen', style: TextStyle(fontSize: 12)),
                      ),
                      ButtonSegment(
                        value: 'modified',
                        label: Text(
                          'Değişenler',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    selected: {_stockFilter},
                    onSelectionChanged: (val) =>
                        setState(() => _stockFilter = val.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  );

                  if (!isCompact) {
                    return Row(
                      children: [
                        Expanded(flex: 3, child: searchField),
                        const SizedBox(
                          height: 24,
                          child: VerticalDivider(width: 24, thickness: 1),
                        ),
                        categoryDropdown,
                        const SizedBox(width: 12),
                        segmentedFilter,
                      ],
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        searchField,
                        const Divider(height: 16, thickness: 1),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          alignment: WrapAlignment.spaceBetween,
                          children: [categoryDropdown, segmentedFilter],
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
          ),
        ),

        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(
                  child: Text(
                    'Kriterlere uygun ürün bulunamadı.',
                    style: TextStyle(color: Colors.black45),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final needsHorizontalScroll = constraints.maxWidth < 900;
                    final listView = ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 80),
                      itemCount: _filteredProducts.length,
                      separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) =>
                          _buildProductRow(_filteredProducts[i]),
                    );

                    if (needsHorizontalScroll) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(width: 900, child: listView),
                      );
                    }
                    return listView;
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Tooltip(
      message: '$label: $value',
      waitDuration: const Duration(milliseconds: 500),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
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
        color: isModified
            ? Colors.amber.shade50.withValues(alpha: 0.5)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isModified
              ? Colors.amber.shade300
              : (isHidden ? AppColors.stone300 : AppColors.stone200),
          width: isModified ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Sabit Boyutlu Kare Görsel Önizleme (Asla Büyümez, Tam Sığar)
          ProductThumbnail(
            product: p,
            githubService: _githubService,
            size: 42,
            borderRadius: 8,
            onTap: () => _openProductEditDialog(p),
          ),
          const SizedBox(width: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.stone100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              p.sku,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isHidden ? AppColors.stone600 : Colors.black87,
                  ),
                ),
                Text(
                  '${p.category} • 1 ${p.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black45),
                ),
              ],
            ),
          ),

          Tooltip(
            message: p.isInStock ? 'Sitede Yayında' : 'Sitede Gizli (Stok: 0)',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: p.isInStock ? AppColors.emerald50 : AppColors.stone100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: p.isInStock
                      ? AppColors.emerald200
                      : AppColors.stone300,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    p.isInStock ? Icons.check_circle : Icons.visibility_off,
                    size: 13,
                    color: p.isInStock
                        ? AppColors.emerald700
                        : AppColors.stone600,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    p.isInStock ? 'Yayında' : 'Gizli (Stok: 0)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: p.isInStock
                          ? AppColors.emerald800
                          : AppColors.stone700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),

          SizedBox(
            width: 140,
            child: Row(
              children: [
                const Text(
                  '₺ ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black54,
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${p.sku}_price_${p.price}'),
                    initialValue: p.price.toStringAsFixed(2),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
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
                Text(
                  ' /${p.unit}',
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),

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
              tooltip:
                  'Değişikliği Geri Al (Fiyat: ₺${p.initialPrice}, Stok: ${p.initialStock})',
              onPressed: () => _revertProduct(p),
            ),

          IconButton(
            icon: const Icon(
              Icons.edit_outlined,
              size: 18,
              color: Colors.black45,
            ),
            tooltip: 'Ürünü Düzenle',
            onPressed: () => _openProductEditDialog(p),
          ),

          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
            tooltip: 'Ürünü Sil',
            onPressed: () => _deleteProduct(p),
          ),
        ],
      ),
    );
  }

  Widget _buildModifiedFloatingBar(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 520;

          final iconWidget = Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.amber.shade400,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit, size: 16, color: Colors.black87),
          );

          final textWidget = Text(
            '$count adet üründe henüz yayınlanmamış değişiklik (ekleme/stok/fiyat/silme) var.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          );

          final revertButton = TextButton(
            onPressed: _revertAllChanges,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.stone400,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              constraints.maxWidth < 650 ? 'İptal' : 'Tümünü İptal Et',
            ),
          );

          final publishButton = ElevatedButton.icon(
            onPressed: _isPublishing ? null : _saveAndPublish,
            icon: _isPublishing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.cloud_upload, size: 16),
            label: Text(
              constraints.maxWidth < 750
                  ? 'Yayınla'
                  : 'Kaydet ve Yayınla',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
          );

          if (!isCompact) {
            return Row(
              children: [
                iconWidget,
                const SizedBox(width: 10),
                Expanded(child: textWidget),
                revertButton,
                const SizedBox(width: 8),
                publishButton,
              ],
            );
          } else {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    iconWidget,
                    const SizedBox(width: 8),
                    Expanded(child: textWidget),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    revertButton,
                    const SizedBox(width: 6),
                    publishButton,
                  ],
                ),
              ],
            );
          }
        },
      ),
    );
  }
}
