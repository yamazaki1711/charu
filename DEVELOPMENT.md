# CHARU — Руководство по разработке

## 📖 Оглавление

1. [Настройка окружения](#настройка-окружения)
2. [Генерация базы данных](#генерация-базы-данных)
3. [Добавление новых слов в словарь](#добавление-новых-слов-в-словарь)
4. [Расширение функциональности](#расширение-функциональности)
5. [Полезные команды](#полезные-команды)

---

## 🛠 Настройка окружения

### 1. Установка Flutter

Скачайте и установите Flutter с официального сайта: https://flutter.dev

Проверка установки:
```bash
flutter doctor
```

### 2. Установка зависимостей

```bash
cd c:\charu
flutter pub get
```

### 3. Генерация тестовой БД

```bash
dart run scripts/generate_test_db.dart
```

Это создаст файл `assets/db/charu_dict.db` с демонстрационными данными.

---

## 🗄 Генерация базы данных

### Вариант 1: Через Dart-скрипт (рекомендуется)

```bash
dart run scripts/generate_test_db.dart
```

**Преимущества:**
- Кроссплатформенность
- Не требует дополнительных инструментов
- Автоматическая индексация

### Вариант 2: Через SQLite CLI

```bash
# Создание БД
sqlite3 assets/db/charu_dict.db < schema.sql

# Или вручную
sqlite3 assets/db/charu_dict.db
sqlite> .read schema.sql
sqlite> .quit
```

### Вариант 3: Импорт из CSV

Для массовой загрузки слов из внешних источников:

```sql
-- Пример импорта из CSV
.mode csv
.import path/to/dictionary.csv dictionary
```

---

## 📚 Добавление новых слов в словарь

### Через SQL-скрипт

Создайте файл `scripts/add_words.sql`:

```sql
INSERT INTO dictionary (simplified, traditional, pinyin, translation, examples) VALUES
    ('示例', '示例', 'shì lì', 'пример', '这是一个示例。'),
    ('测试', '測試', 'cè shì', 'тест', '进行测试'),
    ('开发', '開發', 'kāi fā', 'разработка', '软件开发');
```

Выполните:
```bash
sqlite3 assets/db/charu_dict.db < scripts/add_words.sql
```

### Через Dart-скрипт

```dart
import 'package:sqflite/sqflite.dart';

Future<void> addWords(Database db) async {
  await db.batch().insertAll([
    {'simplified': '示例', 'traditional': '示例', 'pinyin': 'shì lì', 'translation': 'пример'},
    {'simplified': '测试', 'traditional': '測試', 'pinyin': 'cè shì', 'translation': 'тест'},
  ]).commit();
}
```

---

## 🔧 Расширение функциональности

### Добавление нового экрана

1. Создайте файл в `lib/presentation/screens/<name>/<name>_screen.dart`
2. Реализуйте виджет
3. Добавьте маршрут в `lib/presentation/navigation/app_router.dart`
4. Добавьте иконку в `lib/presentation/navigation/app_shell.dart`

**Пример:**
```dart
// lib/presentation/screens/about/about_screen.dart
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('О приложении')),
      body: const Center(child: Text('CHARU v0.1.0')),
    );
  }
}
```

### Добавление Use Case

1. Создайте класс в `lib/domain/usecase/<name>_usecase.dart`
2. Добавьте провайдер в `lib/di/di.dart`

**Пример:**
```dart
// lib/domain/usecase/clear_cache_usecase.dart
class ClearCacheUseCase {
  final ICacheRepository _repository;
  
  ClearCacheUseCase(this._repository);
  
  Future<void> call() async {
    await _repository.clearAll();
  }
}
```

### Добавление репозитория

1. Интерфейс: `lib/domain/repository/<name>_repository.dart`
2. Реализация: `lib/data/repository/<name>_repository_impl.dart`
3. Провайдер: `lib/di/di.dart`

---

## 🧪 Полезные команды

### Анализ и форматирование

```bash
# Анализ кода
flutter analyze

# Авто-исправление
dart fix --apply

# Форматирование
dart format lib/

# Проверка зависимостей
flutter pub outdated
```

### Тестирование

```bash
# Запуск всех тестов
flutter test

# Запуск с покрытием
flutter test --coverage

# Просмотр покрытия
genhtml coverage/lcov.info -o coverage/html
```

### Сборка

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (на macOS)
flutter build ios --release
```

### Отладка БД

```bash
# Просмотр БД
sqlite3 assets/db/charu_dict.db

# Экспорт структуры
sqlite3 assets/db/charu_dict.db .schema

# Экспорт данных
sqlite3 assets/db/charu_dict.db "SELECT * FROM dictionary LIMIT 10;"
```

---

## 🐛 Отладка

### Логирование

В коде используйте `print()` (временно) или добавьте пакет `logger`:

```dart
import 'package:logger/logger.dart';

final logger = Logger();

logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

### Отладка БД

Для просмотра БД на устройстве:

```bash
# Android
adb pull /data/data/com.example.charu/databases/charu_dict.db

# iOS (требуется Xcode)
# Device Manager → Downloads → App Data
```

---

## 📦 Зависимости

### Основные

| Пакет | Назначение |
|-------|------------|
| `flutter_riverpod` | State management |
| `go_router` | Навигация |
| `sqflite` | SQLite база |
| `dio` | HTTP-запросы |
| `jieba_flutter` | Сегментация китайского |
| `html` | Парсинг HTML |
| `file_picker` | Выбор файлов |
| `shared_preferences` | Локальное хранилище |

### Для разработки

| Пакет | Назначение |
|-------|------------|
| `sqlite3` | Генерация БД (standalone) |
| `build_runner` | Code generation |
| `riverpod_generator` | Генерация провайдеров |

---

## 🎯 Roadmap

### MVP (готово)
- ✅ Чтение новостей с сегментацией
- ✅ 5-уровневый словарь
- ✅ Чтение TXT файлов
- ✅ Ударный режим
- ✅ Статистика

### v0.2.0
- [ ] Чтение EPUB
- [ ] Парсинг реальных новостей
- [ ] Система повторений слов
- [ ] Экспорт словаря

### v0.3.0
- [ ] Синхронизация между устройствами
- [ ] Веб-версия
- [ ] Темы оформления
- [ ] Жесты (свайпы)

---

## ❓ FAQ

### Q: Как обновить БД после изменений в schema.sql?

A: Удалите старую БД и перегенерируйте:
```bash
rm assets/db/charu_dict.db
dart run scripts/generate_test_db.dart
```

### Q: Где хранятся данные на устройстве?

A: 
- **Android**: `/data/data/<package>/databases/`
- **iOS**: `~/Library/Application Support/<bundle_id>/`

### Q: Как добавить новый источник новостей?

A: Добавьте запись в таблицу `news_sources`:
```sql
INSERT INTO news_sources (name, url, type, enabled) 
VALUES ('New Source', 'https://example.com', 'rss', 1);
```

---

**Документ обновлён:** 25 февраля 2026 г.  
**Версия:** 0.1.0
