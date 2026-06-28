# Wiggy Wash — How-To Guide

Simple step-by-step instructions for everyday tasks. Roles: **Super Admin**
(runs everything), **Manager** (runs one location), **Employee** (fills out
scorecards).

> Default codes: **Admin password (creates Managers) = `iggy-admin`**,
> **Super Admin code = `iggy-super`**.
> Change these any time (see "Change the access codes" below).

---

## How sign-in works

- **Employees** do NOT use a Google account. They open the app, type their
  **site code**, then pick their **name** from the list. (They stay signed in on
  that device until they switch user.)
- **Managers / Super Admins** use **Google**, reached from the **"Manager sign
  in"** button on the landing page.

---

## Sign in as an employee

1. Open the app. You land on **"Enter site code."**
2. Type your location's **site code** (ask your manager) and tap **Continue**.
3. Tap your **name** in the list. If your name needs an entry code, type it.
4. Tap **Start scorecard**. You're in.

To switch to a different name: tap the **account icon** → **Switch user**.

---

## Become a Manager / create your account

1. On the landing page, tap **Manager sign in**.
2. Tap **Create a manager account**.
3. Type the **admin password** (`iggy-admin`).
4. Tap **Continue with Google** and choose the Google account you'll use.
5. Under **Site**, either:
   - Pick an existing site from the dropdown, **or**
   - Choose **"+ Create a new site"**, then type its **name** and a **site code**
     for your employees.
6. Tap **Finish**. You now see your **Team Dashboard**. From now on, signing in
   with that Google account always takes you straight here.

---

## Sign in as an existing Manager

1. Landing page → **Manager sign in** → **Continue with Google**.
2. You go straight to your **Team Dashboard**.

---

## Become a Super Admin (no sign-in needed)

1. On the landing page, tap **Admin access**.
2. Type the **Super Admin code** (`iggy-super`) and tap **Enter**.
3. You go straight to the **Super Admin** screen (the list of all locations).
   No Google account required — the access is remembered on this device until
   you sign out.

---

## Set or change your site code (Manager)

The site code is what employees type to reach your roster.

1. Team Dashboard → tap the **people icon** (top right).
2. At the top, tap the **Site code** card.
3. Type the new code and tap **Save**. Share it with your team.

---

## Add an employee to the roster (Manager)

1. Team Dashboard → **people icon**.
2. Under **Add a worker**, type their **name**.
3. (Optional) Turn on **Require entry code** and set a short code.
4. Tap **Add to roster**. They can now pick their name after entering the site code.

To remove someone: tap the **✕** next to their name. To change/add an entry
code later, tap their name.

---

## Add a location (Super Admin)

1. On the Super Admin screen, tap **Add location** (bottom right).
2. Enter a **Name**, optional **City**, and a **Site code**.
3. Tap **Create**. It appears in the list (the card shows its code).
4. To turn a site on/off, use the **Active** switch on its card.
5. To view/manage a site, tap **Open dashboard** on its card.

---

## Turn scorecard sections on/off (Manager)

Use this when a site doesn't sell something (e.g. no shop).

1. Team Dashboard → tap the **price tag icon** (top right) → **Edit Prices**.
2. At the top, under **"Sections in use at this location,"** toggle
   **Membership Tally / Single Washes / Shop Sales**.
3. Turned-off sections disappear from employees' scorecards and totals.

---

## Edit prices (Manager)

1. Team Dashboard → **price tag icon** → **Edit Prices**.
2. Tap any item.
3. Set a price, or turn off **"Charged item"** to count it without a dollar value.
4. Tap **Save**. Everyone sees the change instantly.

---

## Fix or delete a submission (Manager)

Use this to correct a mistake or remove a test entry.

1. On the Team Dashboard, open an employee's card and expand **Full breakdown**.
2. Next to a shift, tap the **⋮** menu.
3. Choose **Edit** (adjust counts / BA goal, then **Save**) or **Delete**.

---

## Clear a whole day (Manager)

1. Team Dashboard → tap the **calendar icon** to pick the day.
2. Tap the **broom / delete-sweep icon** → confirm **Reset**.
   (This permanently deletes every submission that day.)

---

## Change the access codes (Super Admin)

The codes are read from Firestore so you can change them without a new build.

1. In the [Firebase console](https://console.firebase.google.com) →
   **Firestore Database → Data**.
2. Create (or open) the document **`config` → `app`**.
3. Add/edit fields:
   - `managerMasterCode` — the admin password that creates Managers
   - `superAdminMasterCode` — the Super Admin code
4. Save. New codes take effect next time someone opens the app.

---

## Sign out / switch user (everyone)

1. Tap the **account icon** (top right).
2. Tap **Sign out** (managers) or **Switch user** (employees).
