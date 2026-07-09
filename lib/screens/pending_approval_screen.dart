import 'package:flutter/material.dart';

import '../services/store.dart';
import '../theme.dart';
import '../widgets/company_header.dart';
import '../widgets/profile_menu.dart';

/// Shown to a new manager while their company awaits platform approval.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Account setup'),
        actions: const [ProfileAction()],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AnimatedBuilder(
                animation: Store.instance,
                builder: (context, _) {
                  final company = Store.instance.activeCompany;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CompanyHeader(company: company),
                      const SizedBox(height: 24),
                      AppCard(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.success),
                                SizedBox(width: 8),
                                Text('Account created',
                                    style: TextStyles.subheading),
                              ],
                            ),
                            const SizedBox(height: 16),
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.schedule_rounded,
                                    color: AppColors.warning),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Waiting for approval',
                                          style: TextStyles.subheading),
                                      SizedBox(height: 4),
                                      Text(
                                        'Your company is being reviewed. '
                                        'You\'ll get access within 24 hours.',
                                        style: TextStyles.caption,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (company != null) ...[
                              const SizedBox(height: 20),
                              const Divider(),
                              const SizedBox(height: 12),
                              Text(company.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  )),
                              const SizedBox(height: 8),
                              Text(
                                'Company code: ${company.companyCode}',
                                style: TextStyles.body,
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Share this code with employees once approved.',
                                style: TextStyles.caption,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
