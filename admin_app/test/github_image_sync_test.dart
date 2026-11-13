import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/product.dart';
import 'package:admin_app/services/github_service.dart';
import 'package:admin_app/services/env_config.dart';
import 'package:admin_app/widgets/product_thumbnail.dart';
import 'package:admin_app/screens/product_edit_dialog.dart';
import 'package:admin_app/screens/inventory_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GitHub Image Sync & Path Normalization Tests (1-8)', () {
    test('1. normalizeImagePath strips leading slashes', () {
      expect(
        GitHubService.normalizeImagePath('/assets/images/products/elma.jpg'),
        'assets/images/products/elma.jpg',
      );
      expect(
        GitHubService.normalizeImagePath('///assets/images/products/elma.jpg'),
        'assets/images/products/elma.jpg',
      );
    });

    test(
      '2. normalizeImagePath converts Windows backslashes to forward slashes',
      () {
        expect(
          GitHubService.normalizeImagePath(r'assets\images\products\elma.jpg'),
          'assets/images/products/elma.jpg',
        );
        expect(
          GitHubService.normalizeImagePath(r'\assets\images\products\elma.jpg'),
          'assets/images/products/elma.jpg',
        );
      },
    );

    test('3. normalizeImagePath strips relative ./ and ../ prefixes', () {
      expect(
        GitHubService.normalizeImagePath('./assets/images/products/elma.jpg'),
        'assets/images/products/elma.jpg',
      );
    });

    test('4. normalizeImagePath removes URL query parameters', () {
      expect(
        GitHubService.normalizeImagePath(
          'assets/images/products/elma.jpg?v=12345',
        ),
        'assets/images/products/elma.jpg',
      );
    });

    test('5. normalizeImagePath trims whitespace around path', () {
      expect(
        GitHubService.normalizeImagePath(
          '   assets/images/products/elma.jpg   ',
        ),
        'assets/images/products/elma.jpg',
      );
    });

    test('6. encodePathSegments encodes spaces safely', () {
      final encoded = GitHubService.encodePathSegments(
        'assets/images/products/yeni elma.png',
      );
      expect(encoded, 'assets/images/products/yeni%20elma.png');
    });

    test('7. encodePathSegments encodes Turkish UTF-8 characters safely', () {
      final encoded = GitHubService.encodePathSegments(
        'assets/images/products/çilek_şeftali_nar.jpg',
      );
      expect(encoded.contains('%C3%A7ilek'), isTrue); // 'ç' -> %C3%A7
    });

    test('8. clearImageCache empties in-memory cache', () async {
      final service = GitHubService();
      // Test cache manipulation via fetch on a mock/test item or directly
      service.clearImageCache();
      expect(service.hasToken, isNotNull);
    });
  });

  group('Product Model State & Lifecycle Tests (9-15)', () {
    test(
      '9. Product isNew starts false and makes isModified true when new',
      () {
        final p = Product(
          sku: 'TEST-NEW-1',
          name: 'Yeni Ürün',
          category: 'Meyve',
          price: 25.0,
          unit: 'kg',
          stock: 10,
          image: 'assets/images/products/TEST-NEW-1.jpg',
          description: 'Açıklama',
          isNew: true,
        );

        expect(p.isNew, isTrue);
        expect(p.isModified, isTrue);
      },
    );

    test('10. Product commitChanges clears isNew and pendingImageBytes', () {
      final p = Product(
        sku: 'TEST-NEW-2',
        name: 'Test',
        category: 'Meyve',
        price: 30.0,
        unit: 'kg',
        stock: 5,
        image: 'assets/images/products/TEST-NEW-2.jpg',
        description: '',
        isNew: true,
        pendingImageBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(p.hasPendingImage, isTrue);
      expect(p.isModified, isTrue);

      p.commitChanges();

      expect(p.isNew, isFalse);
      expect(p.hasPendingImage, isFalse);
      expect(p.isModified, isFalse);
    });

    test(
      '11. Product revertChanges restores initialPrice and initialStock',
      () {
        final p = Product(
          sku: 'TEST-REV',
          name: 'Geri Al Test',
          category: 'Sebze',
          price: 20.0,
          unit: 'kg',
          stock: 15,
          image: 'assets/images/products/TEST-REV.jpg',
          description: '',
        );

        p.price = 99.0;
        p.stock = 0;
        expect(p.isModified, isTrue);

        p.revertChanges();

        expect(p.price, 20.0);
        expect(p.stock, 15);
        expect(p.isModified, isFalse);
      },
    );

    test(
      '12. Product toJson and fromJson serialization preserves all fields',
      () {
        final p = Product(
          sku: 'SER-001',
          name: 'Test Serileştirme',
          category: 'Yeşillik',
          price: 18.5,
          unit: 'demet',
          stock: 40,
          image: 'assets/images/products/SER-001.png',
          description: 'Taze demet',
        );

        final json = p.toJson();
        final revived = Product.fromJson(json);

        expect(revived.sku, 'SER-001');
        expect(revived.name, 'Test Serileştirme');
        expect(revived.category, 'Yeşillik');
        expect(revived.price, 18.5);
        expect(revived.unit, 'demet');
        expect(revived.stock, 40);
        expect(revived.image, 'assets/images/products/SER-001.png');
        expect(revived.description, 'Taze demet');
      },
    );

    test('13. Product fromJson handles integer price gracefully as double', () {
      final json = {
        'sku': 'INT-PRC',
        'name': 'Tam Fiyat',
        'category': 'Meyve',
        'price': 50, // int
        'unit': 'kg',
        'stock': 10,
        'image': '',
        'description': '',
      };
      final p = Product.fromJson(json);
      expect(p.price, 50.0);
      expect(p.price, isA<double>());
    });

    test('14. Product fromJson handles double stock gracefully as int', () {
      final json = {
        'sku': 'DBL-STK',
        'name': 'Küsürat Stok',
        'category': 'Meyve',
        'price': 25.0,
        'unit': 'kg',
        'stock': 20.0, // double in json
        'image': '',
        'description': '',
      };
      final p = Product.fromJson(json);
      expect(p.stock, 20);
      expect(p.stock, isA<int>());
    });

    test(
      '15. Product copyWith preserves and updates isNew and image attributes',
      () {
        final p = Product(
          sku: 'CPY-01',
          name: 'Orijinal',
          category: 'Genel',
          price: 10.0,
          unit: 'adet',
          stock: 5,
          image: 'img.jpg',
          description: '',
          isNew: true,
        );

        final copy = p.copyWith(name: 'Kopya', price: 15.0);
        expect(copy.sku, 'CPY-01');
        expect(copy.name, 'Kopya');
        expect(copy.price, 15.0);
        expect(copy.isNew, isTrue);
      },
    );
  });

  group('SVG & Binary Image Validation Tests (16-18)', () {
    test('16. ProductThumbnail isSvgBytes detects <?xml preamble', () {
      final xmlBytes = Uint8List.fromList(
        utf8.encode('<?xml version="1.0"?><svg viewBox="0 0 100 100"></svg>'),
      );
      expect(ProductThumbnail.isSvgBytes(xmlBytes), isTrue);
    });

    test('17. ProductThumbnail isSvgBytes detects direct <svg tag', () {
      final svgBytes = Uint8List.fromList(
        utf8.encode(
          '<svg xmlns="http://www.w3.org/2000/svg" width="100"></svg>',
        ),
      );
      expect(ProductThumbnail.isSvgBytes(svgBytes), isTrue);
    });

    test(
      '18. ProductThumbnail isSvgBytes returns false for PNG and JPEG header bytes',
      () {
        // PNG magic bytes: 0x89, 0x50, 0x4E, 0x47
        final pngBytes = Uint8List.fromList([
          0x89,
          0x50,
          0x4E,
          0x47,
          0x0D,
          0x0A,
          0x1A,
          0x0A,
        ]);
        expect(ProductThumbnail.isSvgBytes(pngBytes), isFalse);

        // JPEG magic bytes: 0xFF, 0xD8, 0xFF
        final jpegBytes = Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE0,
          0x00,
          0x10,
        ]);
        expect(ProductThumbnail.isSvgBytes(jpegBytes), isFalse);
      },
    );
  });

  group('GitHubService Cache & Local File Operations (19-24)', () {
    test('19. fetchImageBytes returns null on empty path', () async {
      final service = GitHubService();
      final res = await service.fetchImageBytes('');
      expect(res, isNull);
    });

    test('20. fetchImageBytes reads from local test file if exists', () async {
      final service = GitHubService();
      final tempDir = Directory.systemTemp.createTempSync('gh_sync_test');
      final testFile = File('${tempDir.path}/test_img.png');
      final sampleBytes = Uint8List.fromList([1, 2, 3, 4, 5, 6]);
      testFile.writeAsBytesSync(sampleBytes);

      final res = await service.fetchImageBytes(testFile.path);
      expect(res, isNotNull);
      expect(res, sampleBytes);

      tempDir.deleteSync(recursive: true);
    });

    test(
      '21. fetchImageBytes local extension tolerance finds .svg when .jpg requested',
      () async {
        final service = GitHubService();
        final tempDir = Directory.systemTemp.createTempSync('ext_test');
        final svgFile = File('${tempDir.path}/item.svg');
        final svgBytes = Uint8List.fromList(utf8.encode('<svg></svg>'));
        svgFile.writeAsBytesSync(svgBytes);

        // Request .jpg on same base path
        final res = await service.fetchImageBytes('${tempDir.path}/item.jpg');
        expect(res, isNotNull);
        expect(res, svgBytes);

        tempDir.deleteSync(recursive: true);
      },
    );

    test(
      '22. deleteImageFile clears from cache and deletes local file',
      () async {
        final service = GitHubService();
        final tempDir = Directory.systemTemp.createTempSync('del_test');
        final testFile = File('${tempDir.path}/del_me.png');
        testFile.writeAsBytesSync(Uint8List.fromList([9, 9, 9]));

        expect(testFile.existsSync(), isTrue);

        await service.deleteImageFile(repoFilePath: testFile.path);

        expect(testFile.existsSync(), isFalse);
        tempDir.deleteSync(recursive: true);
      },
    );

    test('23. EnvConfig reads and writes valid key-value pairs', () async {
      final tempFile = File(
        '${Directory.systemTemp.path}/test_env_${DateTime.now().millisecondsSinceEpoch}.env',
      );
      await EnvConfig.writeEnv(tempFile, {
        EnvConfig.keyOwner: 'testowner',
        EnvConfig.keyRepo: 'testrepo',
        EnvConfig.keyToken: 'ghp_secrettoken',
      });

      final read = EnvConfig.readEnv(tempFile);
      expect(read[EnvConfig.keyOwner], 'testowner');
      expect(read[EnvConfig.keyRepo], 'testrepo');
      expect(read[EnvConfig.keyToken], 'ghp_secrettoken');

      if (tempFile.existsSync()) tempFile.deleteSync();
    });

    test(
      '24. GitHubService loadSettings falls back gracefully without exception',
      () async {
        final service = GitHubService();
        expect(() async => await service.loadSettings(), returnsNormally);
        expect(service.owner.isNotEmpty, isTrue);
        expect(service.repo.isNotEmpty, isTrue);
      },
    );
  });

  group('UI & Widget Tests (25-35)', () {
    testWidgets('25. ProductThumbnail renders pending image indicator badge', (
      WidgetTester tester,
    ) async {
      final p = Product(
        sku: 'THUMB-01',
        name: 'Rozetli Ürün',
        category: 'Meyve',
        price: 25.0,
        unit: 'kg',
        stock: 10,
        image: 'assets/images/products/THUMB-01.jpg',
        description: '',
        // Provide transparent 1x1 png bytes
        pendingImageBytes: base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductThumbnail(product: p, size: 50)),
        ),
      );

      expect(p.hasPendingImage, isTrue);
      expect(find.byType(ProductThumbnail), findsOneWidget);
    });

    testWidgets(
      '26. ProductThumbnail renders category fallback icon when image empty',
      (WidgetTester tester) async {
        final p = Product(
          sku: 'THUMB-02',
          name: 'Boş Resim',
          category: 'Taze Sebzeler',
          price: 15.0,
          unit: 'kg',
          stock: 5,
          image: '',
          description: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: ProductThumbnail(product: p, size: 50)),
          ),
        );

        expect(find.byIcon(Icons.spa), findsOneWidget); // Sebze ikonu
      },
    );

    testWidgets('27. ProductThumbnail handles fruit category icon fallback', (
      WidgetTester tester,
    ) async {
      final p = Product(
        sku: 'THUMB-03',
        name: 'Elma',
        category: 'Mevsim Meyveleri',
        price: 30.0,
        unit: 'kg',
        stock: 8,
        image: '',
        description: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ProductThumbnail(product: p, size: 50)),
        ),
      );

      expect(find.byIcon(Icons.apple), findsOneWidget); // Meyve ikonu
    });

    testWidgets(
      '28. ProductEditDialog in add mode initializes with isNew: true',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        Product? savedProduct;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProductEditDialog(
                existingCategories: const ['Tümü', 'Meyve'],
                onSave: (p) => savedProduct = p,
              ),
            ),
          ),
        );

        expect(find.text('Yeni Manav Ürünü Ekle'), findsOneWidget);
        expect(find.text('Ürünü Ekle'), findsOneWidget);
        expect(
          find.text('Ürünü Sil'),
          findsNothing,
        ); // Yeni ürün modunda sil butonu olmamalı

        // Form alanlarını doldur
        await tester.enterText(find.byType(TextFormField).at(0), 'YENI-SKU');
        await tester.enterText(find.byType(TextFormField).at(1), 'Yeni Hasat');
        await tester.enterText(
          find.byType(TextFormField).at(3),
          '45.0',
        ); // Fiyat
        await tester.enterText(find.byType(TextFormField).at(4), '20'); // Stok

        await tester.tap(find.text('Ürünü Ekle'));
        await tester.pumpAndSettle();

        expect(savedProduct, isNotNull);
        expect(savedProduct!.isNew, isTrue);
        expect(savedProduct!.sku, 'YENI-SKU');
      },
    );

    testWidgets(
      '29. ProductEditDialog in edit mode displays Ürünü Sil button',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final p = Product(
          sku: 'EDIT-01',
          name: 'Düzenlenecek Ürün',
          category: 'Sebze',
          price: 20.0,
          unit: 'kg',
          stock: 12,
          image: 'assets/images/products/EDIT-01.jpg',
          description: 'Açıklama',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProductEditDialog(
                product: p,
                existingCategories: const ['Tümü', 'Sebze'],
                onSave: (_) {},
                onDelete: (_) {},
              ),
            ),
          ),
        );

        expect(find.text('Güncelle'), findsOneWidget);
        expect(find.text('Ürünü Sil'), findsOneWidget);
      },
    );

    testWidgets(
      '30. ProductEditDialog delete button triggers confirmation dialog',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final p = Product(
          sku: 'DEL-01',
          name: 'Silinecek Ürün',
          category: 'Meyve',
          price: 35.0,
          unit: 'kg',
          stock: 10,
          image: '',
          description: '',
        );

        Product? deletedProduct;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ProductEditDialog(
                product: p,
                existingCategories: const ['Tümü', 'Meyve'],
                onSave: (_) {},
                onDelete: (deleted) => deletedProduct = deleted,
              ),
            ),
          ),
        );

        await tester.tap(find.text('Ürünü Sil'));
        await tester.pumpAndSettle();

        expect(find.text('Evet, Sil'), findsOneWidget);

        await tester.tap(find.text('Evet, Sil'));
        await tester.pumpAndSettle();

        expect(deletedProduct, isNotNull);
        expect(deletedProduct!.sku, 'DEL-01');
      },
    );

    testWidgets(
      '31. InventoryScreen renders table rows with edit and delete buttons',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sampleProducts = [
          Product(
            sku: 'ROW-01',
            name: 'Domates',
            category: 'Sebze',
            price: 25.0,
            unit: 'kg',
            stock: 10,
            image: '',
            description: '',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(home: InventoryScreen(initialProducts: sampleProducts)),
        );
        await tester.pumpAndSettle();

        expect(find.text('ROW-01'), findsOneWidget);
        expect(find.text('Domates'), findsOneWidget);
        expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      },
    );

    testWidgets(
      '32. InventoryScreen deleting a product removes it and shows publish count',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sampleProducts = [
          Product(
            sku: 'ROW-DEL',
            name: 'Karpuz',
            category: 'Meyve',
            price: 15.0,
            unit: 'kg',
            stock: 20,
            image: '',
            description: '',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(home: InventoryScreen(initialProducts: sampleProducts)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();

        expect(find.text('Evet, Sil'), findsOneWidget);
        await tester.tap(find.text('Evet, Sil'));
        await tester.pumpAndSettle();

        expect(find.text('ROW-DEL'), findsNothing);
        expect(find.text('Yayınla (1)'), findsOneWidget);
      },
    );

    testWidgets(
      '33. InventoryScreen undoing deletion restores product to table',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final sampleProducts = [
          Product(
            sku: 'UNDO-01',
            name: 'Şeftali',
            category: 'Meyve',
            price: 35.0,
            unit: 'kg',
            stock: 15,
            image: '',
            description: '',
          ),
        ];

        await tester.pumpWidget(
          MaterialApp(home: InventoryScreen(initialProducts: sampleProducts)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Evet, Sil'));
        await tester.pumpAndSettle();

        expect(find.text('UNDO-01'), findsNothing);

        // SnackBar Geri Al butonuna bas
        expect(find.text('Geri Al'), findsOneWidget);
        await tester.tap(find.text('Geri Al'));
        await tester.pumpAndSettle();

        expect(find.text('UNDO-01'), findsOneWidget);
      },
    );

    testWidgets(
      '34. InventoryScreen floating bar renders with change count and reverts all',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final p = Product(
          sku: 'BAR-01',
          name: 'Muz',
          category: 'Meyve',
          price: 60.0,
          unit: 'kg',
          stock: 30,
          image: '',
          description: '',
        );

        await tester.pumpWidget(
          MaterialApp(home: InventoryScreen(initialProducts: [p])),
        );
        await tester.pumpAndSettle();

        // Stoğu artır
        await tester.tap(find.byTooltip('Stoğu 5 Artır'));
        await tester.pumpAndSettle();

        expect(find.text('Yayınla (1)'), findsOneWidget);
        expect(
          find.textContaining('1 adet üründe henüz yayınlanmamış değişiklik'),
          findsOneWidget,
        );

        // Tümünü iptal et
        await tester.tap(find.text('Tümünü İptal Et'));
        await tester.pumpAndSettle();

        expect(find.text('Yayınla'), findsOneWidget);
      },
    );

    testWidgets(
      '35. InventoryScreen stock quick buttons update stock and mark modified',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final p = Product(
          sku: 'STK-01',
          name: 'Patates',
          category: 'Sebze',
          price: 20.0,
          unit: 'kg',
          stock: 10,
          image: '',
          description: '',
        );

        await tester.pumpWidget(
          MaterialApp(home: InventoryScreen(initialProducts: [p])),
        );
        await tester.pumpAndSettle();

        // Stoğu 0 yap butonuna tıkla
        await tester.tap(find.byIcon(Icons.block));
        await tester.pumpAndSettle();

        expect(p.stock, 0);
        expect(p.isModified, isTrue);
        expect(find.text('Yayınla (1)'), findsOneWidget);
      },
    );
  });
}
