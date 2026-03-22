import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../main.dart';

/// ⚙️ Settings screen — app preferences.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  String _notificationTime = '18:00';
  int _fontSize = 18;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _notificationTime = prefs.getString('notification_time') ?? '18:00';
      _fontSize = prefs.getInt('font_size') ?? 18;
    });
  }

  Future<void> _saveNotifications(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
    setState(() => _notificationsEnabled = enabled);
  }

  Future<void> _saveFontSize(int size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('font_size', size);
    setState(() => _fontSize = size);
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
          _FontSizeTile(
            currentSize: _fontSize,
            onChanged: _saveFontSize,
          ),
          const SizedBox(height: 24),

          // Notifications Section
          _SectionTitle(title: 'Уведомления'),
          _SwitchTile(
            title: 'Ежедневные напоминания',
            subtitle: 'Напоминать о чтении в выбранное время',
            value: _notificationsEnabled,
            onChanged: _saveNotifications,
          ),
          if (_notificationsEnabled)
            _TimePickerTile(
              currentTime: _notificationTime,
              onChanged: (time) async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setString('notification_time', time);
                setState(() => _notificationTime = time);
              },
            ),
          const SizedBox(height: 24),

          // Dictionary Section
          _SectionTitle(title: 'Словарь'),
          _InfoTile(
            title: 'Офлайн-словарь',
            subtitle: 'БКРС (~250k записей)',
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
            title: 'CHARU',
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
            onPressed: () {
              // TODO: Call use case to clear history
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('История очищена')),
              );
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
            onPressed: () {
              // TODO: Call use case to reset progress
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Прогресс сброшен')),
              );
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

  const _SwitchTile({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications),
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
