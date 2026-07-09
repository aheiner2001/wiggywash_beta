import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../config/auth_config.dart';
import '../models/app_user.dart';
import '../models/challenge.dart';
import '../models/company.dart';
import '../models/location.dart';
import '../models/profile.dart';
import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../models/worker.dart';
import 'company_migration.dart' as company_migration;

/// Where the app should send the user right now.
enum AppView {
  /// Resolving auth / saved state.
  loading,

  /// Landing page: enter a site code (employees) or open manager sign-in.
  landing,

  /// Manager sign-in / create-account screen.
  managerAuth,

  /// Employee scorecard (signed in via site code + name).
  employee,

  /// Manager dashboard.
  manager,

  /// Platform-admin console.
  platformAdmin,
}

/// The app's single data seam.
///
/// **Employees** never use a personal login: they enter a per-site **site code**
/// and pick their **name** from the roster. Under the hood the app is signed in
/// **anonymously** so Firestore reads/writes still work. Their selection is
/// remembered on the device.
///
/// **Managers / Super Admins** sign in with **Google**, backed by a
/// `users/{uid}` doc that holds their role + location.
///
/// All operational data is scoped to a location:
/// `locations/{locationId}/{submissions,workers,config}`.
class Store extends ChangeNotifier {
  Store._();
  static final Store instance = Store._();

  static const _kSubmissions = 'ww_submissions';
  static const _kPrices = 'ww_prices';
  static const _kDraftPrefix = 'ww_draft_';
  static const _kSettings = 'ww_settings';
  static const _kActiveLocation = 'ww_active_location';
  static const _kEmployeeProfile = 'ww_employee_profile';
  static const _kCompanies = 'companies';
  static const _kActiveCompany = 'ww_active_company';
  static const _kEmployeeCompanyCode = 'ww_employee_company_code';

  static const _kLocations = 'locations';
  static const _kUsers = 'users';
  static const _kSubmissionsCol = 'submissions';
  static const _kWorkersCol = 'workers';
  static const _kConfigCol = 'config';
  static const _kPricesDoc = 'prices';
  static const _kSettingsDoc = 'settings';
  static const _kItemsDoc = 'items';
  static const _kAppConfigDoc = 'app';

  SharedPreferences? _prefs;
  bool _cloud = false;
  bool _ready = false;

  // ---- Auth ----
  fb.FirebaseAuth? _auth;
  fb.User? _authUser;
  AppUser? _appUser; // users/{uid} for managers/super admins
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;

  // Employee identity (local, device-remembered).
  String? _employeeName;
  String? _employeeLocationId;

  // Navigation flags driven by the user.
  bool _showManagerAuth = false;
  bool _pendingManagerCreate = false;

  // A manager/super-admin temporarily using the employee scorecard under a
  // chosen name, without losing their account session.
  bool _actingAsEmployee = false;
  String? _actingName;

  // ---- Company ----
  String? _activeCompanyId;
  Company? _activeCompany;
  List<Location> _companyLocations = [];

  // ---- Locations ----
  List<Location> _locations = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _locationsSub;
  String? _activeLocationId;

  // ---- Location-scoped data ----
  List<Submission> _submissions = [];
  List<Worker> _workers = [];
  bool _subsLoading = false;
  bool _seeAll = false;
  Challenge? _challenge;
  Map<WashSection, bool> _enabledSections = {
    for (final s in WashSection.values) s: true,
  };
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _workersSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _pricesSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _settingsSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _itemsSub;

  /// Raw line-item customization for the active location.
  Map<String, dynamic> _itemConfig = {};

  // ---- Master codes (Firestore config/app, with fallback defaults) ----
  String _managerCode = kDefaultManagerMasterCode;
  String _superCode = kDefaultSuperAdminMasterCode;

  // ---- Public getters --------------------------------------------------

  bool get isCloud => _cloud;
  bool get seeAll => _seeAll;

  /// True from the moment a location is bound until its first submissions
  /// snapshot arrives — drives loading skeletons.
  bool get submissionsLoading => _subsLoading;

  /// The active team challenge for this location, if any.
  Challenge? get challenge => _challenge;
  AppUser? get appUser => _appUser;
  String? get activeCompanyId => _activeCompanyId;
  Company? get activeCompany => _activeCompany;
  List<Location> get companyLocations => List.unmodifiable(_companyLocations);
  List<Location> get locations => List.unmodifiable(_locations);
  String? get activeLocationId => _activeLocationId;
  bool get pendingManagerCreate => _pendingManagerCreate;

  /// True when a signed-in manager/super-admin is filling out a scorecard.
  bool get isActingAsEmployee => _actingAsEmployee && _actingName != null;

  Location? get activeLocation {
    for (final l in _locations) {
      if (l.id == _activeLocationId) return l;
    }
    return null;
  }

  /// True when a real (non-anonymous, e.g. Google) account is signed in.
  bool get _isGoogleUser =>
      _authUser != null && !_authUser!.isAnonymous;

  /// The provisioned role from `users/{uid}` (managers via Google, super admins
  /// via the admin code on the anonymous session). Null = no role yet.
  UserRole? get _role => _appUser?.role;

  List<Submission> get submissions => List.unmodifiable(_submissions);

  /// Approved scorecards only — what counts toward manager totals & Master Sheet.
  List<Submission> get approvedSubmissions =>
      List.unmodifiable(_submissions.where((s) => s.approved));

  /// Pending scorecards awaiting manager approval (newest first).
  List<Submission> get pendingSubmissions {
    final list = _submissions.where((s) => !s.approved).toList()
      ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
    return List.unmodifiable(list);
  }

  List<Worker> get workers {
    final list = List<Worker>.from(_workers);
    list.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(list);
  }

  List<WashSection> get enabledSections =>
      orderedSections().where(isSectionEnabled).toList();

  bool isSectionEnabled(WashSection section) => _enabledSections[section] ?? true;

  /// Derived profile for the employee/manager screens.
  Profile? get profile {
    if (isActingAsEmployee) {
      return Profile(name: _actingName!, role: UserRole.employee);
    }
    switch (view) {
      case AppView.employee:
        return Profile(name: _employeeName ?? '', role: UserRole.employee);
      case AppView.manager:
        return Profile(name: _appUser!.name, role: UserRole.companyManager);
      case AppView.platformAdmin:
        final n = _appUser!.name;
        return Profile(name: n.isEmpty ? 'Admin' : n, role: UserRole.platformAdmin);
      default:
        return null;
    }
  }

  /// Where to route right now.
  AppView get view {
    if (!_ready) return AppView.loading;

    // A provisioned role wins — unless they've chosen to fill out a scorecard.
    final role = _role;
    if (role == UserRole.platformAdmin || role == UserRole.companyManager) {
      if (isActingAsEmployee) return AppView.employee;
    }
    if (role == UserRole.platformAdmin) return AppView.platformAdmin;
    if (role == UserRole.companyManager && _appUser!.locationId != null) {
      return AppView.manager;
    }
    // Signed in with Google but no role yet → stay on the manager-auth screen
    // (e.g. mid-create, or a Google account with no manager account).
    if (_isGoogleUser && role == null) return AppView.managerAuth;

    if (_showManagerAuth) return AppView.managerAuth;

    // Employee remembered on this device.
    if (_employeeName != null && _employeeLocationId != null) {
      return AppView.employee;
    }
    return AppView.landing;
  }

  // ---- Firestore helpers ----------------------------------------------

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _companiesCol =>
      _db.collection(_kCompanies);
  DocumentReference<Map<String, dynamic>>? get _companyRef =>
      _activeCompanyId == null ? null : _companiesCol.doc(_activeCompanyId);
  CollectionReference<Map<String, dynamic>> get _locationsCol {
    final ref = _companyRef;
    if (ref == null) {
      return _db.collection(_kLocations);
    }
    return ref.collection(_kLocations);
  }
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection(_kUsers);
  DocumentReference<Map<String, dynamic>>? get _locationRef =>
      _activeLocationId == null ? null : _locationsCol.doc(_activeLocationId);

  // ---- Init ------------------------------------------------------------

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPrices();
    _loadSettings();
    _loadEmployeeProfile();
    _activeCompanyId ??= _prefs?.getString(_kActiveCompany);
    _activeLocationId = _prefs?.getString(_kActiveLocation);

    _cloud = Firebase.apps.isNotEmpty;
    if (_cloud) {
      _auth = fb.FirebaseAuth.instance;
      _auth!.authStateChanges().listen(_onAuthChanged);
      // Ensure we always have at least an anonymous session for DB access
      // BEFORE reading any config (reads require an authenticated user).
      if (_auth!.currentUser == null) {
        try {
          await _auth!.signInAnonymously();
        } catch (e) {
          debugPrint('anonymous sign-in failed: $e');
          _ready = true;
          notifyListeners();
        }
      }
      await _loadAppConfig();
    } else {
      _ready = true;
      _loadSubmissions();
    }
  }

  Future<void> _loadAppConfig() async {
    try {
      final doc = await _db.collection(_kConfigCol).doc(_kAppConfigDoc).get();
      final data = doc.data();
      if (data != null) {
        final m = data[kManagerMasterCodeField] as String?;
        final s = data[kSuperAdminMasterCodeField] as String?;
        if (m != null && m.trim().isNotEmpty) _managerCode = m.trim();
        if (s != null && s.trim().isNotEmpty) _superCode = s.trim();
      }
    } catch (e) {
      debugPrint('loadAppConfig error (using defaults): $e');
    }
  }

  void _loadEmployeeProfile() {
    final raw = _prefs?.getString(_kEmployeeProfile);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _employeeName = map['name'] as String?;
      _employeeLocationId = map['locationId'] as String?;
      final companyId = map['companyId'] as String?;
      if (companyId != null && companyId.isNotEmpty) {
        _activeCompanyId = companyId;
      }
    } catch (_) {
      _employeeName = null;
      _employeeLocationId = null;
    }
  }

  // ---- Auth flow -------------------------------------------------------

  Future<void> _onAuthChanged(fb.User? user) async {
    _authUser = user;
    await _userSub?.cancel();
    _userSub = null;

    if (user == null) {
      _appUser = null;
      _ready = true;
      notifyListeners();
      return;
    }

    final ref = _usersCol.doc(user.uid);

    if (user.isAnonymous) {
      // Employee / pre-login session. We still watch users/{uid} so a super
      // admin who entered the admin code on this device is restored.
      _appUser = null;
      if (_employeeLocationId != null) {
        _activeLocationId = _employeeLocationId;
        await _cacheSingleLocation(_activeLocationId);
        _bindLocation(_activeLocationId);
      }
      _userSub = ref.snapshots().listen(_onUserDoc, onError: (Object e) {
        debugPrint('user doc listen error: $e');
      });
      _ready = true;
      notifyListeners();
      return;
    }

    // Real (Google/Apple) account → ensure a users/{uid} doc, then watch it.
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'email': (user.email ?? '').toLowerCase(),
          'displayName': user.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('ensure user doc error: $e');
    }
    _userSub = ref.snapshots().listen(_onUserDoc, onError: (Object e) {
      debugPrint('user doc listen error: $e');
    });
    _ready = true;
    notifyListeners();
  }

  Future<void> _onUserDoc(DocumentSnapshot<Map<String, dynamic>> doc) async {
    _appUser = AppUser.fromDoc(doc);
    final role = _appUser!.role;
    if (role == UserRole.platformAdmin) {
      _bindLocationsList();
      _activeLocationId ??= _prefs?.getString(_kActiveLocation);
      _bindLocation(_activeLocationId);
    } else if (role == UserRole.companyManager) {
      _activeLocationId = _appUser!.locationId;
      await _cacheSingleLocation(_activeLocationId);
      _bindLocation(_activeLocationId);
    }
    notifyListeners();
  }

  Future<void> _cacheSingleLocation(String? locationId) async {
    if (locationId == null) return;
    try {
      final doc = await _locationsCol.doc(locationId).get();
      if (doc.exists) _locations = [Location.fromDoc(doc)];
    } catch (e) {
      debugPrint('cacheSingleLocation error: $e');
    }
  }

  // ---- Manager auth navigation ----------------------------------------

  void openManagerAuth() {
    _showManagerAuth = true;
    notifyListeners();
  }

  void closeManagerAuth() {
    _showManagerAuth = false;
    _pendingManagerCreate = false;
    notifyListeners();
  }

  /// A signed-in manager/super-admin starts filling out a scorecard as [name].
  void enterEmployeeMode(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _actingAsEmployee = true;
    _actingName = trimmed;
    notifyListeners();
  }

  /// Return from scorecard mode back to the manager/super-admin dashboard.
  void exitEmployeeMode() {
    _actingAsEmployee = false;
    _actingName = null;
    notifyListeners();
  }

  Future<String?> signInWithGoogle({bool creating = false}) =>
      _signIn(fb.GoogleAuthProvider(), creating: creating);

  Future<String?> signInWithApple({bool creating = false}) => _signIn(
        fb.AppleAuthProvider()
          ..addScope('email')
          ..addScope('name'),
        creating: creating,
      );

  Future<String?> _signIn(fb.AuthProvider provider,
      {required bool creating}) async {
    if (_auth == null) return 'Sign-in is unavailable right now.';
    _pendingManagerCreate = creating;
    try {
      if (kIsWeb) {
        await _auth!.signInWithPopup(provider);
      } else {
        await _auth!.signInWithProvider(provider);
      }
      return null;
    } catch (e) {
      debugPrint('signIn error: $e');
      _pendingManagerCreate = false;
      return 'Could not sign in. Please try again.';
    }
  }

  /// Sign out of a manager/super-admin account and return to the landing page
  /// (re-establishing the anonymous session employees rely on).
  Future<void> signOutManager() async {
    _showManagerAuth = false;
    _pendingManagerCreate = false;
    _actingAsEmployee = false;
    _actingName = null;
    try {
      await _auth?.signOut();
      await _auth?.signInAnonymously();
    } catch (e) {
      debugPrint('signOutManager error: $e');
    }
  }

  /// Sign out an employee on this device (clears the remembered name).
  Future<void> signOutEmployee() async {
    _employeeName = null;
    _employeeLocationId = null;
    _activeCompanyId = null;
    _activeCompany = null;
    _companyLocations = [];
    await _prefs?.remove(_kEmployeeProfile);
    await _prefs?.remove(_kActiveCompany);
    await _prefs?.remove(_kEmployeeCompanyCode);
    notifyListeners();
  }

  // ---- Company flow ----------------------------------------------------

  Future<Company?> lookupCompanyCode(String code) async {
    final clean = Company.normalizeCode(code);
    if (clean.isEmpty) return null;
    try {
      final snap = await _companiesCol
          .where('companyCode', isEqualTo: clean)
          .limit(1)
          .get();
      if (snap.docs.isNotEmpty) return Company.fromDoc(snap.docs.first);
      final all = await _companiesCol.get();
      for (final d in all.docs) {
        final c = Company.fromDoc(d);
        if (Company.normalizeCode(c.companyCode) == clean) return c;
      }
      return null;
    } catch (e) {
      debugPrint('lookupCompanyCode error: $e');
      return null;
    }
  }

  Future<bool> isCompanyCodeAvailable(String code) async {
    final clean = Company.normalizeCode(code);
    if (clean.isEmpty) return false;
    return await lookupCompanyCode(clean) == null;
  }

  Future<void> previewCompany(String companyId) async {
    _activeCompanyId = companyId;
    final doc = await _companiesCol.doc(companyId).get();
    _activeCompany = doc.exists ? Company.fromDoc(doc) : null;
    final locSnap = await _locationsCol.orderBy('name').get();
    _companyLocations = locSnap.docs.map(Location.fromDoc).toList();
    notifyListeners();
  }

  Future<String?> migrateToCompany({
    required String companyId,
    required String companyName,
    required String companyCode,
  }) =>
      company_migration.migrateToCompany(
        db: _db,
        companyId: companyId,
        companyName: companyName,
        companyCode: companyCode,
      );

  // ---- Employee site-code flow ----------------------------------------

  /// Finds an active location by its site code (case-insensitive). Returns null
  /// if no match.
  Future<Location?> lookupSiteCode(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;
    try {
      final snap = await _locationsCol
          .where('siteCode', isEqualTo: clean)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) {
        // Fall back to a case-insensitive scan (small dataset).
        final all = await _locationsCol.get();
        for (final d in all.docs) {
          final loc = Location.fromDoc(d);
          if (loc.siteCode.toLowerCase() == clean.toLowerCase()) return loc;
        }
        return null;
      }
      return Location.fromDoc(snap.docs.first);
    } catch (e) {
      debugPrint('lookupSiteCode error: $e');
      return null;
    }
  }

  /// Binds a location for the site-code name picker (loads its roster, prices…)
  /// without yet committing the employee.
  void previewLocation(String locationId) {
    _activeLocationId = locationId;
    _bindLocation(locationId);
    notifyListeners();
  }

  /// Commits the chosen employee name and remembers it on this device.
  Future<void> signInEmployee({
    required String locationId,
    required String name,
    String? companyId,
    String? companyCode,
  }) async {
    _employeeName = name;
    _employeeLocationId = locationId;
    _activeLocationId = locationId;
    final profile = <String, dynamic>{
      'name': name,
      'locationId': locationId,
    };
    if (companyId != null && companyId.isNotEmpty) {
      _activeCompanyId = companyId;
      profile['companyId'] = companyId;
      await _prefs?.setString(_kActiveCompany, companyId);
    }
    if (companyCode != null && companyCode.isNotEmpty) {
      final normalized = Company.normalizeCode(companyCode);
      profile['companyCode'] = normalized;
      await _prefs?.setString(_kEmployeeCompanyCode, normalized);
    }
    await _prefs?.setString(_kEmployeeProfile, jsonEncode(profile));
    await _prefs?.setString(_kActiveLocation, locationId);
    _bindLocation(locationId);
    notifyListeners();
  }

  /// Becomes Super Admin using just the admin code — no Google sign-in. The
  /// role is attached to the current (anonymous) session.
  Future<String?> signInSuperAdmin(String code) async {
    final user = _authUser;
    if (user == null) return 'Starting up — try again in a moment.';
    if (code.trim() != _superCode) return 'Incorrect admin password.';
    try {
      await _usersCol.doc(user.uid).set(
        {
          'role': UserRole.platformAdmin.firestoreValue,
          'email': (user.email ?? '').toLowerCase(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _showManagerAuth = false;
      return null;
    } catch (e) {
      debugPrint('signInSuperAdmin error: $e');
      return 'Could not sign in. Check your connection.';
    }
  }

  // ---- Provisioning via master code -----------------------------------

  /// Redeems a master code to provision the current Google account.
  Future<String?> redeemAccessCode(
    String code, {
    String? locationId,
    String? newLocationName,
    String? newSiteCode,
  }) async {
    final user = _appUser;
    if (user == null) return 'You must be signed in.';
    final entered = code.trim();
    if (entered.isEmpty) return 'Enter the admin password.';

    try {
      if (entered == _superCode) {
        await _usersCol.doc(user.uid).set(
          {'role': UserRole.platformAdmin.firestoreValue},
          SetOptions(merge: true),
        );
        _pendingManagerCreate = false;
        return null;
      }

      if (entered == _managerCode) {
        var targetId = locationId;
        if (targetId == null) {
          final name = newLocationName?.trim() ?? '';
          if (name.isEmpty) {
            return 'Choose a site or enter a new site name.';
          }
          targetId = await createLocation(name, siteCode: newSiteCode ?? '');
          if (targetId == null) return 'Could not create the site.';
        }
        await _usersCol.doc(user.uid).set(
          {'role': UserRole.companyManager.firestoreValue, 'locationId': targetId},
          SetOptions(merge: true),
        );
        _pendingManagerCreate = false;
        return null;
      }

      return 'That admin password is not valid.';
    } catch (e) {
      debugPrint('redeemAccessCode error: $e');
      return 'Could not apply the code. Check your connection.';
    }
  }

  // ---- Locations -------------------------------------------------------

  Future<List<Location>> fetchLocations() async {
    try {
      final snap = await _locationsCol.orderBy('name').get();
      return snap.docs.map(Location.fromDoc).toList();
    } catch (e) {
      debugPrint('fetchLocations error: $e');
      return [];
    }
  }

  void _bindLocationsList() {
    if (_locationsSub != null) return;
    _locationsSub = _locationsCol.orderBy('name').snapshots().listen(
      (snap) {
        _locations = snap.docs.map(Location.fromDoc).toList();
        notifyListeners();
      },
      onError: (Object e) => debugPrint('locations listen error: $e'),
    );
  }

  Future<String?> createLocation(String name,
      {String city = '', String siteCode = ''}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    try {
      final ref = _locationsCol.doc();
      await ref.set(
        Location(
          id: ref.id,
          name: trimmed,
          city: city.trim(),
          siteCode: siteCode.trim(),
        ).toMap(),
      );
      return ref.id;
    } catch (e) {
      debugPrint('createLocation error: $e');
      return null;
    }
  }

  Future<String?> setLocationActive(String locationId, bool active) async {
    try {
      await _locationsCol.doc(locationId).set(
        {'active': active},
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      debugPrint('setLocationActive error: $e');
      return 'Could not update the location.';
    }
  }

  /// Manager/super-admin sets this location's site code.
  Future<String?> setSiteCode(String locationId, String code) async {
    try {
      await _locationsCol.doc(locationId).set(
        {'siteCode': code.trim()},
        SetOptions(merge: true),
      );
      await _cacheSingleLocation(locationId);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('setSiteCode error: $e');
      return 'Could not save the site code.';
    }
  }

  Future<void> setActiveLocation(String? locationId) async {
    _activeLocationId = locationId;
    if (locationId != null) {
      await _prefs?.setString(_kActiveLocation, locationId);
    } else {
      await _prefs?.remove(_kActiveLocation);
    }
    _bindLocation(locationId);
    notifyListeners();
  }

  /// One-time migration of legacy flat collections into [locationId].
  Future<String?> migrateLegacyDataToLocation(String locationId) async {
    try {
      final dest = _locationsCol.doc(locationId);
      final batch = _db.batch();

      final legacySubs = await _db.collection('submissions').get();
      for (final d in legacySubs.docs) {
        batch.set(dest.collection(_kSubmissionsCol).doc(d.id), d.data());
      }
      final legacyWorkers = await _db.collection('workers').get();
      for (final d in legacyWorkers.docs) {
        batch.set(dest.collection(_kWorkersCol).doc(d.id), d.data());
      }
      final prices = await _db.collection('config').doc('prices').get();
      if (prices.exists) {
        batch.set(dest.collection(_kConfigCol).doc(_kPricesDoc), prices.data()!);
      }
      final settings = await _db.collection('config').doc('settings').get();
      if (settings.exists) {
        batch.set(
            dest.collection(_kConfigCol).doc(_kSettingsDoc), settings.data()!);
      }
      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('migration error: $e');
      return 'Migration failed: $e';
    }
  }

  // ---- Bind / unbind the active location's data -----------------------

  void _unbindLocation() {
    _subsSub?.cancel();
    _workersSub?.cancel();
    _pricesSub?.cancel();
    _settingsSub?.cancel();
    _itemsSub?.cancel();
    _subsSub = _workersSub = null;
    _pricesSub = _settingsSub = _itemsSub = null;
    _submissions = [];
    _workers = [];
    _itemConfig = {};
    ItemBook.reset();
    SectionBook.reset();
    PointBook.setOverrides({});
  }

  void _bindLocation(String? locationId) {
    _unbindLocation();
    if (!_cloud || locationId == null) {
      notifyListeners();
      return;
    }
    final base = _locationsCol.doc(locationId);

    _subsLoading = true;
    _subsSub = base
        .collection(_kSubmissionsCol)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .listen(_onSubsSnapshot, onError: (Object e) {
      _subsLoading = false;
      debugPrint('submissions listen error: $e');
    });

    _workersSub = base
        .collection(_kWorkersCol)
        .orderBy('name')
        .snapshots()
        .listen(_onWorkersSnapshot, onError: (Object e) {
      debugPrint('workers listen error: $e');
    });

    _pricesSub = base
        .collection(_kConfigCol)
        .doc(_kPricesDoc)
        .snapshots()
        .listen(_onPricesSnapshot, onError: (Object e) {
      debugPrint('prices listen error: $e');
    });

    _settingsSub = base
        .collection(_kConfigCol)
        .doc(_kSettingsDoc)
        .snapshots()
        .listen(_onSettingsSnapshot, onError: (Object e) {
      debugPrint('settings listen error: $e');
    });

    _itemsSub = base
        .collection(_kConfigCol)
        .doc(_kItemsDoc)
        .snapshots()
        .listen(_onItemsSnapshot, onError: (Object e) {
      debugPrint('items listen error: $e');
    });
  }

  // ---- Settings (manager-controlled) ----------------------------------

  void _loadSettings() {
    _seeAll = _prefs?.getBool(_kSettings) ?? false;
  }

  void _onSettingsSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    _seeAll = data['seeAll'] as bool? ?? false;
    final raw = (data['enabledSections'] as Map?)?.cast<String, dynamic>();
    final next = {for (final s in WashSection.values) s: true};
    if (raw != null) {
      for (final s in WashSection.values) {
        if (raw.containsKey(s.name)) next[s] = raw[s.name] as bool? ?? true;
      }
    }
    _enabledSections = next;
    _challenge =
        Challenge.fromMap((data['challenge'] as Map?)?.cast<String, dynamic>());
    notifyListeners();
  }

  // ---- Custom line items & section order (manager-controlled) ----------

  void _onItemsSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    _itemConfig = doc.data() ?? {};
    _rebuildItems();
    notifyListeners();
  }

  /// All line items defined for this location: built-ins plus custom additions
  /// (does NOT filter out hidden ones).
  List<LineItem> _allDefinedItems() {
    final all = <LineItem>[...kDefaultLineItems];
    for (final raw in (_itemConfig['custom'] as List?) ?? const []) {
      final m = (raw as Map).cast<String, dynamic>();
      final id = m['id'] as String?;
      final label = m['label'] as String?;
      if (id == null || label == null) continue;
      final section = WashSection.values.firstWhere(
        (s) => s.name == m['section'],
        orElse: () => WashSection.shop,
      );
      all.add(LineItem(
        id: id,
        label: label,
        section: section,
        defaultPrice: (m['price'] as num?)?.toDouble(),
      ));
    }
    return all;
  }

  List<LineItem> _orderSection(WashSection section, List<LineItem> items) {
    final orderMap = (_itemConfig['order'] as Map?)?.cast<String, dynamic>();
    final order =
        ((orderMap?[section.name] as List?) ?? const []).map((e) => '$e');
    final byId = {for (final i in items) i.id: i};
    final ordered = <LineItem>[];
    for (final id in order) {
      final item = byId.remove(id);
      if (item != null) ordered.add(item);
    }
    ordered.addAll(items.where((i) => byId.containsKey(i.id)));
    return ordered;
  }

  /// Section + per-section item order for the manager's editor (incl. hidden).
  Set<String> get hiddenItemIds => ((_itemConfig['hidden'] as List?) ?? const [])
      .map((e) => '$e')
      .toSet();

  bool isItemHidden(String id) => hiddenItemIds.contains(id);

  /// Ordered items for [section] including hidden ones — for the editor screen.
  List<LineItem> managedItemsFor(WashSection section) => _orderSection(
        section,
        _allDefinedItems().where((i) => i.section == section).toList(),
      );

  /// Recomputes [ItemBook]/[SectionBook] from defaults + the location config:
  /// adds custom items, removes hidden ones, and applies per-section + section
  /// ordering.
  void _rebuildItems() {
    final hidden = hiddenItemIds;
    final visible =
        _allDefinedItems().where((i) => !hidden.contains(i.id)).toList();

    final result = <LineItem>[];
    for (final section in WashSection.values) {
      result.addAll(_orderSection(
          section, visible.where((i) => i.section == section).toList()));
    }
    ItemBook.setItems(result);

    final points =
        (_itemConfig['points'] as Map?)?.cast<String, dynamic>() ?? const {};
    PointBook.setOverrides({
      for (final e in points.entries)
        if (e.value is num) e.key: (e.value as num).toInt(),
    });

    final sectionOrder = ((_itemConfig['sectionOrder'] as List?) ?? const [])
        .map((e) => WashSection.values
            .firstWhere((s) => s.name == e, orElse: () => WashSection.shop))
        .toList();
    if (sectionOrder.isNotEmpty) {
      SectionBook.setOrder(sectionOrder);
    } else {
      SectionBook.reset();
    }
  }

  Future<String?> _saveItemConfig(Map<String, dynamic> patch) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    final previous = Map<String, dynamic>.from(_itemConfig);
    _itemConfig = {..._itemConfig, ...patch};
    _rebuildItems();
    notifyListeners();
    try {
      await ref
          .collection(_kConfigCol)
          .doc(_kItemsDoc)
          .set(patch, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('saveItemConfig error: $e');
      _itemConfig = previous;
      _rebuildItems();
      notifyListeners();
      return 'Could not save. Check your connection.';
    }
  }

  Future<String?> addCustomLineItem(
      String label, WashSection section, double? price,
      {int points = 0}) async {
    final id = 'custom_${const Uuid().v4().substring(0, 8)}';
    final custom = [
      ...((_itemConfig['custom'] as List?) ?? const []),
      {'id': id, 'label': label, 'section': section.name, 'price': price},
    ];
    final pts = Map<String, dynamic>.from((_itemConfig['points'] as Map?) ?? {});
    pts[id] = points;
    return _saveItemConfig({'custom': custom, 'points': pts});
  }

  Future<String?> removeCustomLineItem(String id) async {
    final custom = [
      for (final raw in (_itemConfig['custom'] as List?) ?? const [])
        if ((raw as Map)['id'] != id) raw,
    ];
    return _saveItemConfig({'custom': custom});
  }

  Future<String?> setLineItemHidden(String id, bool hidden) async {
    final current = ((_itemConfig['hidden'] as List?) ?? const [])
        .map((e) => '$e')
        .toSet();
    if (hidden) {
      current.add(id);
    } else {
      current.remove(id);
    }
    return _saveItemConfig({'hidden': current.toList()});
  }

  Future<String?> reorderLineItems(
      WashSection section, List<String> orderedIds) async {
    final orderMap =
        Map<String, dynamic>.from((_itemConfig['order'] as Map?) ?? {});
    orderMap[section.name] = orderedIds;
    return _saveItemConfig({'order': orderMap});
  }

  Future<String?> reorderSections(List<WashSection> order) =>
      _saveItemConfig({'sectionOrder': [for (final s in order) s.name]});

  Future<String?> setItemPoints(String id, int points) async {
    final pts = Map<String, dynamic>.from((_itemConfig['points'] as Map?) ?? {});
    pts[id] = points;
    return _saveItemConfig({'points': pts});
  }

  Future<String?> setChallenge(Challenge? challenge) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    final previous = _challenge;
    _challenge = challenge;
    notifyListeners();
    try {
      await ref.collection(_kConfigCol).doc(_kSettingsDoc).set({
        'challenge': challenge?.toMap() ?? FieldValue.delete(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('setChallenge error: $e');
      _challenge = previous;
      notifyListeners();
      return 'Could not save the challenge. Check your connection.';
    }
  }

  Future<String?> setSeeAll(bool value) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    final previous = _seeAll;
    // Optimistic: flip immediately so the UI responds, then persist.
    _seeAll = value;
    notifyListeners();
    try {
      await ref
          .collection(_kConfigCol)
          .doc(_kSettingsDoc)
          .set({'seeAll': value}, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('setSeeAll error: $e');
      _seeAll = previous;
      notifyListeners();
      return 'Could not save setting. Check your connection and Firestore rules.';
    }
  }

  Future<String?> setSectionEnabled(WashSection section, bool enabled) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    final previous = _enabledSections[section] ?? true;
    // Optimistic: update locally first so the toggle moves right away.
    _enabledSections = {..._enabledSections, section: enabled};
    notifyListeners();
    try {
      await ref.collection(_kConfigCol).doc(_kSettingsDoc).set({
        'enabledSections': {section.name: enabled},
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('setSectionEnabled error: $e');
      _enabledSections = {..._enabledSections, section: previous};
      notifyListeners();
      return 'Could not save setting. Check your connection and Firestore rules.';
    }
  }

  // ---- Prices (manager-editable) --------------------------------------

  void _loadPrices() {
    final raw = _prefs?.getString(_kPrices);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      PriceBook.setOverrides(_decodePrices(map));
    } catch (_) {}
  }

  Map<String, double?> _decodePrices(Map<String, dynamic> map) {
    final result = <String, double?>{};
    map.forEach((key, value) {
      result[key] = value == null ? null : (value as num).toDouble();
    });
    return result;
  }

  void _onPricesSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final prices = (data?['prices'] as Map?)?.cast<String, dynamic>() ?? {};
    PriceBook.setOverrides(_decodePrices(prices));
    _prefs?.setString(_kPrices, jsonEncode(prices));
    notifyListeners();
  }

  Future<String?> setItemPrice(String id, double? price) async {
    final overrides = PriceBook.overrides;
    overrides[id] = price;
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    try {
      await ref
          .collection(_kConfigCol)
          .doc(_kPricesDoc)
          .set({'prices': overrides});
      return null;
    } catch (e) {
      debugPrint('savePrices error: $e');
      return 'Could not save prices. Check your connection and Firestore rules.';
    }
  }

  // ---- In-progress draft (per device, per employee) -------------------

  String _draftKey(String employeeName) =>
      '$_kDraftPrefix${employeeName.toLowerCase().trim()}';

  Map<String, dynamic>? loadDraft(String employeeName) {
    final raw = _prefs?.getString(_draftKey(employeeName));
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> saveDraft(
    String employeeName, {
    required Map<String, int> counts,
    required double baGoal,
    int talkedTo = 0,
  }) async {
    await _prefs?.setString(
      _draftKey(employeeName),
      jsonEncode({'counts': counts, 'baGoal': baGoal, 'talkedTo': talkedTo}),
    );
  }

  Future<void> clearDraft(String employeeName) async {
    await _prefs?.remove(_draftKey(employeeName));
  }

  // ---- Workers (manager roster) ---------------------------------------

  void _onWorkersSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    _workers =
        snap.docs.map(Worker.fromDoc).where((w) => w.name.isNotEmpty).toList();
    notifyListeners();
  }

  bool hasWorkerName(String name) =>
      _workers.any((w) => w.name.toLowerCase() == name.trim().toLowerCase());

  Future<String?> addWorker(String name, {String? pin}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Name cannot be empty';
    if (hasWorkerName(trimmed)) return '$trimmed is already on the team';
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    final cleanedPin = pin?.trim();
    final worker = Worker(
      id: const Uuid().v4(),
      name: trimmed,
      pin: cleanedPin != null && cleanedPin.isNotEmpty ? cleanedPin : null,
    );
    try {
      await ref.collection(_kWorkersCol).doc(worker.id).set(worker.toMap());
      return null;
    } catch (e) {
      debugPrint('addWorker error: $e');
      return 'Could not add worker. Check your connection and Firestore rules.';
    }
  }

  Future<String?> updateWorker(
    String id, {
    String? pin,
    bool clearPin = false,
  }) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    final cleanedPin =
        clearPin ? null : (pin?.trim().isNotEmpty == true ? pin!.trim() : null);
    try {
      if (cleanedPin == null) {
        await ref
            .collection(_kWorkersCol)
            .doc(id)
            .update({'pin': FieldValue.delete()});
      } else {
        await ref.collection(_kWorkersCol).doc(id).update({'pin': cleanedPin});
      }
      return null;
    } catch (e) {
      debugPrint('updateWorker error: $e');
      return 'Could not update entry code. Check Firestore rules.';
    }
  }

  Future<String?> removeWorker(String id) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    try {
      await ref.collection(_kWorkersCol).doc(id).delete();
      return null;
    } catch (e) {
      debugPrint('removeWorker error: $e');
      return 'Could not remove worker. Check Firestore rules allow delete.';
    }
  }

  // ---- Submissions -----------------------------------------------------

  void _loadSubmissions() {
    final raw = _prefs?.getString(_kSubmissions);
    if (raw == null) {
      _submissions = [];
      return;
    }
    try {
      final list = jsonDecode(raw) as List;
      _submissions = list
          .map((e) => Submission.fromJson(e as Map<String, dynamic>))
          .toList();
      _sort();
    } catch (_) {
      _submissions = [];
    }
  }

  void _onSubsSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    _subsLoading = false;
    _submissions = snap.docs.map(_fromDoc).toList();
    _prefs?.setString(
      _kSubmissions,
      jsonEncode(_submissions.map((s) => s.toJson()).toList()),
    );
    notifyListeners();
  }

  Submission _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['submittedAt'];
    final editedTs = data['editedAt'];
    final approvedTs = data['approvedAt'];
    return Submission(
      id: doc.id,
      employeeName: data['employeeName'] as String? ?? 'Unknown',
      baGoal: (data['baGoal'] as num?)?.toDouble() ?? 0,
      counts: ((data['counts'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      submittedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      talkedTo: (data['talkedTo'] as num?)?.toInt() ?? 0,
      approved: data['approved'] as bool? ?? false,
      approvedBy: data['approvedBy'] as String?,
      approvedAt: approvedTs is Timestamp ? approvedTs.toDate() : null,
      editedBy: data['editedBy'] as String?,
      editedAt: editedTs is Timestamp ? editedTs.toDate() : null,
    );
  }

  Map<String, dynamic> _toDoc(Submission s) => {
        'employeeName': s.employeeName,
        'baGoal': s.baGoal,
        'counts': s.counts,
        'submittedAt': Timestamp.fromDate(s.submittedAt),
        'talkedTo': s.talkedTo,
        'approved': s.approved,
        if (s.approvedBy != null) 'approvedBy': s.approvedBy,
        if (s.approvedAt != null) 'approvedAt': Timestamp.fromDate(s.approvedAt!),
        if (s.editedBy != null) 'editedBy': s.editedBy,
        if (s.editedAt != null) 'editedAt': Timestamp.fromDate(s.editedAt!),
      };

  void _sort() =>
      _submissions.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

  Future<void> addSubmission(Submission submission) async {
    final ref = _locationRef;
    if (ref == null) {
      debugPrint('addSubmission: no active location');
      return;
    }
    await ref
        .collection(_kSubmissionsCol)
        .doc(submission.id)
        .set(_toDoc(submission));
  }

  Future<String?> updateSubmission(
    String id, {
    required Map<String, int> counts,
    required double baGoal,
    int? talkedTo,
  }) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    try {
      await ref.collection(_kSubmissionsCol).doc(id).set({
        'counts': counts,
        'baGoal': baGoal,
        'talkedTo': ?talkedTo,
        'editedBy': _appUser?.name ?? 'manager',
        'editedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('updateSubmission error: $e');
      return 'Could not save changes. Check Firestore rules.';
    }
  }

  /// Approve a pending scorecard so it counts toward totals + the Master Sheet.
  Future<String?> approveSubmission(String id) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    try {
      await ref.collection(_kSubmissionsCol).doc(id).set({
        'approved': true,
        'approvedBy': _appUser?.name ?? 'manager',
        'approvedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('approveSubmission error: $e');
      return 'Could not approve. Check Firestore rules.';
    }
  }

  /// Send an approved scorecard back to pending (undo approval).
  Future<String?> unapproveSubmission(String id) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    try {
      await ref.collection(_kSubmissionsCol).doc(id).set({
        'approved': false,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('unapproveSubmission error: $e');
      return 'Could not update. Check Firestore rules.';
    }
  }

  Future<String?> deleteSubmission(String id) async {
    final ref = _locationRef;
    if (ref == null) return 'No active location.';
    try {
      await ref.collection(_kSubmissionsCol).doc(id).delete();
      return null;
    } catch (e) {
      debugPrint('deleteSubmission error: $e');
      return 'Could not delete. Check Firestore rules allow delete.';
    }
  }

  Future<void> resetDay(DateTime day) async {
    final ref = _locationRef;
    if (ref == null) return;
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final snap = await ref
        .collection(_kSubmissionsCol)
        .where('submittedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('submittedAt', isLessThan: Timestamp.fromDate(end))
        .get();
    final batch = _db.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  List<Submission> submissionsOn(DateTime day) =>
      _submissions.where((s) => _isSameDay(s.submittedAt, day)).toList();

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
