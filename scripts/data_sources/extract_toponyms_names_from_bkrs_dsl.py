#!/usr/bin/env python3
"""
Извлекает топонимы и личные имена из официального дампа 大БКРС, чтобы
заполнить таблицы `toponyms` и `person_names` реальными данными вместо
демо-заглушек (было 8 и 10 строк).

Источник: официальная страница загрузок bkrs.info/p47 — ежедневный дамп
словаря в формате DSL (Lingvo/GoldenDict), например:
    https://bkrs.info/downloads/daily/dabkrs_YYMMDD.gz
Это тот же способ, которым изначально был собран основной `dictionary`
(см. scripts/parse_dsl.dart) — тот скрипт выбрасывал все пометы в [...]
как мусор; этот скрипт, наоборот, использует их для классификации.

Метод: в DSL-пометах [p]...[/p] и глоссах встречаются структурные маркеры:
  - [p]г.[/p], [p]ист., г.[/p], [p]г. и уезд[/p]  -> топоним (город)
  - "(фамилия)" / "фамилия, имя" и т.п.            -> личное имя (фамилия)
  - "(имя собственное)" / "личное имя" (без "фамилия") -> личное имя (не фамилия)

Важно: тег [p]topo.[/p] (771 вхождение в дампе) — это НЕ топоним, а помета
"тополект" (диалектизм, topolect); сюда он намеренно не включён — на
первой версии скрипта он давал сотни ложных срабатываний вида
"打花胡哨儿 -> топоним" (это разговорное выражение, не город).

Известное ограничение: ~99% извлечённых топонимов/имён уже присутствуют
и в основном `dictionary` (тот же первоисточник), так что 5-уровневый
каскад поиска чаще всего ответит на этапе 1 (локальный БКРС), не доходя
до этих таблиц. Тем не менее эти таблицы перестают быть пустыми
демо-заглушками и дают честные метаданные (type/is_surname) для тех
~0.5% слов, которых в основном словаре нет.

Результат (дамп от 2026-10-15): 548 топонимов, 58 950 личных имён.

Использование:
    python3 extract_toponyms_names_from_bkrs_dsl.py /path/to/dabkrs_dump
Пишет TSV-файлы toponyms.tsv / person_names.tsv рядом со входным файлом;
дальнейшая загрузка в assets/db/charu_bkrs.db — отдельным шагом (см. README
этой директории или просто INSERT из TSV через sqlite3 CLI).
"""
import re
import sys
import os

TAG_RE = re.compile(r"\[[^\]]*\]")
TOPONYM_P_RE = re.compile(r"\[p\](г\.|ист\., г\.|г\. и уезд)\[/p\]")
SURNAME_RE = re.compile(r"\(фамилия\)|фамилия,\s*имя|имя,\s*фамилия|личное имя,\s*фамилия")
GIVEN_NAME_RE = re.compile(r"\(имя собственное\)|личное имя(?!,\s*фамилия)")
PINYIN_CHARS_RE = re.compile(r"^[a-zA-Zāáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜńň'’\s,./]+$")

TOPONYM_TYPE_LABELS = {
    "г.": "город",
    "ист., г.": "ист. город",
    "г. и уезд": "город и уезд",
}


def clean(text):
    out = TAG_RE.sub("", text)
    return re.sub(r"\s+", " ", out).strip()


def is_chinese_start(s):
    if not s:
        return False
    cp = ord(s[0])
    return (0x4E00 <= cp <= 0x9FFF) or (0x3400 <= cp <= 0x4DBF)


def extract(src_path):
    word = None
    pinyin = None
    seen_toponym = set()
    seen_name = set()
    toponyms = []
    names = []

    with open(src_path, encoding="utf-8-sig") as f:
        for line in f:
            line = line.rstrip("\n")
            if line == "" or line.startswith("#"):
                continue
            stripped = line.strip()
            starts_indented = line[:1] in (" ", "\t")

            if not starts_indented and is_chinese_start(stripped):
                word = stripped.split()[0]
                pinyin = None
                continue

            if word is None:
                continue

            if pinyin is None and PINYIN_CHARS_RE.match(stripped) and re.search(r"[a-zA-Z]", stripped):
                pinyin = stripped
                continue

            m = TOPONYM_P_RE.search(stripped)
            if m and word not in seen_toponym:
                seen_toponym.add(word)
                ttype = TOPONYM_TYPE_LABELS.get(m.group(1), "город")
                toponyms.append((word, pinyin or "", clean(stripped), ttype))

            if word not in seen_name:
                if SURNAME_RE.search(stripped):
                    seen_name.add(word)
                    names.append((word, pinyin or "", 1, clean(stripped)))
                elif GIVEN_NAME_RE.search(stripped):
                    seen_name.add(word)
                    names.append((word, pinyin or "", 0, clean(stripped)))

    return toponyms, names


def main():
    if len(sys.argv) != 2:
        print("Usage: extract_toponyms_names_from_bkrs_dsl.py <path-to-dabkrs-dump>")
        sys.exit(1)

    src = sys.argv[1]
    out_dir = os.path.dirname(os.path.abspath(src))
    toponyms, names = extract(src)

    with open(os.path.join(out_dir, "toponyms.tsv"), "w", encoding="utf-8") as f:
        for row in toponyms:
            f.write("\t".join(row) + "\n")
    with open(os.path.join(out_dir, "person_names.tsv"), "w", encoding="utf-8") as f:
        for row in names:
            f.write("\t".join(str(x) for x in row) + "\n")

    print(f"Toponyms: {len(toponyms)}")
    print(f"Person names: {len(names)}")


if __name__ == "__main__":
    main()
