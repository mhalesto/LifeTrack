# LifeTrack — AI Privacy Review

Snapshot of what leaves the device when the user enables AI features (Claude API).
Scope: every call site of `ClaudeAPIClient.shared.send(...)`.

> Generated 2026-04-25 against branch `feature/money-tracking-and-budget-actuals`.

---

## 1. Endpoint and credential handling

| Item | Detail | Risk |
|---|---|---|
| Endpoint | `https://api.anthropic.com/v1/messages` (HTTPS, TLS) | low |
| Auth header | `x-api-key` from `UserDefaults.standard` (key `LifeTrack.settings.claudeAPIKey`) | **medium — key not in Keychain** |
| Network session | Dedicated `URLSession`, 30s request / 60s resource timeout | low |
| Response cache | In-memory (`responseCache: [String: CacheEntry]`), keyed by SHA-256 of (model + system + user + maxTokens). Cleared via `clearResponseCache()` | low |
| Daily budget | `APIBudgetTracker.shared.consumeOne()` enforces a per-day cap | low |

**Recommendation:** Move `claudeAPIKey` into the iOS Keychain. UserDefaults is plain text on disk and can be read from a backup. (`SubscriptionManager` is a sensible place to add a small Keychain wrapper since it already brokers entitlement state.)

---

## 2. What each call site actually sends

### `MoneyAIAdvisor.analyze(...)` and `.deepAnalyze(...)`
- **Sends:** monthly aggregates (planned/actual income, spending, savings), top-N category names + amounts, **bill titles** ("Rent", "Vodacom Fibre"), days remaining, currency code.
- **Does not send:** account numbers, transaction-level entries, names, addresses.
- **Risk:** low-medium. Bill titles can hint at services in use. Consider an opt-in "anonymise bill names" toggle that replaces titles with `"Bill #1"` style placeholders before sending.

### `AITaskAdvisor.suggest(...)`
- **Sends:** up to 25 task `title`s, category, due date, priority, estimated duration.
- **Does not send:** notes, financial fields, document text, location.
- **Risk:** low. Titles can be sensitive (medical appointments, legal). Worth surfacing this in onboarding.

### `SmartSchedulingAdvisor.optimize(...)`
- **Sends:** task summaries (title/category/due/priority/duration) + Apple Calendar **busy windows** with titles intentionally omitted (commented "titles hidden for privacy" — good).
- **Does not send:** event titles, attendees, location.
- **Risk:** low. Already does the right thing.

### `AIVoiceTaskEnhancer.enhance(transcript:)`
- **Sends:** raw voice transcript verbatim.
- **Risk:** **medium-high.** A voice memo can mention names, amounts, addresses, medical context, etc. The user controls what they say, but most users will not realize the transcript is sent to a third party.
- **Recommendation:**
  1. Add a one-time disclosure on first voice-task creation when AI is enabled.
  2. Optionally pre-process to redact obvious patterns (phone numbers, emails, ID numbers) before sending.

### `WeeklyDigestService.fetchNarrative(...)`
- **Sends:** weekly aggregate counts (completed/rescheduled/new ideas/next-week count), **top category name**, longest streak, week range.
- **Risk:** low.

### `TaskEmojiService.emoji(forTitle:)`
- **Sends:** task title only.
- **Risk:** low (same surface as `AITaskAdvisor`).

---

## 3. What never leaves the device

These call sites either don't exist or were deliberately not wired:

- Bank statement parsing (`BankStatementImport.swift`, `BankStatementReader.swift`) is fully on-device; **no transactions are sent to Claude**.
- Receipt OCR (`ReceiptParser.swift`, new in this branch) is on-device.
- Document analysis (`DocumentAnalysisManager.swift`) — verify locally; not in scope of this audit.
- Health/energy data (`HealthKitEnergyReader.swift`) — only an `EnergyLevel` label is sent by `SmartSchedulingAdvisor`, never raw HealthKit samples.
- Subscription receipts and StoreKit transactions — handled in `SubscriptionManager`, never sent to Claude.

---

## 4. Suggested follow-up tasks

| # | Item | Effort |
|---|---|---|
| 1 | Migrate Claude API key from `UserDefaults` to Keychain | S |
| 2 | First-use disclosure modal listing exactly what each AI feature sends | S |
| 3 | Settings toggle: "Anonymise bill names in AI prompts" (replace titles before send) | S |
| 4 | Pre-redaction pass for voice transcripts (phone/email/ID-number regex) | M |
| 5 | Anthropic privacy & retention link in Settings → AI section | XS |
| 6 | Logging audit: confirm no `print`/`NSLog` includes user-content payloads (`AITaskAdvisor` uses `NSLog(...prefix(400)...)` for parsed JSON — log the response content, not user input) | S |

---

## 5. One-liner summary

LifeTrack's AI surface is **conservative by design** — it sends summaries and titles, never bank transactions, calendar event titles, or health samples. The two sharp edges are: (a) the API key sits in plain UserDefaults, and (b) voice transcripts are sent verbatim. Both are easy fixes.
