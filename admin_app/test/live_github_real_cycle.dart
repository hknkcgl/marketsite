import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/product.dart';
import 'package:admin_app/services/github_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = null; // Gerçek HTTP isteklerine izin ver

  test(
    'Gerçek Canlı GitHub Döngüsü: Ürün ve Görsel Ekleme, Pull Etme, Güncelleme ve Temizleme',
    () async {
      final service = GitHubService();
      await service.loadSettings();

      expect(
        service.hasToken,
        isTrue,
        reason: 'GitHub token bulunamadı (.env dosyasını kontrol edin)',
      );

      // ADIM 1: Mevcut ürün listesini çek
      final initialProducts = await service.fetchProducts();
      expect(initialProducts, isNotEmpty);
      expect(service.currentSha, isNotNull);

      final testSku = 'TEST-PORTAKAL-01';
      final testImagePath = 'assets/images/products/$testSku.png';

      // Gerçek 1x1 şeffaf PNG görsel baytları
      final realPngBytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );

      try {
        // ADIM 2: Görsel dosyasını GitHub reposuna push et
        final imgSha = await service.pushImageFile(
          repoFilePath: testImagePath,
          bytes: realPngBytes,
          customMessage:
              'test(live): upload live test image $testSku via automated test suite',
        );
        expect(imgSha, isNotEmpty);

        // ADIM 3: Yeni ürünü ekle ve GitHub'a push et
        final newProduct = Product(
          sku: testSku,
          name: 'Finike Sıkmalık Portakal',
          category: 'Mevsim Meyveleri',
          price: 42.50,
          unit: 'kg',
          stock: 50,
          image: testImagePath,
          description: 'Taptaze sulu Finike portakalı - Canlı test ürünü',
          isNew: true,
        );

        final listWithNew = List<Product>.from(initialProducts);
        listWithNew.removeWhere((p) => p.sku == testSku);
        listWithNew.add(newProduct);

        final pushSha = await service.pushProducts(
          listWithNew,
          customMessage:
              'test(live): add live product $testSku via automated test suite',
        );
        expect(pushSha, isNotEmpty);

        // ADIM 4: GitHub'dan indir (Pull) ve ürünün eklendiğini doğrula
        final pulledProducts = await service.fetchProducts();
        final found = pulledProducts.firstWhere(
          (p) => p.sku == testSku,
          orElse: () => throw Exception('$testSku GitHub üzerinde bulunamadı!'),
        );
        expect(found.sku, testSku);
        expect(found.name, 'Finike Sıkmalık Portakal');
        expect(found.price, 42.50);
        expect(found.stock, 50);
        expect(found.image, testImagePath);

        // ADIM 5: GitHub API üzerinden raw görsel baytlarını çek ve doğrula
        service.clearImageCache();
        final pulledBytes = await service.fetchImageBytes(testImagePath);
        expect(pulledBytes, isNotNull);
        expect(pulledBytes!.length, realPngBytes.length);

        // ADIM 6: Ürünü Güncelle (Update) ve Tekrar Yükle (Fiyat: ₺52.00, Stok: 35)
        found.price = 52.00;
        found.stock = 35;

        final updateSha = await service.pushProducts(
          pulledProducts,
          customMessage:
              'test(live): update live product $testSku price and stock',
        );
        expect(updateSha, isNotEmpty);

        // ADIM 7: Güncellemeyi GitHub'dan indirip teyit et
        final verifiedProducts = await service.fetchProducts();
        final verifiedItem = verifiedProducts.firstWhere(
          (p) => p.sku == testSku,
        );
        expect(verifiedItem.price, 52.00);
        expect(verifiedItem.stock, 35);
      } finally {
        // ADIM 8: Temizlik (Clean up) - Eklenen son test ürününü ve görselini GitHub'dan sil
        final currentList = await service.fetchProducts();
        final cleanedList = currentList.where((p) => p.sku != testSku).toList();

        await service.pushProducts(
          cleanedList,
          customMessage: 'test(live): cleanup and remove test product $testSku',
        );

        await service.deleteImageFile(
          repoFilePath: testImagePath,
          customMessage:
              'test(live): cleanup and delete test image $testImagePath',
        );

        // Yerel data/products.json dosyasını da temiz listeyle eşitle
        final localJson = File('../data/products.json');
        if (localJson.existsSync()) {
          const encoder = JsonEncoder.withIndent('  ');
          await localJson.writeAsString(
            encoder.convert(cleanedList.map((p) => p.toJson()).toList()),
          );
        }

        // Doğrulama: Ürünün ve görselin gerçekten silindiğini teyit et
        final finalCheck = await service.fetchProducts();
        expect(finalCheck.any((p) => p.sku == testSku), isFalse);

        final shaCheck = await service.fetchFileSha(testImagePath);
        expect(shaCheck, isNull);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
