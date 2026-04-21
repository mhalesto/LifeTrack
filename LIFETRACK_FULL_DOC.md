# LifeTrack iOS App — Complete Technical Reference

> Generated: 2026-04-20 | Branch: feature/daily-focus-document-assistant

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Data Layer](#3-data-layer)
4. [Subscription System](#4-subscription-system)
5. [AI Features & API Cost Analysis](#5-ai-features--api-cost-analysis)
6. [Voice Input System](#6-voice-input-system)
7. [Task Lifecycle](#7-task-lifecycle)
8. [Notification & Reminder System](#8-notification--reminder-system)
9. [Daily Focus & Habit Engines](#9-daily-focus--habit-engines)
10. [HealthKit Integration](#10-healthkit-integration)
11. [Document Handling](#11-document-handling)
12. [Import / Export & Cloud Backup](#12-import--export--cloud-backup)
13. [Views Reference](#13-views-reference)
14. [Theming System](#14-theming-system)
15. [App Shortcuts, Intents & Control Widgets](#15-app-shortcuts-intents--control-widgets)
16. [Settings Keys Reference](#16-settings-keys-reference)
17. [Privacy & Security](#17-privacy--security)
18. [Extensions (Widget, Notifications, Share)](#18-extensions-widget-notifications-share)
19. [Utilities & Component Library](#19-utilities--component-library)

---

## 1. Project Overview

LifeTrack is a SwiftUI + SwiftData iOS task management app with integrated AI assistance, habit tracking, document intelligence, voice input, and location-based reminders.

### Bundle & App Group

| Item | Value |
|---|---|
| Main bundle ID | `com.currenttech.LifeTrack` |
| App group | `group.com.currenttech.LifeTrack` |
| Widget extension | `LifeTrackControlWidget` |
| Notification extension | `LifeTrackNotificationContentExtension` |
| Share extension | `LifeTrackShareExtension` |

### Project Structure

```
LifeTrack/              — 74 Swift source files (~600 KB)
LifeTrackControlWidget/ — Control Center widget (4 controls)
LifeTrackNotificationContentExtension/ — Rich notification UI
LifeTrackShareExtension/ — Share sheet capture
Products.storekit       — Local StoreKit test configuration
LifeTrackTests/         — Compile-only test stubs (no test scheme wired)
```

---

## 2. Architecture

| Layer | Technology |
|---|---|
| UI | SwiftUI |
| Data persistence | SwiftData (`ModelContainer`, not CoreData) |
| AI | Anthropic Claude API (user-supplied key) |
| Subscriptions | StoreKit 2 (`Transaction.currentEntitlements`) |
| Concurrency | Swift structured concurrency (`async/await`, `@MainActor`) |
| Notifications | `UNUserNotificationCenter` |
| Location | `CoreLocation` + `CLCircularRegion` |
| Health | HealthKit (`HKCategoryType`, `HKQuantityType`) |
| Speech | `Speech` framework + `AVFoundation` |
| OCR | Vision framework (`VNRecognizeTextRequest`) |
| Document scanning | VisionKit (`VNDocumentCameraViewController`) |
| Intents | `AppIntents` framework |

### Actor model

- All AI calls, database writes, and UI state changes run on `@MainActor`.
- Statistics are computed on `Task.detached` (background priority) to avoid blocking the main thread.
- `ModelContainer` is shared between the main app and widget via the `group.com.currenttech.LifeTrack` app group.

---

## 3. Data Layer

### 3.1 `LifeTask` (SwiftData `@Model`)

Every user task is one `LifeTask` row. Soft deletion is supported via `deletedAt`.

#### All stored properties

| Property | Type | Default | Purpose |
|---|---|---|---|
| `id` | `UUID` | auto | Primary key (`.unique` attribute) |
| `title` | `String` | — | Task name |
| `categoryRawValue` | `String` | `"personal"` | Backing store for `TaskCategory` |
| `dueDate` | `Date` | — | When the task is due |
| `isCompleted` | `Bool` | `false` | Completion flag |
| `notes` | `String` | `""` | Freeform notes |
| `templateActionRawValue` | `String` | `"none"` | `.none` or `.email` |
| `priorityRawValue` | `String` | `"normal"` | `.low`, `.normal`, `.high` |
| `recurrenceRawValue` | `String` | `"none"` | Recurrence interval |
| `estimatedDurationMinutes` | `Int?` | `nil` (→30) | Planned duration |
| `documentStorageName` | `String?` | `nil` | UUID-prefixed filename in `TaskDocuments/` |
| `documentDisplayName` | `String?` | `nil` | Human-readable filename |
| `documentExtractedText` | `String` | `""` | OCR / PDF text |
| `documentAnalysisSummary` | `String?` | `nil` | One-line local analysis summary |
| `documentSuggestedTitle` | `String?` | `nil` | AI-derived task title from doc |
| `documentSuggestedDueDate` | `Date?` | `nil` | AI-extracted date from doc |
| `documentKeywordsRawValue` | `String` | `""` | Newline-joined detected keywords |
| `deletedAt` | `Date?` | `nil` | Soft-delete timestamp |
| `createdAt` | `Date` | `now` | Creation time |
| `updatedAt` | `Date` | `now` | Last modification time |
| `habitGroupID` | `UUID?` | `nil` | Links recurring instances |
| `completedAt` | `Date?` | `nil` | Completion timestamp |
| `locationReminderName` | `String?` | `nil` | POI display name |
| `locationReminderLatitude` | `Double?` | `nil` | Geofence centre |
| `locationReminderLongitude` | `Double?` | `nil` | Geofence centre |
| `locationReminderRadius` | `Double?` | `150` | Geofence radius in metres |
| `locationReminderOnArrival` | `Bool` | `true` | `true` = arrival; `false` = departure |

#### Key computed properties

| Property | Derived from | Notes |
|---|---|---|
| `category` | `categoryRawValue` | get/set enum bridge |
| `priority` | `priorityRawValue` | get/set |
| `recurrence` | `recurrenceRawValue` | get/set |
| `templateAction` | `templateActionRawValue` | get/set |
| `scheduledDurationMinutes` | `estimatedDurationMinutes ?? 30` | clamped ≥ 5 |
| `scheduledEndDate` | `dueDate + duration * 60` | computed |
| `durationTitle` | `scheduledDurationMinutes` | `"30 min"`, `"1 hour"`, `"1h 30m"` |
| `documentKeywords` | `documentKeywordsRawValue` | split on `\n` |
| `isOverdue` | `!isDeleted && !isCompleted && dueDate < now` | |
| `isDeleted` | `deletedAt != nil` | |
| `hasDocument` | both name fields non-nil | |
| `hasDocumentIntelligence` | any doc analysis field non-nil | |
| `isHabit` | `recurrence != .none` | |
| `hasLocationReminder` | lat & lon both non-nil | |

#### Enums

**`TaskCategory`**: `health`, `finance`, `work`, `home`, `personal`, `other`  
Each has `title (String)` and `symbolName (SF Symbol String)`.

**`TaskPriority`**: `low`, `normal`, `high`  
`focusScore`: low=0, normal=12, high=34 — used in daily focus ranking.

**`TaskRecurrence`**: `none`, `daily`, `weekly`, `monthly`, `yearly`  
`focusScore`: any non-none = 18.  
`nextDate(after:calendar:)` advances by the matching `Calendar.Component`.

**`TaskTemplateAction`**: `none`, `email`  
Email tasks show an "Open Email Draft" button in `TaskDetailView` via a `mailto:` URL.

#### Recurrence logic — `nextRecurringTask(completedAt:calendar:)`

Creates a copy of the task with a new `dueDate` advanced past `completedAt`:
- Advances one recurrence period at a time until the next date is after `completedAt`.
- Copies all fields including location reminder config.
- Sets `habitGroupID = habitGroupID ?? id` (first completion seeds the group).

---

### 3.2 `CustomTaskCategory` (SwiftData `@Model`)

User-created categories.

| Property | Type |
|---|---|
| `id` | `UUID` (`.unique`) |
| `title` | `String` |
| `symbolName` | `String` (SF Symbol) |
| `colorHex` | `Int` (ARGB) |
| `createdAt` | `Date` |

`rawValue` = `"custom:\(id.uuidString)"` — distinguishes from built-in categories.

#### `TaskCategoryOption`

`@MainActor struct` wrapping either built-in or custom category. Used throughout the UI to present a unified category picker.

Static factories: `builtIn(_:)`, `custom(_:)`, `all(customCategories:)`, `resolved(rawValue:customCategories:)`.  
Custom category tints are blended 10% toward the current theme accent.

---

### 3.3 `TaskEntity` (App Intents Entity)

Lightweight `AppEntity` wrapping `LifeTask` for Siri/Shortcuts:

```
id: UUID
title: String
dueDate: Date
isCompleted: Bool
categoryTitle: String
```

`TaskEntityQuery` supports:
- `entities(for:)` — fetch by UUID set
- `entities(matching:)` — title substring search (case-insensitive, first 25 results)
- `suggestedEntities()` — first 10 non-completed, non-deleted tasks

---

## 4. Subscription System

### 4.1 Tiers

```
SubscriptionTier: Int, Comparable, Codable
  .free     = 0
  .standard = 1
  .ultimate = 2
```

### 4.2 StoreKit Product IDs & Prices

| Product ID | Tier | Price |
|---|---|---|
| `com.currenttech.lifetrack.standard.monthly` | Standard | $2.99 / month |
| `com.currenttech.lifetrack.standard.yearly` | Standard | $24.99 / year ($2.08/mo, save 31%) |
| `com.currenttech.lifetrack.ultimate.monthly` | Ultimate | $7.99 / month |
| `com.currenttech.lifetrack.ultimate.yearly` | Ultimate | $59.99 / year ($5.00/mo, save 37%) |

All four products belong to subscription group ID `22041450` named **"LifeTrack Plans"**.

> Note: `PaywallView` displays rounded marketing prices ($3/mo, $25/yr, $8/mo, $60/yr); StoreKit vends the actual prices above.

### 4.3 Feature Gates

| Feature | Tier Required |
|---|---|
| Task creation, categories, due dates | Free |
| Document attachments | Free |
| Statistics & insights | Free |
| Basic notifications | Free |
| Control Center widgets | Free |
| **Daily Planning Ritual** | Standard+ |
| **Habit Tracking & Streaks** | Standard+ |
| **Weekly Review Mode** | Standard+ |
| **Location Reminders** | Standard+ |
| **HealthKit Energy Scheduling** | Standard+ |
| **Custom Themes** | Standard+ |
| **AI Task Suggestions** | Ultimate |
| **Smart Scheduling Optimizer** | Ultimate |
| **iCloud Backup & Export** | Ultimate |
| **Priority Support** | Ultimate |

### 4.4 `SubscriptionManager` (singleton, `@MainActor`)

**Startup sequence:**
1. `init()` — Starts `Transaction.updates` listener task, schedules `bootstrap()`.
2. `bootstrap()` — Runs `loadProducts()` + `refreshTier()` concurrently via `async let`.
3. `loadProducts()` — Calls `Product.products(for: ProductID.all)`, sorted by ascending price.
4. `refreshTier()` — Iterates `Transaction.currentEntitlements`, picks highest verified tier.

**Purchase flow:**
1. `purchase(_ product:)` — `product.purchase()`.
2. On `.success(.verified)` → `tx.finish()` → `refreshTier()`.
3. On `.userCancelled` / `.pending` → no-op.

**Restore:** `AppStore.sync()` → `refreshTier()`.

### 4.5 `APIBudgetTracker` (per-day AI call limiter)

Persisted in `UserDefaults`:
- `LifeTrack.api.budget.countToday` — call count today
- `LifeTrack.api.budget.date` — date the counter was last reset

**Daily caps:**

| Tier | Calls / day |
|---|---|
| Free | 10 |
| Standard | 50 |
| Ultimate | 250 |

Resets automatically at local midnight. `consumeOne()` throws `ClaudeAPIClient.ClientError.budgetExceeded(used:cap:)` when the limit is reached.

---

## 5. AI Features & API Cost Analysis

### 5.1 `ClaudeAPIClient` (singleton, `@MainActor`)

**Endpoint:** `POST https://api.anthropic.com/v1/messages`

**Headers:**
```
Content-Type: application/json
x-api-key: <user's key>
anthropic-version: 2023-06-01
```

**URLSession config:** 30s request timeout, 60s resource timeout, `waitsForConnectivity = true`.

**Models available:**
| Constant | Model ID |
|---|---|
| `Model.haiku` | `claude-haiku-4-5-20251001` |
| `Model.sonnet` | `claude-sonnet-4-6` |

All AI features use **Haiku** by default. Sonnet is available as a constant but not called by any current feature.

**API key storage:** `UserDefaults.standard["LifeTrack.settings.claudeAPIKey"]`  
Key is entered by the user in Settings → AI Settings (Ultimate tier only).

**Prompt caching:**  
When `cacheSystem = true` (default for all calls), the `system` block is sent as:
```json
[{"type": "text", "text": "...", "cache_control": {"type": "ephemeral"}}]
```
This enables Anthropic's **prompt caching** — repeated calls with the same system prompt within the 5-minute cache TTL get a **90% discount on cached input tokens**.

**In-memory response cache:**  
Each `send(...)` call is keyed by `SHA-256(model|maxTokens|systemPrompt|userContent)`. If a cached entry exists and is within its TTL, the network call is skipped entirely. TTL is set per feature (see below). `cacheTTL: .infinity` = permanent for the app session.

**`extractJSON(from:)`:**  
Strips markdown code fences (` ``` `), then finds the outermost `{...}` substring. All AI advisors use this to parse responses that Claude may wrap in explanation text.

---

### 5.2 Anthropic Pricing (as of August 2025)

| Model | Input ($/MTok) | Output ($/MTok) | Cache write ($/MTok) | Cache read ($/MTok) |
|---|---|---|---|---|
| claude-haiku-4-5-20251001 | $0.80 | $4.00 | $1.00 (+25%) | $0.08 (−90%) |
| claude-sonnet-4-6 | $3.00 | $15.00 | $3.75 (+25%) | $0.30 (−90%) |

> The app uses user-supplied API keys. There is **no server-side billing** — all costs accrue directly to the user's Anthropic account.

---

### 5.3 Feature-by-Feature Cost Breakdown

#### A. AI Task Suggestions (`AITaskAdvisor`)

| Parameter | Value |
|---|---|
| Model | Haiku 4.5 |
| `maxTokens` | 512 |
| Cache TTL | 600s (10 minutes) |
| Response cache TTL | 600s |
| Max tasks sent | 25 |

**Typical token usage:**

| Component | Estimated tokens |
|---|---|
| System prompt | ~180 tokens |
| User content (25 tasks × ~22 tokens each) | ~550 tokens |
| **Total input** | **~730 tokens** |
| Output (JSON with 5 suggestions + insight) | ~200–400 tokens |

**Cost per uncached call:**
```
Input:  730 tokens × $0.80/MTok = $0.000584
Output: 350 tokens × $4.00/MTok = $0.001400
Total per call ≈ $0.002 (0.2 cents)
```

**Cost with prompt caching (after first call, same system prompt):**
```
Cache read: 180 tokens × $0.08/MTok = $0.0000144
New input:  550 tokens × $0.80/MTok = $0.000440
Output:     350 tokens × $4.00/MTok = $0.001400
Total per cached call ≈ $0.00185 (0.19 cents)
```

**Daily cost estimate (Ultimate: 250 calls/day):**
- Every call refreshes at most every 10 minutes → realistically ~30–60 advisor refreshes/day.
- 50 calls × $0.002 = **$0.10/day max** for this feature.

---

#### B. Smart Scheduling Optimizer (`SmartSchedulingAdvisor`)

| Parameter | Value |
|---|---|
| Model | Haiku 4.5 |
| `maxTokens` | Not explicitly set (inherits default ~1024) |
| Cache TTL | 900s (15 minutes) |
| Max tasks sent | 20 |

**Typical token usage:**

| Component | Estimated tokens |
|---|---|
| System prompt | ~250 tokens |
| User content (20 tasks + energy level) | ~500 tokens |
| **Total input** | **~750 tokens** |
| Output (schedule JSON with 6 blocks) | ~350–500 tokens |

**Cost per uncached call:**
```
Input:  750 tokens × $0.80/MTok = $0.000600
Output: 425 tokens × $4.00/MTok = $0.001700
Total per call ≈ $0.0023 (0.23 cents)
```

**Daily cost estimate (normal usage, ~5–10 optimizations/day):**
- 10 calls × $0.0023 = **$0.023/day** (2.3 cents).

---

#### C. Voice Task Enhancement (`AIVoiceTaskEnhancer`)

**Single transcript mode:**

| Parameter | Value |
|---|---|
| Model | Haiku 4.5 |
| `maxTokens` | 300 |
| Cache TTL | 3600s (1 hour, for the response) |

| Component | Estimated tokens |
|---|---|
| System prompt | ~200 tokens |
| User transcript | ~30–80 tokens |
| **Total input** | **~250 tokens** |
| Output (title, notes, priority, category) | ~80–150 tokens |

**Cost per call:**
```
Input:  250 tokens × $0.80/MTok = $0.000200
Output: 120 tokens × $4.00/MTok = $0.000480
Total per call ≈ $0.00068 (0.07 cents)
```

**Batch mode** (N transcripts, e.g. from multi-task capture):
- `maxTokens = 300 × N`
- Input grows linearly with transcript count.
- Cost ≈ `N × $0.00068` (since output scales proportionally).

**Daily cost estimate (20 voice tasks/day):**
- 20 × $0.00068 = **$0.0136/day** (1.4 cents).

---

#### D. Weekly Digest Narrative (`WeeklyDigestService`)

| Parameter | Value |
|---|---|
| Model | Haiku 4.5 |
| `maxTokens` | 180 |
| Cache TTL | `.infinity` (permanent — once per ISO week) |
| UserDefaults cache | Max 12 weeks stored |

**Called at most once per calendar week per device.** Result is stored permanently in UserDefaults.

| Component | Estimated tokens |
|---|---|
| System prompt | ~120 tokens |
| User prompt (7 week metrics) | ~80 tokens |
| **Total input** | **~200 tokens** |
| Output (2–3 warm sentences) | ~80–140 tokens |

**Cost per weekly call:**
```
Input:  200 tokens × $0.80/MTok = $0.000160
Output: 110 tokens × $4.00/MTok = $0.000440
Total per week ≈ $0.00060 (0.06 cents)
```

**Annual cost for this feature:** 52 weeks × $0.00060 = **$0.031/year** (3 cents).

---

#### E. Task Emoji Assignment (`TaskEmojiService`)

| Parameter | Value |
|---|---|
| Model | Haiku 4.5 |
| `maxTokens` | 10 |
| Cache TTL | `.infinity` (permanent UserDefaults cache keyed by SHA-256 of title) |

Once an emoji is fetched for a given task title, it is **never fetched again** (cached forever).

| Component | Estimated tokens |
|---|---|
| System prompt | ~50 tokens |
| User (task title) | ~5–10 tokens |
| **Total input** | **~60 tokens** |
| Output (single emoji character) | 1–3 tokens |

**Cost per call:**
```
Input:  60 tokens × $0.80/MTok = $0.000048
Output:  2 tokens × $4.00/MTok = $0.000008
Total per call ≈ $0.000056 (0.006 cents)
```

This is effectively **negligible** — less than 1/100th of a cent per task.

---

### 5.4 Combined Daily Cost Scenarios

| Usage scenario | AI Suggestions | Smart Scheduling | Voice Tasks | Total/day |
|---|---|---|---|---|
| Light (5 suggestions, 2 scheduling, 5 voice) | $0.010 | $0.005 | $0.003 | **~$0.018** |
| Moderate (20 suggestions, 5 scheduling, 20 voice) | $0.040 | $0.012 | $0.014 | **~$0.066** |
| Heavy (250-cap, 10 scheduling, 50 voice) | $0.500 | $0.023 | $0.034 | **~$0.557** |

At Ultimate tier's 250-call daily cap, **worst-case cost is ~$0.55/day** if all calls are AI Task Suggestions. Realistically, mixed usage stays well under **$0.10/day**.

### 5.5 How the App User Pays

1. User creates an Anthropic account at `console.anthropic.com`.
2. Adds a payment method and gets an API key.
3. Pastes the API key into **LifeTrack Settings → AI Settings** (Ultimate tier only).
4. All API calls bill directly to that Anthropic account.
5. LifeTrack enforces daily budget caps to prevent runaway spending.
6. Anthropic's free tier (if any) applies; otherwise pay-as-you-go.

---

## 6. Voice Input System

### 6.1 `VoiceTaskInputManager` (`@MainActor`, `NSObject`)

Uses `AVFoundation` + `Speech` framework.

**Published state:**
```swift
transcript: String
isRecording: Bool
audioLevel: CGFloat   // 0.0–1.0
feedbackMessage: String
authorizationMessage: String?
```

**Recording flow:**
1. Request `SFSpeechRecognizer` authorization + microphone permission.
2. Set `AVAudioSession` category to `.record` with `.duckOthers`.
3. Install audio tap on `AVAudioEngine.inputNode` (buffer size 1024 frames).
4. Feed buffers to `SFSpeechAudioBufferRecognitionRequest` with `shouldReportPartialResults = true`.
5. Partial results update `transcript` live.

**Audio level calculation:**
```
RMS = √(mean of squared samples across all channels)
dB  = 20 × log10(RMS)
normalized = (dB + 56) / 48, clamped to [0, 1]
Smoothed: audioLevel = old × 0.62 + new × 0.38
```

**Locale:** System locale, fallback to `en-US`.

---

### 6.2 `VoiceTaskParser` (local, zero API calls)

Pure static functions. Runs synchronously. No network dependency.

**`parse(_:referenceDate:) → VoiceTaskDraft` steps:**
1. Detect due date: relative time → `NSDataDetector` → natural language keywords
2. Strip time expressions from transcript to get residual body
3. Split into `(title, notes)`:
   - Split on "because" / "so that"
   - Sentence boundary (`.!?`) if text > 90 chars
   - Semicolon / em-dash if text > 90 chars
4. Detect category from keyword lists (see below)
5. Return `VoiceTaskDraft`

**Category keyword detection:**

| Category | Keywords |
|---|---|
| health | appointment, doctor, dentist, clinic, medicine, workout, exercise, health, checkup, therapy |
| finance | budget, bill, invoice, payment, bank, tax, insurance, loan, credit, finance, receipt |
| work | email, meeting, client, report, presentation, project, deadline, follow up, call, work, server, deploy |
| home | home, house, repair, clean, laundry, grocery, groceries, rent, maintenance |
| personal | family, birthday, friend, personal, travel, passport, license |

**Default scheduling times:**
- Future date → 9:00 AM
- Today but already past 9 AM → 6:00 PM
- Tonight keyword → 7:00 PM

---

### 6.3 `AIVoiceTaskEnhancer` (Claude-powered)

Takes the raw transcript from `VoiceTaskInputManager` and upgrades it into structured fields using Claude.

**System prompt rules:**
- Title: verb-led, max 8 words
- Notes: bullet points with `•` prefix, only if task has context/reason/qualifiers; `null` if self-contained
- Priority detection:
  - `high`: urgent, asap, critical, must, important, deadline, overdue
  - `low`: sometime, maybe, eventually, when possible, no rush
  - `normal`: everything else
- Category: health/finance/work/home/personal/other (same 6 as enum)

**Response JSON:**
```json
{
  "title": "Book dentist appointment",
  "notes": "• For annual checkup\n• Prefer morning slots",
  "priority": "normal",
  "category": "health"
}
```

**Application logic in `NewTaskView`:**  
Enhanced fields are only applied if the user hasn't manually edited those fields since the last voice capture (tracked via `lastVoiceGeneratedTitle`, `lastVoiceGeneratedNotes`, `didApplyVoiceCategory`, `didApplyVoiceDueDate`).

---

## 7. Task Lifecycle

### 7.1 `TaskLifecycleManager` (static enum, `@MainActor`)

All task mutation is routed through this manager to ensure reminders, recurrence, and documents stay in sync.

#### `beginToggleCompletion(for:) → PendingToggle`

Flips `isCompleted`, sets `updatedAt = now`. Safe inside `withAnimation`.

- On completion: `completedAt = now`, seeds `habitGroupID = id` if first habit.
- On un-completion: clears `completedAt`.

#### `finishToggleCompletion(_:in:customCategories:)`

Called after animation completes.

- Reopening task: calls `synchronizeReminder` (reschedules notification).
- Completing task: cancels reminder + location region. If recurring, creates `nextRecurringTask`, inserts it, schedules its reminder + location.
- Saves context.

#### `delete(_:in:retentionPeriod:) → Bool`

- `retentionPeriod == .immediately`: calls `permanentlyDelete`, returns `false`.
- Otherwise: cancels reminder, sets `deletedAt = now`, saves, returns `true` (bin).

#### `restore(_:in:customCategories:)`

Clears `deletedAt`, saves, synchronizes reminder.

#### `permanentlyDelete(_:in:)`

Cancels reminder → `DocumentStore.delete(storageName:)` → `modelContext.delete(task)` → save.

#### `purgeExpiredBinItems(from:in:retentionPeriod:)`

Deletes all tasks where `deletedAt + retentionDuration < now`.

#### `applySchedule(_:in:customCategories:)`

Batch-updates `dueDate` for `[(LifeTask, Date)]` pairs. Saves once, then re-synchronizes all reminders.

---

### 7.2 Task Bin Retention Periods

| Option | Duration |
|---|---|
| `immediately` | 0 (delete on spot) |
| `twelveHours` | 12 hours |
| `oneDay` | 24 hours |
| `sevenDays` | 7 days (default) |
| `thirtyDays` | 30 days |

---

## 8. Notification & Reminder System

### 8.1 `ReminderScheduler` (static enum)

**Notification category identifier:** `LIFETRACK_TASK_REMINDER`

**3 interactive actions:**

| Identifier | Label | Behavior |
|---|---|---|
| `LIFETRACK_MARK_COMPLETE` | Mark Complete | Background (no app open) |
| `LIFETRACK_SNOOZE_10_MIN` | Snooze 10 min | Background |
| `LIFETRACK_OPEN_TASK` | Open Task | Foreground (`.foreground` option) |

**Trigger date logic:**
```
If snooze (preferredTriggerDate provided):
  → use it if future, else 3s from now

Else (normal reminder):
  → dueDate - 30 minutes
  → if that's past but dueDate is future: trigger in 3s
  → if dueDate also past: cancel
```

**Notification content:**
- Title: `"Due in 30 minutes"` (if ≥30 min) or `"Due in N minutes"`
- Body: `"Hold: Complete, Snooze, Open • [categoryTitle] • [dueDate time]"`

**Snooze:** New notification scheduled at `now + 10 minutes`, title overridden to `"Snoozed for 10 minutes"`.

**UserInfo keys:** `taskID`, `taskTitle`, `categoryTitle`, `dueTimestamp`, `themeID`

---

### 8.2 `LifeTrackNotificationDelegate`

`UNUserNotificationCenterDelegate`. Presents notifications as `.banner, .list, .sound, .badge` even when app is in foreground.

### 8.3 Notification Action Handler

| Action | Effect |
|---|---|
| Mark Complete | Fetches `LifeTask` by UUID, marks complete, cancels reminder, creates next recurring instance, saves |
| Snooze 10 min | Calls `ReminderScheduler.snoozeReminder(...)` |
| Open Task / default tap | Stores UUID in `UserDefaults["lifetrack.pendingOpenTaskID"]`. HomeView polls on scene-active. |

---

### 8.4 Location Reminders (`LocationReminderManager`)

Singleton. Uses `kCLLocationAccuracyHundredMeters`.

**Region prefix:** `"lifetrack.location."`

**`scheduleRegion(for:)`:**
1. Create `CLCircularRegion` (default 150m radius).
2. Set `notifyOnEntry / notifyOnExit` per `locationReminderOnArrival`.
3. Start monitoring.
4. Schedule `UNLocationNotificationTrigger` notification.

**Notification:**
- Title: `"You've arrived!"` or `"You're leaving!"`
- Subtitle: task title
- Body: `"Near [locationName]"`

**On app launch:** `restoreAllRegions(from:)` re-registers all non-completed active tasks' regions.

---

## 9. Daily Focus & Habit Engines

### 9.1 `DailyFocusPlanner` (static enum, `@MainActor`)

#### Focus scoring algorithm

For each open (non-deleted, non-completed) task:

```
base score = 0

if overdue:
  + 120 + min(|dayDistance| × 4, 36)
elif dueToday:
  + 100
elif due tomorrow:
  + 70
elif due in 2–7 days:
  + (46 - dayDistance × 3)
elif due 8+ days:
  + max(18 - dayDistance, 0)

+ priority.focusScore         (high=34, normal=12, low=0)
+ recurrence.focusScore       (non-none=18)
+ 10 if hasDocumentIntelligence

energy adjustment (only on .low energy):
  + 25 if duration ≤ 30 min
  - 15 if duration ≥ 60 min
```

**Result set size:** `min(max(openTasks.count, 3), 5)` — always 3–5 recommendations.

**Tiebreaker:** `dueDate` ascending.

#### `DailyFocusReason` display order

`overdue` → `dueToday` → `highPriority` → `routine` → `documentReminder` → `upcoming`

#### Reset / Reschedule

**`resetSchedule(for:focusIDs:)`:**
- Focus tasks → slots at 09:00, 11:00, 14:00, 16:00, 18:00
- Non-focus overdue → deferred slots from day+1 onward

**`overdueReschedulePlan(for:)`:**  
Overdue tasks slotted into deferred times starting tomorrow.

---

### 9.2 `HabitEngine` (static enum)

#### Streak calculation

**`currentStreak(dates:recurrence:)`:**
- Iterates sorted dates newest-first.
- A date counts if gap from reference ≤ 2 units of the recurrence interval.
- Streak increments while dates are consecutive within tolerance; stops at first gap.

**`longestStreak(dates:recurrence:)`:**
- Iterates sorted dates oldest-first.
- Increments current run while gap ≤ 2 units; resets on larger gap.

#### Grid cell counts (fill history visualization)

| Recurrence | Cells | Represents |
|---|---|---|
| Daily | 91 (13×7) | ~3 months |
| Weekly | 52 | 1 year |
| Monthly | 26 | ~2 years |
| Yearly | 13 | 13 years |

#### `HabitSummary` struct

```swift
task: LifeTask
currentStreak: Int
longestStreak: Int
completionDates: [Date]
recurrence: TaskRecurrence
filledDateStrings: Set<String>  // indexes for fill grid
cellCount: Int
```

---

## 10. HealthKit Integration

### `HealthKitEnergyReader` (singleton, `@MainActor`)

**Data types read (read-only):**
- `HKCategoryType(.sleepAnalysis)`
- `HKQuantityType(.heartRateVariabilitySDNN)`

**`computeLevel(sleepHours:hrv:)` scoring:**

| Condition | Score delta |
|---|---|
| Sleep ≥ 7h | +2 |
| Sleep ≥ 6h | +1 |
| Sleep < 5h | −1 |
| HRV ≥ 50ms | +2 |
| HRV ≥ 30ms | +1 |
| HRV < 20ms | −1 |

**Final level:**
- Score ≥ 3 → `.high`
- Score 1–2 → `.moderate`
- Score ≤ 0 → `.low`
- Both inputs zero → `.unknown`

**`EnergyLevel` effect on scheduling:**

| Level | Planning nudge |
|---|---|
| `.high` | High-energy tasks preferred in morning |
| `.moderate` | Neutral scheduling |
| `.low` | Prefer short tasks (≤30 min); penalize long tasks (≥60 min) |
| `.unknown` | No adjustment |

---

## 11. Document Handling

### 11.1 `DocumentStore`

Manages files in `~/Documents/TaskDocuments/` with `.completeFileProtection`.

| Function | Behaviour |
|---|---|
| `saveSecurityScopedFile(from:)` | Copies file with UUID-prefix, applies `.complete` protection |
| `adoptFromAppGroup(sourceURL:preferredDisplayName:)` | Same but from Share Extension app group |
| `url(for:)` | Returns full URL only if file exists |
| `shareableURL(for:displayName:)` | Copies to temp `LifeTrackSharedDocuments/` with sanitized display name |
| `delete(storageName:)` | Removes file |

---

### 11.2 `DocumentAnalysisManager` (fully local — no AI)

All analysis runs on-device. No API calls.

**`analyze(url:displayName:) async → DocumentAnalysisResult`:**

1. **Text extraction:**
   - PDF: native `PDFDocument` → Vision OCR fallback (max 4 pages)
   - Image: Vision OCR (`VNRecognizeTextRequest`, accurate, language correction)
   - Plain text: UTF-8 read

2. **Normalize:** Collapse whitespace, trim to 24,000 chars.

3. **Keyword detection** (15 candidates):  
   insurance, policy, passport, school, tax, bill, invoice, application, appointment, renewal, deadline, payment, medical, license, statement

4. **Due date detection:** `NSDataDetector`, first future date found.

5. **Title generation** (pattern-matched, local):

| Document type | Suggested title |
|---|---|
| invoice / bill | "Pay invoice" |
| insurance / renewal | "Renew insurance" |
| appointment | "Book follow-up appointment" |
| passport / license | "Review renewal document" |
| tax | "Review tax document" |
| school / application | "Review application deadline" |
| default | "Review document reminder" |

Appends detected date if found.

6. **Summary generation:** `"Detected: [keywords]. Date found: [date]. [references]"` or default messages.

7. **Reference detection:** Invoice #, Policy #, Reference # via regex.

---

## 12. Import / Export & Cloud Backup

### `TaskExchangeManager`

**Formats:** JSON (full fidelity), CSV, TSV (with header row).

**CSV/TSV columns:** `id, title, category, dueDate, priority, recurrence, notes, isCompleted, estimatedDuration, createdAt, updatedAt`

**Import:** Creates `LifeTask` objects from parsed rows. Inserts into SwiftData context.

**Export:** Serializes all non-deleted tasks. Provided via `ShareLink`.

---

### `CloudBackupView` (Ultimate only)

Full JSON backup including soft-deleted tasks and custom categories.

- Export via `ShareLink` → iCloud Drive, AirDrop, or Files app.
- Import/restore from any previous backup file.
- Last backup date stored in `UserDefaults["LifeTrack.settings.lastBackupDate"]`.

---

### `SharedInboxImporter`

Processes files from the Share Extension's inbox in the app group container.

- Text-only payloads → creates task with title = first line (max 72 chars).
- File attachments → copies to `DocumentStore`, runs `DocumentAnalysisManager.analyze`, populates all document intelligence fields.

---

## 13. Views Reference

### 13.1 `ContentView`

Root view. Shows `SplashScreenView` (950ms fade-out), then fades in `HomeView`. On `.background` scene phase, calls `AppSnapshotCover.show()` for privacy.

---

### 13.2 `HomeView` (largest file, ~124 KB)

**State variables (40+):** See source for full list. Key ones:

| Variable | Purpose |
|---|---|
| `navigationPath: [HomeRoute]` | Navigation stack |
| `showingNewTask` | FAB new task sheet |
| `showingSettings` | Settings sheet |
| `showingDailyRitual` | Daily Planning sheet (Standard+) |
| `showingHabits` | Habit Tracker sheet (Standard+) |
| `showingWeeklyReview` | Weekly Review sheet (Standard+) |
| `showingAISuggestions` | AI Suggestions sheet (Ultimate) |
| `showingSmartScheduling` | Smart Scheduling sheet (Ultimate) |
| `showingPaywall` | Paywall sheet |
| `streakCelebration` | Streak banner trigger |
| `pendingReopenTask` | Confirmation overlay trigger |

**`HomeRoute` enum:**  
`.statistics`, `.calendar`, `.availabilityCalendar`, `.documents`, `.taskData(TaskDataExchangeEntryMode)`

**Navigation destinations:**

| Route | Destination |
|---|---|
| `.statistics` | `StatisticsView(tasks: activeTasks)` |
| `.calendar` | `TaskCalendarView(...)` |
| `.availabilityCalendar` | `TaskCalendarView(focusAvailabilityOnAppear: true)` |
| `.documents` | `DocumentSearchView()` |
| `.taskData(mode)` | `TaskDataExchangeView(initialMode: mode)` |

**Task filter computed properties:**

| Property | Filter |
|---|---|
| `activeTasks` | `!isDeleted` |
| `dueTodayTasks` | active, not completed, `isDateInToday(dueDate)` |
| `upcomingTasks` | active, not completed, `dueDate > now`, not today |
| `completedTasks` | active, `isCompleted` |
| `overdueTasks` | active, `isOverdue` |
| `focusRecommendations` | `DailyFocusPlanner.recommendations(from: activeTasks)` |
| `priorityTasks` | focus recommendations mapped to tasks |
| `documentTasks` | with documents, sorted by `updatedAt` desc |
| `documentReminderTasks` | active, not completed, `hasDocumentIntelligence`, sorted by suggested due date |

**Dashboard message system:**  
5 tonal variants × 20 messages = 100 contextual messages. Context groups: empty, focus, clear, completed, overdue, busy.  
Message index is deterministic but rotated by a seed that changes each time the scene becomes active.

**Quick action tiles (horizontal scroll):**

| Tile | Tier |
|---|---|
| Plan My Day | Standard+ |
| Habits | Standard+ |
| Weekly Review | Standard+ |
| AI Suggestions | Ultimate |
| Schedule | Ultimate |
| New task | All |
| Availability | All |
| Email follow-up | All |
| Import | All |
| Export | All |
| Pay bill | All |
| Medication | All |
| Budget | All |
| Health check | All |
| Calendar | All |
| Statistics | All |
| Documents | All |
| Templates | All |

---

### 13.3 `NewTaskView`

Full-screen modal for create/edit. Pre-fill from `TaskTemplate` or `LifeTask`.

**Card sequence:**
1. Header (Cancel/Save toolbar)
2. Task data shortcut card (file import/export)
3. Voice card (`VoiceInputCard` with AI enhance)
4. Task card (title, category, priority, recurrence)
5. Planning card (duration picker: 15/30/45/60/90/120 min)
6. Date card (due date wheel)
7. Location card (Standard+ — `LocationPickerView`)
8. Notes card (multiline `TextEditor`, dynamic height)
9. Document card (attach file / scan / analysis results)
10. Template action card (email only)
11. Status card (edit mode only — mark complete toggle)

---

### 13.4 `StatisticsView`

**Time ranges:**

| Range | Window | Bar unit |
|---|---|---|
| `.days` | 14 days | per day |
| `.weeks` | 8 weeks | per week |
| `.months` | 6 months | per month |

**Computed off-thread (`Task.detached`):**

| Metric | Description |
|---|---|
| Total completed | Count in range |
| Total overdue | Count in range |
| Completion rate | completed / (completed + overdue) × 100% |
| Best period | Highest completion count period |
| Current streak | Consecutive days with ≥1 completion |
| Best streak | Historical longest streak |
| Best weekday | Day of week with most completions |
| Focus minutes | Sum of `scheduledDurationMinutes` for completed tasks |
| Category mix | Distribution by `TaskCategory` |

**Charts:** Swift Charts `BarMark` (completed) + `AreaMark/LineMark/PointMark` (overdue trend, Catmull-Rom interpolation).

---

### 13.5 Other Key Views

| View | Purpose |
|---|---|
| `TaskDetailView` | Read-only task view with document, schedule, notes cards |
| `TaskRowView` | Swipeable row: lead=complete, trail=edit+delete |
| `HabitTrackerView` | Habit cards with streak, grid history (Standard+) |
| `WeeklyReviewView` | 5-step modal: wins, clear, capture, preview, done (Standard+) |
| `DailyPlanningRitualView` | Multi-step day planner with HealthKit energy (Standard+) |
| `AITaskSuggestionsView` | Focus + reschedule suggestions (Ultimate) |
| `SmartSchedulingOptimizerView` | Time-block schedule with energy tags (Ultimate) |
| `PaywallView` | Paywall with monthly/yearly toggle, tier cards, restore |
| `SettingsView` | 7-card settings: subscription, AI key, profile, theme, motion, data, bin |
| `TaskBinView` | Soft-deleted tasks: restore / permanent delete |
| `TaskCalendarView` | Monthly calendar grid with task dots |
| `DocumentSearchView` | Full-text search across `documentExtractedText` |
| `TaskDataExchangeView` | Import/export JSON/CSV/TSV |
| `CloudBackupView` | Full backup (Ultimate) |
| `LocationPickerView` | Map-based POI search, geofence config |
| `CategoryManagerView` | CRUD for custom categories |
| `AvatarCropView` | Pinch/pan/rotate circle crop |
| `SplashScreenView` | 960ms animated launch screen |
| `AvailabilityTimelineView` | Free/busy timeline view with shareable text |

---

## 14. Theming System

### Themes

| ID | Name | Style |
|---|---|---|
| `focus` | Focus Blue | Default blue, rounded font |
| `sage` | Sage | Green tones, default font |
| `dreamy` | Dreamy | Purple/pink, rounded font |
| `cobalt` | Cobalt | Deep blue, rounded font |
| `ember` | Ember | Warm orange/red, serif font |

### Color Strength Slider

Range: 0.55–1.35 (displayed as %). Stored in `LifeTrackSettings.Keys.colorStrength`.
- Below 1.0 → blend accent toward pale
- Above 1.0 → blend toward vivid
- Backgrounds and soft colors have separate tuning

### `LifeTrackTheme.Spacing`

| Constant | Value |
|---|---|
| xSmall | 6 pt |
| small | 8 pt |
| medium | 12 pt |
| large | 16 pt |
| xLarge | 20 pt |
| xxLarge | 28 pt |

### `LifeTrackTheme.Radius`

card=8, control=8, chip=18

### Font scale

| Font | SwiftUI equivalent |
|---|---|
| `lifeTrackHero` | `.largeTitle` bold |
| `lifeTrackTitle` | `.title2` semibold |
| `lifeTrackHeadline` | `.headline` semibold |
| `lifeTrackBody` | `.body` regular |
| `lifeTrackCallout` | `.callout` medium |
| `lifeTrackCaption` | `.caption` medium |

All fonts use the theme's `fontDesign` (serif/rounded/default).

---

## 15. App Shortcuts, Intents & Control Widgets

### 5 Registered App Shortcuts (Siri / Spotlight)

| Shortcut | Intent | Phrases |
|---|---|---|
| Add Task | `CreateTaskIntent` | "Add a task to LifeTrack", "New task in LifeTrack", "Remind me in LifeTrack" |
| Today's Tasks | `GetTodaysTasksIntent` | "What's on my plate in LifeTrack", "Today's tasks in LifeTrack" |
| Complete Task | `CompleteTaskIntent` | "Mark a task done in LifeTrack", "Complete task in LifeTrack" |
| Voice Task | `StartVoiceTaskIntent` | "Capture a task with LifeTrack", "Start voice task in LifeTrack" |
| Today's Focus | `TodaysFocusIntent` | "Show my focus in LifeTrack", "Open today's focus in LifeTrack" |

### Intent Details

**`CreateTaskIntent`:**  
Parameters: `taskTitle (String)`, `notes (String, default "")`, `dueDate (Date?, default nil)`, `category (TaskCategoryAppEnum, default .personal)`.  
Default due date if nil: tomorrow 9:00 AM. Creates `LifeTask` directly in SwiftData. Returns `TaskEntity`. `openAppWhenRun = false`.

**`GetTodaysTasksIntent`:**  
Fetches tasks due by 23:59:59 today, returns first 5 as `[TaskEntity]`. `openAppWhenRun = false`.

**`CompleteTaskIntent`:**  
Parameter: `task (TaskEntity)`. Marks complete with timestamp. `openAppWhenRun = false`.

**`StartVoiceTaskIntent` / `NewBlankTaskIntent` / `TodaysFocusIntent` / `QuickCompleteIntent`:**  
All set a flag in shared `UserDefaults (group.com.currenttech.LifeTrack)` and set `openAppWhenRun = true`.  
`HomeView.checkPendingVoiceLaunch()` reads and clears flags on each scene-active event.

### Control Center Widgets (4)

| Control | Kind | Icon | Fires |
|---|---|---|---|
| New Voice Task | `VoiceTaskControl` | waveform | `StartVoiceTaskIntent` |
| New Task | `NewBlankTaskControl` | plus.circle | `NewBlankTaskIntent` |
| Today's Focus | `TodaysFocusControl` | scope | `TodaysFocusIntent` |
| Complete Next Task | `QuickCompleteControl` | checkmark.circle | `QuickCompleteIntent` |

---

## 16. Settings Keys Reference

All stored in `UserDefaults.standard` unless noted.

| Key | Type | Purpose |
|---|---|---|
| `LifeTrack.settings.nickname` | `String` | User display name |
| `LifeTrack.settings.themeID` | `String` | Active theme raw value |
| `LifeTrack.settings.avatarVersion` | `Int` | Bumped on avatar change (forces image cache bust) |
| `LifeTrack.settings.animationsEnabled` | `Bool` | UI animation toggle |
| `LifeTrack.settings.colorStrength` | `Double` | Theme color intensity (0.55–1.35) |
| `LifeTrack.settings.binRetentionPeriod` | `String` | `TaskBinRetentionPeriod` raw value |
| `LifeTrack.settings.lastDashboardMessageText` | `String` | Prevents dashboard message repetition |
| `LifeTrack.settings.claudeAPIKey` | `String` | Anthropic API key |
| `LifeTrack.settings.lastBackupDate` | `Double` | Timestamp of last iCloud backup |
| `LifeTrack.settings.isProEnabled` | `Bool` | Legacy, unused |
| `LifeTrack.notifications.reminderActionTipPending` | `Bool` | One-time tip trigger |
| `LifeTrack.notifications.reminderActionTipShown` | `Bool` | One-time tip shown |
| `LifeTrack.api.budget.countToday` | `Int` | Daily API call count |
| `LifeTrack.api.budget.date` | `String` | Date the budget counter was last reset |
| `LifeTrack.ai.weeklyDigestCache` | `Data` | `[String: String]` ISO week → narrative, max 12 entries |
| `LifeTrack.ai.emojiCache` | `Data` | `[String: String]` SHA-256(title) → emoji |
| `lifetrack.pendingOpenTaskID` | `String` | Task UUID to open on next foreground |

**Shared `UserDefaults` (app group `group.com.currenttech.LifeTrack`):**

| Key | Purpose |
|---|---|
| `pendingVoiceTaskLaunch` | `Bool` — open voice capture on next foreground |
| `pendingBlankTaskLaunch` | `Bool` — open blank new task on next foreground |
| `pendingFocusLaunch` | `Bool` — open focus view on next foreground |
| `pendingQuickComplete` | `Bool` — trigger quick complete on next foreground |

**Avatar storage:** `~/Library/Application Support/LifeTrack/profile-avatar.jpg` (640×640 JPEG, 88% quality, `.atomicWrite`).

---

## 17. Privacy & Security

### API Key

The Anthropic API key is stored in `UserDefaults.standard` — **not** in the Keychain. This means the key is stored in plaintext in the app's sandboxed UserDefaults plist. For a production app handling sensitive keys, Keychain would be more appropriate.

### App Snapshot Cover

On backgrounding, a `UIHostingController` with `SplashScreenView` (no animation) is added as a UIKit overlay to cover the app screenshot in the app switcher. On foregrounding, it fades out and is removed. Tag: `987654`.

### File Protection

All attached documents are saved with `.completeFileProtection` — inaccessible when the device is locked.

### No Server-Side Validation

StoreKit 2 transactions are validated client-side via `Transaction.currentEntitlements`. There is no receipt validation server.

---

## 18. Extensions

### Control Widget Extension (`LifeTrackControlWidget`)

4 `StaticControlConfiguration` `ControlWidget` controls for iOS Control Center. Each uses a static `ControlValueProvider` (always `false`). Blue tint for task controls, green for complete.

### Notification Content Extension (`LifeTrackNotificationContentExtension`)

Rich notification UI for `LIFETRACK_TASK_REMINDER` category. Renders custom task details in the expanded notification view.

### Share Extension (`LifeTrackShareExtension`)

Captures shared text or file attachments from any app. Writes `SharedInboxPayload` JSON files to the app group inbox. `SharedInboxImporter.drain(context:)` processes these on next app launch.

---

## 19. Utilities & Component Library

### Buttons (`LifeTrackButtons.swift`)

| Component | Description |
|---|---|
| `LifeTrackPressableButtonStyle` | Scale + opacity on press (animated) |
| `LifeTrackPrimaryButton` | Gradient fill |
| `LifeTrackSecondaryButton` | Card fill |
| `PrimaryFloatingButton` | 62pt circle FAB |
| `QuickActionButton` | Horizontal pill with icon + title/subtitle |

### Cards / Layout

| Component | Description |
|---|---|
| `SectionCardView` | Generic card with rounded corners, hairline border, shadow |
| `StatCardView` | 2×2 grid stat card |
| `LifeTrackCardModifier` | Padding + rounded rect background + hairline + shadow (r=13, y=8) |

### Overlays (`TaskSafetyOverlays.swift`)

| Component | Trigger | Duration |
|---|---|---|
| `LifeTrackConfirmationOverlay` | Re-opening completed task | Manual dismiss |
| `TaskBinUndoToast` | Task moved to bin | 5s auto-dismiss |
| `TaskRestoredToast` | Task restored from bin | 2.4s auto-dismiss |
| `ReminderActionTipToast` | First notification permission | 6s auto-dismiss |
| `StreakCelebrationBanner` | Habit completion | 2.8s auto-dismiss |

### Other Utilities

| File | Purpose |
|---|---|
| `LifeTrackHaptics.swift` | `UIImpactFeedbackGenerator(.light)` wrapper |
| `LifeTrackLogoView.swift` | Custom branded logo |
| `CategoryChipView.swift` | Category icon + name pill |
| `ProfileAvatarView.swift` | Round avatar with initials fallback, optional edit badge |
| `EmptyStateView.swift` | Centered message + "Create Task" CTA |
| `VoiceLevelMeterView.swift` | Animated audio level bars |
| `RecordingButtonIcon.swift` | Pulsing mic button |

---

*End of document.*
