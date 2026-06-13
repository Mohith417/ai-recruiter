import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recruitment_app/features/candidates/application/candidates_providers.dart';
import 'package:recruitment_app/features/candidates/domain/candidate.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';

class CandidateDetailsPage extends ConsumerStatefulWidget {
  const CandidateDetailsPage({super.key, required this.candidateId});

  final String candidateId;

  @override
  ConsumerState<CandidateDetailsPage> createState() => _CandidateDetailsPageState();
}

class _CandidateDetailsPageState extends ConsumerState<CandidateDetailsPage> {
  static const _statuses = <String>[
    'APPLIED',
    'PARSED',
    'SCREENED',
    'INTERVIEW',
    'OFFER',
    'HIRED',
    'REJECTED',
  ];

  final _valuesCtrl = TextEditingController(text: 'transparency, collaboration, move fast, ownership');
  final _notesCtrl = TextEditingController();
  bool _isEvaluating = false;
  bool _showEditorForce = false;

  @override
  void dispose() {
    _valuesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> saveStatus(String nextStatus) async {
    final repo = ref.read(candidatesRepositoryProvider);
    await repo.updateCandidateStatus(id: widget.candidateId, status: nextStatus);
    ref.invalidate(candidateByIdProvider(widget.candidateId));
    ref.invalidate(candidatesFeedProvider);
    if (!mounted) return;
    context.pop();
  }

  Future<void> evaluateCultureFit() async {
    final values = _valuesCtrl.text.trim();
    final notes = _notesCtrl.text.trim();

    if (values.isEmpty || notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both company values and interview notes are required.')),
      );
      return;
    }

    setState(() => _isEvaluating = true);
    try {
      final repo = ref.read(candidatesRepositoryProvider);
      await repo.evaluateCultureFit(
        id: widget.candidateId,
        companyValues: values,
        interviewNotes: notes,
      );
      ref.invalidate(candidateByIdProvider(widget.candidateId));
      ref.invalidate(candidatesFeedProvider);
      setState(() => _showEditorForce = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Culture fit analysis complete!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Evaluation failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isEvaluating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final candidateAsync = ref.watch(candidateByIdProvider(widget.candidateId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Candidate Profile'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              final c = candidateAsync.valueOrNull;
              if (c == null) return;

              final nameCtrl = TextEditingController(text: c.name ?? '');
              final emailCtrl = TextEditingController(text: c.email ?? '');
              final resumeCtrl = TextEditingController(text: c.resumeFileUrl ?? '');

              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Edit candidate'),
                  content: SizedBox(
                    width: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: resumeCtrl,
                          decoration: const InputDecoration(labelText: 'Resume URL'),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;

              try {
                final repo = ref.read(candidatesRepositoryProvider);
                await repo.updateCandidate(
                  id: widget.candidateId,
                  name: nameCtrl.text.trim(),
                  email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                  resumeFileUrl: resumeCtrl.text.trim().isEmpty ? null : resumeCtrl.text.trim(),
                );
                ref.invalidate(candidateByIdProvider(widget.candidateId));
                ref.invalidate(candidatesFeedProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saved')),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Save failed: $e')),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete candidate?'),
                  content: const Text('This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (ok != true) return;

              try {
                final repo = ref.read(candidatesRepositoryProvider);
                await repo.deleteCandidate(widget.candidateId);
                ref.invalidate(candidatesFeedProvider);
                ref.invalidate(candidateByIdProvider(widget.candidateId));
                if (context.mounted) context.pop();
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Delete failed: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: candidateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Text('Failed to load candidate.\n$e', style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
        data: (Candidate c) {
          final title = (c.name?.trim().isNotEmpty ?? false) ? c.name!.trim() : 'Unnamed candidate';
          final hasFitScore = c.cultureFitScore != null;
          final showEditor = !hasFitScore || _showEditorForce;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(c.email ?? 'Email: —', style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(
                        c.resumeFileUrl ?? 'Resume: —',
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Status', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900))),
                      DropdownButton<String>(
                        value: _statuses.contains(c.status) ? c.status : 'PARSED',
                        items: _statuses
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (v) async {
                          if (v == null) return;
                          await saveStatus(v);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                
                // AI Culture-Fit Card
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.psychology_rounded, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'AI Culture Fit Alignment',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                            ),
                          ),
                          if (!showEditor) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                color: c.cultureFitScore! >= 80
                                    ? Colors.green.withValues(alpha: 0.14)
                                    : c.cultureFitScore! >= 65
                                        ? Colors.orange.withValues(alpha: 0.14)
                                        : Colors.red.withValues(alpha: 0.14),
                              ),
                              child: Text(
                                '${c.cultureFitScore}% Align',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: c.cultureFitScore! >= 80
                                      ? Colors.green.shade800
                                      : c.cultureFitScore! >= 65
                                          ? Colors.orange.shade800
                                          : Colors.red.shade800,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      if (!showEditor) ...[
                        Text(
                          'AI Analysis Rationale:',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          c.cultureFitRationale ?? 'No rationale provided.',
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: () {
                            setState(() {
                              _showEditorForce = true;
                              _notesCtrl.text = ''; // clear or reset
                            });
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Re-evaluate Candidate Fit'),
                        ),
                      ] else ...[
                        Text(
                          'Input candidate interview details to run the semantic AI comparison.',
                          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          controller: _valuesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Core Company/Team Values',
                            hintText: 'e.g. transparency, collaboration, ownership',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notesCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Recruiter Interview Notes',
                            hintText: 'Enter candidate interview summaries, answers, and observations...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _isEvaluating ? null : evaluateCultureFit,
                          icon: _isEvaluating
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.bolt_rounded),
                          label: Text(_isEvaluating ? 'Evaluating Alignment...' : 'Analyze Culture Fit'),
                        ),
                        if (_showEditorForce) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() => _showEditorForce = false);
                            },
                            child: const Text('Cancel Re-evaluation'),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Tip: changing the dropdown status saves immediately.',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
