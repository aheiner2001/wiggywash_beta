# Wiggy Wash — Feature Build Prompts

> **How to use this file.** This is an executable prompt script for the AI agent.
> Run it in the chat and the agent will work through the phases **in order**.
> Each phase is a self-contained prompt: a goal, exactly what to build, and the
> acceptance criteria to check before moving on. You can run the whole file at
> once, or paste a single phase to do just that piece.

---

## Vision (the end state we are building toward)

> Build a Firebase-powered web app with **role-based authentication (Super Admin,
> Manager, Employee)**, **license plate recognition integration**, and
> **auto-generated reports** — replacing manual spreadsheets with a scalable
> system that can grow from **one pilot location to all 155 sites** before
> handing full control over to the client.

We are NOT building all of that in one shot. The phases below take the current
single-location app there incrementally.

> **About the Firebase steps.** Each phase has a **"Firebase console steps (you
> do these by hand)"** block. The agent writes the code, but these are the
> point-and-click changes *you* must make in the [Firebase console](https://console.firebase.google.com)
> (and a few CLI commands) for that phase to actually work. A full consolidated
> checklist is at the bottom of this file under **"Firebase setup checklist."**

---

## Firebase prerequisites (do this once, before Phase 1)

- Confirm which Firebase project this app points at: open
  `lib/firebase_options.dart` and note the `projectId`. All console work below
  happens in **that** project.
- Install/refresh tooling locally: `npm i -g firebase-tools` then
  `firebase login` and `firebase use <projectId>`.
- **Upgrade the project to the Blaze (pay-as-you-go) plan.** Cloud Functions and
  outbound email (Phases 4 and 9) require Blaze. Set a budget alert so it stays cheap.
- In **Build → Firestore Database**, confirm a database exists (create in
  production mode if not).

---

## Current state (what already exists — read before building)

The agent must read these files first to ground every change:

- `lib/main.dart` — boots Firebase, does **anonymous** sign-in, routes by role.
- `lib/services/store.dart` — the single data layer. Today it uses **flat**
  Firestore collections (`submissions`, `workers`, `config/prices`,
  `config/settings`) with a local-storage fallback.
- `lib/models/profile.dart` — `UserRole { employee, manager }` only. Profile is
  stored **on-device only** (no real account).
- `lib/config/auth_config.dart` — managers are gated by a hardcoded client-side
  password `iggy`. This is a placeholder to be replaced.
- `lib/models/scorecard_config.dart` — static sections
  `WashSection { membership, single, shop }` and the `kLineItems` list / `PriceBook`.
- `lib/screens/onboarding_screen.dart` — first-run name/PIN picker + manager
  password entry.
- `lib/screens/manager_screen.dart`, `pricing_screen.dart`, `workers_screen.dart` —
  manager dashboard, edit prices, team roster.

### Global rules for every phase

1. **Keep the app working at every step.** Run `flutter analyze` after each
   phase and fix all errors before moving on. Preserve the existing
   local-storage fallback path so the app still runs if Firebase is down.
2. **Route all data access through `Store`** (`lib/services/store.dart`). Do not
   sprinkle Firestore calls across screens.
3. **Match the existing style** — theme tokens in `lib/theme.dart`, `AppCard`,
   `TextStyles`, `showStoreMessage`, `AnimatedBuilder(animation: Store.instance)`.
4. **Comments explain intent, not mechanics** (follow the tone already in the repo).
5. When a phase changes the Firestore schema, also update/author the security
   rules and note any required composite indexes.
6. At the end of each phase, output: what changed, files touched, any new
   Firestore structure/rules, and manual setup steps the owner must do in the
   Firebase console.

---

## Phase 1 — Multi-location data model (scalability foundation)

**Goal:** Restructure data so everything is scoped to a location, allowing growth
from 1 pilot site to 155 sites without rework.

**Build:**
- Introduce a `locations` Firestore collection. Each location doc has at least:
  `id`, `name`, `city`, `active` (bool), `createdAt`.
- Re-scope all existing per-site data under each location:
  `locations/{locationId}/submissions`, `.../workers`, `.../config/prices`,
  `.../config/settings`.
- Add a `Location` model (`lib/models/location.dart`).
- In `Store`, add a notion of the **active location** the user is operating in,
  and make every read/write (submissions, workers, prices, settings) target that
  location's subcollections instead of the flat top-level collections.
- Write a small one-time **migration helper** that copies today's flat
  collections into a default location doc (e.g. "Omaha — Pilot") so no data is lost.

**Firebase console steps (you do these by hand):**
- **Firestore → Rules:** publish the new location-scoped rules the agent
  generates (everything moves under `locations/{locationId}/...`). Paste them in
  **Firestore Database → Rules → Publish**, or run `firebase deploy --only firestore:rules`.
- **Firestore → Indexes:** if the agent reports any "composite index required"
  link in the console error, click it to auto-create the index (e.g. for the
  `submissions` `orderBy('submittedAt')` query now inside each location).
- **Create the pilot location doc:** in **Firestore Database → Data**, confirm the
  migration created a `locations` collection with the default doc
  (e.g. "Omaha — Pilot"). If you run migration manually, add that doc yourself.
- No console changes needed for the local-storage fallback.

**Acceptance criteria:**
- All existing manager/employee flows work unchanged, now reading/writing under a
  single default location.
- Adding a second location in Firestore yields fully isolated data.
- `flutter analyze` is clean.

---

## Phase 2 — Real authentication (Google / Apple) + dedicated sign-in screen

**Goal:** Replace anonymous auth with real accounts. The website should open
directly to a **sign-in screen**.

**Build:**
- Add **Google** and **Apple** sign-in via Firebase Auth (web first; keep iOS in
  mind). Add required packages and platform config; document the Firebase console
  + OAuth setup steps needed.
- Replace `signInAnonymously()` in `lib/main.dart` with an auth-state-driven
  router: if no authenticated user → show the **Sign-In screen**; if signed in →
  resolve the user's role/location and route accordingly.
- Create `lib/screens/sign_in_screen.dart` with "Continue with Google" and
  "Continue with Apple" buttons, branded with `BrandHeader` and `lib/theme.dart`.
- Store each authenticated user in a `users/{uid}` Firestore doc:
  `uid`, `email`, `displayName`, `role`, `locationId(s)`, `createdAt`.
- The old `onboarding_screen.dart` name/PIN flow is superseded; keep or retire it
  based on the new flow (employees are now resolved by email — see Phase 4).

**Firebase console steps (you do these by hand):**
- **Authentication → Sign-in method → enable Google.** Set the project support
  email. (Google works out of the box on web.)
- **Authentication → Sign-in method → enable Apple.** This requires an Apple
  Developer account: create a Services ID, key, and configure the OAuth
  redirect/return URL Firebase shows you, then paste the Team ID / Key ID / Service
  ID / private key into the Firebase Apple provider config.
- **Authentication → Settings → Authorized domains:** add the domain(s) you serve
  the web app from (e.g. `localhost`, your Firebase Hosting domain, and any custom
  domain). Google/Apple sign-in is rejected from non-authorized domains.
- **Google Cloud console → APIs & Services → Credentials:** if Apple/Google needs a
  configured OAuth consent screen, fill it in (app name, support email, logo).
- **Firestore → Rules:** publish rules so a signed-in user can read/write only
  their own `users/{uid}` doc.
- (iOS later) add the reversed-client-id URL scheme + `GoogleService-Info.plist`
  when you build the iOS target.

**Acceptance criteria:**
- Visiting the site with no session lands on the sign-in screen.
- Signing in with Google/Apple creates/loads a `users/{uid}` doc and routes by role.
- Sign-out returns to the sign-in screen.

---

## Phase 3 — Role-based access: Super Admin, Manager, Employee + master code

**Goal:** Expand from two roles to three and define how managers are created.

**Build:**
- Extend roles to `UserRole { superAdmin, manager, employee }` in
  `lib/models/profile.dart` (+ everywhere it's switched on, e.g. `main.dart`).
- **Manager creation by master code:** retire the hardcoded `iggy` password. A
  signed-in user who enters the correct **master code** is promoted to Manager
  (and assigned to a location). Store the master code securely (Firebase
  Remote Config or a server-checked value / Cloud Function) rather than
  hardcoding it in client source.
- **Super Admin** is the top role: can create/disable locations, create managers,
  and assign managers to locations. Add a Super Admin screen
  (`lib/screens/super_admin_screen.dart`) for managing locations and managers.
- Routing in `main.dart`:
  `superAdmin → SuperAdminScreen`, `manager → ManagerScreen`,
  `employee → ScorecardScreen`.

**Firebase console steps (you do these by hand):**
- **Store the master code, not in client source.** Recommended:
  **Remote Config** → add a parameter (e.g. `manager_master_code`) with your secret
  value, and Publish. (Better still, have the agent verify it inside a Cloud
  Function so the code never ships to the browser — if so, set it as a function
  config/secret instead: `firebase functions:secrets:set MANAGER_MASTER_CODE`.)
- **Seed the first Super Admin.** There is no UI to make the very first one. In
  **Firestore → Data**, open your own `users/{uid}` doc (sign in once to create it)
  and set `role: "superAdmin"` manually. If using custom claims instead, run the
  agent-provided admin script / Cloud Function once to set the claim, then sign out
  and back in.
- **Firestore → Rules:** publish role-aware rules (only Super Admin can write
  `locations` docs and set other users' `role`; managers limited to their own
  `locationId`).
- If the agent uses **custom claims** for roles, no extra console click is needed
  beyond running its set-claim function once per admin/manager.

**Acceptance criteria:**
- A user can become a Manager only via the master code (no client-side password).
- Super Admin can create a location and assign a manager to it.
- Each role lands on the correct screen after sign-in.

---

## Phase 4 — Managers add approved employee emails (allowlist) + email invites

**Goal:** Each site's manager controls who can join, by email. Use Firebase cloud
services to send the invites.

**Build:**
- Replace/extend the name-based roster (`workers`) so a manager adds **approved
  employee emails** for their location:
  `locations/{locationId}/approvedEmails/{email}` with `status`
  (`invited` / `active`), `invitedAt`.
- On sign-in (Phase 2), an authenticated user's email is checked against their
  location's approved list:
  - On the approved list → granted the Employee role for that location.
  - Not approved → friendly "ask your manager to add your email" screen.
- **Invites via Firebase:** when a manager adds an email, send an invite email
  using a Firebase Cloud Function (e.g. with an email provider, or Firebase Auth
  email action links). Document the Cloud Function + provider setup.
- Update `workers_screen.dart` (or a new "Team / Approved Emails" screen) so the
  manager adds/removes emails and sees invite status.

**Firebase console steps (you do these by hand):**
- **Be on the Blaze plan** (required for Cloud Functions + outbound email).
- **Deploy the invite Cloud Function:** from the project root run
  `firebase deploy --only functions` (the agent will scaffold `functions/`). First
  time, enable the **Cloud Functions** and **Cloud Build** APIs if prompted.
- **Pick an email path and configure it:**
  - *Easiest:* install the **"Trigger Email from Firestore"** Firebase Extension
    (**Build → Extensions**), connect an SMTP provider (e.g. SendGrid/Mailgun/Gmail
    SMTP), and set the mail collection it watches. The function just writes mail docs.
  - *Or* set your provider's API key as a function secret:
    `firebase functions:secrets:set SENDGRID_API_KEY` (or similar).
- **Customize Firebase Auth email templates** under **Authentication → Templates**
  if you use Auth action links for the invite.
- **Firestore → Rules:** publish rules so only a location's manager can write that
  location's `approvedEmails`, and a user can read whether their own email is approved.
- **Firestore → Indexes:** create any composite index the console flags for the
  approved-emails / invite-status queries.

**Acceptance criteria:**
- A manager adds an email; an invite email is sent.
- That person can sign in with Google/Apple using the approved email and is
  auto-assigned Employee for that location.
- Removing an email revokes future access.

---

## Phase 5 — Per-location toggleable scorecard sections (on Edit Prices)

**Goal:** Let each site's manager choose which sections employees see, so sites
without a shop don't show **Shop Sales** (and similar).

**Build:**
- Add per-location **section visibility** settings (e.g. toggle Membership Tally,
  Single Washes, Shop Sales). Persist under
  `locations/{locationId}/config/settings` (extend the existing settings doc).
- Surface the toggles on the **Edit Prices** page (`lib/screens/pricing_screen.dart`)
  — a switch per `WashSection` controlling whether it's enabled for this location.
- Honor the toggles everywhere a section is rendered: the employee scorecard
  (`lib/screens/scorecard_screen.dart`), summary, manager dashboard breakdown,
  and reports. Hidden sections must not appear for employees and must not count
  toward totals for that location.
- Drive section rendering from the live settings (replace hardcoded
  `WashSection.values` loops where appropriate).

**Firebase console steps (you do these by hand):**
- **Firestore → Rules:** confirm/publish that managers can write their location's
  `config/settings` doc and employees can read it. (Likely already covered by
  Phase 1 rules — re-publish if the agent changed them.)
- No other console changes; the section flags are just new fields on the existing
  settings doc, created automatically on first save.

**Acceptance criteria:**
- Turning off "Shop Sales" for a location hides it from that location's employees
  and totals, while other locations are unaffected.
- Settings sync live across devices (same pattern as the existing see-all toggle).

---

## Phase 6 — Edit / remove submissions (manager data cleanup)

**Goal:** Let a location's manager fix or delete submissions — e.g. remove entries
from a test account.

**Build:**
- Add a manager UI to **edit** a submission's counts/BA goal and to **delete**
  individual submissions, scoped to the manager's location. `Store` already has
  `deleteSubmission`; add an `updateSubmission` and wire both into the dashboard
  (`lib/screens/manager_screen.dart`, e.g. per-shift row actions in `_Breakdown`).
- Guard edit/delete behind the Manager/Super Admin role in both the UI and the
  Firestore security rules.
- Keep an audit trail field (e.g. `editedBy`, `editedAt`) on edited submissions.

**Firebase console steps (you do these by hand):**
- **Firestore → Rules:** publish rules allowing `update`/`delete` on a location's
  `submissions` only for that location's Manager (or Super Admin), and denying it
  for employees. Deploy with `firebase deploy --only firestore:rules`.
- No other console changes (the `editedBy`/`editedAt` fields are created on save).

**Acceptance criteria:**
- A manager can edit a submission's numbers and see totals recompute live.
- A manager can delete a specific submission (e.g. a test entry).
- Employees cannot edit/delete submissions.

---

## Phase 7 — Submission approval + Excel export (replace manual spreadsheets)

**Goal:** A dedicated manager page where approved submissions flow into an
Excel-style sheet, with a manual-insert option for paper-scorecard entries.

**Build:**
- Add an **approval** state to submissions (`pending` / `approved`). Build a new
  manager page (`lib/screens/approvals_screen.dart`) listing submissions for the
  location with Approve / Reject actions.
- Approved submissions populate an **Excel-type sheet** view (spreadsheet-style
  grid: one row per submission, columns per line item + totals).
- **Manual insert:** a form on this page to add a submission by hand (for someone
  who used a paper scorecard), which enters the same approval/sheet pipeline.
- **Export to Excel:** generate a real `.xlsx` (or CSV) download of the approved
  rows for the selected day/range. Add the needed package and a download action.

**Firebase console steps (you do these by hand):**
- **Firestore → Rules:** allow only Manager/Super Admin to change a submission's
  `status` (`pending`/`approved`) and to create manual-insert submissions.
- **Firestore → Indexes:** create the composite index the console flags for the
  approvals list (e.g. filter by `status` + `orderBy submittedAt`).
- Excel/CSV export runs client-side (browser download), so **no** Cloud Storage or
  extra console setup is required. If the agent instead generates the file via a
  Cloud Function, `firebase deploy --only functions` and (if it stores files)
  enable **Build → Storage**.

**Acceptance criteria:**
- Manager can approve/reject submissions; only approved ones hit the sheet.
- Manager can manually add a row that behaves like a normal approved submission.
- Manager can export the approved data to an Excel/CSV file.

---

## Phase 8 — Challenges with rewards (manager settings)

**Goal:** Managers can create a challenge for their site with a reward.

**Build:**
- Add a **challenges** feature in manager settings:
  `locations/{locationId}/challenges/{id}` with `title`, `description`,
  `cadence` (`daily` / `weekly` / `monthly` / `quarterly`), `metric` (what's being
  measured — e.g. memberships sold, BA %, revenue), `target`, `reward`,
  `startDate`, `endDate`, `active`.
- Manager UI to create/edit/end a challenge (a new settings screen or section).
- Employee-facing display: show the active challenge, its reward, and live
  progress toward the target on the scorecard/summary.
- Compute progress from existing submission data for the cadence window.

**Firebase console steps (you do these by hand):**
- **Firestore → Rules:** allow only the location's Manager/Super Admin to
  create/edit/end `challenges`; employees read-only.
- **Firestore → Indexes:** create any composite index the console flags for
  active-challenge queries (e.g. `active == true` + date range).
- No other console changes (progress is computed from existing submissions).

**Acceptance criteria:**
- A manager creates a weekly challenge with a reward; employees see it and their
  progress.
- Challenges are per-location and respect the chosen cadence window.

---


---

## Firebase setup checklist (everything you do by hand, in one place)

Tick these off as you go. "Console" = Firebase console UI; "CLI" = terminal.

**One-time (before Phase 1)**
- [ ] Note the `projectId` in `lib/firebase_options.dart`.
- [ ] CLI: `npm i -g firebase-tools`, `firebase login`, `firebase use <projectId>`.
- [ ] Console: upgrade to **Blaze** plan + set a budget alert.
- [ ] Console: confirm **Firestore Database** exists.

**Phase 1 — multi-location**
- [ ] Console/CLI: publish location-scoped **Firestore rules**.
- [ ] Console: create any **composite index** the error links request.
- [ ] Console: verify the migrated default `locations/<pilot>` doc exists.

**Phase 2 — auth + sign-in**
- [ ] Console: **Authentication → enable Google** (set support email).
- [ ] Console: **Authentication → enable Apple** (Apple Developer Service ID, key,
      return URL).
- [ ] Console: **Authentication → Settings → Authorized domains** (localhost +
      hosting + custom domain).
- [ ] Console: configure OAuth consent screen if prompted.
- [ ] Console/CLI: publish rules for `users/{uid}` self-access.

**Phase 3 — roles + master code**
- [ ] Console: store master code in **Remote Config** (or CLI
      `firebase functions:secrets:set MANAGER_MASTER_CODE`).
- [ ] Console: manually set your own `users/{uid}.role = "superAdmin"` (first admin).
- [ ] Console/CLI: publish role-aware rules.

**Phase 4 — approved emails + invites**
- [ ] CLI: `firebase deploy --only functions` (enable Functions/Cloud Build APIs).
- [ ] Console: install **Trigger Email** extension + connect SMTP provider, OR
      CLI set provider API key as a secret.
- [ ] Console: customize **Authentication → Templates** (if using action links).
- [ ] Console/CLI: publish `approvedEmails` rules + any index.

**Phase 5 — toggleable sections**
- [ ] Console/CLI: re-publish settings rules if changed (usually none).

**Phase 6 — edit/remove submissions**
- [ ] Console/CLI: publish rules allowing manager `update`/`delete` on submissions.

**Phase 7 — approval + Excel**
- [ ] Console/CLI: publish rules for `status` changes + manual inserts.
- [ ] Console: create the approvals composite index when flagged.
- [ ] (Only if server-side export) enable **Storage** + deploy functions.

**Phase 8 — challenges**
- [ ] Console/CLI: publish `challenges` rules + any index.

