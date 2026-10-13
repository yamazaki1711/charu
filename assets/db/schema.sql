-- CHARU Dictionary Database Schema
-- Версия: 1.0
-- Описание: Основная структура БД для словарей (БКРС, топонимы, имена)

-- ============================================================================
-- 1. ОСНОВНОЙ СЛОВАРЬ БКРС (~250k записей офлайн)
-- ============================================================================
CREATE TABLE IF NOT EXISTS dictionary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    simplified TEXT NOT NULL,           -- Упрощённое написание
    traditional TEXT,                    -- Традиционное написание (опционально)
    pinyin TEXT NOT NULL,                -- Пиньинь с тонами
    translation TEXT NOT NULL,           -- Перевод на русский
    examples TEXT,                       -- Примеры использования
    frequency INTEGER DEFAULT 0,         -- Частотность слова (опционально)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для быстрого поиска
CREATE INDEX IF NOT EXISTS idx_dictionary_simplified ON dictionary(simplified);
CREATE INDEX IF NOT EXISTS idx_dictionary_traditional ON dictionary(traditional);
CREATE INDEX IF NOT EXISTS idx_dictionary_pinyin ON dictionary(pinyin);

-- ============================================================================
-- 2. БАЗА ТОПОНИМОВ (географические названия, ~100k записей)
-- ============================================================================
CREATE TABLE IF NOT EXISTS toponyms (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chinese TEXT NOT NULL,               -- Китайское название
    pinyin TEXT NOT NULL,                -- Пиньинь
    english TEXT NOT NULL,               -- Английское название
    type TEXT NOT NULL,                  -- Тип объекта (город, река, гора...)
    latitude REAL,                       -- Широта
    longitude REAL,                      -- Долгота
    country TEXT,                        -- Страна
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для поиска
CREATE INDEX IF NOT EXISTS idx_toponyms_chinese ON toponyms(chinese);
CREATE INDEX IF NOT EXISTS idx_toponyms_pinyin ON toponyms(pinyin);
CREATE INDEX IF NOT EXISTS idx_toponyms_type ON toponyms(type);

-- ============================================================================
-- 3. БАЗА ЛИЧНЫХ ИМЁН (~20k записей)
-- ============================================================================
CREATE TABLE IF NOT EXISTS person_names (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    chinese TEXT NOT NULL,               -- Иероглифическое написание
    pinyin TEXT NOT NULL,                -- Пиньинь
    is_surname INTEGER DEFAULT 0,        -- 1 = фамилия, 0 = имя
    gender TEXT,                         -- 'M', 'F', 'U' (unknown)
    meaning TEXT,                        -- Значение имени (опционально)
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для поиска
CREATE INDEX IF NOT EXISTS idx_person_names_chinese ON person_names(chinese);
CREATE INDEX IF NOT EXISTS idx_person_names_pinyin ON person_names(pinyin);
CREATE INDEX IF NOT EXISTS idx_person_names_surname ON person_names(is_surname);

-- ============================================================================
-- 4. ПОЛЬЗОВАТЕЛЬСКИЙ СЛОВАРЬ (сохранённые слова)
-- ============================================================================
CREATE TABLE IF NOT EXISTS user_vocabulary (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT NOT NULL,                  -- Китайское слово
    pinyin TEXT NOT NULL,                -- Пиньинь
    translation TEXT NOT NULL,           -- Перевод
    source_type TEXT NOT NULL,           -- Источник: 'bkrs', 'toponym', 'person', 'online'
    saved_date DATETIME NOT NULL,        -- Дата сохранения
    last_reviewed DATETIME,              -- Последнее повторение
    review_count INTEGER DEFAULT 0,      -- Количество повторений
    notes TEXT,                          -- Пользовательские заметки
    UNIQUE(word, source_type)            -- Уникальность пары слово+источник
);

-- Индексы для быстрого доступа
CREATE INDEX IF NOT EXISTS idx_user_vocabulary_word ON user_vocabulary(word);
CREATE INDEX IF NOT EXISTS idx_user_vocabulary_saved ON user_vocabulary(saved_date);
CREATE INDEX IF NOT EXISTS idx_user_vocabulary_review ON user_vocabulary(last_reviewed);

-- ============================================================================
-- 5. ЕЖЕДНЕВНАЯ СТАТИСТИКА (для геймификации)
-- ============================================================================
CREATE TABLE IF NOT EXISTS daily_stats (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL UNIQUE,           -- Дата в формате YYYY-MM-DD
    articles_read INTEGER DEFAULT 0,     -- Прочитано статей
    words_encountered INTEGER DEFAULT 0, -- Встречено слов
    words_saved INTEGER DEFAULT 0,       -- Сохранено слов
    reading_minutes INTEGER DEFAULT 0,   -- Минут чтения
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Индекс для поиска по дате
CREATE INDEX IF NOT EXISTS idx_daily_stats_date ON daily_stats(date);

-- ============================================================================
-- 6. УДАРНЫЙ РЕЖИМ (streak data)
-- ============================================================================
CREATE TABLE IF NOT EXISTS streak_data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    current_streak INTEGER DEFAULT 0,    -- Текущая серия дней
    max_streak INTEGER DEFAULT 0,        -- Максимальная серия
    last_active_date TEXT,               -- Дата последней активности (YYYY-MM-DD)
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Инициализация первой записи
INSERT INTO streak_data (id, current_streak, max_streak, last_active_date, updated_at)
VALUES (1, 0, 0, NULL, CURRENT_TIMESTAMP);

-- ============================================================================
-- 7. КЭШИРОВАННЫЕ СТАТЬИ (для offline-режима новостей)
-- ============================================================================
CREATE TABLE IF NOT EXISTS cached_articles (
    id TEXT PRIMARY KEY,                 -- Уникальный ID статьи
    source_id INTEGER,                   -- ID источника
    title TEXT NOT NULL,                 -- Заголовок
    content TEXT,                        -- Полный текст статьи
    url TEXT,                            -- Оригинальная ссылка
    summary TEXT,                        -- Краткое описание
    thumbnail_url TEXT,                  -- URL обложки
    cached_date DATETIME NOT NULL,       -- Дата кэширования
    expires_date DATETIME,               -- Дата истечения кэша
    is_pinned INTEGER DEFAULT 0,         -- Закреплённая статья (1 = не удалять автоматически)
    cache_type TEXT DEFAULT 'auto',      -- 'auto' или 'manual'
    read_position INTEGER DEFAULT 0,     -- Позиция последнего чтения
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Индексы для поиска
CREATE INDEX IF NOT EXISTS idx_cached_articles_date ON cached_articles(cached_date);
CREATE INDEX IF NOT EXISTS idx_cached_articles_pinned ON cached_articles(is_pinned);
CREATE INDEX IF NOT EXISTS idx_cached_articles_source ON cached_articles(source_id);

-- ============================================================================
-- 8. ИСТОЧНИКИ НОВОСТЕЙ
-- ============================================================================
CREATE TABLE IF NOT EXISTS news_sources (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,                  -- Название источника
    url TEXT NOT NULL,                   -- Базовый URL
    type TEXT DEFAULT 'rss',             -- Тип: 'rss', 'html', 'api'
    enabled INTEGER DEFAULT 1,           -- Активен ли источник
    last_updated DATETIME,               -- Последнее обновление
    icon_url TEXT,                       -- URL иконки источника
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Добавление встроенных источников по умолчанию.
-- Baidu/Sina/People's Daily — тестовые (enabled = 0); рабочий источник: 中国生活.
INSERT INTO news_sources (id, name, url, type, enabled) VALUES
    (1, 'Baidu Baijiahao', 'https://baijiahao.baidu.com', 'html', 0),
    (2, 'Sina News', 'https://news.sina.com.cn', 'rss', 0),
    (3, "People's Daily", 'http://en.people.cn', 'rss', 0),
    (4, '中国生活', 'https://www.chinanews.com.cn/rss/life.xml', 'rss', 1);

-- ============================================================================
-- 9. ИСТОРИЯ ЧТЕНИЯ ФАЙЛОВ
-- ============================================================================
CREATE TABLE IF NOT EXISTS reading_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,             -- Путь к файлу
    file_name TEXT NOT NULL,             -- Имя файла
    file_type TEXT NOT NULL,             -- Тип: 'txt', 'html', 'epub'
    last_position INTEGER DEFAULT 0,     -- Последняя позиция чтения
    last_opened DATETIME NOT NULL,       -- Дата последнего открытия
    progress_percent REAL DEFAULT 0,     -- Прогресс в процентах
    total_length INTEGER DEFAULT 0,      -- Общая длина текста
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_reading_history_path ON reading_history(file_path);
CREATE INDEX IF NOT EXISTS idx_reading_history_opened ON reading_history(last_opened);

-- ============================================================================
-- 10. ЗАКЛАДКИ
-- ============================================================================
CREATE TABLE IF NOT EXISTS bookmarks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    file_path TEXT NOT NULL,             -- Путь к файлу
    position INTEGER NOT NULL,           -- Позиция закладки
    note TEXT,                           -- Заметка к закладке
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Индексы
CREATE INDEX IF NOT EXISTS idx_bookmarks_path ON bookmarks(file_path);
CREATE INDEX IF NOT EXISTS idx_bookmarks_position ON bookmarks(position);

-- ============================================================================
-- TRIGGER: Обновление updated_at при изменении записей
-- ============================================================================

-- Для daily_stats
CREATE TRIGGER IF NOT EXISTS update_daily_stats_updated_at
AFTER UPDATE ON daily_stats
BEGIN
    UPDATE daily_stats SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- Для streak_data
CREATE TRIGGER IF NOT EXISTS update_streak_data_updated_at
AFTER UPDATE ON streak_data
BEGIN
    UPDATE streak_data SET updated_at = CURRENT_TIMESTAMP WHERE id = NEW.id;
END;

-- ============================================================================
-- ПРЕДСТАВЛЕНИЯ (VIEWS) для удобных запросов
-- ============================================================================

-- Представление: общая статистика пользователя
CREATE VIEW IF NOT EXISTS user_stats_summary AS
SELECT
    (SELECT COUNT(*) FROM user_vocabulary) AS total_words_saved,
    (SELECT COALESCE(SUM(articles_read), 0) FROM daily_stats) AS total_articles_read,
    (SELECT COALESCE(SUM(reading_minutes), 0) FROM daily_stats) AS total_reading_minutes,
    (SELECT current_streak FROM streak_data LIMIT 1) AS current_streak,
    (SELECT max_streak FROM streak_data LIMIT 1) AS max_streak;

-- Представление: последние сохранённые слова
CREATE VIEW IF NOT EXISTS recent_vocabulary AS
SELECT word, pinyin, translation, saved_date
FROM user_vocabulary
ORDER BY saved_date DESC
LIMIT 20;

-- ============================================================================
-- Конец схемы БД
-- ============================================================================
