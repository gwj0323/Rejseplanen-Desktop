import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/api_client.dart';
import '../i18n/translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _keyCtrl;
  late TextEditingController _urlCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;
  bool? _testSuccess;

  @override
  void initState() {
    super.initState();
    final config = Provider.of<AppConfig>(context, listen: false);
    _keyCtrl = TextEditingController(text: config.apiKey);
    _urlCtrl = TextEditingController(text: config.baseUrl);
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
      _testSuccess = null;
    });

    final config = Provider.of<AppConfig>(context, listen: false);
    final client = RejseplanenApiClient(config);
    final res = await client.testConnection(
      apiKey: _keyCtrl.text,
      baseUrl: _urlCtrl.text,
    );

    if (mounted) {
      setState(() {
        _testing = false;
        _testSuccess = res["success"] as bool;
        _testResult = res["message"] as String;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final config = Provider.of<AppConfig>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t(context, "settings_title"), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Group 1: API Configuration
          Text(
            I18n.t(context, "settings_api_group"),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    I18n.t(context, "settings_api_key_label"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    I18n.t(context, "settings_api_key_desc"),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: I18n.t(context, "settings_api_key_placeholder"),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                    ),
                    onChanged: (val) => config.setApiKey(val),
                  ),
                  const SizedBox(height: 14),

                  Text(
                    I18n.t(context, "settings_base_url_label"),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _urlCtrl,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (val) => config.setBaseUrl(val),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _testing ? null : _testConnection,
                        icon: _testing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check, size: 18),
                        label: Text(I18n.t(context, "settings_test_conn_btn")),
                      ),
                    ],
                  ),

                  if (_testResult != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _testSuccess == true
                            ? Colors.green.withOpacity(0.12)
                            : Colors.red.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            _testSuccess == true ? Icons.check_circle : Icons.error,
                            color: _testSuccess == true ? Colors.green : Colors.red,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _testResult!,
                              style: TextStyle(
                                color: _testSuccess == true ? Colors.green.shade900 : Colors.red.shade900,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const Divider(height: 24),

                  // Mock Fallback Switch
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(I18n.t(context, "settings_mock_fallback_label")),
                    subtitle: Text(
                      I18n.t(context, "settings_mock_fallback_desc"),
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                    value: config.mockFallback,
                    onChanged: (val) => config.setMockFallback(val),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Group 2: Appearance & Language
          Text(
            I18n.t(context, "settings_appearance_group"),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Language Selector
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.language),
                    title: Text(I18n.t(context, "settings_lang_label")),
                    trailing: DropdownButton<String>(
                      value: config.language,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: "zh_CN", child: Text("简体中文")),
                        DropdownMenuItem(value: "en_US", child: Text("English")),
                        DropdownMenuItem(value: "da_DK", child: Text("Dansk")),
                      ],
                      onChanged: (val) {
                        if (val != null) config.setLanguage(val);
                      },
                    ),
                  ),
                  const Divider(height: 1),

                  // Theme Selector
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.palette_outlined),
                    title: Text(I18n.t(context, "settings_theme_label")),
                    trailing: DropdownButton<ThemeMode>(
                      value: config.themeMode,
                      underline: const SizedBox(),
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(I18n.t(context, "theme_auto")),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(I18n.t(context, "theme_light")),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(I18n.t(context, "theme_dark")),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) config.setThemeMode(val);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Group 3: About
          Text(
            I18n.t(context, "settings_about_group"),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Rejseplanen Mobile",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    I18n.t(context, "settings_about_desc"),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    I18n.t(context, "settings_about_author"),
                    style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Version 1.0.0 (Android Native / Flutter)",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
