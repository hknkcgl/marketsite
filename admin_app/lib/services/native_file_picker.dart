import 'dart:io';

class NativeFilePicker {
  /// Desteklenen görsel uzantıları
  static const List<String> supportedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'svg',
  ];

  /// İşletim sisteminin yerel dosya seçici penceresini açar (harici paket gerektirmez)
  static Future<File?> pickImage() async {
    try {
      if (Platform.isMacOS) {
        // macOS AppleScript ile yerel dosya seçici
        const script = '''
try
  set f to choose file of type {"public.image", "jpg", "jpeg", "png", "webp", "svg"} with prompt "Ürün Görseli Seçin"
  return POSIX path of f
on error
  return ""
end try
''';
        final result = await Process.run('osascript', ['-e', script]);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty) {
            final file = File(path);
            if (file.existsSync()) return file;
          }
        }
      } else if (Platform.isWindows) {
        // Windows PowerShell System.Windows.Forms.OpenFileDialog ile yerel dosya seçici
        const script = '''
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
\$dlg = New-Object System.Windows.Forms.OpenFileDialog
\$dlg.Title = "Ürün Görseli Seçin"
\$dlg.Filter = "Görsel Dosyaları (*.jpg;*.jpeg;*.png;*.webp;*.svg)|*.jpg;*.jpeg;*.png;*.webp;*.svg|Tüm Dosyalar (*.*)|*.*"
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$dlg.FileName
}
''';
        final result = await Process.run('powershell', [
          '-NoProfile',
          '-Command',
          script,
        ]);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty) {
            final file = File(path);
            if (file.existsSync()) return file;
          }
        }
      } else if (Platform.isLinux) {
        // Linux zenity ile yerel dosya seçici
        final result = await Process.run('zenity', [
          '--file-selection',
          '--title=Ürün Görseli Seçin',
          '--file-filter=Görseller | *.jpg *.jpeg *.png *.webp *.svg',
        ]);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty) {
            final file = File(path);
            if (file.existsSync()) return file;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  /// Dosya uzantısını normalize eder (ör. 'jpg', 'png')
  static String extractExtension(String path) {
    final dotIdx = path.lastIndexOf('.');
    if (dotIdx == -1) return 'jpg';
    final ext = path.substring(dotIdx + 1).toLowerCase().trim();
    if (ext == 'jpeg') return 'jpg';
    return supportedExtensions.contains(ext) ? ext : 'jpg';
  }
}
