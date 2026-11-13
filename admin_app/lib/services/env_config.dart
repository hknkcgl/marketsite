import 'dart:io';

class EnvConfig {
  static const String keyOwner = 'GITHUB_OWNER';
  static const String keyRepo = 'GITHUB_REPO';
  static const String keyBranch = 'GITHUB_BRANCH';
  static const String keyFilePath = 'GITHUB_FILEPATH';
  static const String keyToken = 'GITHUB_TOKEN';
  static const String keyLocalRepoPath = 'GITHUB_LOCAL_REPO_PATH';

  /// Best-effort resolution of the .env file path
  static File resolveEnvFile() {
    // 1. Check directory where executable resides (Crucial for Windows release & standalone)
    try {
      final exe = File(Platform.resolvedExecutable);
      final exeDir = exe.parent;
      final envInExe = File('${exeDir.path}${Platform.pathSeparator}.env');
      if (envInExe.existsSync()) {
        return envInExe;
      }

      // On macOS .app bundle, executable is inside Contents/MacOS/
      // The app root is 3 levels up
      if (Platform.isMacOS && exeDir.path.contains('.app/Contents/MacOS')) {
        final bundleParent = exeDir.parent.parent.parent;
        final envInBundleParent = File(
          '${bundleParent.path}${Platform.pathSeparator}.env',
        );
        if (envInBundleParent.existsSync()) {
          return envInBundleParent;
        }
      }
    } catch (_) {}

    // 2. Check current working directory
    final envInCwd = File(
      '${Directory.current.path}${Platform.pathSeparator}.env',
    );
    if (envInCwd.existsSync()) {
      return envInCwd;
    }

    // 3. Check parent directory (common when running from admin_app folder in dev)
    final envInParent = File(
      '${Directory.current.path}${Platform.pathSeparator}..${Platform.pathSeparator}.env',
    );
    if (envInParent.existsSync()) {
      return envInParent;
    }

    // Fallback default target when creating a new file:
    // If on Windows, save alongside the executable
    if (Platform.isWindows) {
      try {
        final exeDir = File(Platform.resolvedExecutable).parent;
        return File('${exeDir.path}${Platform.pathSeparator}.env');
      } catch (_) {}
    }

    return envInCwd;
  }

  /// Parses a .env file into key-value pairs
  static Map<String, String> readEnv(File file) {
    if (!file.existsSync()) return {};
    final map = <String, String>{};
    try {
      final lines = file.readAsLinesSync();
      for (var line in lines) {
        line = line.trim();
        if (line.isEmpty || line.startsWith('#')) continue;
        final eqIdx = line.indexOf('=');
        if (eqIdx == -1) continue;
        final key = line.substring(0, eqIdx).trim();
        var val = line.substring(eqIdx + 1).trim();
        // Remove enclosing quotes if present
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          if (val.length >= 2) {
            val = val.substring(1, val.length - 1);
          }
        }
        map[key] = val;
      }
    } catch (_) {}
    return map;
  }

  /// Writes configuration to a .env file
  static Future<void> writeEnv(File file, Map<String, String> values) async {
    try {
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }
      final buffer = StringBuffer();
      buffer.writeln(
        '# Marketsite Yönetim Masası - GitHub Entegrasyon Ayarları',
      );
      buffer.writeln(
        '# Bu dosya uygulamanın kurulduğu dizinde saklanır ve repo/token değişimlerinde kullanılır.',
      );
      buffer.writeln();
      for (final entry in values.entries) {
        buffer.writeln('${entry.key}=${entry.value}');
      }
      await file.writeAsString(buffer.toString());
    } catch (_) {}
  }
}
