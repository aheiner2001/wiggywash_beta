import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../config/auth_config.dart';
import '../models/app_user.dart';
import '../models/challenge.dart';
import '../models/company.dart';
import '../models/location.dart';
import '../models/location_access.dart';
import '../models/manager_invite.dart';
import '../models/profile.dart';
import '../models/request_preset.dart';
import '../models/scorecard_config.dart';
import '../models/staff_request.dart';
import '../models/submission.dart';
import '../models/worker.dart';
import '../theme/app_theme_id.dart';
import '../utils/brand_color.dart';
import '../utils/firestore_user_error.dart';
import '../utils/location_entitlement.dart' as entitlement;
import '../utils/manager_invite_logic.dart';
import '../utils/staff_request_logic.dart';
import 'company_migration.dart' as company_migration;

/// Where [CompanyLoginScreen] should resume after Switch person/location.
enum EmployeeLoginResume { none, location, name }

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

  /// Manager signed up but company awaits platform approval.
  pendingApproval,
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
  static const _kRecentLocations = 'ww_recent_locations';

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
  bool _pinUnlockedThisLaunch = false;
  EmployeeLoginResume employeeLoginResume = EmployeeLoginResume.none;

  // Navigation flags driven by the user.
  bool _showManagerAuth = false;
  bool _pendingManagerCreate = false;
  String? _managerClaimError;

  // A manager/super-admin temporarily using the employee scorecard under a
  // chosen name, without losing their account session.
  bool _actingAsEmployee = false;
  String? _actingName;

  // ---- Company ----
  String? _activeCompanyId;
  Company? _activeCompany;
  List<Location> _companyLocations = [];
  List<Company> _companies = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _companiesSub;

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
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _presetsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _completionPresetsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _staffRequestsSub;

  List<RequestPreset> _requestPresets = [];
  List<RequestPreset> _completionPresets = [];
  List<StaffRequest> _staffRequests = [];

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
  List<RequestPreset> get requestPresets => List.unmodifiable(_requestPresets);
  List<RequestPreset> get completionPresets =>
      List.unmodifiable(_completionPresets);
  List<StaffRequest> get staffRequests => List.unmodifiable(_staffRequests);
  int get pendingStaffRequestCount => _staffRequests.where((r) {
        if (!isManagerBoardVisible(r)) return false;
        return r.status == StaffRequestStatus.pending ||
            r.status == StaffRequestStatus.awaitingReview;
      }).length;
  AppUser? get appUser => _appUser;
  String? get activeCompanyId => _activeCompanyId;
  Company? get activeCompany => _activeCompany;
  List<Location> get companyLocations => List.unmodifiable(_companyLocations);
  List<Company> get companies => List.unmodifiable(_companies);
  List<Location> get locations => List.unmodifiable(_locations);
  String? get activeLocationId => _activeLocationId;
  bool get pendingManagerCreate => _pendingManagerCreate;
  String? get managerClaimError => _managerClaimError;

  /// True when a signed-in manager/super-admin is filling out a scorecard.
  bool get isActingAsEmployee => _actingAsEmployee && _actingName != null;

  Location? get activeLocation {
    for (final l in _locations) {
      if (l.id == _activeLocationId) return l;
    }
    for (final l in _companyLocations) {
      if (l.id == _activeLocationId) return l;
    }
    return null;
  }

  /// Effective write access for the active location (trial expiry applied).
  bool get canWriteAtActiveLocation {
    final loc = activeLocation;
    if (loc == null) return false;
    return entitlement.locationAllowsWrites(
      entitlement.effectiveAccess(
        loc.accessStatus,
        trialEndsAt: loc.trialEndsAt,
      ),
    );
  }

  String get readOnlyMessage =>
      'This site is read-only. Ask your manager to update billing.';

  bool get pinUnlockedThisLaunch => _pinUnlockedThisLaunch;

  void unlockPinForLaunch() {
    _pinUnlockedThisLaunch = true;
    notifyListeners();
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
    if (role == UserRole.companyManager) {
      if (_activeCompany?.status == CompanyStatus.pending) {
        return AppView.pendingApproval;
      }
      if (_appUser!.locationId != null || _appUser!.companyId != null) {
        return AppView.manager;
      }
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

  CollectionReference<Map<String, dynamic>> _managerInvitesCol(String companyId) =>
      _companiesCol.doc(companyId).collection('managerInvites');
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
      if (_employeeLocationId != null) {
        _activeLocationId = _employeeLocationId;
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
      await _validateEmployeeSession();
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
        await tryClaimManagerInvite();
      } else {
        final data = snap.data();
        final role =
            data == null ? null : roleFromString(data['role'] as String?);
        if (role == null) {
          await tryClaimManagerInvite();
        }
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
      _bindCompaniesList();
      _bindLocationsList();
      _activeLocationId ??= _prefs?.getString(_kActiveLocation);
      _bindLocation(_activeLocationId);
    } else if (role == UserRole.companyManager) {
      _activeCompanyId = _appUser!.companyId;
      if (_activeCompanyId != null) {
        await _loadActiveCompanyDoc();
        try {
          final locSnap = await _locationsCol.orderBy('name').get();
          _companyLocations = locSnap.docs.map(Location.fromDoc).toList();
        } catch (e) {
          debugPrint('load company locations error: $e');
        }
      }
      _activeLocationId = _appUser!.locationId;
      await _cacheSingleLocation(_activeLocationId);
      _bindLocation(_activeLocationId);
    }
    notifyListeners();
  }

  Future<void> _loadActiveCompanyDoc() async {
    final id = _activeCompanyId;
    if (id == null) return;
    try {
      final doc = await _companiesCol.doc(id).get();
      _activeCompany = doc.exists ? Company.fromDoc(doc) : null;
    } catch (e) {
      debugPrint('loadActiveCompanyDoc error: $e');
    }
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

  Future<String?> signInWithGoogle({bool creating = false}) {
    final provider = fb.GoogleAuthProvider();
    // Web often reuses the last Google session without a chooser, which makes
    // "use a different account" feel stuck on the not-invited screen.
    provider.setCustomParameters({'prompt': 'select_account'});
    return _signIn(provider, creating: creating);
  }

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
    _managerClaimError = null;
    _actingAsEmployee = false;
    _actingName = null;
    try {
      await _auth?.signOut();
      await _auth?.signInAnonymously();
    } catch (e) {
      debugPrint('signOutManager error: $e');
    }
  }

  /// Leave the current Google manager session but stay on the manager auth
  /// screen so the user can pick a different Google account.
  Future<void> switchManagerGoogleAccount() async {
    _pendingManagerCreate = false;
    _managerClaimError = null;
    _actingAsEmployee = false;
    _actingName = null;
    _showManagerAuth = true;
    _appUser = null;
    notifyListeners();
    try {
      await _auth?.signOut();
      await _auth?.signInAnonymously();
    } catch (e) {
      debugPrint('switchManagerGoogleAccount error: $e');
    }
  }

  /// Sign out an employee on this device (clears the remembered session).
  Future<void> signOutEmployee() async {
    _employeeName = null;
    _employeeLocationId = null;
    _activeCompanyId = null;
    _activeCompany = null;
    _activeLocationId = null;
    _companyLocations = [];
    _pinUnlockedThisLaunch = false;
    employeeLoginResume = EmployeeLoginResume.none;
    await _prefs?.remove(_kEmployeeProfile);
    await _prefs?.remove(_kActiveCompany);
    await _prefs?.remove(_kEmployeeCompanyCode);
    await _prefs?.remove(_kActiveLocation);
    notifyListeners();
  }

  /// Keep company + location; clear person and resume at name picker.
  Future<void> switchEmployeePerson() async {
    _employeeName = null;
    _employeeLocationId = null;
    _pinUnlockedThisLaunch = false;
    employeeLoginResume = EmployeeLoginResume.name;
    await _prefs?.remove(_kEmployeeProfile);
    notifyListeners();
  }

  /// Keep company; clear location + person and resume at location picker.
  Future<void> switchEmployeeLocation() async {
    _employeeName = null;
    _employeeLocationId = null;
    _pinUnlockedThisLaunch = false;
    employeeLoginResume = EmployeeLoginResume.location;
    await _prefs?.remove(_kEmployeeProfile);
    _activeLocationId = null;
    await _prefs?.remove(_kActiveLocation);
    notifyListeners();
  }

  List<String> loadRecentLocationIds() {
    final raw = _prefs?.getString(_kRecentLocations);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> rememberRecentLocation(String id) async {
    if (id.isEmpty) return;
    final next = <String>[id];
    for (final existing in loadRecentLocationIds()) {
      if (existing != id) next.add(existing);
      if (next.length >= 5) break;
    }
    await _prefs?.setString(_kRecentLocations, jsonEncode(next));
  }

  /// Re-validates a remembered employee session against Firestore.
  Future<void> _validateEmployeeSession() async {
    if (_employeeName == null || _employeeName!.trim().isEmpty) return;
    final companyId = _activeCompanyId;
    if (companyId == null || companyId.isEmpty) {
      await signOutEmployee();
      return;
    }
    try {
      final companyDoc = await _companiesCol.doc(companyId).get();
      if (!companyDoc.exists) {
        await signOutEmployee();
        return;
      }
      final company = Company.fromDoc(companyDoc);
      _activeCompany = company;
      if (company.status != CompanyStatus.active) {
        await signOutEmployee();
        return;
      }
      final locSnap = await _locationsCol.orderBy('name').get();
      _companyLocations = locSnap.docs.map(Location.fromDoc).toList();
      final locId = _employeeLocationId ?? _activeLocationId;
      Location? loc;
      for (final l in _companyLocations) {
        if (l.id == locId) loc = l;
      }
      if (loc == null || !loc.active) {
        _employeeName = null;
        _employeeLocationId = null;
        _activeLocationId = null;
        _pinUnlockedThisLaunch = false;
        employeeLoginResume = EmployeeLoginResume.location;
        await _prefs?.remove(_kEmployeeProfile);
        await _prefs?.remove(_kActiveLocation);
        notifyListeners();
        return;
      }
      _activeLocationId = loc.id;
      await rememberRecentLocation(loc.id);
      // Workers may not be loaded yet; check roster once bound.
      if (_workers.isNotEmpty) {
        final name = _employeeName!.trim().toLowerCase();
        final onRoster =
            _workers.any((w) => w.name.trim().toLowerCase() == name);
        if (!onRoster) {
          _employeeName = null;
          _employeeLocationId = null;
          _pinUnlockedThisLaunch = false;
          employeeLoginResume = EmployeeLoginResume.name;
          await _prefs?.remove(_kEmployeeProfile);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('_validateEmployeeSession error: $e');
    }
  }

  Future<bool> companyExists(String companyId) async {
    try {
      final doc = await _companiesCol.doc(companyId).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> setActiveCompany(String? companyId) async {
    _activeCompanyId = companyId;
    if (companyId != null) {
      await _prefs?.setString(_kActiveCompany, companyId);
      final doc = await _companiesCol.doc(companyId).get();
      _activeCompany = doc.exists ? Company.fromDoc(doc) : null;
    } else {
      await _prefs?.remove(_kActiveCompany);
      _activeCompany = null;
    }
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

  Future<String?> createPendingCompany({
    required String companyName,
    required String companyCode,
    required String locationName,
    String city = '',
  }) async {
    final user = _appUser;
    if (user == null) return 'Sign in with Google first.';
    final code = Company.normalizeCode(companyCode);
    if (code.length < 4) return 'Company code must be at least 4 characters.';
    if (!await isCompanyCodeAvailable(code)) {
      return 'That code is taken — try another.';
    }
    final trimmedName = companyName.trim();
    final trimmedLoc = locationName.trim();
    if (trimmedName.isEmpty || trimmedLoc.isEmpty) {
      return 'Enter a company name and first location name.';
    }
    try {
      final companyRef = _companiesCol.doc();
      final locRef = companyRef.collection('locations').doc();
      final batch = _db.batch();
      batch.set(
        companyRef,
        Company(
          id: companyRef.id,
          name: trimmedName,
          companyCode: code,
          status: CompanyStatus.pending,
          purchasedSeats: 1,
          createdByEmail: user.email,
          createdByUid: user.uid,
        ).toMap(),
      );
      final trialEnd = DateTime.now().add(const Duration(days: 14));
      batch.set(
        locRef,
        Location(
          id: locRef.id,
          name: trimmedLoc,
          city: city.trim(),
          accessStatus: LocationAccessStatus.trial,
          trialEndsAt: trialEnd,
        ).toMap(),
      );
      batch.set(
        _usersCol.doc(user.uid),
        {
          'role': UserRole.companyManager.firestoreValue,
          'companyId': companyRef.id,
          'locationId': locRef.id,
          'email': user.email,
          'displayName': user.displayName,
        },
        SetOptions(merge: true),
      );
      batch.set(
        companyRef.collection('managerInvites').doc(),
        {
          'email': ManagerInvite.normalizeEmail(user.email),
          if (user.displayName.trim().isNotEmpty)
            'displayName': user.displayName.trim(),
          'invitedByUid': user.uid,
          'invitedByEmail': ManagerInvite.normalizeEmail(user.email),
          'claimedUid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );
      await batch.commit();
      _activeCompanyId = companyRef.id;
      _activeLocationId = locRef.id;
      _activeCompany = Company(
        id: companyRef.id,
        name: trimmedName,
        companyCode: code,
        status: CompanyStatus.pending,
        createdByEmail: user.email,
        createdByUid: user.uid,
      );
      _pendingManagerCreate = false;
      _showManagerAuth = false;
      await _cacheSingleLocation(locRef.id);
      _bindLocation(locRef.id);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('createPendingCompany error: $e');
      return mapFirestoreUserError(
        e,
        fallback: 'Could not create your company. Check your connection.',
      );
    }
  }

  Future<List<ManagerInvite>> listManagerInvites(String companyId) async {
    try {
      final snap = await _managerInvitesCol(companyId).orderBy('email').get();
      return snap.docs
          .map((d) =>
              ManagerInvite.fromMap(d.id, d.data(), companyId: companyId))
          .toList();
    } catch (e) {
      debugPrint('listManagerInvites error: $e');
      return [];
    }
  }

  Future<String?> addManagerInvite({
    required String companyId,
    required String email,
    String? displayName,
  }) async {
    final normalized = ManagerInvite.normalizeEmail(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      return 'Enter a valid email address.';
    }
    final me = _appUser;
    if (me == null) return 'Not signed in.';
    try {
      final existing = await _managerInvitesCol(companyId)
          .where('email', isEqualTo: normalized)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) return 'That email is already invited.';
      await _managerInvitesCol(companyId).add({
        'email': normalized,
        if (displayName != null && displayName.trim().isNotEmpty)
          'displayName': displayName.trim(),
        'invitedByUid': me.uid,
        'invitedByEmail': me.email,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('addManagerInvite error: $e');
      String? code;
      try {
        code = (e as dynamic).code as String?;
      } catch (_) {}
      return mapFirestoreUserError(
        e,
        code: code,
        fallback: 'Could not add manager.',
      );
    }
  }

  Future<String?> updateManagerInviteDisplayName({
    required String companyId,
    required String inviteId,
    required String? displayName,
  }) async {
    try {
      final trimmed = displayName?.trim() ?? '';
      await _managerInvitesCol(companyId).doc(inviteId).set({
        if (trimmed.isEmpty)
          'displayName': FieldValue.delete()
        else
          'displayName': trimmed,
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('updateManagerInviteDisplayName error: $e');
      return 'Could not update name.';
    }
  }

  Future<String?> removeManagerInvite({
    required String companyId,
    required String inviteId,
  }) async {
    try {
      final invites = await listManagerInvites(companyId);
      if (!canRemoveManager(inviteCount: invites.length)) {
        return 'Keep at least one manager.';
      }
      ManagerInvite? target;
      for (final i in invites) {
        if (i.id == inviteId) target = i;
      }
      if (target == null) return 'Invite not found.';
      await _managerInvitesCol(companyId).doc(inviteId).delete();
      final users = await _usersCol
          .where('email', isEqualTo: target.email)
          .where('companyId', isEqualTo: companyId)
          .get();
      for (final doc in users.docs) {
        await doc.reference.set({
          'role': FieldValue.delete(),
          'companyId': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
      return null;
    } catch (e) {
      debugPrint('removeManagerInvite error: $e');
      return 'Could not remove manager.';
    }
  }

  /// Claims a matching manager invite for the current Google user (no role yet).
  Future<String?> tryClaimManagerInvite() async {
    final user = _authUser;
    if (user == null || user.isAnonymous) return null;
    final email = ManagerInvite.normalizeEmail(user.email ?? '');
    if (email.isEmpty) return null;
    _managerClaimError = null;
    try {
      final snap = await _db
          .collectionGroup('managerInvites')
          .where('email', isEqualTo: email)
          .get();
      final eligible = <({DocumentReference<Map<String, dynamic>> ref,
          ManagerInvite invite, Company company})>[];
      for (final doc in snap.docs) {
        final companyId = doc.reference.parent.parent?.id;
        if (companyId == null) continue;
        final companySnap = await _companiesCol.doc(companyId).get();
        if (!companySnap.exists) continue;
        final company = Company.fromDoc(companySnap);
        final invite = ManagerInvite.fromMap(
          doc.id,
          doc.data(),
          companyId: companyId,
        );
        if (isInviteEligible(
          companyStatus: company.status,
          companyCreatedByUid: company.createdByUid,
          signedInUid: user.uid,
        )) {
          eligible.add((ref: doc.reference, invite: invite, company: company));
        }
      }
      switch (pickClaimTarget(eligible.map((e) => e.company.id).toList())) {
        case ClaimPick.none:
          notifyListeners();
          return null;
        case ClaimPick.many:
          _managerClaimError =
              'Contact support — this email is invited to multiple companies.';
          notifyListeners();
          return _managerClaimError;
        case ClaimPick.one:
          final hit = eligible.first;
          final locSnap = await _companiesCol
              .doc(hit.company.id)
              .collection('locations')
              .limit(1)
              .get();
          final locationId =
              locSnap.docs.isEmpty ? null : locSnap.docs.first.id;
          await _usersCol.doc(user.uid).set({
            'role': UserRole.companyManager.firestoreValue,
            'companyId': hit.company.id,
            'locationId': ?locationId,
            'email': email,
            'displayName': user.displayName ?? '',
          }, SetOptions(merge: true));
          await hit.ref.set({
            'claimedUid': user.uid,
          }, SetOptions(merge: true));
          notifyListeners();
          return null;
      }
    } catch (e) {
      debugPrint('tryClaimManagerInvite error: $e');
      return null;
    }
  }

  void _bindCompaniesList() {
    if (_companiesSub != null) return;
    _companiesSub = _companiesCol.orderBy('name').snapshots().listen(
      (snap) {
        _companies = snap.docs.map(Company.fromDoc).toList();
        notifyListeners();
      },
      onError: (Object e) => debugPrint('companies listen error: $e'),
    );
  }

  Future<int> locationCountForCompany(String companyId) async {
    try {
      final snap =
          await _companiesCol.doc(companyId).collection('locations').get();
      return snap.docs.length;
    } catch (_) {
      return 0;
    }
  }

  Future<String?> updateCompanyPrimaryColor(String hex) async {
    final id = _activeCompanyId;
    if (id == null) return 'No active company.';
    final parsed = parseBrandColor(hex);
    if (parsed == null) return 'Invalid color.';
    final normalized = formatBrandColor(parsed);
    try {
      await _companiesCol.doc(id).set(
        {'primaryColor': normalized},
        SetOptions(merge: true),
      );
      if (_activeCompany != null) {
        _activeCompany = _activeCompany!.copyWith(primaryColor: normalized);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCompanyPrimaryColor error: $e');
      return 'Could not save brand color.';
    }
  }

  Future<String?> updateCompanyThemeId(String themeId) async {
    final id = _activeCompanyId;
    if (id == null) return 'No active company.';
    final allowed = AppThemeId.values.map((e) => e.name).toSet();
    if (!allowed.contains(themeId)) return 'Unknown theme.';
    final parsed = AppThemeIdX.parse(themeId);
    try {
      await _companiesCol.doc(id).set(
        {'themeId': parsed.firestoreValue},
        SetOptions(merge: true),
      );
      if (_activeCompany != null) {
        _activeCompany =
            _activeCompany!.copyWith(themeId: parsed.firestoreValue);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCompanyThemeId error: $e');
      return 'Could not save theme.';
    }
  }

  /// Updates the company display name shown on employee login.
  Future<String?> updateCompanyName(String raw) async {
    final id = _activeCompanyId;
    if (id == null) return 'No active company.';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'Enter a company name.';
    if (trimmed.length > 80) return 'Name is too long (max 80 characters).';
    try {
      await _companiesCol.doc(id).set(
        {'name': trimmed},
        SetOptions(merge: true),
      );
      if (_activeCompany != null) {
        _activeCompany = _activeCompany!.copyWith(name: trimmed);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCompanyName error: $e');
      return 'Could not save company name.';
    }
  }

  /// Saves or clears the company logo URL shown on employee login.
  Future<String?> updateCompanyLogoUrl(String? raw) async {
    final id = _activeCompanyId;
    if (id == null) return 'No active company.';
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      try {
        await _companiesCol.doc(id).set(
          {'logoUrl': FieldValue.delete()},
          SetOptions(merge: true),
        );
        if (_activeCompany != null) {
          _activeCompany = _activeCompany!.copyWith(clearLogoUrl: true);
        }
        notifyListeners();
        return null;
      } catch (e) {
        debugPrint('updateCompanyLogoUrl clear error: $e');
        return 'Could not clear logo.';
      }
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a full https:// image URL.';
    }
    try {
      await _companiesCol.doc(id).set(
        {'logoUrl': trimmed},
        SetOptions(merge: true),
      );
      if (_activeCompany != null) {
        _activeCompany = _activeCompany!.copyWith(logoUrl: trimmed);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCompanyLogoUrl error: $e');
      return 'Could not save logo.';
    }
  }

  /// Saves or clears the company Google review URL used for the QR dialog.
  Future<String?> updateCompanyGoogleReviewUrl(String? raw) async {
    final id = _activeCompanyId;
    if (id == null) return 'No active company.';
    final trimmed = raw?.trim() ?? '';
    if (trimmed.isEmpty) {
      try {
        await _companiesCol.doc(id).set(
          {'googleReviewUrl': FieldValue.delete()},
          SetOptions(merge: true),
        );
        if (_activeCompany != null) {
          _activeCompany =
              _activeCompany!.copyWith(clearGoogleReviewUrl: true);
        }
        notifyListeners();
        return null;
      } catch (e) {
        debugPrint('updateCompanyGoogleReviewUrl clear error: $e');
        return 'Could not clear review link.';
      }
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      return 'Enter a full https:// link from Google.';
    }
    try {
      await _companiesCol.doc(id).set(
        {'googleReviewUrl': trimmed},
        SetOptions(merge: true),
      );
      if (_activeCompany != null) {
        _activeCompany =
            _activeCompany!.copyWith(googleReviewUrl: trimmed);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('updateCompanyGoogleReviewUrl error: $e');
      return 'Could not save review link.';
    }
  }

  Future<String?> addRequestPreset(String label) async {
    final err = validatePresetLabel(label);
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    if (_requestPresets.length >= kStaffRequestPresetCap) {
      return 'Limit of $kStaffRequestPresetCap presets reached.';
    }
    final me = _appUser;
    try {
      final nextOrder = _requestPresets.isEmpty
          ? 0
          : _requestPresets.map((p) => p.sortOrder).reduce((a, b) => a > b ? a : b) +
              1;
      await loc.collection('requestPresets').add({
        'label': label.trim(),
        'sortOrder': nextOrder,
        if (me != null) 'createdByUid': me.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('addRequestPreset error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not add preset.');
    }
  }

  Future<String?> updateRequestPreset({
    required String id,
    required String label,
    int? sortOrder,
  }) async {
    final err = validatePresetLabel(label);
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    try {
      final data = <String, dynamic>{'label': label.trim()};
      if (sortOrder != null) data['sortOrder'] = sortOrder;
      await loc
          .collection('requestPresets')
          .doc(id)
          .set(data, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('updateRequestPreset error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not update preset.');
    }
  }

  Future<String?> deleteRequestPreset(String id) async {
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    try {
      await loc.collection('requestPresets').doc(id).delete();
      return null;
    } catch (e) {
      debugPrint('deleteRequestPreset error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not delete preset.');
    }
  }

  Future<String?> addCompletionPreset(String label) async {
    final err = validatePresetLabel(label);
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    if (_completionPresets.length >= kCompletionPresetCap) {
      return 'Limit of $kCompletionPresetCap completion presets reached.';
    }
    final me = _appUser;
    try {
      final nextOrder = _completionPresets.isEmpty
          ? 0
          : _completionPresets
                  .map((p) => p.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      await loc.collection('completionPresets').add({
        'label': label.trim(),
        'sortOrder': nextOrder,
        if (me != null) 'createdByUid': me.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('addCompletionPreset error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not add preset.');
    }
  }

  Future<String?> updateCompletionPreset({
    required String id,
    required String label,
    int? sortOrder,
  }) async {
    final err = validatePresetLabel(label);
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    try {
      final data = <String, dynamic>{'label': label.trim()};
      if (sortOrder != null) data['sortOrder'] = sortOrder;
      await loc
          .collection('completionPresets')
          .doc(id)
          .set(data, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('updateCompletionPreset error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not update preset.');
    }
  }

  Future<String?> deleteCompletionPreset(String id) async {
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    try {
      await loc.collection('completionPresets').doc(id).delete();
      return null;
    } catch (e) {
      debugPrint('deleteCompletionPreset error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not delete preset.');
    }
  }

  Future<String?> createStaffRequest({
    required String text,
    String? presetId,
  }) async {
    if (!canWriteAtActiveLocation) return readOnlyMessage;
    final err = validateRequestText(text);
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    final name = profile?.name.trim() ?? '';
    if (name.isEmpty) return 'Sign in as an employee first.';
    try {
      final data = <String, dynamic>{
        'text': text.trim(),
        'employeeName': name,
        'employeeProfileKey': staffRequestProfileKey(name),
        'source': StaffRequestSource.employeeAsk.firestoreValue,
        'status': StaffRequestStatus.pending.firestoreValue,
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (presetId != null) data['presetId'] = presetId;
      await loc.collection('staffRequests').add(data);
      return null;
    } catch (e) {
      debugPrint('createStaffRequest error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not send request.');
    }
  }

  Future<String?> _transitionStaffRequest(
    String id,
    StaffRequestStatus to,
  ) async {
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    StaffRequest? current;
    for (final r in _staffRequests) {
      if (r.id == id) current = r;
    }
    if (current == null) return 'Request not found.';
    if (!canTransition(current.status, to)) {
      return 'That status change is not allowed.';
    }
    final uid = _appUser?.uid;
    try {
      final data = <String, dynamic>{
        'status': to.firestoreValue,
      };
      switch (to) {
        case StaffRequestStatus.accepted:
          data['acceptedAt'] = FieldValue.serverTimestamp();
          if (uid != null) data['acceptedByUid'] = uid;
        case StaffRequestStatus.closed:
          data['completedAt'] = FieldValue.serverTimestamp();
          if (uid != null) data['completedByUid'] = uid;
          data['reviewedAt'] = FieldValue.serverTimestamp();
          if (uid != null) data['reviewedByUid'] = uid;
        case StaffRequestStatus.assigned:
          data['reviewedAt'] = FieldValue.delete();
          data['reviewedByUid'] = FieldValue.delete();
        case StaffRequestStatus.awaitingReview:
          data['completedAt'] = FieldValue.serverTimestamp();
          if (uid != null) data['completedByUid'] = uid;
        case StaffRequestStatus.dismissed:
          data['dismissedAt'] = FieldValue.serverTimestamp();
        case StaffRequestStatus.pending:
        case StaffRequestStatus.completed:
          break;
      }
      await loc
          .collection('staffRequests')
          .doc(id)
          .set(data, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('transitionStaffRequest error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not update request.');
    }
  }

  Future<String?> acceptStaffRequest(String id) =>
      _transitionStaffRequest(id, StaffRequestStatus.accepted);

  Future<String?> dismissStaffRequest(String id) =>
      _transitionStaffRequest(id, StaffRequestStatus.dismissed);

  Future<String?> completeStaffRequest(String id) =>
      _transitionStaffRequest(id, StaffRequestStatus.closed);

  Future<String?> closeStaffRequest(String id) =>
      _transitionStaffRequest(id, StaffRequestStatus.closed);

  Future<String?> reopenStaffRequest(String id) =>
      _transitionStaffRequest(id, StaffRequestStatus.assigned);

  Future<String?> sendBackStaffRequest({
    required String id,
    required String revisionNote,
  }) async {
    final noteErr = validateRevisionNote(revisionNote);
    if (noteErr != null) return noteErr;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    StaffRequest? current;
    for (final r in _staffRequests) {
      if (r.id == id) current = r;
    }
    if (current == null) return 'Request not found.';
    if (!canTransition(current.status, StaffRequestStatus.assigned)) {
      return 'That status change is not allowed.';
    }
    try {
      await loc.collection('staffRequests').doc(id).set({
        'status': StaffRequestStatus.assigned.firestoreValue,
        'revisionNote': revisionNote.trim(),
        'revisionRequestedAt': FieldValue.serverTimestamp(),
        'reviewedAt': FieldValue.delete(),
        'reviewedByUid': FieldValue.delete(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('sendBackStaffRequest error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not send back.');
    }
  }

  Future<String?> assignStaffRequest({
    required String id,
    required String assigneeName,
    DateTime? dueAt,
  }) async {
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    final name = assigneeName.trim();
    if (name.isEmpty) return 'Pick a team member.';
    StaffRequest? current;
    for (final r in _staffRequests) {
      if (r.id == id) current = r;
    }
    if (current == null) return 'Request not found.';
    if (!canTransition(current.status, StaffRequestStatus.assigned)) {
      return 'That status change is not allowed.';
    }
    final uid = _appUser?.uid;
    try {
      final data = <String, dynamic>{
        'status': StaffRequestStatus.assigned.firestoreValue,
        'assigneeName': name,
        'assigneeProfileKey': staffRequestProfileKey(name),
        'assignedAt': FieldValue.serverTimestamp(),
        'assignedByUid': ?uid,
      };
      if (dueAt != null) {
        data['dueAt'] = Timestamp.fromDate(dueAt);
      } else {
        data['dueAt'] = FieldValue.delete();
      }
      await loc
          .collection('staffRequests')
          .doc(id)
          .set(data, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('assignStaffRequest error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not assign.');
    }
  }

  Future<String?> createAssignedTask({
    required String text,
    required String assigneeName,
    DateTime? dueAt,
  }) async {
    final err = validateRequestText(text);
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    final name = assigneeName.trim();
    if (name.isEmpty) return 'Pick a team member.';
    final uid = _appUser?.uid;
    try {
      await loc.collection('staffRequests').add({
        'text': text.trim(),
        'employeeName': name,
        'employeeProfileKey': staffRequestProfileKey(name),
        'assigneeName': name,
        'assigneeProfileKey': staffRequestProfileKey(name),
        'source': StaffRequestSource.managerAssign.firestoreValue,
        'status': StaffRequestStatus.assigned.firestoreValue,
        'assignedAt': FieldValue.serverTimestamp(),
        'assignedByUid': ?uid,
        if (dueAt != null) 'dueAt': Timestamp.fromDate(dueAt),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('createAssignedTask error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not create task.');
    }
  }

  Future<String?> createPersonalTodo(String text) async {
    if (!canWriteAtActiveLocation) return readOnlyMessage;
    final err = validateRequestText(text);
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    final name = profile?.name.trim() ?? '';
    if (name.isEmpty) return 'Sign in as an employee first.';
    final key = staffRequestProfileKey(name);
    try {
      await loc.collection('staffRequests').add({
        'text': text.trim(),
        'employeeName': name,
        'employeeProfileKey': key,
        'assigneeName': name,
        'assigneeProfileKey': key,
        'source': StaffRequestSource.employeePersonal.firestoreValue,
        'status': StaffRequestStatus.assigned.firestoreValue,
        'assignedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('createPersonalTodo error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not add to-do.');
    }
  }

  Future<String?> deletePersonalTodo(String id) async {
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    StaffRequest? current;
    for (final r in _staffRequests) {
      if (r.id == id) current = r;
    }
    if (current == null) return 'Not found.';
    if (current.source != StaffRequestSource.employeePersonal) {
      return 'Only personal to-dos can be removed this way.';
    }
    try {
      await loc.collection('staffRequests').doc(id).delete();
      return null;
    } catch (e) {
      debugPrint('deletePersonalTodo error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not remove to-do.');
    }
  }

  Future<String?> submitAssignedCompletion({
    required String id,
    required String note,
    String? completionPresetId,
    String? completionPresetLabel,
  }) async {
    if (!canWriteAtActiveLocation) return readOnlyMessage;
    final err = validateCompletionPayload(
      note: note,
      presetLabel: completionPresetLabel,
    );
    if (err != null) return err;
    final loc = _locationRef;
    if (loc == null) return 'No active location.';
    StaffRequest? current;
    for (final r in _staffRequests) {
      if (r.id == id) current = r;
    }
    if (current == null) return 'Not found.';
    if (current.isPersonal) {
      return 'Personal to-dos are removed, not reviewed.';
    }
    if (!canTransition(current.status, StaffRequestStatus.awaitingReview)) {
      return 'That status change is not allowed.';
    }
    final uid = _appUser?.uid;
    try {
      await loc.collection('staffRequests').doc(id).set({
        'status': StaffRequestStatus.awaitingReview.firestoreValue,
        'completionNote': note.trim(),
        'completionPresetId': ?completionPresetId,
        if (completionPresetLabel != null)
          'completionPresetLabel': completionPresetLabel.trim(),
        'completedAt': FieldValue.serverTimestamp(),
        'completedByUid': ?uid,
        'revisionNote': FieldValue.delete(),
        'revisionRequestedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
      return null;
    } catch (e) {
      debugPrint('submitAssignedCompletion error: $e');
      return mapFirestoreUserError(e, fallback: 'Could not submit.');
    }
  }

  Future<String?> approveCompany(String companyId) async {
    final admin = _appUser;
    if (admin?.role != UserRole.platformAdmin) return 'Not authorized.';
    try {
      await _companiesCol.doc(companyId).set(
        {
          'status': CompanyStatus.active.firestoreValue,
          'approvedAt': FieldValue.serverTimestamp(),
          'approvedBy': admin!.uid,
          'rejectionReason': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      debugPrint('approveCompany error: $e');
      return 'Could not approve the company.';
    }
  }

  Future<String?> rejectCompany(String companyId, {String? reason}) async {
    final admin = _appUser;
    if (admin?.role != UserRole.platformAdmin) return 'Not authorized.';
    try {
      await _companiesCol.doc(companyId).set(
        {
          'status': CompanyStatus.suspended.firestoreValue,
          if (reason != null && reason.trim().isNotEmpty)
            'rejectionReason': reason.trim(),
        },
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      debugPrint('rejectCompany error: $e');
      return 'Could not reject the company.';
    }
  }

  Future<String?> setCompanyActive(String companyId, bool active) async {
    final admin = _appUser;
    if (admin?.role != UserRole.platformAdmin) return 'Not authorized.';
    try {
      await _companiesCol.doc(companyId).set(
        {
          'status': active
              ? CompanyStatus.active.firestoreValue
              : CompanyStatus.suspended.firestoreValue,
        },
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      debugPrint('setCompanyActive error: $e');
      return 'Could not update the company.';
    }
  }

  Future<void> openCompanyAsAdmin(String companyId, {String? locationId}) async {
    await setActiveCompany(companyId);
    if (locationId != null) {
      await setActiveLocation(locationId);
    } else {
      final locs = await _companiesCol
          .doc(companyId)
          .collection('locations')
          .orderBy('name')
          .limit(1)
          .get();
      if (locs.docs.isNotEmpty) {
        await setActiveLocation(locs.docs.first.id);
      }
    }
    notifyListeners();
  }

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
    await rememberRecentLocation(locationId);
    employeeLoginResume = EmployeeLoginResume.none;
    _pinUnlockedThisLaunch = false;
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
      final trialEnd = DateTime.now().add(const Duration(days: 14));
      final ref = _locationsCol.doc();
      await ref.set(
        Location(
          id: ref.id,
          name: trimmed,
          city: city.trim(),
          siteCode: siteCode.trim(),
          accessStatus: LocationAccessStatus.trial,
          trialEndsAt: trialEnd,
        ).toMap(),
      );
      await previewCompany(_activeCompanyId!);
      return ref.id;
    } catch (e) {
      debugPrint('createLocation error: $e');
      return null;
    }
  }

  Future<String?> setLocationAccessStatus({
    required String locationId,
    required LocationAccessStatus status,
    DateTime? trialEndsAt,
  }) async {
    final company = _activeCompany;
    if (company == null) return 'No active company.';
    if (status == LocationAccessStatus.comp) {
      return 'Only a platform admin can mark a site as comp.';
    }
    if (status == LocationAccessStatus.active) {
      final others = _companyLocations.where((l) => l.id != locationId).map(
            (l) => entitlement.effectiveAccess(
              l.accessStatus,
              trialEndsAt: l.trialEndsAt,
            ),
          );
      final used = entitlement.seatsUsed(others);
      if (!entitlement.canActivateAnother(
        purchasedSeats: company.purchasedSeats,
        seatsUsed: used,
      )) {
        return 'No seats left. Buy more seats or ask platform admin.';
      }
    }
    try {
      final data = <String, dynamic>{
        'accessStatus': status.firestoreValue,
      };
      if (status == LocationAccessStatus.trial) {
        data['trialEndsAt'] = Timestamp.fromDate(
          trialEndsAt ?? DateTime.now().add(const Duration(days: 14)),
        );
      } else {
        data['trialEndsAt'] = FieldValue.delete();
      }
      await _locationsCol.doc(locationId).set(data, SetOptions(merge: true));
      if (_activeCompanyId != null) {
        await previewCompany(_activeCompanyId!);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('setLocationAccessStatus error: $e');
      return 'Could not update location access.';
    }
  }

  Future<String?> adminSetPurchasedSeats({
    required String companyId,
    required int seats,
  }) async {
    if (seats < 0) return 'Seats cannot be negative.';
    try {
      await _companiesCol.doc(companyId).set(
        {'purchasedSeats': seats},
        SetOptions(merge: true),
      );
      if (_activeCompanyId == companyId && _activeCompany != null) {
        _activeCompany = _activeCompany!.copyWith(purchasedSeats: seats);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('adminSetPurchasedSeats error: $e');
      return 'Could not update seats.';
    }
  }

  Future<String?> adminSetLocationAccessStatus({
    required String companyId,
    required String locationId,
    required LocationAccessStatus status,
    DateTime? trialEndsAt,
  }) async {
    try {
      final data = <String, dynamic>{
        'accessStatus': status.firestoreValue,
      };
      if (status == LocationAccessStatus.trial) {
        data['trialEndsAt'] = Timestamp.fromDate(
          trialEndsAt ?? DateTime.now().add(const Duration(days: 14)),
        );
      } else {
        data['trialEndsAt'] = FieldValue.delete();
      }
      await _companiesCol
          .doc(companyId)
          .collection('locations')
          .doc(locationId)
          .set(data, SetOptions(merge: true));
      if (_activeCompanyId == companyId) {
        await previewCompany(companyId);
      }
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('adminSetLocationAccessStatus error: $e');
      return 'Could not update location access.';
    }
  }

  Future<List<Location>> locationsForCompany(String companyId) async {
    final snap = await _companiesCol
        .doc(companyId)
        .collection('locations')
        .orderBy('name')
        .get();
    return snap.docs.map(Location.fromDoc).toList();
  }

  Future<String?> startSeatCheckout({required int quantity}) async {
    final company = _activeCompany;
    if (company == null) return 'No active company.';
    if (quantity < 1) return 'Quantity must be at least 1.';
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createCheckoutSession');
      final result = await callable.call(<String, dynamic>{
        'companyId': company.id,
        'quantity': quantity,
        'returnOrigin': Uri.base.origin,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['updated'] == true) {
        await previewCompany(company.id);
        return null;
      }
      final url = data['url'] as String?;
      if (url == null || url.isEmpty) return 'No checkout URL returned.';
      final ok = await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
      if (!ok) return 'Could not open Stripe Checkout.';
      return null;
    } catch (e) {
      debugPrint('startSeatCheckout error: $e');
      return 'Could not start checkout. Is Stripe configured?';
    }
  }

  Future<String?> openBillingPortal() async {
    final company = _activeCompany;
    if (company == null) return 'No active company.';
    try {
      final callable =
          FirebaseFunctions.instance.httpsCallable('createPortalSession');
      final result = await callable.call(<String, dynamic>{
        'companyId': company.id,
        'returnOrigin': Uri.base.origin,
      });
      final url = (result.data as Map)['url'] as String?;
      if (url == null || url.isEmpty) return 'No portal URL returned.';
      final ok = await launchUrl(Uri.parse(url), webOnlyWindowName: '_self');
      if (!ok) return 'Could not open billing portal.';
      return null;
    } catch (e) {
      debugPrint('openBillingPortal error: $e');
      return 'Buy seats once before managing payment methods.';
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
    _presetsSub?.cancel();
    _completionPresetsSub?.cancel();
    _staffRequestsSub?.cancel();
    _subsSub = _workersSub = null;
    _pricesSub = _settingsSub = _itemsSub = null;
    _presetsSub = _completionPresetsSub = _staffRequestsSub = null;
    _submissions = [];
    _workers = [];
    _requestPresets = [];
    _completionPresets = [];
    _staffRequests = [];
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

    _presetsSub = base
        .collection('requestPresets')
        .orderBy('sortOrder')
        .snapshots()
        .listen((snap) {
      _requestPresets = snap.docs.map(RequestPreset.fromDoc).toList();
      notifyListeners();
    }, onError: (Object e) => debugPrint('requestPresets listen error: $e'));

    _completionPresetsSub = base
        .collection('completionPresets')
        .orderBy('sortOrder')
        .snapshots()
        .listen((snap) {
      _completionPresets = snap.docs.map(RequestPreset.fromDoc).toList();
      notifyListeners();
    }, onError: (Object e) =>
        debugPrint('completionPresets listen error: $e'));

    _staffRequestsSub = base
        .collection('staffRequests')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .listen((snap) {
      _staffRequests = snap.docs.map(StaffRequest.fromDoc).toList();
      notifyListeners();
    }, onError: (Object e) => debugPrint('staffRequests listen error: $e'));
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
    if (_employeeName != null && _employeeName!.trim().isNotEmpty) {
      final name = _employeeName!.trim().toLowerCase();
      final onRoster =
          _workers.any((w) => w.name.trim().toLowerCase() == name);
      if (!onRoster) {
        _employeeName = null;
        _employeeLocationId = null;
        _pinUnlockedThisLaunch = false;
        employeeLoginResume = EmployeeLoginResume.name;
        _prefs?.remove(_kEmployeeProfile);
      }
    }
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
    if (!canWriteAtActiveLocation) {
      debugPrint('addSubmission: location read-only');
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
    if (!canWriteAtActiveLocation) return readOnlyMessage;
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
