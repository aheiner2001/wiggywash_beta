/// Static definition of the Wiggy Wash scorecard line items, mirroring the
/// physical tally card. Editing this list updates every screen + the totals.
library;

enum WashSection { membership, single, shop }

extension WashSectionLabel on WashSection {
  String get title => switch (this) {
        WashSection.membership => 'Membership Tally',
        WashSection.single => 'Single Washes',
        WashSection.shop => 'Shop Sales',
      };
}

class LineItem {
  const LineItem({
    required this.id,
    required this.label,
    required this.section,
    this.defaultPrice,
  });

  final String id;
  final String label;
  final WashSection section;

  /// Out-of-the-box dollar value of one sale. `null` for items that ship as
  /// count-only (no fixed price on the card). The manager can override this —
  /// always read the live value via [PriceBook.priceFor] / [priceOf].
  final double? defaultPrice;
}

/// The built-in, ordered list of scorecard line items. A location can add
/// custom items, hide some of these, and reorder them on top of this baseline
/// — see [ItemBook] / [SectionBook], which the [Store] hydrates from Firestore.
const List<LineItem> kDefaultLineItems = [
  // Membership tally
  LineItem(
    id: 'full_service_protect',
    label: 'Full Service Protect',
    section: WashSection.membership,
    defaultPrice: 49,
  ),
  LineItem(
    id: 'protect',
    label: 'Protect',
    section: WashSection.membership,
    defaultPrice: 29,
  ),
  LineItem(
    id: 'shine',
    label: 'Shine',
    section: WashSection.membership,
    defaultPrice: 23,
  ),
  LineItem(
    id: 'basic',
    label: 'Basic',
    section: WashSection.membership,
    defaultPrice: 17,
  ),
  // Single washes
  LineItem(
    id: 'single_protect',
    label: 'Single Protect',
    section: WashSection.single,
    defaultPrice: 29,
  ),
  LineItem(
    id: 'single_shine',
    label: 'Single Shine',
    section: WashSection.single,
    defaultPrice: 23,
  ),
  LineItem(
    id: 'single_basic',
    label: 'Single Basic',
    section: WashSection.single,
    defaultPrice: 17,
  ),
  LineItem(
    id: 'economy',
    label: 'Economy',
    section: WashSection.single,
    defaultPrice: 11,
  ),
  // Shop sales (count-only by default — manager can attach a price)
  LineItem(
    id: 'full_service',
    label: 'Full Service',
    section: WashSection.shop,
  ),
  LineItem(
    id: 'wax_upsell',
    label: 'Wax Upsell',
    section: WashSection.shop,
  ),
];

/// Runtime registry of the *active* (location-specific) line items, seeded from
/// [kDefaultLineItems]. The [Store] swaps these in when a location's config
/// loads so every screen, the totals, and CSV export stay in sync.
class ItemBook {
  ItemBook._();

  static List<LineItem> _items = List.of(kDefaultLineItems);

  static List<LineItem> get items => _items;

  static void setItems(List<LineItem> items) {
    _items = List.of(items);
  }

  static void reset() {
    _items = List.of(kDefaultLineItems);
  }
}

/// Runtime registry for the display order of the (fixed) wash sections.
class SectionBook {
  SectionBook._();

  static List<WashSection> _order = List.of(WashSection.values);

  static List<WashSection> get order => _order;

  static void setOrder(List<WashSection> order) {
    // Keep only known sections, then append any missing so nothing disappears.
    final seen = <WashSection>{};
    final next = <WashSection>[];
    for (final s in order) {
      if (!seen.contains(s)) {
        next.add(s);
        seen.add(s);
      }
    }
    for (final s in WashSection.values) {
      if (!seen.contains(s)) next.add(s);
    }
    _order = next;
  }

  static void reset() {
    _order = List.of(WashSection.values);
  }
}

/// The active, ordered list of line items.
List<LineItem> get kLineItems => ItemBook.items;

/// Sections in the manager's chosen display order.
List<WashSection> orderedSections() => SectionBook.order;

List<LineItem> itemsFor(WashSection section) =>
    ItemBook.items.where((i) => i.section == section).toList();

LineItem itemById(String id) => ItemBook.items.firstWhere(
      (i) => i.id == id,
      orElse: () => kDefaultLineItems.firstWhere(
        (i) => i.id == id,
        orElse: () =>
            LineItem(id: id, label: id, section: WashSection.shop),
      ),
    );

/// True for items the manager added (not part of the built-in card).
bool isCustomItem(String id) => !kDefaultLineItems.any((i) => i.id == id);

/// Holds the manager's live price edits. Seeded from each item's
/// [LineItem.defaultPrice]; the [Store] hydrates overrides from local storage /
/// Firestore at startup and on every change. Kept here (not in the Store) so the
/// pure [Submission] model can compute revenue without importing services.
class PriceBook {
  PriceBook._();

  /// id -> price. A present key with a `null` value means "count only".
  static Map<String, double?> _overrides = {};

  static void setOverrides(Map<String, double?> overrides) {
    _overrides = Map.of(overrides);
  }

  static Map<String, double?> get overrides => Map.of(_overrides);

  /// The effective price for an item: the manager override if set, otherwise the
  /// built-in default. `null` means the item is tracked as a count only.
  static double? priceFor(String id) =>
      _overrides.containsKey(id) ? _overrides[id] : itemById(id).defaultPrice;

  static bool hasPrice(String id) => priceFor(id) != null;
}

/// Convenience accessor for a [LineItem]'s live price.
double? priceOf(LineItem item) => PriceBook.priceFor(item.id);

bool itemHasPrice(LineItem item) => PriceBook.hasPrice(item.id);

// ---- Point values (OVERALL SCORE) -----------------------------------------

/// Points awarded per car talked to.
const int kTalkedToPoints = 1;

/// Built-in OVERALL SCORE weight for each default line item.
const Map<String, int> kDefaultPoints = {
  'full_service_protect': 15,
  'protect': 13,
  'shine': 11,
  'basic': 9,
  'single_protect': 8,
  'single_shine': 6,
  'single_basic': 3,
  'economy': 1,
  'full_service': 9,
  'wax_upsell': 10,
};

/// Holds the manager's live point-value edits (id -> points). Hydrated by the
/// [Store] from each location's config, same pattern as [PriceBook].
class PointBook {
  PointBook._();

  static Map<String, int> _overrides = {};

  static void setOverrides(Map<String, int> overrides) {
    _overrides = Map.of(overrides);
  }

  static Map<String, int> get overrides => Map.of(_overrides);

  static int pointFor(String id) =>
      _overrides[id] ?? kDefaultPoints[id] ?? 0;
}

/// The effective point value for a line item.
int pointOf(LineItem item) => PointBook.pointFor(item.id);
