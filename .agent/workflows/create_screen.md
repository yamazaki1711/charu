---
description: How to create a new screen in CHARU following MVVM and Clean Architecture
---

# Workflow: Create a New Screen

Follow these steps when creating a new screen for CHARU in Flutter. Do not skip the separated architecture layers.

### 1. Define the Domain Layer
- Create `Model` definition in `lib/domain/model/`.
- Create the repository interface in `lib/domain/repository/`.
- Implement necessary use-cases in `lib/domain/usecase/`. Use-cases must not import anything from `presentation` or `data` layers.

### 2. Define the Data Layer
- Implement the required repositories in `lib/data/repository/` that conform to the interface defined in `domain`.
- Handle interactions with offline (SQLite/Drift) data structures in `lib/data/local/` or online (HTTP/Dio) in `lib/data/remote/`.

### 3. Implement State Management
- Define Screen State models in `lib/presentation/state/`.
- Create a ViewModel or Notifier (using Riverpod or Bloc) mapped strictly to the domain Use-cases.

### 4. Build the Presentation Layer
- Base the raw layout on Liquid Glass style guidelines. (See project rules or `stitch_ui_design` skill).
- Create Widgets under `lib/presentation/screens/<feature_name>/`.
- Ensure presentation layer only depends on the generated State models and ViewModel instances for interaction. Data fetching logic is not allowed here.

### 5. Dependency Injection
- Register the new repository, use-case, and viewmodel in your `lib/di/` configuration (e.g., GetIt or Provider scopes) to complete wiring.
