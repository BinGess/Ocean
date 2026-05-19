# From Sarah Tab Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current Insights tab experience with a Sarah letter inbox that shows welcome, weekly, and legacy letters in reverse chronological order.

**Architecture:** Add a Sarah Letter domain layer alongside the existing insight/report layer instead of mutating `InsightReport` into a letter model. Reuse existing weekly report cache as the source for legacy migration, store letters locally for fast rendering, sync them to the service backend as the source of truth, and rebuild the tab UI as an inbox-style letter feed. The mobile client must not hold the Coze token or call Coze directly; weekly letter generation is requested from the service backend, which owns Coze credentials and generation rules.

**Tech Stack:** Flutter, Dart, flutter_bloc, Hive, Dio, freezed/json_serializable, flutter_test

---

## Product Interpretation

- The tab is no longer a dashboard; it is Sarah's mailbox.
- The primary artifact is a letter, not an analytical report.
- Existing weekly insight reports remain useful only as migration input.
- The visual direction is warm paper, editorial title typography, quiet companionship, and hand-drawn Sarah illustrations.
- Errors from AI generation should stay silent in the user-facing UI.

## Confirmed Product/Architecture Decisions

- [x] Remove the old Insights tab entry; do not keep a visible legacy insight entrance.
- [x] Convert existing weekly report data into Sarah letters during migration.
- [x] Sarah letters must sync and be stored on the service backend.
- [x] Store Sarah illustration assets at `assets/images/sarah/`.
- [x] Defer Playfair Display bundling for now; use existing serif typography/fallbacks until a later polish pass.
- [x] Coze token belongs in service backend configuration, not local app config; the backend should initiate Coze requests.

## Backend Contract Needed

The Flutter app needs service APIs before the weekly generation flow can be fully implemented:

- `GET /sarah/letters`: returns all visible Sarah letters for the current account, sorted by date descending.
- `POST /sarah/letters/welcome`: idempotently creates or returns the one-time Welcome Letter.
- `POST /sarah/letters/migrate-legacy`: idempotently converts legacy weekly reports into Sarah letters, or accepts client-uploaded legacy report snapshots if the backend does not already store old reports.
- `POST /sarah/letters/generate-weekly`: backend checks Sunday timing, record count, duplicate week, calls Coze with server-side token, stores the generated letter, and returns it.
- `PATCH /sarah/letters/{id}`: updates `isRead` and any lightweight client-owned state.
- Sync payload should include `id`, `type`, `createdAt`, `weekStart`, `weekEnd`, `content`, `previewText`, `illustrationIndex`, `isRead`, `updatedAt`, and a deletion/tombstone strategy if deletes are later supported.

## Client Sync / Export Decision

- Sarah letters sync through the dedicated Sarah backend APIs (`/sarah/letters...`), not through the generic Ocean snapshot sync payload in this iteration.
- iCloud sync remains disabled for Sarah letters; the service backend is the cross-device source of truth.
- Existing export continues to export legacy insight reports/NVC insight data for now. Sarah letter export is intentionally deferred until product copy and privacy expectations are defined.
- Old insight report screens/share code may remain in the codebase as migration/export support, but no visible bottom-tab or Sarah-page entrance should point to them.

## Data Model And Storage

### Task 1: Add Sarah letter entity and type coverage

**Files:**
- Create: `lib/domain/entities/sarah_letter.dart`
- Create: `test/domain/entities/sarah_letter_test.dart`

- [x] Add `SarahLetter` with fields from the spec: `id`, `type`, `createdAt`, `weekStart`, `weekEnd`, `content`, `previewText`, `illustrationIndex`, `isRead`.
- [x] Represent `LetterType` as `weekly`, `welcome`, `legacy`.
- [x] Add helper getters for date display, week-range display, and collapsed preview generation.
- [x] Unit test preview extraction, date sorting, optional week dates for welcome letter, and type serialization if using `freezed`.

### Task 2: Add local persistence

**Files:**
- Create: `lib/data/models/sarah_letter_model.dart`
- Modify: `lib/data/datasources/local/hive_database.dart`
- Modify: `lib/core/services/ocean_account_cache_service.dart`
- Modify: `lib/core/services/ocean_sync_service.dart`
- Test: `test/data/models/sarah_letter_model_test.dart`

- [x] Add a `sarah_letters` Hive box.
- [x] Register a new Hive adapter with a safe unused type id.
- [x] Map between `SarahLetter` and `SarahLetterModel`.
- [x] Include Sarah letters in account cache clearing rules.
- [ ] Include Sarah letters in service sync import/export once backend payloads exist.
- [x] Add tests for model round-trip and box initialization assumptions where practical.

### Task 3: Add repository and use cases

**Files:**
- Create: `lib/domain/repositories/sarah_letter_repository.dart`
- Create: `lib/data/repositories/sarah_letter_repository_impl.dart`
- Create: `lib/data/datasources/remote/sarah_letter_remote_datasource.dart`
- Create: `lib/domain/usecases/get_sarah_letters_usecase.dart`
- Create: `lib/domain/usecases/mark_sarah_letter_read_usecase.dart`
- Create: `lib/domain/usecases/ensure_welcome_letter_usecase.dart`
- Modify: `lib/core/di/injection.dart`

- [ ] Implement list, get by week/type, create, update read state, count unread, and count total.
- [x] `ensureWelcomeLetter` calls the backend's idempotent welcome endpoint when signed in, then caches the result locally.
- [ ] Support local fallback only for unauthenticated/offline app state if the current product flow permits it; otherwise require account context for Sarah letters.
- [ ] Generate deterministic `previewText` and random `illustrationIndex` in the creation path.
- [x] Register repository/use cases in GetIt.

## AI Generation And Migration

### Task 4: Add Sarah weekly letter generation

**Files:**
- Create: `lib/domain/usecases/generate_sarah_weekly_letter_usecase.dart`
- Create or modify: `lib/core/network/ocean_api_client.dart`
- Create or modify: `lib/data/datasources/remote/sarah_letter_remote_datasource.dart`
- Test: `test/domain/usecases/generate_sarah_weekly_letter_usecase_test.dart`

- [x] Client requests weekly generation from the service backend; it must not call Coze directly.
- [ ] Backend owns eligibility checks: Sunday timing, target week record count >= 3, and one weekly letter per week.
- [ ] Backend owns Coze request shape, token, project id, parser, retry policy, and persistence.
- [x] Client sends only the minimum needed request context, preferably target week/date range; do not upload token or prompt credentials.
- [ ] On backend generation failure, client keeps the existing letter list and surfaces no user-facing error.
- [ ] Unit test success, insufficient records/no-op response, duplicate week/idempotent response, offline/backend failure, and silent failure behavior.

### Task 5: Add legacy migration

**Files:**
- Create: `lib/domain/usecases/migrate_legacy_insights_to_sarah_letters_usecase.dart`
- Create or modify: `lib/data/datasources/remote/sarah_letter_remote_datasource.dart`
- Modify: `lib/data/repositories/insight_repository_impl.dart` only if extra read helpers are needed
- Test: `test/domain/usecases/migrate_legacy_insights_to_sarah_letters_usecase_test.dart`

- [ ] Read existing `InsightReportCache` items from `insightReportsBox`.
- [ ] For each old weekly report, create one `legacy` letter using the report's week date.
- [ ] Keep only `emotionOverview.summary` and `patternHypothesis.text`.
- [ ] Drop high-frequency situations and action suggestions.
- [ ] Skip reports that have neither emotion overview nor potential need text.
- [x] Push migrated letters to the service backend and cache the backend-confirmed versions locally.
- [ ] Make migration idempotent with both a local migration version key in `settingsBox` and backend idempotency keyed by legacy week/report id.

## State Management

### Task 6: Add Sarah bloc/state/events

**Files:**
- Create: `lib/presentation/bloc/sarah/sarah_bloc.dart`
- Create: `lib/presentation/bloc/sarah/sarah_event.dart`
- Create: `lib/presentation/bloc/sarah/sarah_state.dart`
- Modify: `lib/core/di/injection.dart`
- Test: `test/presentation/bloc/sarah/sarah_bloc_test.dart`

- [x] State should expose `letters`, `weeklyLetter`, `pastLetters`, `totalCount`, `unreadCount`, `status`, and optional `expandedLetterIds` if expansion is state-owned.
- [x] On tab load: sync letters from backend, ensure welcome letter, run legacy migration once, request weekly generation if due/eligible, then reload letters.
- [x] Mark a letter read when opened or fully expanded.
- [ ] Keep multiple past letters independently expandable.
- [x] Test welcome creation, migration call order, weekly eligibility, unread handling, and list ordering.

### Task 7: Decide weekly trigger timing

**Files:**
- Modify: `lib/presentation/bloc/sarah/sarah_bloc.dart`
- Or create: `lib/core/services/sarah_letter_scheduler.dart`

- [ ] For V1, client can request a backend weekly-generation check when Sarah tab opens and app data changes; backend remains authoritative.
- [ ] Store last checked week/date locally to avoid repeated client calls on the same Sunday, while backend still enforces duplicate protection.
- [ ] Treat "not enough records" as no letter and no backfill.
- [ ] Consider moving Sunday generation fully backend-side later, so users can receive letters without opening the tab.

## UI Implementation

### Task 8: Replace tab label and unread dot

**Files:**
- Modify: `lib/main.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify generated localization file if this project does not run codegen automatically

- [x] Change tab label from `洞察`/`Insights` to `Sarah`.
- [x] Use `Icons.auto_awesome` / outlined variant for sparkles.
- [x] Apply active color `#8a7655` and inactive color `#c0b8ac` for this nav set or update theme constants if global.
- [x] Show a small red/orange dot on the Sarah tab when unread letters exist, especially first welcome letter.

### Task 9: Build Sarah screen shell

**Files:**
- Replace or heavily modify: `lib/presentation/screens/insights/insights_screen.dart`
- Or create: `lib/presentation/screens/sarah/sarah_screen.dart` and update `lib/main.dart`
- Create: `lib/presentation/widgets/sarah/sarah_section_header.dart`

- [x] Use page background `#f5f0e8`.
- [x] Header: `From Sarah`, `Stay with you`, right-side `共 N 封信`.
- [ ] Use Playfair Display for title/subtitle when font assets are available; otherwise add a named typography style that can swap later.
- [x] Hide "本周来信" when current week has no generated letter.
- [x] Hide "往期信件" when there are no past letters.
- [x] Empty history should still show welcome letter only.

### Task 10: Build paper letter components

**Files:**
- Create: `lib/presentation/widgets/sarah/sarah_letter_paper.dart`
- Create: `lib/presentation/widgets/sarah/current_week_letter_card.dart`
- Create: `lib/presentation/widgets/sarah/past_letter_tile.dart`
- Create: `lib/presentation/widgets/sarah/sarah_illustration.dart`
- Test: `test/presentation/widgets/sarah_letter_paper_test.dart`

- [x] Implement paper background: white base, top torn texture, horizontal ruled lines at 26px, left red margin line, bottom fold/shadow.
- [x] Current weekly letter collapsed state shows about 3 lines with a fade mask and no signature.
- [x] Expanded state shows full body and signature; button toggles `查看全部` / `收起`.
- [x] Past letter collapsed state shows date, first-sentence preview, and `展开`.
- [x] Tapping a past letter anywhere expands it; multiple expanded letters can coexist.
- [x] Render unread dot in the letter's top-right corner until read.
- [ ] Float Sarah illustration at top-right and allow text to wrap visually around it. If Flutter rich text wrapping is too constrained, approximate with a right-aligned overlay plus top padding.

### Task 11: Add illustration assets

**Files:**
- Add: `assets/images/sarah/sarah_01.png` through `assets/images/sarah/sarah_20.png`
- Modify: `pubspec.yaml`

- [ ] Add all 20 transparent PNGs.
- [ ] Add `assets/images/sarah/` to `pubspec.yaml`.
- [ ] `SarahIllustration` should clamp or wrap invalid indexes into 1-20.
- [ ] Add a fallback line-art placeholder only for debug/dev missing assets.

## Compatibility And Existing Feature Cleanup

### Task 12: Preserve export/sync behavior intentionally

**Files:**
- Review: `lib/core/services/export_formatter.dart`
- Review: `lib/core/services/icloud_sync_service.dart`
- Review: `lib/core/services/ocean_sync_service.dart`

- [x] Decide whether exported "洞察报告" remains old reports or changes to Sarah letters.
- [ ] Extend backend sync payloads and conflict rules for Sarah letters.
- [x] Decide whether iCloud sync mirrors Sarah letters, or whether service backend is the only cross-device source of truth.
- [ ] Ensure read state updates sync promptly enough for the Sarah tab unread dot.

### Task 13: Retire old insight UI paths safely

**Files:**
- Review: `lib/presentation/screens/insights/history_reports_screen.dart`
- Review: `lib/presentation/screens/insights/history_report_detail_screen.dart`
- Review: `lib/presentation/screens/share/share_insight_screen.dart`

- [ ] Remove old history entry from the Sarah tab UI.
- [ ] Remove visible old insight entry points from bottom tab, Sarah page, and history navigation.
- [ ] Keep old report detail/share files only if still referenced by settings/export/debug or needed as migration support.
- [ ] Avoid deleting old models until migration and export decisions are stable.

## Verification

### Task 14: Automated tests

Run:
- [ ] `flutter test test/domain/entities/sarah_letter_test.dart`
- [ ] `flutter test test/domain/usecases/generate_sarah_weekly_letter_usecase_test.dart`
- [ ] `flutter test test/domain/usecases/migrate_legacy_insights_to_sarah_letters_usecase_test.dart`
- [ ] `flutter test test/presentation/bloc/sarah/sarah_bloc_test.dart`
- [ ] `flutter test test/presentation/widgets/sarah_letter_paper_test.dart`
- [ ] `flutter test`

### Task 15: Manual QA

- [ ] Fresh user: Sarah tab shows only Welcome Letter, unread dot appears, expanding marks read.
- [ ] Current week with 0-2 records: no "本周来信" section.
- [ ] Current week with 3+ records on Sunday: one weekly letter generated, no duplicate on repeat opens.
- [ ] AI failure: no UI error, old letters remain visible, retry can happen next trigger.
- [ ] Legacy reports: eligible reports become past letters, empty reports are skipped.
- [ ] Sign in on another device/account session: Sarah letters sync from the service backend with correct read state.
- [ ] Past letters: multiple expansions work independently.
- [ ] Small iPhone viewport: title, count, card text, and bottom nav do not overlap.
- [ ] Long Chinese text: collapsed fade and expanded paper remain visually stable.
- [ ] Missing illustration asset in debug: no crash.

## Iteration Plan

### Iteration 0: Backend Contract And Data Ownership

**Goal:** Lock the Sarah letter backend contract before mobile depends on it.

**Scope:**
- Define Sarah letter server schema and API payloads.
- Store Sarah letters on the service backend as the cross-device source of truth.
- Keep Coze token, project id, prompt/parsing, retry, and generation persistence entirely backend-side.
- Decide whether iCloud sync should mirror Sarah letters or whether service backend is the only cross-device source.

**Acceptance:**
- Mobile has API docs or typed contract for list, welcome, migration, weekly generation, and read-state update.
- Backend weekly generation is idempotent per user/week.
- Backend migration is idempotent per legacy report/week.
- No Coze credential is required in Flutter local config.

### Iteration 1: Mobile Foundation And Local Cache

**Goal:** Add Sarah letter data support without changing the visible UI yet.

**Scope:**
- Add `SarahLetter` entity, Hive model, repository, remote datasource, and use cases.
- Add `sarah_letters` local box.
- Register dependencies in GetIt.
- Cache backend letters locally for fast page rendering.
- Add account cache clearing and sync import/export hooks.

**Acceptance:**
- Unit tests pass for model mapping, local persistence, repository list/update behavior, and read-state update.
- App can fetch Sarah letters from backend and render them in logs/test state without exposing old UI changes.

### Iteration 2: Welcome Letter And Legacy Migration

**Goal:** Ensure every user sees Sarah's first letter and old weekly reports become past Sarah letters.

**Scope:**
- Call backend idempotent Welcome Letter endpoint.
- Convert local old `InsightReportCache` items into migration payloads.
- Keep only emotion overview and potential needs.
- Skip empty legacy reports.
- Upload migration results to backend and cache backend-confirmed letters locally.
- Store local migration version to avoid repeated work.

**Acceptance:**
- Fresh user receives exactly one Welcome Letter.
- Users with old weekly reports see them as `legacy` letters in date-descending order.
- Reopening the tab or reinstalling after sync does not duplicate migrated letters.

### Iteration 3: Weekly Letter Request Flow

**Goal:** Wire the client to request weekly Sarah generation while keeping generation authority on the backend.

**Scope:**
- Add client use case to request backend weekly-generation check.
- Request on Sarah tab load and relevant data changes.
- Locally throttle same-day repeated generation checks.
- Treat backend no-op, insufficient records, duplicate week, and failure as silent non-blocking outcomes.

**Acceptance:**
- With 0-2 weekly records, no weekly letter appears and no error is shown.
- With 3+ eligible records, backend returns at most one weekly letter for the week.
- Backend failure leaves existing letters visible and does not show a snackbar/error state.

### Iteration 4: Sarah Inbox UI

**Goal:** Replace the old Insights tab with the Sarah mailbox experience.

**Scope:**
- Rename tab to `Sarah` and remove visible old insight entry.
- Build Sarah screen header: `From Sarah`, `Stay with you`, `共 N 封信`.
- Build current weekly letter card with collapsed/expanded states.
- Build past letter tiles with independent expansion.
- Build paper visual: torn top texture, ruled lines, left red margin, bottom fold.
- Add unread marks and mark-as-read behavior.

**Acceptance:**
- No visible legacy insight dashboard/history entry remains in the tab.
- Welcome, weekly, and legacy letters are mixed by date descending.
- Current weekly letter collapses to about 3 lines and expands with signature.
- Multiple past letters can stay expanded independently.
- Unread dot disappears after reading/expanding and syncs read state.

### Iteration 5: Asset And Visual Polish

**Goal:** Bring the screen close to the provided mockups.

**Scope:**
- Add 20 Sarah line-art images under `assets/images/sarah/`.
- Use `illustrationIndex` to select `sarah_01.png` through `sarah_20.png`.
- Tune spacing, text sizes, paper shadows, fade masks, and bottom nav colors.
- Keep Playfair Display deferred; use current serif fallback with a named typography style that can be swapped later.
- Run small-screen QA.

**Acceptance:**
- Missing/invalid illustration index does not crash.
- UI matches the warm paper mailbox direction from the mockups.
- No text overlaps on small iPhone viewport.
- Bottom nav active color is `#8a7655`, inactive color is `#c0b8ac`.

### Iteration 6: Export, Cleanup, And Release Verification

**Goal:** Close compatibility gaps before shipping.

**Scope:**
- Decide whether exports show old "洞察报告" or Sarah letters.
- Keep old report models/storage only as needed for migration/export.
- Remove unused visible old insight routes after references are checked.
- Run full automated and manual QA.

**Acceptance:**
- `flutter test` passes or unrelated failures are documented.
- Cross-device Sarah letter sync works for content and read state.
- Legacy migration remains safe after repeated app launches.
- Release notes mention the Insights tab has become Sarah.

## Risks

- Backend Sarah APIs are now a dependency; mobile implementation should avoid inventing a local Coze fallback that leaks credentials.
- The current Coze parser expects report fields that differ from the new Sarah response; parsing should move to the backend Sarah generation flow.
- The spec includes a raw API token; implementation must not place it in local app config, and the exposed token should be rotated if it is real.
- Flutter cannot naturally float text around an image like CSS; the first version may need a carefully tuned overlay approximation.
- If backend sync and optional iCloud sync both handle Sarah letters, conflict ownership must be explicit to avoid duplicate letters or stale read states.
