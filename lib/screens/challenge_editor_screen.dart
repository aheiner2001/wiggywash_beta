import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/challenge.dart';
import '../services/store.dart';
import '../theme.dart';
import '../widgets/store_message.dart';

/// Manager screen to create, edit, or clear the team challenge & reward.
class ChallengeEditorScreen extends StatefulWidget {
  const ChallengeEditorScreen({super.key});

  @override
  State<ChallengeEditorScreen> createState() => _ChallengeEditorScreenState();
}

class _ChallengeEditorScreenState extends State<ChallengeEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _reward;
  late final TextEditingController _target;
  ChallengeMetric _metric = ChallengeMetric.revenue;
  ChallengePeriod _period = ChallengePeriod.week;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final c = Store.instance.challenge;
    _title = TextEditingController(text: c?.title ?? '');
    _reward = TextEditingController(text: c?.reward ?? '');
    _target =
        TextEditingController(text: c == null ? '' : c.target.toStringAsFixed(0));
    if (c != null) {
      _metric = c.metric;
      _period = c.period;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _reward.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final target = double.tryParse(_target.text.trim()) ?? 0;
    if (title.isEmpty) {
      showStoreMessage(context, 'Give the challenge a title.', error: true);
      return;
    }
    if (target <= 0) {
      showStoreMessage(context, 'Enter a target greater than 0.', error: true);
      return;
    }
    setState(() => _saving = true);
    final err = await Store.instance.setChallenge(Challenge(
      title: title,
      reward: _reward.text.trim(),
      metric: _metric,
      period: _period,
      target: target,
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _clear() async {
    setState(() => _saving = true);
    final err = await Store.instance.setChallenge(null);
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      showStoreMessage(context, err, error: true);
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final hasExisting = Store.instance.challenge != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Challenge'),
        actions: [
          if (hasExisting)
            TextButton(
              onPressed: _saving ? null : _clear,
              child: const Text('Clear',
                  style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Title', style: TextStyles.caption),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _title,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. Membership push',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Goal', style: TextStyles.caption),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ChallengeMetric>(
                      initialValue: _metric,
                      items: [
                        for (final m in ChallengeMetric.values)
                          DropdownMenuItem(value: m, child: Text(m.label)),
                      ],
                      onChanged: (v) => setState(() => _metric = v ?? _metric),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _target,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Target',
                        hintText: 'e.g. 5000',
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text('Resets', style: TextStyles.caption),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<ChallengePeriod>(
                      initialValue: _period,
                      items: [
                        for (final p in ChallengePeriod.values)
                          DropdownMenuItem(value: p, child: Text(p.label)),
                      ],
                      onChanged: (v) => setState(() => _period = v ?? _period),
                    ),
                    const SizedBox(height: 18),
                    const Text('Reward', style: TextStyles.caption),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _reward,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'e.g. \$50 gift card for top BA',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Save challenge'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
