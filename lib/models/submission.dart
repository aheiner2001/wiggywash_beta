import 'scorecard_config.dart';

/// A single submitted (or in-progress) shift scorecard.
class Submission {
  Submission({
    required this.id,
    required this.employeeName,
    required this.baGoal,
    required this.counts,
    required this.submittedAt,
    this.talkedTo = 0,
    this.approved = false,
    this.approvedBy,
    this.approvedAt,
    this.editedBy,
    this.editedAt,
  });

  final String id;
  final String employeeName;

  /// Business-average goal entered by the employee, as a percentage (e.g. 40).
  final double baGoal;

  /// Map of line-item id -> tally count.
  final Map<String, int> counts;
  final DateTime submittedAt;

  /// Cars the employee talked to — the denominator for business average / BA%.
  final int talkedTo;

  /// Approval workflow: a scorecard is pending until a manager approves it.
  final bool approved;
  final String? approvedBy;
  final DateTime? approvedAt;

  /// Audit trail: set when a manager edits the submission after the fact.
  final String? editedBy;
  final DateTime? editedAt;

  bool get wasEdited => editedAt != null;

  int countOf(String id) => counts[id] ?? 0;

  int sectionCount(WashSection section) => itemsFor(section)
      .fold(0, (sum, item) => sum + countOf(item.id));

  int get totalMemberships => sectionCount(WashSection.membership);
  int get totalSingleWashes => sectionCount(WashSection.single);
  int get totalShopSales => sectionCount(WashSection.shop);

  /// Total cars that bought any wash (memberships + single washes).
  int get totalWashes => totalMemberships + totalSingleWashes;

  double sectionRevenue(WashSection section) =>
      itemsFor(section).fold(0.0, (sum, item) {
        final price = priceOf(item);
        if (price == null) return sum;
        return sum + countOf(item.id) * price;
      });

  double get grandTotalRevenue =>
      kLineItems.fold(0.0, (sum, item) {
        final price = priceOf(item);
        if (price == null) return sum;
        return sum + countOf(item.id) * price;
      });

  /// BA Actual / conversion rate: share of washes that became memberships.
  double get conversionRate {
    if (totalWashes == 0) return 0;
    return totalMemberships / totalWashes * 100;
  }

  /// Business average using cars talked to as the denominator (matches the BA
  /// MASTER DOC). Falls back to [conversionRate] when no talked-to is recorded.
  double get businessAverage {
    if (talkedTo <= 0) return conversionRate;
    return totalMemberships / talkedTo * 100;
  }

  /// Memberships + single washes above the economy tier (everything but Economy).
  int get aboveEco {
    final economy = countOf('economy');
    return totalMemberships + totalSingleWashes - economy;
  }

  /// Weighted point total across all line items (+1 per car talked to).
  int get overallScore {
    var total = talkedTo * kTalkedToPoints;
    for (final item in kLineItems) {
      total += countOf(item.id) * pointOf(item);
    }
    return total;
  }

  Submission copyWith({
    String? employeeName,
    double? baGoal,
    Map<String, int>? counts,
    DateTime? submittedAt,
    int? talkedTo,
    bool? approved,
    String? approvedBy,
    DateTime? approvedAt,
    String? editedBy,
    DateTime? editedAt,
  }) {
    return Submission(
      id: id,
      employeeName: employeeName ?? this.employeeName,
      baGoal: baGoal ?? this.baGoal,
      counts: counts ?? this.counts,
      submittedAt: submittedAt ?? this.submittedAt,
      talkedTo: talkedTo ?? this.talkedTo,
      approved: approved ?? this.approved,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      editedBy: editedBy ?? this.editedBy,
      editedAt: editedAt ?? this.editedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeName': employeeName,
        'baGoal': baGoal,
        'counts': counts,
        'submittedAt': submittedAt.toIso8601String(),
        'talkedTo': talkedTo,
        'approved': approved,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
        if (editedBy != null) 'editedBy': editedBy,
        if (editedAt != null) 'editedAt': editedAt!.toIso8601String(),
      };

  factory Submission.fromJson(Map<String, dynamic> json) {
    final rawCounts = (json['counts'] as Map?) ?? {};
    return Submission(
      id: json['id'] as String,
      employeeName: json['employeeName'] as String? ?? 'Unknown',
      baGoal: (json['baGoal'] as num?)?.toDouble() ?? 0,
      counts: rawCounts.map((k, v) => MapEntry(k as String, (v as num).toInt())),
      submittedAt:
          DateTime.tryParse(json['submittedAt'] as String? ?? '') ??
              DateTime.now(),
      talkedTo: (json['talkedTo'] as num?)?.toInt() ?? 0,
      approved: json['approved'] as bool? ?? false,
      approvedBy: json['approvedBy'] as String?,
      approvedAt: DateTime.tryParse(json['approvedAt'] as String? ?? ''),
      editedBy: json['editedBy'] as String?,
      editedAt: DateTime.tryParse(json['editedAt'] as String? ?? ''),
    );
  }
}
