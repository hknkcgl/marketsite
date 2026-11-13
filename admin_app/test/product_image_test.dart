import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/product.dart';
import 'package:admin_app/widgets/product_thumbnail.dart';

void main() {
  group('Product Image & Model Tests', () {
    test('Product detects image modification via pendingImageBytes', () {
      final product = Product(
        sku: 'TEST-001',
        name: 'Test Elma',
        category: 'Meyve',
        price: 25.0,
        unit: 'kg',
        stock: 50,
        image: 'assets/images/products/TEST-001.jpg',
        description: 'Test açıklama',
      );

      expect(product.isModified, isFalse);
      expect(product.hasPendingImage, isFalse);

      // Simüle görsel seçimi
      final dummyBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
      product.pendingImageBytes = dummyBytes;
      product.pendingImageExt = 'png';

      expect(product.hasPendingImage, isTrue);
      expect(product.isModified, isTrue);

      // Değişiklikleri kaydet (commit)
      product.commitChanges();
      expect(product.hasPendingImage, isFalse);
      expect(product.isModified, isFalse);
    });

    test(
      'Product revertChanges clears pendingImageBytes and restores initial values',
      () {
        final product = Product(
          sku: 'TEST-002',
          name: 'Test Domates',
          category: 'Sebze',
          price: 30.0,
          unit: 'kg',
          stock: 10,
          image: 'assets/images/products/TEST-002.jpg',
          description: 'Test açıklama',
        );

        product.price = 40.0;
        product.stock = 5;
        product.pendingImageBytes = Uint8List.fromList([9, 8, 7]);

        expect(product.isModified, isTrue);

        product.revertChanges();

        expect(product.price, 30.0);
        expect(product.stock, 10);
        expect(product.hasPendingImage, isFalse);
        expect(product.isModified, isFalse);
      },
    );

    testWidgets(
      'ProductThumbnail renders strictly with fixed size and no overflow',
      (WidgetTester tester) async {
        final product = Product(
          sku: 'TEST-003',
          name: 'Test Biber',
          category: 'Sebze',
          price: 20.0,
          unit: 'kg',
          stock: 15,
          image: '',
          description: '',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: ProductThumbnail(product: product, size: 44)),
            ),
          ),
        );

        final containerFinder = find.byType(ProductThumbnail);
        expect(containerFinder, findsOneWidget);

        final size = tester.getSize(containerFinder);
        expect(size.width, 44);
        expect(size.height, 44);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
