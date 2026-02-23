---
name: dictionary_query
description: Instructions for resolving Chinese words through the 5-layer cascade dictionary system.
---

# Dictionary Query Fallback Protocol

When building the dictionary service layer for CHARU, you MUST implement the following strict 5-level lookup cascade for any Chinese word tapped by the user.

## Pre-requisites
- Ensure the selected sentence has been correctly segmented using `Jieba`.
- Capture the entire segmented word (not just single characters unless the word is 1 char).

## Implementation Cascade Steps

### 1. Local BKRS (Offline) primary lookup
Search the local SQLite database (~250k records).
- **If found**: return Russian translation.
- **If NOT found**: proceed to Step 2.

### 2. Toponym Base (Offline) lookup
Search OSM/GNS geographic data (~100k records).
- **If found**: return Map Icon [🗺️], Pinyin, location name in Russian/English, and metadata (type, lat/long).
- **If NOT found**: proceed to Step 3.

### 3. Person Names (Offline) lookup
Search personal names database (~20k records).
- **If found**: return Profile Icon [👤] and Pinyin (predicting Name and Surname structure).
- **If NOT found**: proceed to Step 4.

### 4. Online Grand BKRS (bkrs.info)
Check device network state (online/offline).
- **If ONLINE & found**: return Russian translation, Pinyin, and Web Icon [🌐].
- **If OFFLINE** or **NOT found**: proceed to Step 5.

### 5. Pinyin Character Fallback
This is the ultimate fallback to avoid returning nothing.
- Split the word into individual characters.
- Look up the Pinyin for each character individually.
- Provide the Pinyin row with a Question Mark Icon [❓] to indicate no translation is available.
