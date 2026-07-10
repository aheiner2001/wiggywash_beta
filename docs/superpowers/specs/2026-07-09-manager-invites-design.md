# Manager Invites + Sign-in Instructions — Design Spec

**Date:** 2026-07-09  
**Status:** Approved  
**Approach:** Email invite list (Approach 1) — managers and platform admin manage invites; matching Google sign-in grants `companyManager`

## Summary

Make manager Google sign-in self-explanatory, and let company managers (with platform-admin override) add, edit, and remove manager emails for their company. When an invited Google account signs in, the app grants `companyManager` for that company. Unknown Google users see clear “ask your manager to invite this email” copy — no self-serve join. Company pending/active approval stays as today.

## Goals

1. **Clear manager sign-in instructions** — returning managers vs create company vs not invited.
2. **Email invite list** — add Google emails ahead of time; claim on first matching sign-in.
3. **Manage managers** — list, optional display-name edit, remove access.
4. **Platform admin override** — same list/actions on company detail; still Approves/Rejects companies.
5. **Safe remove** — cannot remove the last manager on a company.

## Non-Goals

- Self-serve “request access” or join-by-company-code for managers
- Employee Google accounts / email invites for floor staff
- Sending invite emails (in-app list only; share verbally/Slack)
- Changing employee company-code + name (+ PIN) login
- Multi-company managers on one Google account (v1: one company per manager email)

## Decisions (from brainstorm)

| Topic | Choice |
|-------|--------|
| Who manages managers | **B** — company managers for their company; platform admin can override |
| Unknown Google user | **A** — instructions only; no request-access flow |
| Implementation | **1** — email invite list + claim on sign-in |
| Invite delivery | In-app only (no email send) |

---

## Sign-in copy (`ManagerAuthScreen`)

### Returning managers

> Sign in with the Google account your company invited. After your company is approved, you’ll land on the Team Dashboard.

### Create a new company

> New car wash? Continue with Google, submit your company for approval, then wait for platform approval. You’ll be the first manager.

### Not invited (signed in with Google, no role, not on create path)

> This Google account isn’t a manager yet. Ask a company manager to add **{email}** under Managers, then sign in again.  
> Or choose **Create a new company** if you’re starting a new business.

### Pending company (manager of a still-pending company)

Keep existing waiting UI (`PendingApprovalScreen`); no change to approval semantics.

---

## Data model

### Invites

`companies/{companyId}/managerInvites/{inviteId}`

| Field | Type | Meaning |
|-------|------|---------|
| `email` | string | Lowercased Google email (immutable after create) |
| `displayName` | string? | Optional label; editable |
| `invitedByUid` | string | Who added the invite |
| `invitedByEmail` | string | Inviter email |
| `createdAt` | timestamp | Created |
| `claimedUid` | string? | Set on first successful claim |

Document id may be a slug of the email or auto-id; uniqueness is enforced by querying existing invites for that email under the company before add.

### Live access

`users/{uid}` remains source of truth for session routing:

- `role: companyManager`
- `companyId`
- `email` (lowercased)
- `displayName` (optional)

### Create company

Unchanged batch: pending `Company`, first location, creator `users/{uid}` as `companyManager`.  
**Also** write a `managerInvites` doc for the creator’s email (claimedUid = creator uid) so the Managers list is consistent.

---

## Grant on Google sign-in

After Google auth and `users/{uid}` load/create:

1. If role is `platformAdmin` or `companyManager` → existing routing.
2. Else run a **collection group** query on `managerInvites` where `email ==` signed-in email (normalized).
3. Resolve company for each hit; apply grant rules:
   - Company **active** → eligible.
   - Company **pending** → eligible **only if** `users` is `createdByUid` / already the signup creator (normally already has role from create).
   - Company **suspended** → do not grant; show suspended message.
4. If **exactly one** eligible invite → merge `users/{uid}` with `companyManager` + `companyId`; set invite `claimedUid`.
5. If **zero** → stay on manager auth with **not invited** copy (show their email).
6. If **more than one** eligible → show “Contact support — this email is invited to multiple companies” (rare; out of happy path).

Firestore rules must prevent arbitrary self-assignment of `companyManager` without a matching invite (or platform-admin write).

---

## Remove / edit

| Action | Behavior |
|--------|----------|
| **Add** | Email required; normalize; reject duplicates on same company; optional display name |
| **Edit** | Display name only; email change = remove + re-add |
| **Remove** | Delete invite; if a `users` doc has that email + `companyId`, clear `role` and `companyId` (or delete role fields). User loses dashboard on next refresh/sign-in |
| **Last manager** | Block remove with message: keep at least one manager |

**Company manager:** only their `companyId`; cannot remove self if they are the only manager.  
**Platform admin:** any company; same last-manager guard.

---

## UI

### Team screen — Managers section

- List invites: email, display name, status (Invited / Signed in).
- Add manager (email + optional name).
- Edit name; Remove with confirm.
- Short helper: “They must Continue with Google using this exact address.”

### Platform Admin — company detail

- Existing Approve / Reject / Suspend / View.
- **Managers** list with same add/edit/remove (override).

### Manager auth

- Apply copy from section above on sign-in / create / not-invited states.

---

## Architecture

| Area | Touchpoints |
|------|-------------|
| Auth copy | `lib/screens/manager_auth_screen.dart` |
| Managers UI | `lib/screens/team_screen.dart` (+ optional extract widget) |
| Platform admin | `lib/screens/platform_admin_screen.dart` |
| Store | Invite CRUD; claim on Google sign-in path; remove clears user role |
| Model | Small `ManagerInvite` type |
| Rules | `firestore.rules` — invites + constrained user role writes |
| Index | Collection group index on `managerInvites.email` |

### Error handling

- Duplicate invite → inline error.
- Last manager remove → blocked.
- Persist failures → `showStoreMessage`.
- Email mismatch → copy stresses exact Google address.

---

## Testing

- Unit: email normalize; duplicate detection; last-manager guard; claim eligibility (active vs pending vs suspended).
- Manual: invite → Google sign-in → dashboard; remove → not invited copy; platform admin add/remove; create company still pending → waiting screen; approve company → dashboard.

## Success criteria

- New/returning managers understand what to do from the sign-in page alone.
- Invited email can become a manager without Firestore console edits.
- Managers and platform admin can add/edit/remove managers; last manager cannot be removed.
- Uninvited Google users cannot self-promote to manager.
