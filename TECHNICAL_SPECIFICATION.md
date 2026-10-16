# CHARU — Техническая спецификация приложения

**Версия документа:** 1.0  
**Дата:** 26 февраля 2026 г.  
**Статус:** MVP готов к тестированию

> ⚠️ **Исторический документ, зафиксирован на 26 февраля 2026.** Проект
> с тех пор опубликован под именем **Kira** (`ru.kira.app`; код в
> репозитории — под кодовым именем `charu`). Многие цифры и разделы
> устарели (БКРС — 863 740 записей, не ~250k; топонимов 548, имён
> 58 950 — не ~100k/~20k; «Liquid Glass»-тема не реализована, фактически
> плоская Material 3 с другой палитрой; раздел 10 «Чеклист релиза» не
> отражает текущий прогресс). Актуальный статус — [README.md](README.md)
> и [ROADMAP.md](ROADMAP.md).

---

## 1. Введение

### 1.1 Назначение документа

Данный документ описывает техническую спецификацию мобильного приложения **CHARU** — читателя китайских текстов со встроенным китайско-русским словарём. Документ предназначен для разработчиков, тестировщиков и технических специалистов.

### 1.2 Область применения

Приложение предназначено для изучающих китайский язык и предоставляет возможности:
- Чтения китайских текстов с пословным переводом
- Поиска слов в интегрированном словаре
- Отслеживания прогресса обучения
- Управления личным словарём

### 1.3 Определения и сокращения

| Термин | Определение |
|--------|-------------|
| **БКРС** | Большой китайско-русский словарь (офлайн-база 863 740 записей — актуальная цифра, см. банер выше) |
| **Jieba** | Библиотека для сегментации китайского текста |
| **Пиньинь** | Система транскрипции китайских иероглифов латиницей |
| **Топоним** | Географическое название (город, река, гора и т.д.) |
| **Ударный режим** | Механика отслеживания дней подряд, проведённых в приложении |

---

## 2. Концепция приложения

### 2.1 Миссия

**CHARU** (читается «чару») — это приложение для иммерсивного чтения китайских текстов, где каждое слово находится «в один клик». Интегрированный словарь устраняет необходимость переключения между приложениями, создавая непрерывный поток чтения.

### 2.2 Целевая аудитория

- Изучающие китайский язык (уровни HSK 1-6)
- Студенты языковых вузов
- Самообучающиеся по аутентичным материалам
- Преподаватели китайского языка

### 2.3 Уникальное торговое предложение (УТП)

1. **5-уровневая система поиска слов:**
   - Локальный БКРС (мгновенный офлайн-поиск)
   - База топонимов (географические названия с координатами)
   - База личных имён (распознавание фамилий и имён)
   - Онлайн-БКРС (3.6M записей на bkrs.info)
   - Посимвольный пиньинь (fallback для неизвестных иероглифов)

2. **Сегментация текста в реальном времени:**
   - Автоматическое разбиение текста на слова
   - Подчёркивание кликабельных элементов
   - Всплывающие окна с переводом

3. **Геймификация обучения:**
   - Ударный режим (счётчик дней подряд)
   - Статистика чтения
   - Личный словарь с историей

---

## 3. Функциональные требования

### 3.1 Модуль «Новости» (📰)

#### 3.1.1 Назначение
Просмотр и чтение китайских новостных статей с интегрированным словарём.

#### 3.1.2 Функции

| ID | Функция | Описание | Приоритет |
|----|---------|----------|-----------|
| N1 | Просмотр ленты | Отображение списка статей с заголовком, источником, временем публикации, миниатюрой | Высокий |
| N2 | Pull-to-refresh | Обновление ленты свайпом вниз | Средний |
| N3 | Чтение статьи | Открытие полной версии статьи с сегментированным текстом | Высокий |
| N4 | Сегментация текста | Автоматическое разбиение китайского текста на слова | Высокий |
| N5 | Поиск по клику | Тап по слову → всплывающее окно с переводом | Высокий |
| N6 | Сохранение слова | Добавление слова в личный словарь из всплывающего окна | Средний |
| N7 | Кэширование статей | Сохранение прочитанных статей для офлайн-доступа | Низкий |

#### 3.1.3 Источники новостей (тестовые данные)

| Источник | Тип | URL | Статус |
|----------|-----|-----|--------|
| Baidu Baijiahao | HTML | https://baijiahao.baidu.com | Mock |
| Sina News | RSS | https://news.sina.com.cn | Mock |
| People's Daily | RSS | http://en.people.cn | Mock |

#### 3.1.4 Модель данных NewsArticle

```dart
class NewsArticle {
  final String id;              // Уникальный идентификатор
  final String title;           // Заголовок статьи
  final String source;          // Источник (название)
  final DateTime publishedAt;   // Дата публикации
  final String summary;         // Краткое содержание
  final String? url;            // URL оригинала
  final String? fullContent;    // Полный текст статьи
  final String? thumbnailUrl;   // URL миниатюры
}
```

---

### 3.2 Модуль «Файлы» (📁)

#### 3.2.1 Назначение
Чтение локальных файлов (TXT, HTML, EPUB) с сегментацией и переводом.

#### 3.2.2 Функции

| ID | Функция | Описание | Приоритет |
|----|---------|----------|-----------|
| F1 | Браузер файлов | Выбор файла через системный диалог | Высокий |
| F2 | Поддержка форматов | TXT, HTML, EPUB | Высокий |
| F3 | Определение кодировки | Автоопределение UTF-8, GBK, GB2312, Big5 | Высокий |
| F4 | Сегментация текста | Разбиение на слова с помощью Jieba | Высокий |
| F5 | Поиск по клику | Тап по слову → всплывающее окно | Высокий |
| F6 | История чтения | Сохранение последних открытых файлов | Средний |
| F7 | Закладки | Добавление и управление закладками | Средний |
| F8 | Прогресс чтения | Сохранение позиции в файле | Средний |

#### 3.2.3 Модель данных LocalFile

```dart
class LocalFile {
  final String path;            // Путь к файлу
  final String name;            // Имя файла
  final FileFormat type;        // Формат (txt/html/epub)
  final DateTime? lastOpened;   // Дата последнего открытия
  final int lastPosition;       // Позиция чтения (символ)
  final double progressPercent; // Прогресс в %
  final int totalLength;        // Общая длина файла
}

enum FileFormat { txt, html, epub, unknown }
```

---

### 3.3 Модуль «Прогресс» (📊)

#### 3.3.1 Назначение
Визуализация учебной активности и управление личным словарём.

#### 3.3.2 Функции

| ID | Функция | Описание | Приоритет |
|----|---------|----------|-----------|
| P1 | Ударный режим | Отображение текущей и максимальной серии дней | Высокий |
| P2 | Статистика | Статьи, слова, минуты чтения | Высокий |
| P3 | Выученные слова | Список сохранённых слов с переводом | Высокий |
| P4 | Pull-to-refresh | Обновление статистики | Средний |
| P5 | Экспорт словаря | Выгрузка слов в CSV/Anki | Низкий |

#### 3.3.3 Модель данных ProgressSummary

```dart
class ProgressSummary {
  final int totalWordsSaved;      // Всего слов в словаре
  final int totalArticlesRead;    // Всего прочитано статей
  final int totalReadingMinutes;  // Всего минут чтения
  final int currentStreak;        // Текущая серия дней
  final int maxStreak;            // Максимальная серия
}

class VocabularyWord {
  final String word;              // Иероглифическое написание
  final String pinyin;            // Пиньинь
  final String translation;       // Перевод
  final DateTime savedDate;       // Дата сохранения
  final String sourceType;        // Источник (bkrs/toponym/person/online)
}
```

---

### 3.4 Модуль «Настройки» (⚙️)

#### 3.4.1 Назначение
Управление предпочтениями пользователя.

#### 3.4.2 Функции

| ID | Функция | Описание | Приоритет |
|----|---------|----------|-----------|
| S1 | Выбор темы | Системная / Светлая / Тёмная | Высокий |
| S2 | Размер шрифта | Регулировка от 14 до 24 px | Высокий |
| S3 | Уведомления | Вкл/выкл ежедневные напоминания | Средний |
| S4 | Время напоминания | Выбор времени (часы:минуты) | Средний |
| S5 | Информация о БД | Отображение статуса словарей | Низкий |
| S6 | Очистка данных | Сброс истории и прогресса | Низкий |

---

## 4. Словарная система

### 4.1 Архитектура 5-уровневого поиска

```
┌─────────────────────────────────────────────────────────────┐
│                    ЗАПРОС: 北京                              │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│  УРОВЕНЬ 1: Локальный БКРС (SQLite, ~250k записей)          │
│  ─────────────────────────────────────────────────────────  │
│  SELECT * FROM dictionary WHERE simplified = '北京'         │
│  Результат: 北京 (Běi jīng) — Пекин                         │
│  Статус: ✅ НАЙДЕНО → ВОЗВРАТ                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (если не найдено)
┌─────────────────────────────────────────────────────────────┐
│  УРОВЕНЬ 2: Топонимы (SQLite, ~100k записей)                │
│  ─────────────────────────────────────────────────────────  │
│  SELECT * FROM toponyms WHERE chinese = '北京'              │
│  Результат: 北京 (Běi jīng) — Beijing 🗺️                   │
│  Статус: ✅ НАЙДЕНО → ВОЗВРАТ                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (если не найдено)
┌─────────────────────────────────────────────────────────────┐
│  УРОВЕНЬ 3: Личные имена (SQLite, ~20k записей)             │
│  ─────────────────────────────────────────────────────────  │
│  SELECT * FROM person_names WHERE chinese = '王'            │
│  Результат: 王 (Wáng) — фамилия 👤                          │
│  Статус: ✅ НАЙДЕНО → ВОЗВРАТ                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (если не найдено)
┌─────────────────────────────────────────────────────────────┐
│  УРОВЕНЬ 4: Онлайн-БКРС (HTTP, bkrs.info, 3.6M записей)     │
│  ─────────────────────────────────────────────────────────  │
│  GET https://bkrs.info/search?q=北京                        │
│  Парсинг HTML → извлечение перевода                        │
│  Результат: 北京 — Пекин 🌐                                 │
│  Статус: ✅ НАЙДЕНО → ВОЗВРАТ                               │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼ (если не найдено)
┌─────────────────────────────────────────────────────────────┐
│  УРОВЕНЬ 5: Посимвольный пиньинь (Fallback)                 │
│  ─────────────────────────────────────────────────────────  │
│  北 → běi, 京 → jīng                                        │
│  Результат: běi jīng — Перевод не найден ❓                 │
│  Статус: ✅ ВОЗВРАТ (дефолт)                                │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 База данных

#### 4.2.1 Схема БД

**Таблица `dictionary` (БКРС)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| simplified | TEXT | Упрощённое написание |
| traditional | TEXT | Традиционное написание |
| pinyin | TEXT | Пиньинь с тонами |
| translation | TEXT | Перевод на русский |
| examples | TEXT | Примеры использования |
| frequency | INTEGER | Частотность (опционально) |

**Таблица `toponyms` (Топонимы)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| chinese | TEXT | Китайское название |
| pinyin | TEXT | Пиньинь |
| english | TEXT | Английское название |
| type | TEXT | Тип объекта |
| latitude | REAL | Широта |
| longitude | REAL | Долгота |
| country | TEXT | Страна |

**Таблица `person_names` (Личные имена)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| chinese | TEXT | Иероглифическое написание |
| pinyin | TEXT | Пиньинь |
| is_surname | INTEGER | 1=фамилия, 0=имя |
| gender | TEXT | M/F/U (муж/жен/универс) |
| meaning | TEXT | Значение |

**Таблица `user_vocabulary` (Личный словарь)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| word | TEXT | Слово |
| pinyin | TEXT | Пиньинь |
| translation | TEXT | Перевод |
| source_type | TEXT | Источник (bkrs/toponym/person/online) |
| saved_date | DATETIME | Дата сохранения |
| last_reviewed | DATETIME | Последнее повторение |
| review_count | INTEGER | Количество повторений |
| notes | TEXT | Заметки пользователя |

**Таблица `daily_stats` (Ежедневная статистика)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| date | TEXT UNIQUE | Дата (YYYY-MM-DD) |
| articles_read | INTEGER | Прочитано статей |
| words_encountered | INTEGER | Встречено слов |
| words_saved | INTEGER | Сохранено слов |
| reading_minutes | INTEGER | Минут чтения |

**Таблица `streak_data` (Ударный режим)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID (всегда 1) |
| current_streak | INTEGER | Текущая серия |
| max_streak | INTEGER | Максимальная серия |
| last_active_date | TEXT | Дата последней активности |

**Таблица `cached_articles` (Кэш статей)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | TEXT PRIMARY KEY | ID статьи |
| title | TEXT | Заголовок |
| content | TEXT | Содержимое |
| url | TEXT | URL оригинала |
| cached_date | DATETIME | Дата кэширования |
| expires_date | DATETIME | Дата истечения |

**Таблица `news_sources` (Источники новостей)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| name | TEXT | Название источника |
| url | TEXT | URL |
| type | TEXT | Тип (html/rss) |
| enabled | INTEGER | 1=активен, 0=отключён |

**Таблица `reading_history` (История чтения)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| file_path | TEXT | Путь к файлу |
| file_name | TEXT | Имя файла |
| file_type | TEXT | Формат |
| last_position | INTEGER | Последняя позиция |
| last_opened | DATETIME | Дата открытия |
| progress_percent | REAL | Прогресс в % |

**Таблица `bookmarks` (Закладки)**
| Поле | Тип | Описание |
|------|-----|----------|
| id | INTEGER PRIMARY KEY | Уникальный ID |
| file_path | TEXT | Путь к файлу |
| position | INTEGER | Позиция закладки |
| note | TEXT | Заметка |
| created_at | DATETIME | Дата создания |

#### 4.2.2 Индексы

```sql
-- Dictionary
CREATE INDEX idx_dictionary_simplified ON dictionary(simplified);
CREATE INDEX idx_dictionary_traditional ON dictionary(traditional);
CREATE INDEX idx_dictionary_pinyin ON dictionary(pinyin);

-- Toponyms
CREATE INDEX idx_toponyms_chinese ON toponyms(chinese);
CREATE INDEX idx_toponyms_pinyin ON toponyms(pinyin);
CREATE INDEX idx_toponyms_type ON toponyms(type);

-- Person names
CREATE INDEX idx_person_names_chinese ON person_names(chinese);

-- User vocabulary
CREATE INDEX idx_user_vocabulary_word ON user_vocabulary(word);

-- Daily stats
CREATE INDEX idx_daily_stats_date ON daily_stats(date);
```

---

## 5. Архитектура приложения

### 5.1 Общая архитектура

Приложение следует принципам **Clean Architecture + MVVM**:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Screens   │  │   Widgets   │  │   State (Riverpod)  │ │
│  │  - News     │  │  - Popup    │  │  - newsFeedProvider │ │
│  │  - Files    │  │  - SegText  │  │  - recentFilesProv. │ │
│  │  - Progress │  │  - NavShell │  │  - progressProvider │ │
│  │  - Settings │  │             │  │                     │ │
│  └─────────────┘  └─────────────┘  └─────────────────────┘ │
│                            │                                │
│                    ┌───────▼───────┐                        │
│                    │  Navigation   │                        │
│                    │  (GoRouter)   │                        │
│                    └───────┬───────┘                        │
└────────────────────────────┼────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                      DOMAIN LAYER                           │
│  ┌──────────────────┐  ┌─────────────────────────────────┐ │
│  │   Use Cases      │  │    Repositories (Interfaces)    │ │
│  │  - LookupWord    │  │  - IDictionaryRepository        │ │
│  │  - SaveWord      │  │  - IFileRepository              │ │
│  │  - GetNews       │  │  - IProgressRepository          │ │
│  │  - OpenFile      │  │  - INewsRepository              │ │
│  │  - GetProgress   │  │                                 │ │
│  └──────────────────┘  └─────────────────────────────────┘ │
│                             │                               │
│  ┌──────────────────────────▼───────────────────────────┐  │
│  │              Domain Models                           │  │
│  │  - NewsArticle, DictionaryResult, LocalFile,         │  │
│  │  - ProgressSummary, VocabularyWord                   │  │
│  └──────────────────────────────────────────────────────┘  │
└────────────────────────────┬────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────┐
│                       DATA LAYER                            │
│  ┌──────────────────┐  ┌─────────────────────────────────┐ │
│  │   Local Data     │  │       Remote Data               │ │
│  │  - SQLite (DB)   │  │  - HTTP (Dio)                   │ │
│  │  - SharedPreferences │  │  - Online BKRS API            │ │
│  └──────────────────┘  └─────────────────────────────────┘ │
│                             │                               │
│  ┌──────────────────────────▼───────────────────────────┐  │
│  │           Repository Implementations                 │  │
│  │  - DictionaryRepositoryImpl                          │  │
│  │  - FileRepositoryImpl                                │  │
│  │  - ProgressRepositoryImpl                            │  │
│  │  - NewsRepositoryImpl                                │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 5.2 Структура проекта

```
lib/
├── main.dart                       # Точка входа, инициализация
│
├── data/                           # Слой данных
│   ├── local/
│   │   ├── database_helper.dart    # SQLite помощник
│   │   └── .gitkeep.dart
│   ├── remote/
│   │   ├── online_dictionary_service.dart  # Онлайн-словарь
│   │   └── news_api_service.dart   # API новостей
│   └── repository/
│       ├── dictionary_repository_impl.dart
│       ├── file_repository_impl.dart
│       ├── progress_repository_impl.dart
│       └── news_repository_impl.dart
│
├── domain/                         # Бизнес-логика
│   ├── model/
│   │   ├── dictionary_models.dart  # DictionaryResult, WordEntry
│   │   ├── news_models.dart        # NewsArticle
│   │   ├── file_models.dart        # LocalFile, FileFormat
│   │   └── progress_models.dart    # ProgressSummary, VocabularyWord
│   ├── repository/
│   │   ├── dictionary_repository.dart  # IDictionaryRepository
│   │   ├── file_repository.dart        # IFileRepository
│   │   ├── progress_repository.dart    # IProgressRepository
│   │   └── news_repository.dart        # INewsRepository
│   └── usecase/
│       ├── lookup_word_usecase.dart
│       ├── save_word_usecase.dart
│       ├── news_usecases.dart
│       ├── file_usecases.dart
│       └── progress_usecases.dart
│
├── presentation/                   # UI слой
│   ├── screens/
│   │   ├── news/
│   │   │   ├── news_screen.dart    # 📰 Лента новостей
│   │   │   └── article_screen.dart # 📄 Чтение статьи
│   │   ├── files/
│   │   │   ├── files_screen.dart   # 📁 Браузер файлов
│   │   │   └── reader_screen.dart  # 📖 Читалка
│   │   ├── progress/
│   │   │   └── progress_screen.dart# 📊 Статистика
│   │   └── settings/
│   │       └── settings_screen.dart# ⚙️ Настройки
│   ├── widgets/
│   │   ├── dictionary_popup.dart   # Всплывающий словарь
│   │   ├── segmented_text_display.dart  # Сегментированный текст
│   │   └── .gitkeep.dart
│   ├── state/
│   │   ├── news_state.dart         # newsFeedProvider
│   │   ├── file_state.dart         # recentFilesProvider
│   │   └── .gitkeep.dart
│   ├── navigation/
│   │   ├── app_router.dart         # GoRouter конфигурация
│   │   └── app_shell.dart          # Navigation Bar
│   └── theme/
│       └── charu_theme.dart        # Light/Dark темы
│
└── di/                             # Dependency Injection
    └── di.dart                     # Провайдеры Riverpod
```

### 5.3 State Management (Riverpod)

#### 5.3.1 Провайдеры

```dart
// Новости
final newsFeedProvider = AsyncNotifierProvider<NewsFeedNotifier, List<NewsArticle>>();
final articleContentProvider = FutureProvider.family<NewsArticle, String>();

// Файлы
final recentFilesProvider = AsyncNotifierProvider<RecentFilesNotifier, List<LocalFile>>();

// Словарь
final lookupWordUseCaseProvider = Provider<LookupWordUseCase>();
final saveWordUseCaseProvider = Provider<SaveWordUseCase>();

// Прогресс
final getProgressSummaryUseCaseProvider = Provider<GetProgressSummaryUseCase>();
final getVocabularyUseCaseProvider = Provider<GetVocabularyUseCase>();

// Репозитории
final dictionaryRepositoryProvider = Provider<IDictionaryRepository>();
final fileRepositoryProvider = Provider<IFileRepository>();
final progressRepositoryProvider = Provider<IProgressRepository>();
final newsRepositoryProvider = Provider<INewsRepository>();

// База данных
final databaseHelperProvider = Provider<DatabaseHelper>();
```

#### 5.3.2 Поток данных

```
┌─────────────────────────────────────────────────────────────┐
│                    UI (NewsScreen)                          │
│                     ref.watch()                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              newsFeedProvider (AsyncNotifier)               │
│                     build() → _fetch()                      │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│            GetLatestNewsUseCase (Domain Layer)              │
│                      call()                                 │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         INewsRepository (Interface, Domain Layer)           │
│                   getLatestNews()                           │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│       NewsRepositoryImpl (Data Layer, Implementation)       │
│                   Mock / HTTP запрос                        │
└─────────────────────────────────────────────────────────────┘
```

---

## 6. Навигация

### 6.1 Маршруты

```dart
final GoRouter appRouter = GoRouter(
  initialLocation: '/news',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/news', ...),           // 📰 Новости
        GoRoute(path: '/files', ..., routes: [ // 📁 Файлы
          GoRoute(path: 'reader', ...)         // 📖 Читалка
        ]),
        GoRoute(path: '/progress', ...),       // 📊 Прогресс
        GoRoute(path: '/settings', ...),       // ⚙️ Настройки
      ],
    ),
  ],
);
```

### 6.2 Навигационная оболочка (AppShell)

```
┌─────────────────────────────────────┐
│           AppBar                    │
│  (Заголовок меняется по экрану)     │
├─────────────────────────────────────┤
│                                     │
│           Контент экрана            │
│         (NewsScreen, etc.)          │
│                                     │
├─────────────────────────────────────┤
│    NavigationBar (Bottom)           │
│  ┌──────┬──────┬──────┬──────┐     │
│  │ 📰   │ 📁   │ 📊   │ ⚙️   │     │
│  │Новости│Файлы│Прогр│Настр│     │
│  └──────┴──────┴──────┴──────┘     │
└─────────────────────────────────────┘
```

---

## 7. Дизайн-система

### 7.1 Liquid Glass Theme

**Принципы:**
1. **Плотные фоны** для текстовых областей (читаемость CJK)
2. **Blur-эффекты** для декоративных элементов
3. **Material 3** с кастомной темой
4. **Адаптивность** под светлую/тёмную тему

### 7.2 Цветовая палитра

**Light Theme:**
```dart
Background:    #F8F9FA
Surface:       #FFFFFF
Text:          #1A1A1A
Accent:        #FF6B6B (коралловый красный)
```

**Dark Theme:**
```dart
Background:    #1A1D23 (тёмно-серый)
Surface:       #252830
Text:          #E8E8E8
Accent:        #FF8585 (светло-коралловый)
```

### 7.3 Типографика

```dart
family: 'Roboto'           // Латиница
cjkMinFontSize: 18.0       // Минимальный размер для CJK
bodyFontSize: 18.0         // Основной текст
titleFontSize: 20.0        // Заголовки
displayFontSize: 28.0      // Крупные заголовки
```

---

## 8. Технологический стек

| Компонент | Технология | Версия | Назначение |
|-----------|------------|--------|------------|
| **Фреймворк** | Flutter | 3.41.2 | Кроссплатформенная разработка |
| **Язык** | Dart | 3.11.0 | Основной язык |
| **State Management** | Riverpod | 2.6.1 | Управление состоянием |
| **Навигация** | GoRouter | 14.8.1 | Декларативная навигация |
| **База данных** | SQLite (sqflite) | 2.4.2 | Локальное хранение |
| **Сеть** | Dio | 5.8.0+1 | HTTP-запросы |
| **Сегментация** | Jieba Flutter | 0.2.0 | Китайский NLP |
| **HTML Parsing** | html | 0.15.5 | Парсинг HTML/XML |
| **Файлы** | file_picker | 8.3.7 | Выбор файлов |
| **Кодировки** | flutter_charset_detector | 5.0.0 | Определение кодировки |
| **Кэш изображений** | cached_network_image | 3.4.1 | Кэширование картинок |
| **Локальное хранилище** | shared_preferences | 2.5.3 | Настройки |
| **UI** | flutter_svg | 2.0.17 | SVG графика |
| **UI** | shimmer | 3.0.0 | Эффект загрузки |

---

## 9. Ограничения и известные проблемы

### 9.1 Web-версия

| Проблема | Причина | Решение |
|----------|---------|---------|
| sqflite не работает | SQLite не поддерживается в браузере | In-memory словарь для демо |
| Jieba не работает | Нативный пакет для Android/iOS | Простая сегментация (2 символа) |
| File picker ограничен | Безопасность браузера | Только демо-режим |

### 9.2 Мобильная версия

| Проблема | Статус |
|----------|--------|
| Онлайн-БКРС требует сети | Требуется реализация проверки подключения |
| EPUB парсинг | Отложен до v0.2.0 |
| Синхронизация между устройствами | Отложена до v0.3.0 |

---

## 10. Roadmap

### v0.1.0 (MVP) — ✅ Готово
- [x] Чтение новостей с сегментацией
- [x] 5-уровневый словарь (офлайн)
- [x] Чтение TXT файлов
- [x] Ударный режим
- [x] Статистика

### v0.2.0 — В разработке
- [ ] Чтение EPUB
- [ ] Парсинг реальных новостей
- [ ] Система повторений слов (SRS)
- [ ] Экспорт словаря в Anki/CSV

### v0.3.0 — Планируется
- [ ] Синхронизация между устройствами
- [ ] Веб-версия с полной функциональностью
- [ ] Темы оформления (пользовательские)
- [ ] Жесты (свайпы для навигации)

### v1.0.0 — Релиз
- [ ] Полный БКРС (250k+ записей)
- [ ] Офлайн-режим (полностью)
- [ ] Публикация в Google Play / App Store

---

## 11. Приложения

### Приложение A: Модель данных (полная)

```dart
// dictionary_models.dart
class DictionaryResult {
  final String chineseWord;
  final String pinyin;
  final String translation;
  final String source;        // bkrs/toponym/person/online/fallback
  final String? icon;         // 🗺️/👤/🌐/❓
  final Map<String, dynamic>? metadata;
}

class WordEntry {
  final int id;
  final String simplified;
  final String? traditional;
  final String pinyin;
  final String translation;
  final String? examples;
}

class ToponymEntry {
  final int id;
  final String chinese;
  final String pinyin;
  final String english;
  final String type;
  final double? latitude;
  final double? longitude;
}

class PersonNameEntry {
  final int id;
  final String chinese;
  final String pinyin;
  final bool isSurname;
  final String? gender;
}
```

### Приложение B: Use Cases (полный список)

```dart
// Словарь
- LookupWordUseCase
- SaveWordUseCase

// Новости
- GetLatestNewsUseCase
- FetchArticleContentUseCase

// Файлы
- OpenFileUseCase
- ReadFileContentUseCase
- GetRecentFilesUseCase
- SaveReadingPositionUseCase

// Прогресс
- GetProgressSummaryUseCase
- GetTodayStatsUseCase
- GetStreakDataUseCase
- UpdateStreakUseCase
- GetVocabularyUseCase
- GetStatsForRangeUseCase
```

---

**Конец документа**
