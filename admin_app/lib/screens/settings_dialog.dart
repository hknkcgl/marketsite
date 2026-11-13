import 'package:flutter/material.dart';
import '../services/github_service.dart';
import '../theme/app_colors.dart';

class SettingsDialog extends StatefulWidget {
  final GitHubService githubService;
  final VoidCallback onSaved;

  const SettingsDialog({
    super.key,
    required this.githubService,
    required this.onSaved,
  });

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late final TextEditingController _tokenController;

  bool _isTesting = false;
  String? _testResult;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.githubService.token);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    try {
      widget.githubService.token = _tokenController.text.trim();

      final products = await widget.githubService.fetchProducts();

      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = true;
          _testResult =
              'Bağlantı başarılı! ${products.length} adet ürün bulundu.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTesting = false;
          _testSuccess = false;
          _testResult = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  Future<void> _save() async {
    await widget.githubService.saveSettings(
      token: _tokenController.text,
    );
    widget.onSaved();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final envPath = widget.githubService.currentEnvFile.path;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emerald50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: AppColors.emerald800,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GitHub Entegrasyon Ayarları',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Ürün ve stok verilerini çekmek ve güncellemek için repo bilgileri',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // .env BİLGİLENDİRME KUTUSU
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.emerald50.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.emerald200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.folder_outlined,
                        color: AppColors.emerald700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kurulum & .env Dosya Konumu',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.emerald900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              envPath,
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Uygulama Windows veya başka bir bilgisayara taşındığında, bu dizindeki .env dosyası otomatik okunur ve tüm değişiklikler doğrudan bu dosyaya kaydedilir.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Personal Access Token
                TextField(
                  controller: _tokenController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'GitHub Personal Access Token (PAT)',
                    hintText: 'ghp_xxxxxxxxxxxx veya github_pat_xxxx',
                    border: OutlineInputBorder(),
                    isDense: true,
                    helperText:
                        'Stok, fiyat ve ürün görsellerini push edebilmek için repo okuma/yazma yetkisi gereklidir.',
                  ),
                ),
                const SizedBox(height: 16),

                // Test Sonucu Banner
                if (_testResult != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: _testSuccess
                          ? AppColors.emerald50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _testSuccess
                            ? AppColors.emerald200
                            : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _testSuccess ? Icons.check_circle : Icons.error,
                          color: _testSuccess
                              ? AppColors.emerald700
                              : Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _testResult!,
                            style: TextStyle(
                              fontSize: 12,
                              color: _testSuccess
                                  ? AppColors.emerald900
                                  : Colors.red.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Butonlar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: _isTesting ? null : _testConnection,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_alt, size: 18),
                      label: const Text('Bağlantıyı Test Et'),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('İptal'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Kaydet (.env)'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
