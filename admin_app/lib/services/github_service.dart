import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';

class GitHubService {
  static const String keyOwner = 'github_owner';
  static const String keyRepo = 'github_repo';
  static const String keyBranch = 'github_branch';
  static const String keyFilePath = 'github_filepath';
  static const String keyToken = 'github_token';

  String owner = 'hknkcgl';
  String repo = 'marketsite';
  String branch = 'main';
  String filePath = 'data/products.json';
  String token = '';

  String? currentSha;

  GitHubService() {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    owner = prefs.getString(keyOwner) ?? 'hknkcgl';
    repo = prefs.getString(keyRepo) ?? 'marketsite';
    branch = prefs.getString(keyBranch) ?? 'main';
    filePath = prefs.getString(keyFilePath) ?? 'data/products.json';
    token = prefs.getString(keyToken) ?? '';
  }

  Future<void> saveSettings({
    required String owner,
    required String repo,
    required String branch,
    required String filePath,
    required String token,
  }) async {
    this.owner = owner.trim();
    this.repo = repo.trim();
    this.branch = branch.trim();
    this.filePath = filePath.trim();
    this.token = token.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyOwner, this.owner);
    await prefs.setString(keyRepo, this.repo);
    await prefs.setString(keyBranch, this.branch);
    await prefs.setString(keyFilePath, this.filePath);
    await prefs.setString(keyToken, this.token);
  }

  bool get hasToken => token.isNotEmpty;

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{
      'Accept': 'application/vnd.github.v3+json',
      'Content-Type': 'application/json',
    };
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GitHub'dan data/products.json dosyasını çeker
  Future<List<Product>> fetchProducts() async {
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$filePath?ref=$branch',
    );

    final response = await http.get(url, headers: _buildHeaders());

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      currentSha = data['sha'] as String?;

      // GitHub içeriği Base64 formatında döner (satır sonu \n temizlenmeli)
      final String rawContent = (data['content'] as String).replaceAll('\n', '').replaceAll('\r', '');
      final String decodedUtf8 = utf8.decode(base64.decode(rawContent));
      
      final List<dynamic> jsonList = jsonDecode(decodedUtf8);
      return jsonList.map((item) => Product.fromJson(item as Map<String, dynamic>)).toList();
    } else if (response.statusCode == 404) {
      throw Exception('Dosya bulunamadı ($filePath). Repo ayarlarını kontrol edin.');
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception('GitHub Yetkilendirme Hatası: Token geçersiz veya API limiti aşıldı.');
    } else {
      throw Exception('GitHub Hatası (${response.statusCode}): ${response.body}');
    }
  }

  /// Güncellenmiş ürün listesini GitHub'a commit & push eder
  Future<String> pushProducts(List<Product> products, {String? customMessage}) async {
    if (!hasToken) {
      throw Exception('GitHub Personal Access Token (PAT) girilmedi. Ayarlar menüsünden token ekleyin.');
    }

    if (currentSha == null) {
      // Eğer mevcut SHA yoksa önce güncel dosyadan alalım
      await fetchProducts();
    }

    final url = Uri.parse('https://api.github.com/repos/$owner/$repo/contents/$filePath');

    // JSON formatla (okunaklı ve düzgün 2 boşluklu girinti)
    const encoder = JsonEncoder.withIndent('  ');
    final String jsonString = encoder.convert(products.map((p) => p.toJson()).toList());
    final String base64Content = base64.encode(utf8.encode(jsonString));

    final commitMsg = customMessage?.trim().isNotEmpty == true 
        ? customMessage!.trim() 
        : 'chore(inventory): update stock levels and prices via Desktop App';

    final body = jsonEncode({
      'message': commitMsg,
      'content': base64Content,
      'sha': currentSha,
      'branch': branch,
    });

    final response = await http.put(url, headers: _buildHeaders(), body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> resData = jsonDecode(response.body);
      currentSha = resData['content']?['sha'] as String? ?? currentSha;
      final String commitHash = resData['commit']?['sha']?.toString().substring(0, 7) ?? 'ok';
      return commitHash;
    } else if (response.statusCode == 409) {
      throw Exception('Çakışma Hatası (Conflict): Repoda dosya başka biri tarafından güncellendi. Lütfen önce yenileyin.');
    } else {
      throw Exception('Yayınlama Hatası (${response.statusCode}): ${response.body}');
    }
  }
}
