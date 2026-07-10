import 'package:flutter/material.dart';

import '../models/location.dart';
import '../models/location_access.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/location_entitlement.dart' as entitlement;
import '../widgets/store_message.dart';

/// Manager view of per-location seats (Stripe self-serve comes later).
class BillingScreen extends StatefulWidget {
  const BillingScreen({super.key});

  @override
  State<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends State<BillingScreen> {
  bool _busy = false;

  Future<void> _setAccess(Location loc, LocationAccessStatus status) async {
    setState(() => _busy = true);
    final err = await Store.instance.setLocationAccessStatus(
      locationId: loc.id,
      status: status,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    showStoreMessage(
      context,
      err ?? 'Updated ${loc.displayName}',
      error: err != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Billing')),
      body: AnimatedBuilder(
        animation: Store.instance,
        builder: (context, _) {
          final company = Store.instance.activeCompany;
          final locs = Store.instance.companyLocations;
          final purchased = company?.purchasedSeats ?? 1;
          final used = entitlement.seatsUsed(
            locs.map(
              (l) => entitlement.effectiveAccess(
                l.accessStatus,
                trialEndsAt: l.trialEndsAt,
              ),
            ),
          );
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Location seats', style: TextStyles.subheading),
                        const SizedBox(height: 6),
                        Text(
                          'Seats used $used / $purchased',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Self-serve billing (Stripe) is coming later. Ask a platform admin to add seats. You can choose which sites use a seat.',
                          style: TextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final loc in locs) ...[
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(loc.displayName, style: TextStyles.subheading),
                          const SizedBox(height: 10),
                          SegmentedButton<LocationAccessStatus>(
                            segments: const [
                              ButtonSegment(
                                value: LocationAccessStatus.active,
                                label: Text('Active'),
                              ),
                              ButtonSegment(
                                value: LocationAccessStatus.trial,
                                label: Text('Trial'),
                              ),
                              ButtonSegment(
                                value: LocationAccessStatus.readOnly,
                                label: Text('Read-only'),
                              ),
                            ],
                            selected: {
                              entitlement.effectiveAccess(
                                loc.accessStatus,
                                trialEndsAt: loc.trialEndsAt,
                              ),
                            },
                            onSelectionChanged: _busy
                                ? null
                                : (s) => _setAccess(loc, s.first),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
