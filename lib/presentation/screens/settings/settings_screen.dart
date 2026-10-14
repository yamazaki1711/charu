import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../data/repository/news_sources_repository.dart';
import '../../../di/di.dart';
import '../../services/notification_service.dart';
import '../../state/app_settings_state.dart';
import '../../state/file_state.dart';
import '../../state/news_state.dart';
import '../../state/progress_state.dart';

/// ⚙️ Settings screen — app preferences.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _notificationTime = '18:00';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationTime = prefs.getString('notification_time') ?? '18:00';
    });
  }

  Future<void> _saveNotifications(bool enabled) async {
    // Persist via the live provider (writes to SharedPreferences) and
    // schedule/cancel the daily reminder accordingly.
    await ref.read(notificationsEnabledProvider.notifier).set(enabled);
    await NotificationService.instance.onReminderChanged(enabled, _notificationTime);
  }

  Future<void> _saveFontSize(int size) async {
    // Persist via the live provider so the reader rebuilds immediately.
    await ref.read(fontSizeProvider.notifier).set(size);
  }

  Future<void> _saveShowPinyin(bool value) async {
    // Persist via the live provider so the reader rebuilds immediately.
    await ref.read(showPinyinProvider.notifier).set(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Appearance Section
          _SectionTitle(title: 'Внешний вид'),
          const _ThemeTile(),
          Consumer(
            builder: (context, ref, _) {
              final currentSize = ref.watch(fontSizeProvider);
              return _FontSizeTile(
                currentSize: currentSize,
                onChanged: _saveFontSize,
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final showPinyin = ref.watch(showPinyinProvider);
              return _SwitchTile(
                title: 'Показывать пиньинь',
                subtitle: 'Фонетика над словами в читалке и в словаре',
                value: showPinyin,
                onChanged: _saveShowPinyin,
                icon: Icons.translate,
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final showPinyin = ref.watch(showPinyinProvider);
              if (!showPinyin) return const SizedBox.shrink();
              final tapOnly = ref.watch(pinyinTapOnlyProvider);
              return _SwitchTile(
                title: 'Пиньинь только по тапу',
                subtitle: 'Защита от «слепого чтения»: строка чистая, '
                    'пиньинь появляется при нажатии на слово',
                value: tapOnly,
                onChanged: (v) =>
                    ref.read(pinyinTapOnlyProvider.notifier).set(v),
                icon: Icons.visibility_off_outlined,
              );
            },
          ),
          const SizedBox(height: 24),

          // Notifications Section
          _SectionTitle(title: 'Уведомления'),
          Consumer(
            builder: (context, ref, _) {
              final enabled = ref.watch(notificationsEnabledProvider);
              return _SwitchTile(
                title: 'Ежедневные напоминания',
                subtitle: 'Напоминать о чтении в выбранное время',
                value: enabled,
                onChanged: _saveNotifications,
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final enabled = ref.watch(notificationsEnabledProvider);
              if (!enabled) return const SizedBox.shrink();
              return _TimePickerTile(
                currentTime: _notificationTime,
                onChanged: (time) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('notification_time', time);
                  if (!mounted) return;
                  setState(() => _notificationTime = time);
                  await NotificationService.instance
                      .onReminderChanged(true, time);
                },
              );
            },
          ),
          const SizedBox(height: 24),

          // News Sources Section
          _SectionTitle(title: 'Источники новостей'),
          const _NewsSourcesList(),
          const SizedBox(height: 24),

          // Dictionary Section
          _SectionTitle(title: 'Словарь'),
          _InfoTile(
            title: 'Офлайн-словарь',
            subtitle: 'БКРС (~860k записей)',
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          _InfoTile(
            title: 'Топонимы',
            subtitle: '~100k географических названий',
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          _InfoTile(
            title: 'Личные имена',
            subtitle: '~20k имён и фамилий',
            trailing: const Icon(Icons.check_circle, color: Colors.green),
          ),
          const SizedBox(height: 24),

          // About Section
          _SectionTitle(title: 'О приложении'),
          _InfoTile(
            title: 'Версия',
            subtitle: '0.1.0',
          ),
          _InfoTile(
            title: 'Kira',
            subtitle: 'Читатель китайских текстов с интегрированным словарём',
          ),
          const SizedBox(height: 32),

          // Clear Data Button
          _DangerButton(
            title: 'Очистить историю чтения',
            onpressed: () => _showClearDataDialog(context),
          ),
          const SizedBox(height: 16),
          _DangerButton(
            title: 'Сбросить прогресс',
            onpressed: () => _showResetProgressDialog(context),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Очистить историю?'),
        content: const Text(
          'Это удалит всю историю открытых файлов из приложения. Файлы не будут удалены с устройства.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(clearHistoryUseCaseProvider).call();
                ref.invalidate(recentFilesProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('История очищена')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка очистки: $e')),
                );
              }
            },
            child: const Text('Очистить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showResetProgressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Сбросить прогресс?'),
        content: const Text(
          'Это удалит всю статистику чтения и ударный режим. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(resetProgressUseCaseProvider).call();
                ref.invalidate(progressSummaryProvider);
                ref.invalidate(vocabularyProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Прогресс сброшен')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка сброса: $e')),
                );
              }
            },
            child: const Text('Сбросить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ThemeTile extends ConsumerWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeModeProvider);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.palette),
        title: const Text('Тема'),
        subtitle: Text(_getThemeModeName(currentMode)),
        trailing: DropdownMenu<ThemeMode>(
          initialSelection: currentMode,
          onSelected: (mode) {
            if (mode != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(mode);
            }
          },
          dropdownMenuEntries: const [
            DropdownMenuEntry(value: ThemeMode.system, label: 'Системная'),
            DropdownMenuEntry(value: ThemeMode.light, label: 'Светлая'),
            DropdownMenuEntry(value: ThemeMode.dark, label: 'Тёмная'),
          ],
        ),
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Системная',
      ThemeMode.light => 'Светлая',
      ThemeMode.dark => 'Тёмная',
    };
  }
}

class _FontSizeTile extends StatelessWidget {
  final int currentSize;
  final Function(int) onChanged;

  const _FontSizeTile({required this.currentSize, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.text_fields),
        title: const Text('Размер шрифта'),
        subtitle: Text('$currentSize px'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: currentSize > 14 ? () => onChanged(currentSize - 2) : null,
            ),
            Text('$currentSize', style: const TextStyle(fontSize: 16)),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: currentSize < 24 ? () => onChanged(currentSize + 2) : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final Function(bool) onChanged;
  final IconData icon;

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.icon = Icons.notifications,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(icon),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String currentTime;
  final Function(String) onChanged;

  const _TimePickerTile({required this.currentTime, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time),
        title: const Text('Время напоминания'),
        subtitle: Text(currentTime),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () async {
            // Simple time picker simulation
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: int.parse(currentTime.split(':')[0]),
                minute: int.parse(currentTime.split(':')[1]),
              ),
            );
            if (time != null) {
              onChanged('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}');
            }
          },
        ),
      ),
    );
  }
}

class _NewsSourcesList extends ConsumerWidget {
  const _NewsSourcesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sources = ref.watch(newsSourcesProvider);
    final notifier = ref.read(newsSourcesProvider.notifier);

    // Ensure sources are loaded on first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifier.load();
    });

    if (sources.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Загрузка источников...'),
        ),
      );
    }

    return Column(
      children: [
        for (final source in sources)
          Card(
            child: SwitchListTile(
              secondary: _SourceAvatar(name: source.name),
              title: Text(source.name),
              subtitle: Text(source.url),
              value: source.enabled,
              onChanged: (enabled) async {
                await notifier.toggle(source.id, enabled);
                // Reload feed immediately with the new source set.
                ref.read(newsFeedProvider.notifier).refresh();
              },
            ),
          ),
      ],
    );
  }
}

/// Colored circular initial avatar for a news source — no real favicons are
/// fetched (offline-first, no extra network dependency), but a stable
/// per-source color makes the source list visually distinguishable instead
/// of every row sharing one identical RSS icon.
class _SourceAvatar extends StatelessWidget {
  final String name;

  const _SourceAvatar({required this.name});

  static const _palette = [
    Color(0xFFCC2B2B),
    Color(0xFF2E8B57),
    Color(0xFF3B6FB6),
    Color(0xFFD4AF37),
    Color(0xFF8E5BC0),
    Color(0xFFD97A3C),
  ];

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    final color = _palette[name.hashCode.abs() % _palette.length];

    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.15),
      foregroundColor: color,
      child: Text(
        initial,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const _InfoTile({
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: trailing,
      ),
    );
  }
}

class _DangerButton extends StatelessWidget {
  final String title;
  final VoidCallback onpressed;

  const _DangerButton({required this.title, required this.onpressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onpressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(title),
      ),
    );
  }
}
