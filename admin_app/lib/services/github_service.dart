import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product.dart';
import 'env_config.dart';

class GitHubService {
  static const String keyOwner = 'github_owner';
  static const String keyRepo = 'github_repo';
  static const String keyBranch = 'github_branch';
  static const String keyFilePath = 'github_filepath';
  static const String keyToken = 'github_token';
  static const String keyLocalRepoPath = 'github_local_repo_path';

  String owner = 'hknkcgl';
  String repo = 'marketsite';
  String branch = 'main';
  String filePath = 'data/products.json';
  String token = '';
  String localRepoPath =
      '/Users/hakankocaoglu/Documents/Development/marketsite';

  String? currentSha;

  /// Son başarılı fetch/push anındaki ürünlerin JSON anlık görüntüsü (SKU -> json).
  /// 3-yönlü birleştirmede "ben ne değiştirdim?" sorusunu yanıtlamak için kullanılır.
  Map<String, String>? _baseline;

  /// Son push'ta uzaktan alınıp yerel listeye eklenmesi gereken (başkasının eklediği) ürünler
  List<Product> lastMergedRemoteAdditions = [];

  static String _fp(Product p) => jsonEncode(p.toJson());
  static Map<String, String> _snapshot(Iterable<Product> ps) => {
    for (final p in ps) p.sku: _fp(p),
  };

  /// Görseller için bellek içi önbellek (token/kota tasarrufu)
  final Map<String, Uint8List> _imageCache = {};

  /// Bellek içi görsel önbelleğini temizler
  void clearImageCache() {
    _imageCache.clear();
  }

  /// Görsel yolunu normalize eder: Ters eğik çizgileri düzeltir, baştaki eğik çizgileri temizler
  static String normalizeImagePath(String path) {
    var clean = path.trim().replaceAll('\\', '/');
    if (clean.isEmpty) return clean;
    if (clean.contains('?')) {
      clean = clean.split('?').first;
    }
    // İşletim sisteminin mutlak kök dizini ise dokunma
    final isSystemAbsolute =
        clean.startsWith('/Users') ||
        clean.startsWith('/var') ||
        clean.startsWith('/tmp') ||
        clean.startsWith('/private') ||
        (clean.length > 2 && clean[1] == ':');
    if (isSystemAbsolute) {
      return clean;
    }
    while (clean.startsWith('/')) {
      clean = clean.substring(1);
    }
    while (clean.startsWith('./')) {
      clean = clean.substring(2);
    }
    return clean;
  }

  /// GitHub URL segmentlerini URI-safe formatta encode eder
  static String encodePathSegments(String path) {
    final clean = normalizeImagePath(path);
    return clean.split('/').map(Uri.encodeComponent).join('/');
  }

  GitHubService() {
    loadSettings();
  }

  /// Aktif olarak kullanılan .env dosyasını döndürür
  File get currentEnvFile => EnvConfig.resolveEnvFile();

  /// Ayarları önce .env dosyasından, yoksa SharedPreferences ve varsayılanlardan yükler.
  /// Yayın adresi (owner/repo/branch/filePath) sabittir; kullanıcı tarafından
  /// değiştirilemez. Yalnızca token ve yerel repo yolu dışarıdan okunur.
  Future<void> loadSettings() async {
    final envFile = currentEnvFile;

    if (envFile.existsSync()) {
      final env = EnvConfig.readEnv(envFile);
      if (env.isNotEmpty) {
        token = env[EnvConfig.keyToken] ?? token;
        localRepoPath = env[EnvConfig.keyLocalRepoPath] ?? localRepoPath;
        return;
      }
    }

    // .env dosyası bulunamadıysa SharedPreferences'tan çek ve .env oluştur
    try {
      final prefs = await SharedPreferences.getInstance();
      token = prefs.getString(keyToken) ?? token;
      localRepoPath = prefs.getString(keyLocalRepoPath) ?? localRepoPath;

      // Otomatik olarak .env dosyası oluşturup kaydet
      await EnvConfig.writeEnv(envFile, {
        EnvConfig.keyOwner: owner,
        EnvConfig.keyRepo: repo,
        EnvConfig.keyBranch: branch,
        EnvConfig.keyFilePath: filePath,
        EnvConfig.keyToken: token,
        EnvConfig.keyLocalRepoPath: localRepoPath,
      });
    } catch (_) {}
  }

  /// Ayarları hem .env dosyasına hem de SharedPreferences'a kaydeder
  Future<void> saveSettings({
    required String token,
    String? localRepoPath,
  }) async {
    this.token = token.trim();
    if (localRepoPath != null) {
      this.localRepoPath = localRepoPath.trim();
    }

    // 1. .env dosyasına yaz (Windows ve diğer sistemlerde kurulum dizininde tutulur)
    await EnvConfig.writeEnv(currentEnvFile, {
      EnvConfig.keyOwner: owner,
      EnvConfig.keyRepo: repo,
      EnvConfig.keyBranch: branch,
      EnvConfig.keyFilePath: filePath,
      EnvConfig.keyToken: this.token,
      EnvConfig.keyLocalRepoPath: this.localRepoPath,
    });

    // 2. Geriye dönük uyumluluk için SharedPreferences'a da yaz
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(keyToken, this.token);
      await prefs.setString(keyLocalRepoPath, this.localRepoPath);
    } catch (_) {}
  }

  /// Yalnızca yerel test ve debug ortamında: Yerel çalışma dizininde 'git pull' çalıştırır
  Future<String> gitPullLocalRepo() async {
    final candidates = [localRepoPath, Directory.current.path, '..'];

    Directory? targetDir;
    for (final path in candidates) {
      if (path.isEmpty) continue;
      final dir = Directory(path);
      if (dir.existsSync() && Directory('${dir.path}/.git').existsSync()) {
        targetDir = dir;
        break;
      }
    }

    if (targetDir == null) {
      throw Exception(
        'Yerel .git reposu bulunamadı. Ayarlardan yerel repo yolunu kontrol edin.',
      );
    }

    final result = await Process.run('git', [
      'pull',
      'origin',
      branch,
    ], workingDirectory: targetDir.path);

    if (result.exitCode == 0) {
      clearImageCache();
      final out = result.stdout.toString().trim();
      return out.isNotEmpty ? out : 'Yerel repo güncel.';
    } else {
      throw Exception('Git Pull Hatası (${result.exitCode}): ${result.stderr}');
    }
  }

  bool get hasToken => token.isNotEmpty;

  Map<String, String> _buildHeaders({bool raw = false}) {
    final headers = <String, String>{
      'Accept': raw
          ? 'application/vnd.github.raw'
          : 'application/vnd.github.v3+json',
      'User-Agent': 'Marketsite-Admin-App/1.0',
    };
    if (!raw) {
      headers['Content-Type'] = 'application/json';
    }
    if (token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// GitHub'daki belirtilen dosyanın güncel SHA değerini sorgular
  Future<String?> fetchFileSha(String targetPath) async {
    final cleanPath = normalizeImagePath(targetPath);
    if (cleanPath.isEmpty) return null;
    final encoded = encodePathSegments(cleanPath);
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$encoded?ref=$branch',
    );
    try {
      final response = await http
          .get(url, headers: _buildHeaders())
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['sha'] as String?;
      }
    } catch (_) {}
    return null;
  }

  /// GitHub'daki data/products.json dosyasının güncel SHA değerini sorgular
  Future<String?> fetchCurrentSha() async {
    currentSha = await fetchFileSha(filePath) ?? currentSha;
    return currentSha;
  }

  /// Uzaktaki products.json'u ve SHA değerini çeker (baseline'ı değiştirmez)
  Future<({String? sha, List<Product> products})> _fetchRemote() async {
    final cleanPath = normalizeImagePath(filePath);
    final encoded = encodePathSegments(cleanPath);
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$encoded?ref=$branch',
    );

    final http.Response response;
    try {
      response = await http
          .get(url, headers: _buildHeaders())
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      throw Exception(
        'GitHub bağlantısı zamanaşımına uğradı (15s). İnternet bağlantınızı kontrol edin.',
      );
    } catch (e) {
      throw Exception('GitHub bağlantı hatası: $e');
    }

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final sha = data['sha'] as String?;
      String rawContent = ((data['content'] as String?) ?? '')
          .replaceAll('\n', '')
          .replaceAll('\r', '');
      if (rawContent.isEmpty) {
        // Dosya >1MB ise Contents API içeriği boş döner: raw biçimde yeniden iste
        final rawResp = await http
            .get(url, headers: _buildHeaders(raw: true))
            .timeout(const Duration(seconds: 25));
        if (rawResp.statusCode != 200) {
          throw Exception(
            'GitHub Hatası (${rawResp.statusCode}): büyük dosya okunamadı.',
          );
        }
        final list =
            jsonDecode(utf8.decode(rawResp.bodyBytes)) as List<dynamic>;
        return (
          sha: sha,
          products: list
              .map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
      final String decodedUtf8 = utf8.decode(base64.decode(rawContent));
      final List<dynamic> jsonList = jsonDecode(decodedUtf8);
      return (
        sha: sha,
        products: jsonList
            .map((item) => Product.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
    } else if (response.statusCode == 404) {
      throw _NotFound(
        'Dosya veya repo bulunamadı ($owner/$repo/$filePath). Ayarları ve token erişimini kontrol edin.',
      );
    } else if (response.statusCode == 401 || response.statusCode == 403) {
      throw Exception(
        'GitHub Yetkilendirme Hatası: Token geçersiz, süresi dolmuş veya "Contents: Read" yetkisi yok.',
      );
    } else {
      throw Exception(
        'GitHub Hatası (${response.statusCode}): ${response.body}',
      );
    }
  }

  /// GitHub'dan data/products.json dosyasını çeker
  Future<List<Product>> fetchProducts() async {
    final r = await _fetchRemote();
    currentSha = r.sha;
    _baseline = _snapshot(r.products);
    return r.products;
  }

  /// Yerel liste (local), son bilinen durum (baseline) ve uzaktaki güncel liste (remote) ile
  /// 3-yönlü birleştirme yapar: başkasının eklediği/değiştirdiği ürünler korunur,
  /// benim değiştirdiklerim ve sildiklerim uygulanır.
  static List<Product> mergeProducts({
    required List<Product> local,
    required List<Product> remote,
    required Map<String, String>? baseline,
  }) {
    if (baseline == null) return List<Product>.from(local);
    final localBySku = {for (final p in local) p.sku: p};
    final merged = <Product>[];
    final used = <String>{};
    for (final r in remote) {
      final l = localBySku[r.sku];
      if (l != null) {
        used.add(r.sku);
        final localChanged = baseline[r.sku] != _fp(l);
        merged.add(localChanged ? l : r);
      } else if (!baseline.containsKey(r.sku)) {
        merged.add(r); // başkası eklemiş, ben silmedim
      }
      // baseline'da var ama yerelde yok -> ben sildim, uzakta da silinir
    }
    for (final l in local) {
      if (!used.contains(l.sku)) merged.add(l);
    }
    return merged;
  }

  /// Bir görsel dosyasının baytlarını çeker (Önce önbellek, sonra yerel disk, en son GitHub API)
  Future<Uint8List?> fetchImageBytes(String imagePath) async {
    final rawTrimmed = imagePath.trim();
    if (rawTrimmed.isEmpty) return null;

    // 0. Doğrudan yerel dosya yolu kontrolü
    if (File(rawTrimmed).existsSync()) {
      try {
        final bytes = await File(rawTrimmed).readAsBytes();
        _imageCache[rawTrimmed] = bytes;
        return bytes;
      } catch (_) {}
    }

    final cleanPath = normalizeImagePath(imagePath);
    if (cleanPath.isEmpty) return null;

    // 1. Doğrudan HTTP/HTTPS web bağlantısı ise
    if (cleanPath.startsWith('http://') || cleanPath.startsWith('https://')) {
      try {
        final resp = await http
            .get(Uri.parse(cleanPath))
            .timeout(const Duration(seconds: 12));
        if (resp.statusCode == 200) {
          _imageCache[cleanPath] = resp.bodyBytes;
          return resp.bodyBytes;
        }
      } catch (_) {}
      return null;
    }

    // 2. Bellek içi önbellek kontrolü
    if (_imageCache.containsKey(cleanPath)) {
      return _imageCache[cleanPath];
    }

    // 3. Yerel dosya sistemi kontrolü (eğer repo yerelde mevcutsa)
    final localCandidates = [
      File(cleanPath),
      File('$localRepoPath/$cleanPath'),
      File('../$cleanPath'),
      File('../../$cleanPath'),
    ];
    for (final file in localCandidates) {
      try {
        if (file.existsSync()) {
          final bytes = await file.readAsBytes();
          _imageCache[cleanPath] = bytes;
          return bytes;
        }
      } catch (_) {}
    }

    // Yerel disk uzantı toleransı (Örn: ürün modelinde .jpg kayıtlı ama diskte .svg veya .png mevcut)
    final dotIndex = cleanPath.lastIndexOf('.');
    if (dotIndex != -1) {
      final basePath = cleanPath.substring(0, dotIndex);
      final altExts = ['.png', '.jpg', '.jpeg', '.webp', '.svg'];
      for (final ext in altExts) {
        final altPath = '$basePath$ext';
        if (altPath == cleanPath) continue;
        final altCandidates = [
          File(altPath),
          File('$localRepoPath/$altPath'),
          File('../$altPath'),
        ];
        for (final file in altCandidates) {
          try {
            if (file.existsSync()) {
              final bytes = await file.readAsBytes();
              _imageCache[cleanPath] = bytes;
              return bytes;
            }
          } catch (_) {}
        }
      }
    }

    // 4. GitHub API üzerinden doğrudan raw baytları çek
    final encoded = encodePathSegments(cleanPath);
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$encoded?ref=$branch',
    );
    try {
      final response = await http
          .get(url, headers: _buildHeaders(raw: true))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        _imageCache[cleanPath] = bytes;
        _saveBytesToLocalIfPossible(cleanPath, bytes);
        return bytes;
      }
    } catch (_) {}

    // GitHub üzerinde uzantı toleransı (Örn: .jpg yoksa .png veya .svg ara)
    if (dotIndex != -1) {
      final basePath = cleanPath.substring(0, dotIndex);
      final altExts = ['.png', '.jpg', '.jpeg', '.webp', '.svg'];
      for (final ext in altExts) {
        final altPath = '$basePath$ext';
        if (altPath == cleanPath) continue;
        final altEncoded = encodePathSegments(altPath);
        final altUrl = Uri.parse(
          'https://api.github.com/repos/$owner/$repo/contents/$altEncoded?ref=$branch',
        );
        try {
          final response = await http
              .get(altUrl, headers: _buildHeaders(raw: true))
              .timeout(const Duration(seconds: 10));
          if (response.statusCode == 200) {
            final bytes = response.bodyBytes;
            _imageCache[cleanPath] = bytes;
            _saveBytesToLocalIfPossible(cleanPath, bytes);
            return bytes;
          }
        } catch (_) {}
      }
    }

    return null;
  }

  /// Yerel çalışma dizini mevcutsa indirilen baytları diske önbellekler
  void _saveBytesToLocalIfPossible(String cleanPath, Uint8List bytes) {
    try {
      final localCandidates = [
        File(cleanPath),
        File('$localRepoPath/$cleanPath'),
        File('../$cleanPath'),
      ];
      for (final candidate in localCandidates) {
        if (candidate.parent.existsSync() ||
            (localRepoPath.isNotEmpty &&
                candidate.path.startsWith(localRepoPath))) {
          if (!candidate.parent.existsSync()) {
            candidate.parent.createSync(recursive: true);
          }
          candidate.writeAsBytesSync(bytes);
          break;
        }
      }
    } catch (_) {}
  }

  /// Bir görsel dosyasını GitHub reposuna commit & push eder
  Future<String> pushImageFile({
    required String repoFilePath,
    required Uint8List bytes,
    String? customMessage,
  }) async {
    if (!hasToken) {
      throw Exception('GitHub Personal Access Token (PAT) girilmedi.');
    }

    final cleanPath = normalizeImagePath(repoFilePath);
    final existingSha = await fetchFileSha(cleanPath);

    final encoded = encodePathSegments(cleanPath);
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$encoded',
    );
    final base64Content = base64Encode(bytes);

    final bodyMap = <String, dynamic>{
      'message':
          customMessage ??
          'chore(images): upload product image $cleanPath via Desktop App',
      'content': base64Content,
      'branch': branch,
    };
    if (existingSha != null) {
      bodyMap['sha'] = existingSha;
    }

    final response = await http
        .put(url, headers: _buildHeaders(), body: jsonEncode(bodyMap))
        .timeout(const Duration(seconds: 25));

    if (response.statusCode == 200 || response.statusCode == 201) {
      _imageCache[cleanPath] = bytes;
      _saveBytesToLocalIfPossible(cleanPath, bytes);

      final data = jsonDecode(response.body);
      return data['commit']?['sha']?.toString().substring(0, 7) ?? 'ok';
    } else {
      throw Exception(
        'Görsel yükleme hatası ($cleanPath - HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }

  /// GitHub reposundan ve yerel diskten bir görsel dosyasını siler
  Future<bool> deleteImageFile({
    required String repoFilePath,
    String? customMessage,
  }) async {
    final cleanPath = normalizeImagePath(repoFilePath);
    if (cleanPath.isEmpty) return true;

    _imageCache.remove(cleanPath);
    _deleteLocalFileIfExists(cleanPath);

    if (!hasToken) {
      return true; // Token yoksa yerel ve bellek temizliği kafi
    }

    final existingSha = await fetchFileSha(cleanPath);
    if (existingSha == null) {
      // GitHub'da bu dosya zaten mevcut değil
      return true;
    }

    final encoded = encodePathSegments(cleanPath);
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$encoded',
    );
    final body = jsonEncode({
      'message':
          customMessage ??
          'chore(images): delete product image $cleanPath via Desktop App',
      'sha': existingSha,
      'branch': branch,
    });

    final response = await http
        .delete(url, headers: _buildHeaders(), body: body)
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      throw Exception(
        'Görsel silme hatası ($cleanPath - HTTP ${response.statusCode}): ${response.body}',
      );
    }
  }

  void _deleteLocalFileIfExists(String cleanPath) {
    final localCandidates = [
      File(cleanPath),
      File('$localRepoPath/$cleanPath'),
      File('../$cleanPath'),
      File('../../$cleanPath'),
    ];
    for (final file in localCandidates) {
      try {
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {}
    }
  }

  /// Güncellenmiş ürün listesini GitHub'a commit & push eder.
  /// Push öncesi uzaktaki güncel liste ile birleştirilir (başkasının değişikliği ezilmez).
  Future<String> pushProducts(
    List<Product> products, {
    String? customMessage,
  }) async {
    if (!hasToken) {
      throw Exception(
        'GitHub Personal Access Token (PAT) girilmedi. Ayarlar menüsünden token ekleyin.',
      );
    }

    // Aynı SKU iki kez olamaz
    final seen = <String>{};
    for (final p in products) {
      if (!seen.add(p.sku.trim().toUpperCase())) {
        throw Exception(
          'Tekrarlı SKU: ${p.sku}. Her ürünün SKU kodu benzersiz olmalı.',
        );
      }
    }

    final cleanFilePath = normalizeImagePath(filePath);
    final encodedFilePath = encodePathSegments(cleanFilePath);
    final url = Uri.parse(
      'https://api.github.com/repos/$owner/$repo/contents/$encodedFilePath',
    );
    final commitMsg = customMessage?.trim().isNotEmpty == true
        ? customMessage!.trim()
        : 'chore(inventory): update stock levels, prices and products via Desktop App';
    const encoder = JsonEncoder.withIndent('  ');

    http.Response? response;
    List<Product> merged = products;
    // 409 gelirse taze veriyle yeniden birleştirip 1 kez daha dene
    for (var attempt = 0; attempt < 2; attempt++) {
      String? sha;
      List<Product> remote = [];
      try {
        final r = await _fetchRemote();
        sha = r.sha;
        remote = r.products;
      } on _NotFound {
        sha = null; // dosya henüz yok: ilk kez oluşturulacak
      }

      merged = mergeProducts(
        local: products,
        remote: remote,
        baseline: _baseline,
      );
      final base64Content = base64.encode(
        utf8.encode(encoder.convert(merged.map((p) => p.toJson()).toList())),
      );
      final body = jsonEncode({
        'message': commitMsg,
        'content': base64Content,
        'sha': ?sha,
        'branch': branch,
      });

      try {
        response = await http
            .put(url, headers: _buildHeaders(), body: body)
            .timeout(const Duration(seconds: 15));
      } on TimeoutException {
        throw Exception(
          'GitHub yayınlama isteği zamanaşımına uğradı (15s). İnternet bağlantınızı kontrol edin.',
        );
      } catch (e) {
        throw Exception('GitHub yayınlama bağlantı hatası: $e');
      }
      if (response.statusCode != 409) break;
    }

    final res = response!;
    if (res.statusCode == 200 || res.statusCode == 201) {
      final Map<String, dynamic> resData = jsonDecode(res.body);
      currentSha = resData['content']?['sha'] as String? ?? currentSha;
      final localSkus = products.map((p) => p.sku).toSet();
      lastMergedRemoteAdditions = merged
          .where((p) => !localSkus.contains(p.sku))
          .toList();
      _baseline = _snapshot(merged);
      return resData['commit']?['sha']?.toString().substring(0, 7) ?? 'ok';
    } else if (res.statusCode == 409) {
      throw Exception(
        'Çakışma Hatası (Conflict): Repodaki dosya başka bir commit ile değişmiş. Lütfen listeyi yenileyip tekrar deneyin.',
      );
    } else if (res.statusCode == 401 || res.statusCode == 403) {
      throw Exception(
        'GitHub Yetki Hatası (${res.statusCode}): Token yetersiz veya süresi dolmuş. PAT ayarlarında "Contents: Read and Write" yetkisi verildiğinden emin olun.',
      );
    } else {
      throw Exception('Yayınlama Hatası (${res.statusCode}): ${res.body}');
    }
  }
}

class _NotFound implements Exception {
  final String message;
  _NotFound(this.message);
  @override
  String toString() => 'Exception: $message';
}
