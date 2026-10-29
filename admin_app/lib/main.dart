import 'package:flutter/material.dart';
import 'screens/inventory_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const YildirimlarAdminApp());
}

class YildirimlarAdminApp extends StatelessWidget {
  const YildirimlarAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yıldırımlar Manav - Stok & Fiyat Yönetimi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF059669), // Emerald 600
          primary: const Color(0xFF047857),
          brightness: Brightness.light,
        ),
        fontFamily: '-apple-system',
        scaffoldBackgroundColor: const Color(0xFFF9FAFB),
        cardTheme: const CardThemeData(
          elevation: 0,
          color: Colors.white,
        ),
      ),
      home: const InventoryScreen(),
    );
  }
}
