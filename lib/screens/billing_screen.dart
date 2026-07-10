import 'package:flutter/material.dart';

import '../models/location.dart';
import '../models/location_access.dart';
import '../services/store.dart';
import '../theme.dart';
import '../utils/location_entitlement.dart' as entitlement;
import '../widgets/store_message.dart';

/// Manager view of per-location seats + Stripe Checkout / Portal.
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

  Future<void> _buySeats(int purchased, int used) async {
    final controller = TextEditingController(
      text: '${purchased > used ? purchased : used}',
    );
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Buy / update seats'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Seat quantity',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final n = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, n);
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (qty == null || !mounted) return;
    if (qty < 1) {
      showStoreMessage(context, 'Enter a quantity of at least 1', error: true);
      return;
    }
    setState(() => _busy = true);
    final err = await Store.instance.startSeatCheckout(quantity: qty);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    final after = Store.instance.activeCompany?.purchasedSeats;
    if (after == qty) {
      showStoreMessage(context, 'Seats updated to $qty');
    }
  }

  Future<void> _openPortal() async {
    setState(() => _busy = true);
    final err = await Store.instance.openBillingPortal();
    if (!mounted) return;
    setState(() => _busy = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
    }
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
          final over = entitlement.isOverAllocated(
            purchasedSeats: purchased,
            seatsUsed: used,
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
                        if (company?.billingStatus != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Billing status: ${company!.billingStatus}',
                            style: TextStyles.caption,
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Text(
                          'Buy seats with Stripe or ask a platform admin. Choose which sites use a paid seat.',
                          style: TextStyles.caption,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed:
                              _busy ? null : () => _buySeats(purchased, used),
                          child: const Text('Buy / update seats'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _busy ? null : _openPortal,
                          child: const Text('Manage payment & invoices'),
                        ),
                      ],
                    ),
                  ),
                  if (over) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Over allocated: $used active sites but only $purchased seats. Move extras to read-only or buy seats.',
                      style: const TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  for (final loc in locs) ...[
                    AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(loc.displayName, style: TextStyles.subheading),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final effective = entitlement.effectiveAccess(
                                loc.accessStatus,
                                trialEndsAt: loc.trialEndsAt,
                              );
                              final isComp =
                                  effective == LocationAccessStatus.comp;
                              if (isComp) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Chip(
                                      label: Text(
                                        LocationAccessStatus.comp.label,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'Comp site — full access, no seat. Only platform admin can change.',
                                      style: TextStyles.caption,
                                    ),
                                  ],
                                );
                              }
                              return SegmentedButton<LocationAccessStatus>(
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
                                selected: {effective},
                                onSelectionChanged: _busy
                                    ? null
                                    : (s) => _setAccess(loc, s.first),
                              );
                            },
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
