import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _buildAccentSwatch(
    BuildContext context, {
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Accent color',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: isSelected ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isSelected ? 0.16 : 0.05,
                  ),
                  blurRadius: isSelected ? 10 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, size: 20, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildFontPreview(
    BuildContext context, {
    required String fontFamily,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final foreground = theme.colorScheme.onSurface;
    final outline = theme.colorScheme.outline;

    return Semantics(
      selected: isSelected,
      button: true,
      label: 'Font family $fontFamily',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 112,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primary.withValues(alpha: 0.12)
                  : theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : outline.withValues(alpha: 0.45),
                width: isSelected ? 1.6 : 1.0,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aa',
                  style: TextStyle(
                    color: foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: fontFamily,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fontFamily,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground.withValues(alpha: 0.72),
                    fontSize: 12,
                    fontFamily: fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final background = theme.scaffoldBackgroundColor;
    final foreground = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurfaceVariant;
    final outline = theme.colorScheme.outline;
    final isDarkMode = settingsProvider.themeMode == ThemeMode.dark;
    const fontFamilies = <String>[
      'Roboto',
      'Poppins',
      'Nunito',
      'Lato',
      'Merriweather',
    ];

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: ListView(
            children: [
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Back'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: outline.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.dark_mode_outlined),
                      title: Text(
                        'Dark Mode',
                        style: TextStyle(color: foreground),
                      ),
                      value: settingsProvider.themeMode == ThemeMode.dark,
                      onChanged: (_) => settingsProvider.toggleTheme(),
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    SwitchListTile(
                      secondary: Icon(
                        Icons.brightness_2_outlined,
                        color: isDarkMode ? null : muted,
                      ),
                      title: Text(
                        'OLED (Pure Black) Mode',
                        style: TextStyle(
                          color: isDarkMode ? foreground : muted,
                        ),
                      ),
                      subtitle: Text(
                        'Saves battery on AMOLED screens when Dark Mode is enabled.',
                        style: TextStyle(
                          color: isDarkMode
                              ? muted
                              : muted.withValues(alpha: 0.6),
                        ),
                      ),
                      value: settingsProvider.isOledMode,
                      onChanged: isDarkMode
                          ? (_) => settingsProvider.toggleOledMode()
                          : null,
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Font',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: settingsProvider.selectedFontFamily,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: theme.colorScheme.surface,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: outline.withValues(alpha: 0.45),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: outline.withValues(alpha: 0.45),
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                            dropdownColor: theme.colorScheme.surface,
                            iconEnabledColor: foreground,
                            style: TextStyle(color: foreground),
                            items: [
                              for (final fontFamily in fontFamilies)
                                DropdownMenuItem<String>(
                                  value: fontFamily,
                                  child: Text(
                                    fontFamily,
                                    style: TextStyle(fontFamily: fontFamily),
                                  ),
                                ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              settingsProvider.changeFontFamily(value);
                            },
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final fontFamily in fontFamilies)
                                _buildFontPreview(
                                  context,
                                  fontFamily: fontFamily,
                                  isSelected:
                                      settingsProvider.selectedFontFamily ==
                                      fontFamily,
                                  onTap: () => settingsProvider
                                      .changeFontFamily(fontFamily),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accent Color',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final color in SettingsProvider.accentColors)
                                _buildAccentSwatch(
                                  context,
                                  color: color,
                                  isSelected:
                                      settingsProvider
                                          .currentAccentColor
                                          .value ==
                                      color.value,
                                  onTap: () =>
                                      settingsProvider.changeAccentColor(color),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.ring_volume_outlined),
                      title: Text(
                        'Progress Ring',
                        style: TextStyle(color: foreground),
                      ),
                      subtitle: Text(
                        'Show a circular progress ring around the timer.',
                        style: TextStyle(color: muted),
                      ),
                      value: settingsProvider.showProgressRing,
                      onChanged: (_) => settingsProvider.toggleProgressRing(),
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.self_improvement_outlined),
                      title: Text(
                        'Zen Mode breathing animation',
                        style: TextStyle(color: foreground),
                      ),
                      subtitle: Text(
                        'Disable to show a static pure black Zen view.',
                        style: TextStyle(color: muted),
                      ),
                      value: settingsProvider.zenAnimationEnabled,
                      onChanged: (_) => settingsProvider.toggleZenAnimation(),
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.playlist_play_outlined),
                      title: Text(
                        'Auto-start next phase',
                        style: TextStyle(color: foreground),
                      ),
                      subtitle: Text(
                        'Overrides individual phase auto-start settings.',
                        style: TextStyle(color: muted),
                      ),
                      value: settingsProvider.globalAutoStart,
                      onChanged: (_) =>
                          settingsProvider.toggleGlobalAutoStart(),
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.music_note_outlined),
                      title: Text('Sound', style: TextStyle(color: foreground)),
                      subtitle: Text(
                        'Play a chime when a timer finishes.',
                        style: TextStyle(color: muted),
                      ),
                      value: settingsProvider.soundEnabled,
                      onChanged: (_) => settingsProvider.toggleSoundEnabled(),
                    ),
                    Divider(color: outline.withValues(alpha: 0.45), height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.vibration_outlined),
                      title: Text(
                        'Vibration',
                        style: TextStyle(color: foreground),
                      ),
                      subtitle: Text(
                        'Use haptic feedback when a timer finishes.',
                        style: TextStyle(color: muted),
                      ),
                      value: settingsProvider.hapticsEnabled,
                      onChanged: (_) => settingsProvider.toggleHapticsEnabled(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
