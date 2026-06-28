import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/scorecard_config.dart';
import '../models/submission.dart';
import '../services/store.dart';
import '../theme.dart';

/// Opens the shared scorecard editor. Returns the edited [Submission] (not yet
/// persisted) or null if cancelled. For [isNew] entries a fresh id is created.
Future<Submission?> showSubmissionEditor(
  BuildContext context, {
  Submission? existing,
  bool isNew = false,
}) {
  return showDialog<Submission>(
    context: context,
    builder: (_) => _SubmissionEditorDialog(existing: existing, isNew: isNew),
  );
}

class _SubmissionEditorDialog extends StatefulWidget {
  const _SubmissionEditorDialog({this.existing, this.isNew = false});
  final Submission? existing;
  final bool isNew;

  @override
  State<_SubmissionEditorDialog> createState() =>
      _SubmissionEditorDialogState();
}

class _SubmissionEditorDialogState extends State<_SubmissionEditorDialog> {
  late final Map<String, int> _counts;
  late final TextEditingController _baGoal;
  late int _talkedTo;
  late DateTime _date;
  String? _name;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _counts = {for (final i in kLineItems) i.id: e?.countOf(i.id) ?? 0};
    _baGoal =
        TextEditingController(text: (e?.baGoal ?? 40).toStringAsFixed(0));
    _talkedTo = e?.talkedTo ?? 0;
    _date = e?.submittedAt ?? DateTime.now();
    _name = e?.employeeName;
  }

  @override
  void dispose() {
    _baGoal.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _save() {
    final name = _name?.trim();
    if (widget.isNew && (name == null || name.isEmpty)) return;
    final result = Submission(
      id: widget.existing?.id ?? const Uuid().v4(),
      employeeName: name ?? widget.existing?.employeeName ?? 'Unknown',
      baGoal: double.tryParse(_baGoal.text.trim()) ?? 0,
      counts: Map.of(_counts),
      submittedAt: _date,
      talkedTo: _talkedTo,
      approved: widget.existing?.approved ?? false,
      approvedBy: widget.existing?.approvedBy,
      approvedAt: widget.existing?.approvedAt,
    );
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final workers = Store.instance.workers;
    return AlertDialog(
      title: Text(widget.isNew
          ? 'Add scorecard'
          : 'Edit ${widget.existing?.employeeName ?? ''}'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.isNew) ...[
                DropdownButtonFormField<String>(
                  initialValue: _name,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Team member'),
                  items: [
                    for (final w in workers)
                      DropdownMenuItem(value: w.name, child: Text(w.name)),
                  ],
                  onChanged: (v) => setState(() => _name = v),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(labelText: 'Date'),
                    child: Text(
                      '${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Row(
                children: [
                  const Expanded(child: Text('Cars talked to')),
                  _Stepper(
                    value: _talkedTo,
                    onChanged: (v) => setState(() => _talkedTo = v),
                  ),
                ],
              ),
              Row(
                children: [
                  const Expanded(child: Text('BA Goal %')),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: _baGoal,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      decoration: const InputDecoration(isDense: true),
                    ),
                  ),
                ],
              ),
              for (final section in Store.instance.enabledSections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Text(section.title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      )),
                ),
                for (final item in itemsFor(section))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Expanded(child: Text(item.label)),
                        _Stepper(
                          value: _counts[item.id] ?? 0,
                          onChanged: (v) =>
                              setState(() => _counts[item.id] = v),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        SizedBox(
          width: 30,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }
}
