import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/services/env_config.dart';

void main() {
  group('EnvConfig Tests', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('env_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test(
      'readEnv parses key-value pairs and ignores comments and whitespace',
      () {
        final envFile = File('${tempDir.path}/.env');
        envFile.writeAsStringSync('''
# Test comment
GITHUB_OWNER=custom_user
GITHUB_REPO="custom_repo"
GITHUB_BRANCH='feature/v2'
GITHUB_FILEPATH=data/custom.json
GITHUB_TOKEN=ghp_test1234567890

# Another comment
EMPTY_KEY=
''');

        final env = EnvConfig.readEnv(envFile);
        expect(env[EnvConfig.keyOwner], 'custom_user');
        expect(env[EnvConfig.keyRepo], 'custom_repo');
        expect(env[EnvConfig.keyBranch], 'feature/v2');
        expect(env[EnvConfig.keyFilePath], 'data/custom.json');
        expect(env[EnvConfig.keyToken], 'ghp_test1234567890');
      },
    );

    test('writeEnv writes valid .env file that can be read back', () async {
      final envFile = File('${tempDir.path}/.env');
      final data = {
        EnvConfig.keyOwner: 'new_owner',
        EnvConfig.keyRepo: 'new_repo',
        EnvConfig.keyBranch: 'main',
        EnvConfig.keyFilePath: 'data/products.json',
        EnvConfig.keyToken: 'github_pat_xyz987',
      };

      await EnvConfig.writeEnv(envFile, data);
      expect(envFile.existsSync(), isTrue);

      final reloaded = EnvConfig.readEnv(envFile);
      expect(reloaded[EnvConfig.keyOwner], 'new_owner');
      expect(reloaded[EnvConfig.keyRepo], 'new_repo');
      expect(reloaded[EnvConfig.keyToken], 'github_pat_xyz987');
    });
  });
}
