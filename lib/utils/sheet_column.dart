import '../models/scorecard_config.dart';

/// Stable ids for Master Sheet metric columns (first/name-date is never hidden).
abstract final class SheetColumnId {
  static const first = 'first';
  static const talked = 'talked';
  static const vip = 'vip';
  static const aboveEco = 'aboveEco';
  static const ba = 'ba';
  static const score = 'score';
  static const revenue = 'revenue';

  /// Line-item columns use the item's `id` from [kLineItems].
  static String lineItem(String itemId) => 'li:$itemId';

  static List<String> allToggleableIds() => [
        talked,
        for (final i in kLineItems) lineItem(i.id),
        vip,
        aboveEco,
        ba,
        score,
        revenue,
      ];
}

enum SheetDensity { comfortable, compact, dense }

enum SheetSortKey { nameOrDate, revenue, ba, score, talked }
