# Weekly Insight Analysis Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local weekly record analytics to the insights screen so users see structured weekly data before the existing AI-written weekly summary.

**Architecture:** Introduce a standalone `WeeklyAnalysis` domain model plus a local aggregation use case that derives weekly facts from `Record` data. Keep the existing `InsightReport` flow intact, wire both into `InsightBloc`, and extend the insights screen with analytics cards ahead of the current AI content.

**Tech Stack:** Flutter, Dart, flutter_bloc, freezed/json, flutter_test

---

## Chunk 1: Analytics Domain

### Task 1: Add failing tests for weekly aggregation behavior

**Files:**
- Create: `test/domain/usecases/build_weekly_analysis_usecase_test.dart`
- Reference: `lib/domain/entities/record.dart`
- Reference: `lib/domain/entities/nvc_analysis.dart`

- [ ] **Step 1: Write the failing tests**

Cover:
- counts total records, active days, longest streak
- falls back to NVC feelings/needs when direct tags are missing
- computes top moods, top needs, peak time bucket, busiest weekday
- compares current week vs last week

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/domain/usecases/build_weekly_analysis_usecase_test.dart`
Expected: FAIL because `BuildWeeklyAnalysisUseCase` and related entities do not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create:
- `lib/domain/entities/weekly_analysis.dart`
- `lib/domain/usecases/build_weekly_analysis_usecase.dart`

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/domain/usecases/build_weekly_analysis_usecase_test.dart`
Expected: PASS

### Task 2: Refine analytics model for UI consumption

**Files:**
- Create: `lib/domain/entities/weekly_analysis.dart`
- Modify: `lib/domain/usecases/build_weekly_analysis_usecase.dart`

- [ ] **Step 1: Expose UI-friendly summary fields**

Add:
- coverage summary text
- changes summary list
- top mood / top need shortcuts

- [ ] **Step 2: Re-run analytics tests**

Run: `flutter test test/domain/usecases/build_weekly_analysis_usecase_test.dart`
Expected: PASS

## Chunk 2: State Wiring

### Task 3: Add state coverage for weekly analysis

**Files:**
- Modify: `lib/presentation/bloc/insight/insight_state.dart`
- Modify: `lib/presentation/bloc/insight/insight_bloc.dart`
- Reference: `lib/domain/usecases/generate_insight_report_usecase.dart`

- [ ] **Step 1: Add failing state test or targeted expectation test if practical**

If bloc tests are not already set up, at minimum add a focused unit test for state copy behavior:
- `test/presentation/bloc/insight/insight_state_test.dart`

- [ ] **Step 2: Run targeted test to verify it fails**

Run: `flutter test test/presentation/bloc/insight/insight_state_test.dart`
Expected: FAIL until `weeklyAnalysis` is added.

- [ ] **Step 3: Implement state and bloc integration**

Add `weeklyAnalysis` to `InsightState` and compute it inside current-week load/generate flows.

- [ ] **Step 4: Re-run targeted tests**

Run:
- `flutter test test/presentation/bloc/insight/insight_state_test.dart`
- `flutter test test/domain/usecases/build_weekly_analysis_usecase_test.dart`
Expected: PASS

## Chunk 3: Insights Screen

### Task 4: Add analytics cards ahead of AI content

**Files:**
- Modify: `lib/presentation/screens/insights/insights_screen.dart`
- Reference: `lib/core/theme/app_colors.dart`
- Reference: `lib/core/theme/app_typography.dart`

- [ ] **Step 1: Add a focused widget test if feasible**

Create a minimal widget test asserting analytics sections render when state contains both `currentReport` and `weeklyAnalysis`.

- [ ] **Step 2: Run the widget test to verify it fails**

Run: `flutter test test/presentation/screens/insights/insights_screen_test.dart`
Expected: FAIL until analytics UI exists.

- [ ] **Step 3: Implement analytics UI**

Add cards for:
- weekly overview
- mood/need distribution
- rhythm and change reminders
- coverage summary

Keep current AI sections intact and below analytics cards.

- [ ] **Step 4: Re-run widget and domain tests**

Run:
- `flutter test test/presentation/screens/insights/insights_screen_test.dart`
- `flutter test test/domain/usecases/build_weekly_analysis_usecase_test.dart`
Expected: PASS

## Chunk 4: Final Verification

### Task 5: Run full relevant verification

**Files:**
- Verify only

- [ ] **Step 1: Run targeted test suite**

Run:
- `flutter test test/domain/usecases/build_weekly_analysis_usecase_test.dart`
- `flutter test test/presentation/bloc/insight/insight_state_test.dart`
- `flutter test test/presentation/screens/insights/insights_screen_test.dart`

- [ ] **Step 2: Run broader regression smoke**

Run: `flutter test`
Expected: PASS or report exact failures unrelated to this feature.

- [ ] **Step 3: Manual code review**

Check:
- no AI flow regression
- empty state still works
- analytics can render with partial tag coverage

- [ ] **Step 4: Report results with evidence**

Summarize changed files, test commands, and any residual risks.
