import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/models/product.dart';
import 'package:admin_app/screens/inventory_screen.dart';

void main() {
  final sampleProducts = [
    Product(
      sku: 'ELM-01',
      name: 'Amasya Elması Yerli Sulu',
      category: 'Taze Meyveler',
      price: 45.0,
      unit: 'kg',
      stock: 120,
      image: 'assets/images/products/ELM-01.jpg',
      description: 'Amasya elması',
      initialPrice: 45.0,
      initialStock: 120,
    ),
    Product(
      sku: 'DOM-01',
      name: 'Çanakkale Domatesi Tarla',
      category: 'Taze Sebzeler',
      price: 35.0,
      unit: 'kg',
      stock: 0,
      image: 'assets/images/products/DOM-01.jpg',
      description: 'Tarla domatesi',
      initialPrice: 35.0,
      initialStock: 0,
    ),
  ];

  for (final size in [
    const Size(1440, 900),
    const Size(1280, 800),
    const Size(1024, 768),
    const Size(900, 700),
    const Size(800, 600),
    const Size(650, 500),
  ]) {
    testWidgets(
      'InventoryScreen renders without overflow on ${size.width.toInt()}x${size.height.toInt()} viewport',
      (WidgetTester tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          MaterialApp(home: InventoryScreen(initialProducts: sampleProducts)),
        );
        await tester.pumpAndSettle();

        expect(find.byType(InventoryScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Modified floating bar renders without overflow on compact 700x500 viewport',
    (WidgetTester tester) async {
      final modifiedProducts = [
        Product(
          sku: 'ELM-01',
          name: 'Amasya Elması Yerli Sulu',
          category: 'Taze Meyveler',
          price: 50.0,
          unit: 'kg',
          stock: 100,
          image: 'assets/images/products/ELM-01.jpg',
          description: 'Amasya elması',
          initialPrice: 45.0,
          initialStock: 120,
        ),
      ];

      tester.view.physicalSize = const Size(700, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: InventoryScreen(initialProducts: modifiedProducts)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(InventoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
