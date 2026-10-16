import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/api_client.dart';
import '../services/update_service.dart';
import '../i18n/translations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _keyCtrl;
  late TextEditingController _urlCtrl;
  late TextEditingController _hexCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  bool _checkingUpdate = false;
  String? _testResult;
  bool? _testSuccess;

  static const List<Map<String, dynamic>> _presetColors = [
    {"nameKey": "accent_preset_red", "hex": "#C72027", "color": Color(0xFFC72027)},
    {"nameKey": "accent_preset_blue", "hex": "#005776", "color": Color(0xFF005776)},
    {"nameKey": "accent_preset_green", "hex": "#007D55", "color": Color(0xFF007D55)},
    {"nameKey": "accent_preset_orange", "hex": "#E65100", "color": Color(0xFFE65100)},
    {"nameKey": "accent_preset_purple", "hex": "#6750A4", "color": Color(0xFF6750A4)},
    {"nameKey": "accent_preset_teal", "hex": "#006874", "color": Color(0xFF006874)},
    {"nameKey": "accent_preset_amber", "hex": "#B45309", "color": Color(0xFFB45309)},
  ];

  @override
  void initState() {
    super.initState();
    final config = Provider.of<AppConfig>(context, listen: false);
    _keyCtrl = TextEditingController(text: config.apiKey);
    _urlCtrl = TextEditingController(text: config.baseUrl);
    _hexCtrl = TextEditingController(
      text: config.isSystemAccentColor ? "#C72027" : config.accentColor,
    );
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    _urlCtrl.dispose();
    _hexCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final config = Provider.of<AppConfig>(context);
    if (_keyCtrl.text.isEmpty && config.apiKey.isNotEmpty) {
      _keyCtrl.text = config.apiKey;
    }
    if (_urlCtrl.text.isEmpty && config.baseUrl.isNotEmpty) {
      _urlCtrl.text = config.baseUrl;
    }
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
      final success = res["success"] as bool;
      setState(() {
        _testing = false;
        _testSuccess = success;
        _testResult = res["message"] as String;
      });
      if (success) {
        config.setApiKey(_keyCtrl.text);
        config.setBaseUrl(_urlCtrl.text);
      }
    }
  }

  Future<void> _handleCheckUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Text(I18n.t(context, "settings_checking_update")),
          ],
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    final res = await UpdateService.checkUpdate();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);

    if (res.success && res.release != null) {
      final rel = res.release!;
      if (rel.hasUpdate) {
        final isAndroid = defaultTargetPlatform == TargetPlatform.android;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.system_update, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(I18n.t(context, "settings_update_found")),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rel.name.isNotEmpty ? rel.name : "Version ${rel.cleanVersion}",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (isAndroid) ...[
                    const SizedBox(height: 6),
                    Text(
                      I18n.t(context, "settings_update_play_hint"),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (rel.body.trim().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rel.body.trim(),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(I18n.t(context, "common_later")),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  UpdateService.openStoreOrReleaseUrl(fallbackUrl: rel.htmlUrl);
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text(
                  isAndroid
                      ? I18n.t(context, "settings_update_in_store")
                      : I18n.t(context, "settings_download_update"),
                ),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    I18n.t(context, "settings_already_latest", {
                      "version": AppConfig.appVersion,
                    }),
                  ),
                ),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.orangeAccent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(I18n.t(context, "settings_update_failed")),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        config.hasApiKey ? Icons.check_circle_outline : Icons.info_outline,
                        size: 14,
                        color: config.hasApiKey ? Colors.green.shade600 : Colors.amber.shade800,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        config.hasApiKey
                            ? "${I18n.t(context, "settings_api_status_saved")} (${I18n.t(context, "settings_key_chars", {"count": "${config.apiKey.length}"})})"
                            : I18n.t(context, "settings_api_status_none"),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: config.hasApiKey ? Colors.green.shade700 : Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
                      const SizedBox(width: 10),
                      FilledButton.icon(
                        onPressed: () {
                          final key = _keyCtrl.text.trim();
                          final url = _urlCtrl.text.trim();
                          config.setApiKey(key);
                          config.setBaseUrl(url);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(I18n.t(context, "settings_saved_feedback")),
                                ],
                              ),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        },
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: Text(I18n.t(context, "settings_save_btn")),
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
                      items: [
                        DropdownMenuItem(
                          value: "system",
                          child: Text(I18n.t(context, "lang_system")),
                        ),
                        const DropdownMenuItem(value: "zh_CN", child: Text("简体中文")),
                        const DropdownMenuItem(value: "en_US", child: Text("English")),
                        const DropdownMenuItem(value: "da_DK", child: Text("Dansk")),
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
                  const Divider(height: 1),

                  // Navigation Bar Style Section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.blur_on),
                          title: Text(I18n.t(context, "settings_navbar_style")),
                          subtitle: Text(
                            I18n.t(context, "settings_navbar_style_desc"),
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            showSelectedIcon: true,
                            segments: [
                              ButtonSegment<String>(
                                value: "liquid_glass",
                                icon: const Icon(Icons.auto_awesome, size: 16),
                                label: Text(I18n.t(context, "navbar_style_glass")),
                              ),
                              ButtonSegment<String>(
                                value: "material3",
                                icon: const Icon(Icons.dock, size: 16),
                                label: Text(I18n.t(context, "navbar_style_m3")),
                              ),
                            ],
                            selected: {config.navBarStyle},
                            onSelectionChanged: (newSelection) {
                              if (newSelection.isNotEmpty) {
                                config.setNavBarStyle(newSelection.first);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 24),

                  // Accent Color Section
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.color_lens_outlined),
                    title: Text(I18n.t(context, "settings_accent_label")),
                    subtitle: Text(
                      I18n.t(context, "settings_accent_desc"),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),

                  // Option 1: Follow system
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(I18n.t(context, "accent_follow_system")),
                    subtitle: Text(
                      I18n.t(context, "accent_follow_system_desc"),
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: config.isSystemAccentColor,
                    onChanged: (val) {
                      if (val) {
                        config.setAccentColor('system');
                      } else {
                        config.setAccentColor('#C72027');
                        _hexCtrl.text = "#C72027";
                      }
                    },
                  ),

                  // Preset colors & custom hex when not following system
                  if (!config.isSystemAccentColor) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: _presetColors.map((preset) {
                        final String hex = preset["hex"] as String;
                        final Color color = preset["color"] as Color;
                        final bool isSelected =
                            config.accentColor.toLowerCase() == hex.toLowerCase();

                        return GestureDetector(
                          onTap: () {
                            config.setAccentColor(hex);
                            _hexCtrl.text = hex;
                          },
                          child: Tooltip(
                            message: I18n.t(context, preset["nameKey"]),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: theme.colorScheme.onSurface, width: 3)
                                    : Border.all(color: Colors.black12, width: 1),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: color.withOpacity(0.4),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              child: isSelected
                                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Custom hex code input
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _hexCtrl,
                            decoration: InputDecoration(
                              hintText: I18n.t(context, "accent_custom_hint"),
                              labelText: I18n.t(context, "accent_custom_hex"),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.tonal(
                          onPressed: () {
                            String text = _hexCtrl.text.replaceAll('#', '').trim();
                            if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text)) {
                              config.setAccentColor('#$text');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(I18n.t(context, "settings_saved_msg"))),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(I18n.t(context, "accent_custom_error")),
                                  backgroundColor: Colors.red.shade700,
                                ),
                              );
                            }
                          },
                          child: Text(I18n.t(context, "accent_custom_apply")),
                        ),
                      ],
                    ),
                  ],
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
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Spor",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _checkingUpdate ? null : _handleCheckUpdate,
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        icon: _checkingUpdate
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.sync, size: 15),
                        label: Text(
                          I18n.t(context, "settings_check_update"),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
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
                  Text(
                    I18n.t(context, "settings_about_disclaimer"),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11.5),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        "Version ${AppConfig.appVersion} (Build ${AppConfig.appBuildNumber})",
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      const Spacer(),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse(AppConfig.privacyPolicyUrl);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.privacy_tip_outlined, size: 13, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                I18n.t(context, "settings_privacy_policy"),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: theme.colorScheme.primary.withOpacity(0.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
