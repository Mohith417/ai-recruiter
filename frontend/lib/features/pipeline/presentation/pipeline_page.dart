import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recruitment_app/features/candidates/application/candidates_providers.dart';
import 'package:recruitment_app/features/candidates/domain/candidate.dart';
import 'package:recruitment_app/features/feed/application/jobs_providers.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';

class PipelinePage extends ConsumerStatefulWidget {
  const PipelinePage({super.key});

  static const _stages = <String>[
    'APPLIED',
    'PARSED',
    'SCREENED',
    'INTERVIEW',
    'OFFER',
    'HIRED',
    'REJECTED',
  ];

  @override
  ConsumerState<PipelinePage> createState() => _PipelinePageState();
}

class _PipelinePageState extends ConsumerState<PipelinePage> {
  final _h = ScrollController();
  final Set<String> _movingIds = <String>{};
  bool _isRefreshing = false;
  bool _showSearch = false;
  String _query = '';
  Timer? _snackbarTimer;

  @override
  void dispose() {
    _h.dispose();
    _snackbarTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final jobId = GoRouterState.of(context).uri.queryParameters['jobId'];
    final asyncCandidates = ref.watch(candidatesByJobProvider(jobId));
    final jobsAsync = ref.watch(jobsFeedProvider);
    final repo = ref.read(candidatesRepositoryProvider);

    String pipelineTitle() {
      if (jobId == null || jobId.isEmpty) return 'Hiring pipeline';
      final jobs = jobsAsync.valueOrNull;
      if (jobs == null) return 'Hiring pipeline';
      for (final j in jobs) {
        if (j.id == jobId) return 'Pipeline · ${j.title}';
      }
      return 'Hiring pipeline';
    }

    void scrollHorizontallyBy(double delta) {
      if (!_h.hasClients) return;
      final max = _h.position.maxScrollExtent;
      var target = _h.offset + delta;
      if (target < 0) target = 0;
      if (target > max) target = max;
      _h.animateTo(target, duration: 250.ms, curve: Curves.easeOut);
    }

    Future<void> refresh() async {
      if (_isRefreshing) return;
      setState(() => _isRefreshing = true);
      try {
        ref.invalidate(candidatesByJobProvider(jobId));
        await ref.read(candidatesByJobProvider(jobId).future);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Refreshed'),
            duration: Duration(milliseconds: 1200),
          ),
        );
      } finally {
        if (mounted) setState(() => _isRefreshing = false);
      }
    }

    Future<void> openCreateCandidateDialog() async {
      final nameCtrl = TextEditingController();
      final emailCtrl = TextEditingController();
      final resumeCtrl = TextEditingController();
      var selectedStatus = 'APPLIED';
      var isSubmitting = false;
      var submittedOnce = false;

      Future<void> submit(BuildContext dialogContext) async {
        final name = nameCtrl.text.trim();
        final resume = resumeCtrl.text.trim();
        if (name.isEmpty) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name is required'),
              duration: Duration(milliseconds: 1500),
            ),
          );
          return;
        }

        try {
          final created = await repo.createCandidate(
            name: name,
            email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
            resumeFileUrl: resume.isEmpty ? null : resume,
            status: selectedStatus,
            jobId: jobId,
          );

          ref.invalidate(candidatesByJobProvider(jobId));
          ref.invalidate(candidatesFeedProvider);
          if (!context.mounted) return;
          if (dialogContext.mounted) Navigator.of(dialogContext).pop(); // close after success
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Candidate created'),
              duration: const Duration(milliseconds: 2000),
              action: SnackBarAction(
                label: 'Open',
                onPressed: () => context.push('/candidates/${created.id}'),
              ),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Create failed: $e'),
              duration: const Duration(milliseconds: 2000),
            ),
          );
        } finally {
          // dialog-local flag (handled in StatefulBuilder)
        }
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submitWithLock() async {
                // Extra guard for super-fast double click.
                if (submittedOnce) return;
                submittedOnce = true;
                setDialogState(() => isSubmitting = true);
                try {
                  await submit(dialogContext);
                } finally {
                  if (dialogContext.mounted) {
                    setDialogState(() => isSubmitting = false);
                  }
                  submittedOnce = false;
                }
              }

              return AlertDialog(
                title: const Text('Create candidate'),
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
                        decoration: const InputDecoration(labelText: 'Resume URL (optional)'),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Expanded(child: Text('Start in')),
                          DropdownButton<String>(
                            value: selectedStatus,
                            items: PipelinePage._stages
                                .map((s) => DropdownMenuItem<String>(
                                      value: s,
                                      child: Text(s),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              if (v == null) return;
                              setDialogState(() => selectedStatus = v);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSubmitting ? null : submitWithLock,
                    child: isSubmitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Create'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    Future<void> moveCandidate(Candidate candidate, String nextStage) async {
      if (candidate.status == nextStage) return;
      if (_movingIds.contains(candidate.id)) return;

      final prevStage = candidate.status;
      setState(() => _movingIds.add(candidate.id));
      
      final messenger = ScaffoldMessenger.of(context);
      
      try {
        await repo.updateCandidateStatus(id: candidate.id, status: nextStage);
        ref.invalidate(candidatesByJobProvider(jobId));
        ref.invalidate(candidatesFeedProvider);

        _snackbarTimer?.cancel();
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Moved to $nextStage'),
            duration: const Duration(milliseconds: 4000),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                _snackbarTimer?.cancel();
                await repo.updateCandidateStatus(id: candidate.id, status: prevStage);
                ref.invalidate(candidatesByJobProvider(jobId));
                ref.invalidate(candidatesFeedProvider);
              },
            ),
          ),
        );

        _snackbarTimer = Timer(const Duration(milliseconds: 2200), () {
          messenger.clearSnackBars();
        });
      } catch (e) {
        _snackbarTimer?.cancel();
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to move: $e'),
            duration: const Duration(milliseconds: 2000),
          ),
        );
      } finally {
        if (mounted) setState(() => _movingIds.remove(candidate.id));
      }
    }

    final items = asyncCandidates.valueOrNull ?? const <Candidate>[];
    final isLoading = asyncCandidates.isLoading && items.isEmpty;
    final isActuallyRefreshing = asyncCandidates.isRefreshing || (asyncCandidates.isLoading && items.isNotEmpty);

    return RefreshIndicator.adaptive(
      onRefresh: refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: _showSearch
                ? TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search candidates...',
                      border: InputBorder.none,
                      suffixIcon: IconButton(
                        tooltip: 'Clear',
                        onPressed: () => setState(() => _query = ''),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  )
                : Text(pipelineTitle()),
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            actions: [
              if (isActuallyRefreshing)
                const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Center(
                    child: SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
              IconButton(
                tooltip: _showSearch ? 'Close search' : 'Search',
                onPressed: () => setState(() {
                  _showSearch = !_showSearch;
                  if (!_showSearch) _query = '';
                }),
                icon: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded),
              ),
              IconButton(
                tooltip: 'Add candidate',
                onPressed: openCreateCandidateDialog,
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
              IconButton(
                tooltip: 'Refresh',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          if (isLoading)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              sliver: SliverToBoxAdapter(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text('Loading candidates...', style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            )
          else if (asyncCandidates.hasError && items.isEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              sliver: SliverToBoxAdapter(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Failed to load pipeline: ${asyncCandidates.error}',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FilledButton(onPressed: refresh, child: const Text('Retry')),
                    ],
                  ),
                ),
              ),
            )
          else
            Builder(builder: (context) {
              final q = _query.trim().toLowerCase();
              final visible = q.isEmpty
                  ? items
                  : items.where((c) {
                      final hay = [
                        c.name ?? '',
                        c.email ?? '',
                        c.resumeFileUrl ?? '',
                        c.status,
                      ].join(' ').toLowerCase();
                      return hay.contains(q);
                    }).toList();

              final grouped = <String, List<Candidate>>{
                for (final s in PipelinePage._stages) s: <Candidate>[],
              };
              for (final c in visible) {
                final normalizedStatus = c.status.trim().toUpperCase();
                if (grouped.containsKey(normalizedStatus)) {
                  grouped[normalizedStatus]!.add(c);
                } else {
                  // Fallback for statuses that don't match our columns exactly
                  grouped['APPLIED']!.add(c);
                }
              }

              if (items.isEmpty) {
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  sliver: SliverToBoxAdapter(
                    child: GlassCard(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(Icons.person_search_rounded, size: 48, color: cs.onSurfaceVariant),
                            const SizedBox(height: 16),
                            Text(
                              'No candidates found',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text('Add candidates manually or wait for applications.'),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }

              return SliverFillRemaining(
                hasScrollBody: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        controller: _h,
                        scrollDirection: Axis.horizontal,
                        child: ScrollConfiguration(
                          behavior: ScrollConfiguration.of(context).copyWith(
                            dragDevices: {
                              PointerDeviceKind.touch,
                              PointerDeviceKind.mouse,
                              PointerDeviceKind.trackpad,
                              PointerDeviceKind.stylus,
                              PointerDeviceKind.unknown,
                            },
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: constraints.maxHeight),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final stage in PipelinePage._stages)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: SizedBox(
                                      width: 300,
                                      child: _KanbanColumn(
                                        stage: stage,
                                        candidates: grouped[stage] ?? const <Candidate>[],
                                        movingIds: _movingIds,
                                        onMoveHere: (c) => moveCandidate(c, stage),
                                        accent: stage == 'HIRED'
                                            ? Colors.green
                                            : stage == 'REJECTED'
                                                ? Colors.red
                                                : stage == 'PARSED'
                                                    ? Colors.purple
                                                    : cs.primary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _PipelineCandidateCard extends StatelessWidget {
  const _PipelineCandidateCard({required this.candidate, required this.isMoving});

  final Candidate candidate;
  final bool isMoving;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final title = (candidate.name?.trim().isNotEmpty ?? false) ? candidate.name!.trim() : 'Unnamed candidate';
    final subtitle = candidate.email ?? candidate.resumeFileUrl ?? '—';

    return GlassCard(
      onTap: isMoving
          ? null
          : () {
        context.push('/candidates/${candidate.id}');
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.surfaceContainerHighest,
            child: Text(title.characters.first.toUpperCase(), style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (candidate.isApplication)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        ),
                        child: const Text(
                          'Applicant',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: cs.primary.withValues(alpha: 0.12),
            ),
            child: isMoving
                ? SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(cs.primary),
                    ),
                  )
                : Text(
                    candidate.status,
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.primary),
                  ),
          ),
        ],
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.stage,
    required this.candidates,
    required this.movingIds,
    required this.onMoveHere,
    required this.accent,
  });

  final String stage;
  final List<Candidate> candidates;
  final Set<String> movingIds;
  final ValueChanged<Candidate> onMoveHere;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stage,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: cs.surfaceContainerHighest,
                ),
                child: Text(
                  '${candidates.length}',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: DragTarget<Candidate>(
              onWillAcceptWithDetails: (details) => details.data.status != stage && !movingIds.contains(details.data.id),
              onAcceptWithDetails: (details) => onMoveHere(details.data),
              builder: (context, incoming, rejected) {
                final isHover = incoming.isNotEmpty;
                return AnimatedContainer(
                  duration: 120.ms,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isHover ? accent.withValues(alpha: 0.8) : cs.outlineVariant.withValues(alpha: 0.35),
                      width: isHover ? 2 : 1,
                    ),
                    color: isHover ? accent.withValues(alpha: 0.08) : Colors.transparent,
                  ),
                  child: ListView.builder(
                    // Flutter Web scrollbar is drawn ON TOP of content.
                    // Give enough bottom padding so it never blocks the last cards.
                    padding: const EdgeInsets.only(bottom: 84),
                    itemCount: candidates.length + (candidates.isEmpty ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (candidates.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            'Drop here',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        );
                      }

                      final c = candidates[i];
                      final isMoving = movingIds.contains(c.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Draggable<Candidate>(
                          data: c,
                          maxSimultaneousDrags: isMoving ? 0 : 1,
                          feedback: SizedBox(
                            width: 270,
                            child: Material(
                              color: Colors.transparent,
                              child: _PipelineCandidateCard(candidate: c, isMoving: isMoving),
                            ),
                          ),
                          childWhenDragging: Opacity(
                            opacity: 0.35,
                            child: _PipelineCandidateCard(candidate: c, isMoving: isMoving),
                          ),
                          child: _PipelineCandidateCard(candidate: c, isMoving: isMoving),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
