/// Access codes used to provision roles for this internal team app.
///
/// These are *fallback* defaults so a fresh project works out of the box. The
/// live values are read at runtime from Firestore `config/app`
/// (`managerMasterCode` / `superAdminMasterCode`), so the owner can change them
/// from the console without shipping a new build — see [Store].
///
/// NOTE: This is "internal-team" security, the same posture as the old manager
/// password. For production, verify codes in a Cloud Function with the Admin SDK
/// so the secret never reaches the browser and roles can't be self-elevated.
/// The "admin password" a person types to create a Manager account.
const kDefaultManagerMasterCode = 'iggy-admin';

/// Separate code that creates a Super Admin account.
const kDefaultSuperAdminMasterCode = 'iggy-super';

/// Firestore field names on the `config/app` document.
const kManagerMasterCodeField = 'managerMasterCode';
const kSuperAdminMasterCodeField = 'superAdminMasterCode';
