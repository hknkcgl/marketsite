import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:admin_app/models/product.dart';
import 'package:admin_app/services/github_service.dart';

/// Bellekte çalışan sahte GitHub Contents API (SHA çakışması, token, 5xx simülasyonu)
class FakeGitHub {
  final Map<String, Uint8List> files = {};
  final Map<String, String> shas = {};
  int _n = 0;
  String validToken = 'good';
  int failNextWith = 0; // bir sonraki PUT/DELETE için durum kodu
  bool offline = false;
  int commits = 0;

  String _sha() => 'sha${++_n}'.padRight(40, '0');

  Future<http.Response> handle(http.Request r) async {
    if (offline) throw http.ClientException('offline');
    if (r.headers['Authorization'] != 'Bearer $validToken') {
      return http.Response('{"message":"Bad credentials"}', 401);
    }
    final m = RegExp(r'/contents/(.+)$').firstMatch(r.url.path);
    final path = Uri.decodeComponent(m!.group(1)!);
    if (r.method == 'GET') {
      if (!files.containsKey(path)) return http.Response('{}', 404);
      if ((r.headers['Accept'] ?? '').contains('raw')) {
        return http.Response.bytes(files[path]!, 200);
      }
      return http.Response(
        jsonEncode({'sha': shas[path], 'content': base64Encode(files[path]!)}),
        200,
      );
    }
    if (failNextWith != 0) {
      final c = failNextWith;
      failNextWith = 0;
      return http.Response('{"message":"err"}', c);
    }
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final sha = body['sha'];
    if (r.method == 'PUT') {
      if (files.containsKey(path) && sha != shas[path]) {
        return http.Response('{"message":"sha mismatch"}', 409);
      }
      if (!files.containsKey(path) && sha != null) {
        return http.Response('{"message":"unprocessable"}', 422);
      }
      files[path] = Uint8List.fromList(base64Decode(body['content']));
      shas[path] = _sha();
      commits++;
      return http.Response(
        jsonEncode({
          'content': {'sha': shas[path]},
          'commit': {'sha': 'c${commits}abcdefghij'},
        }),
        files.length == 1 ? 201 : 200,
      );
    }
    if (r.method == 'DELETE') {
      if (sha != shas[path]) return http.Response('{}', 409);
      files.remove(path);
      shas.remove(path);
      commits++;
      return http.Response('{}', 200);
    }
    return http.Response('{}', 405);
  }

  void seedProducts(List<Product> ps, {String path = 'data/products.json'}) {
    files[path] = Uint8List.fromList(
      utf8.encode(
        const JsonEncoder.withIndent(
          '  ',
        ).convert(ps.map((p) => p.toJson()).toList()),
      ),
    );
    shas[path] = _sha();
  }

  List<Product> remote() =>
      (jsonDecode(utf8.decode(files['data/products.json']!)) as List)
          .map((e) => Product.fromJson(e))
          .toList();
}

Product mk(String sku, {double price = 10, int stock = 5, String image = ''}) =>
    Product(
      sku: sku,
      name: 'Ürün $sku',
      category: 'Meyve',
      price: price,
      unit: 'kg',
      stock: stock,
      image: image,
      description: 'ç ğ ı ö ş ü İ açıklama',
    );

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

void main() {
  late FakeGitHub gh;
  late GitHubService svc;

  Future<T> run<T>(Future<T> Function() f) =>
      http.runWithClient(f, () => MockClient(gh.handle));

  setUp(() {
    gh = FakeGitHub();
    gh.seedProducts([mk('A1'), mk('B2'), mk('C3')]);
    svc = GitHubService()
      ..token = 'good'
      ..owner = 'o'
      ..repo = 'r'
      ..branch = 'main'
      ..filePath = 'data/products.json'
      ..localRepoPath = '/nonexistent_repo_path';
  });

  group('Ürün ekleme (1-10)', () {
    for (var i = 1; i <= 10; i++) {
      test('$i. yeni ürün N$i eklenir ve uzaktan okunur', () async {
        await run(() async {
          final list = await svc.fetchProducts();
          list.add(mk('N$i', price: i * 1.5, stock: i)..isNew = true);
          await svc.pushProducts(list);
          final back = await svc.fetchProducts();
          expect(back.length, 4);
          final n = back.firstWhere((p) => p.sku == 'N$i');
          expect(n.price, i * 1.5);
          expect(n.stock, i);
        });
      });
    }
  });

  group('Fiyat/stok değiştirme (11-22)', () {
    for (var i = 1; i <= 12; i++) {
      test('${10 + i}. fiyat ${i * 7.25} stok ${i * 3} kaydedilir', () async {
        await run(() async {
          final list = await svc.fetchProducts();
          list[0].price = i * 7.25;
          list[0].stock = i * 3;
          expect(list[0].isModified, isTrue);
          await svc.pushProducts(list);
          final back = await svc.fetchProducts();
          expect(back[0].price, i * 7.25);
          expect(back[0].stock, i * 3);
          expect(back[1].price, 10); // diğerleri bozulmadı
        });
      });
    }
  });

  group('Ürün silme (23-28)', () {
    for (var i = 0; i < 3; i++) {
      test('${23 + i}. ${['A1', 'B2', 'C3'][i]} silinir', () async {
        await run(() async {
          final sku = ['A1', 'B2', 'C3'][i];
          final list = await svc.fetchProducts()
            ..removeWhere((p) => p.sku == sku);
          await svc.pushProducts(list);
          final back = await svc.fetchProducts();
          expect(back.map((p) => p.sku), isNot(contains(sku)));
          expect(back.length, 2);
        });
      });
    }
    test('26. hepsi silinince boş liste push edilir ve okunabilir', () async {
      await run(() async {
        await svc.fetchProducts();
        await svc.pushProducts([]);
        expect(await svc.fetchProducts(), isEmpty);
      });
    });
    test('27. silinen ürünün görseli GitHub\'dan kaldırılır', () async {
      await run(() async {
        await svc.pushImageFile(
          repoFilePath: 'assets/images/products/A1.png',
          bytes: png,
        );
        expect(
          await svc.deleteImageFile(
            repoFilePath: 'assets/images/products/A1.png',
          ),
          isTrue,
        );
        expect(gh.files.containsKey('assets/images/products/A1.png'), isFalse);
      });
    });
    test('28. olmayan görseli silmek hata vermez', () async {
      await run(() async {
        expect(
          await svc.deleteImageFile(
            repoFilePath: 'assets/images/products/YOK.png',
          ),
          isTrue,
        );
      });
    });
  });

  group('Görsel ekleme (29-40)', () {
    for (var i = 1; i <= 6; i++) {
      test(
        '${28 + i}. görsel SKU$i.png yüklenir, baytlar aynı döner',
        () async {
          await run(() async {
            final path = 'assets/images/products/SKU$i.png';
            final bytes = Uint8List.fromList([...png, i]);
            await svc.pushImageFile(repoFilePath: path, bytes: bytes);
            svc.clearImageCache();
            final back = await svc.fetchImageBytes(path);
            expect(back, bytes);
          });
        },
      );
    }
    test('35. var olan görsel üzerine yazılır (SHA ile)', () async {
      await run(() async {
        final p = 'assets/images/products/X.png';
        await svc.pushImageFile(repoFilePath: p, bytes: png);
        final v2 = Uint8List.fromList([...png, 9, 9]);
        await svc.pushImageFile(repoFilePath: p, bytes: v2);
        expect(gh.files[p], v2);
      });
    });
    test('36. Türkçe karakterli/boşluklu görsel yolu yüklenir', () async {
      await run(() async {
        final p = 'assets/images/products/ÇİLEK ŞEKER.png';
        await svc.pushImageFile(repoFilePath: p, bytes: png);
        expect(gh.files.containsKey(p), isTrue);
      });
    });
    test('37. başında / ve Windows \\ olan yol normalize edilir', () async {
      await run(() async {
        await svc.pushImageFile(
          repoFilePath: '\\assets\\images\\products\\W.png',
          bytes: png,
        );
        expect(gh.files.containsKey('assets/images/products/W.png'), isTrue);
      });
    });
    test('38. token yokken görsel yükleme anlamlı hata verir', () async {
      svc.token = '';
      await run(() async {
        expect(
          () => svc.pushImageFile(repoFilePath: 'a.png', bytes: png),
          throwsException,
        );
      });
    });
    test('39. 2 MB görsel yüklenir', () async {
      await run(() async {
        final big = Uint8List(2 * 1024 * 1024)
          ..fillRange(0, 2 * 1024 * 1024, 7);
        await svc.pushImageFile(
          repoFilePath: 'assets/images/products/BIG.jpg',
          bytes: big,
        );
        expect(gh.files['assets/images/products/BIG.jpg']!.length, big.length);
      });
    });
    test('40. görsel + ürün birlikte: önce görsel sonra JSON', () async {
      await run(() async {
        final list = await svc.fetchProducts();
        final p = mk('Z9', image: 'assets/images/products/Z9.png')
          ..isNew = true;
        list.add(p);
        await svc.pushImageFile(repoFilePath: p.image, bytes: png);
        await svc.pushProducts(list);
        expect(gh.files.containsKey('assets/images/products/Z9.png'), isTrue);
        expect(gh.remote().last.image, p.image);
      });
    });
  });

  group('Bağlantı / token / hata dayanıklılığı (41-52)', () {
    test('41. geçersiz token fetch -> yetkilendirme hatası', () async {
      svc.token = 'bad';
      await run(() async {
        expect(
          svc.fetchProducts(),
          throwsA(predicate((e) => e.toString().contains('Yetkilendirme'))),
        );
      });
    });
    test('42. geçersiz token push -> yetki hatası, veri değişmez', () async {
      await run(() async {
        final list = await svc.fetchProducts();
        svc.token = 'bad';
        list[0].price = 999;
        await expectLater(svc.pushProducts(list), throwsException);
        expect(gh.remote()[0].price, 10);
      });
    });
    test(
      '43. token süresi bir oturum ortasında dolar: sonraki istek net hata verir',
      () async {
        await run(() async {
          await svc.fetchProducts();
          gh.validToken = 'rotated';
          await expectLater(svc.fetchProducts(), throwsException);
          svc.token = 'rotated';
          expect((await svc.fetchProducts()).length, 3);
        });
      },
    );
    test('44. internet yok -> fetch bağlantı hatası fırlatır', () async {
      await run(() async {
        gh.offline = true;
        await expectLater(svc.fetchProducts(), throwsException);
      });
    });
    test(
      '45. internet yok -> push hata fırlatır (sessizce kaybolmaz)',
      () async {
        await run(() async {
          final list = await svc.fetchProducts();
          gh.offline = true;
          await expectLater(svc.pushProducts(list), throwsException);
        });
      },
    );
    test('46. internet geri gelince aynı liste push edilebilir', () async {
      await run(() async {
        final list = await svc.fetchProducts();
        list[0].price = 77;
        gh.offline = true;
        await expectLater(svc.pushProducts(list), throwsException);
        gh.offline = false;
        await svc.pushProducts(list);
        expect(gh.remote()[0].price, 77);
      });
    });
    test('47. 500 hatası -> Yayınlama Hatası', () async {
      await run(() async {
        final list = await svc.fetchProducts();
        gh.failNextWith = 500;
        await expectLater(
          svc.pushProducts(list),
          throwsA(predicate((e) => e.toString().contains('500'))),
        );
      });
    });
    test(
      '48. tek seferlik 409 sonrası taze veriyle otomatik retry başarılı olur',
      () async {
        await run(() async {
          final list = await svc.fetchProducts();
          gh.failNextWith = 409;
          await svc.pushProducts(list);
          expect(gh.commits, 1);
        });
      },
    );
    test('49. yanlış dosya yolu -> 404 anlamlı mesaj', () async {
      svc.filePath = 'data/yok.json';
      await run(() async {
        await expectLater(
          svc.fetchProducts(),
          throwsA(predicate((e) => e.toString().contains('bulunamadı'))),
        );
      });
    });
    test('50. ardışık 20 push (stok artışları) tutarlı kalır', () async {
      await run(() async {
        final list = await svc.fetchProducts();
        for (var i = 1; i <= 20; i++) {
          list[0].stock = i;
          await svc.pushProducts(list);
        }
        expect(gh.remote()[0].stock, 20);
        expect(gh.commits, 20);
      });
    });
    test(
      '51. 1 yıl sonra bile: SHA tazelenir, eski currentSha önemsiz',
      () async {
        await run(() async {
          final list = await svc.fetchProducts();
          svc.currentSha = 'eskiveyanlis';
          await svc.pushProducts(list);
          expect(gh.commits, 1);
        });
      },
    );
    test('52. Türkçe karakterler gidiş-dönüşte bozulmaz', () async {
      await run(() async {
        final list = await svc.fetchProducts();
        list[0].description = 'Çiğ şeker ığdır İĞÜŞÖ 🍊';
        await svc.pushProducts(list);
        expect(
          (await svc.fetchProducts())[0].description,
          'Çiğ şeker ığdır İĞÜŞÖ 🍊',
        );
      });
    });
  });

  group('Mantık hataları / riskler (53-58)', () {
    test(
      '53. [RİSK] başka biri uzakta ürün ekledikten sonra eski liste push edilirse o ürün SİLİNİR (lost update)',
      () async {
        await run(() async {
          final stale = await svc.fetchProducts(); // uygulama açıldı
          // başka cihaz/site yöneticisi uzakta ürün ekliyor
          gh.seedProducts([...stale, mk('REMOTE-NEW')]);
          stale[0].price = 55;
          await svc.pushProducts(stale);
          final skus = gh.remote().map((p) => p.sku).toList();
          // Beklenen doğru davranış: REMOTE-NEW korunmalı
          expect(
            skus,
            contains('REMOTE-NEW'),
            reason: 'pushProducts taze SHA ile eski listeyi üzerine yazıyor',
          );
        });
      },
    );
    test(
      '54. [RİSK] iki ürün aynı SKU ile eklenirse engellenmiyor mu? (serviste doğrulama yok)',
      () async {
        await run(() async {
          final list = await svc.fetchProducts()
            ..add(mk('a1', price: 99));
          await expectLater(
            svc.pushProducts(list),
            throwsA(predicate((e) => e.toString().contains('Tekrarlı SKU'))),
          );
          expect(gh.remote().length, 3);
        });
      },
    );
    test('55. fromJson: fiyat string gelirse çöker mi', () {
      expect(
        Product.fromJson({'sku': 'x', 'price': '12,5', 'stock': 1}).price,
        12.5,
      );
    });
    test('56. fromJson: stok null/eksik -> 0', () {
      expect(Product.fromJson({'sku': 'x', 'price': 1}).stock, 0);
    });
    test('57. fromJson: stok string "5" gelirse', () {
      expect(Product.fromJson({'sku': 'x', 'price': 1, 'stock': '5'}).stock, 5);
    });
    test(
      '58. 1 MB üstü products.json (content boş döner) okunabilir mi',
      () async {
        // GitHub Contents API >1MB dosyada content="" ve encoding="none" döner
        final big = List.generate(6000, (i) => mk('P$i'));
        gh.seedProducts(big);
        await run(() async {
          // gerçek API bu boyutta (≈1.2MB) content boş döner; burada sadece boyutu raporluyoruz
          expect(gh.files['data/products.json']!.length, greaterThan(1000000));
        });
      },
    );
  });

  group('Birleştirme (59-64)', () {
    test(
      '59. başkası aynı anda başka ürünün fiyatını değiştirdi: ikisi de korunur',
      () async {
        await run(() async {
          final mine = await svc.fetchProducts();
          final other = await svc.fetchProducts();
          other[1].price = 123;
          gh.seedProducts(other);
          mine[0].price = 55;
          await svc.pushProducts(mine);
          final r = gh.remote();
          expect(r[0].price, 55);
          expect(r[1].price, 123);
        });
      },
    );
    test('60. ben sildiğim ürün, uzakta durduğu için geri gelmez', () async {
      await run(() async {
        final list = await svc.fetchProducts()
          ..removeWhere((p) => p.sku == 'B2');
        await svc.pushProducts(list);
        expect(gh.remote().map((p) => p.sku), ['A1', 'C3']);
      });
    });
    test(
      '61. başkasının eklediği ürün lastMergedRemoteAdditions ile bildirilir',
      () async {
        await run(() async {
          final mine = await svc.fetchProducts();
          gh.seedProducts([...mine, mk('R1')]);
          await svc.pushProducts(mine);
          expect(svc.lastMergedRemoteAdditions.map((p) => p.sku), ['R1']);
        });
      },
    );
    test('62. aynı ürünü ikimiz değiştirdik: benimki kazanır', () async {
      await run(() async {
        final mine = await svc.fetchProducts();
        final other = await svc.fetchProducts();
        other[0].price = 1;
        gh.seedProducts(other);
        mine[0].price = 2;
        await svc.pushProducts(mine);
        expect(gh.remote()[0].price, 2);
      });
    });
    test('63. 1 MB üstü products.json raw yoluyla okunur', () async {
      gh.seedProducts(List.generate(6000, (i) => mk('P$i')));
      final orig = gh.handle;
      await http.runWithClient(
        () async {
          expect((await svc.fetchProducts()).length, 6000);
        },
        () => MockClient((r) async {
          final resp = await orig(r);
          if (r.method == 'GET' &&
              !(r.headers['Accept'] ?? '').contains('raw') &&
              resp.statusCode == 200) {
            return http.Response(
              jsonEncode({'sha': 'x', 'content': '', 'encoding': 'none'}),
              200,
            );
          }
          return resp;
        }),
      );
    });
    test('64. dosya hiç yokken ilk push dosyayı oluşturur', () async {
      gh.files.clear();
      gh.shas.clear();
      await run(() async {
        await svc.pushProducts([mk('F1')]);
        expect(gh.remote().single.sku, 'F1');
      });
    });
  });

  group('Sayı ayraçları (65-74)', () {
    final ok = {'12,5': 12.5, '12.5': 12.5, '0,250': 0.25, '1.250,50': 1250.5, '1,250.50': 1250.5, ' 7 ': 7, '10': 10};
    ok.forEach((k, v) => test('parse "$k" -> $v', () => expect(Product.parseNumber(k), v)));
    for (final bad in ['1.250', '1,250', '-5', 'abc']) {
      test('parse "$bad" -> reddedilir', () => expect(Product.parseNumber(bad), isNull));
    }
  });
}
