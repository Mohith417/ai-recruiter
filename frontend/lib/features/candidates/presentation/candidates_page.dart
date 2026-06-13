import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import 'package:recruitment_app/features/candidates/application/candidates_providers.dart';
import 'package:recruitment_app/features/candidates/domain/candidate.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';
import 'package:recruitment_app/shared/widgets/shimmer_block.dart';

class CandidatesPage extends ConsumerWidget {
  const CandidatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncCandidates = ref.watch(candidatesFeedProvider);
    final repo = ref.read(candidatesRepositoryProvider);
    final query = ref.watch(_candidatesQueryProvider);

    Future<void> refresh() async {
      ref.invalidate(candidatesFeedProvider);
    }

    Future<void> openCreateCandidateDialog() async {
      final nameCtrl = TextEditingController();
      final emailCtrl = TextEditingController();
      final resumeCtrl = TextEditingController();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isSubmitting = false;
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> submit() async {
                if (isSubmitting) return;
                final name = nameCtrl.text.trim();
                final resume = resumeCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Name is required')),
                  );
                  return;
                }

                setDialogState(() => isSubmitting = true);
                try {
                  await repo.createCandidate(
                    name: name,
                    email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                    resumeFileUrl: resume.isEmpty ? null : resume,
                    status: 'APPLIED',
                  );
                  ref.invalidate(candidatesFeedProvider);
                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Candidate created')),
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Create failed: $e')),
                  );
                } finally {
                  if (dialogContext.mounted) setDialogState(() => isSubmitting = false);
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
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: isSubmitting ? null : submit,
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

    Future<void> openResumeParseDialog() async {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          var isSubmitting = false;
          PlatformFile? selectedFile;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickFile() async {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['pdf'],
                  withData: true,
                );
                if (result != null) {
                  setDialogState(() {
                    selectedFile = result.files.first;
                  });
                }
              }

              Future<void> submit() async {
                if (isSubmitting) return;
                if (selectedFile == null || selectedFile!.bytes == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a PDF resume file')),
                  );
                  return;
                }
                setDialogState(() => isSubmitting = true);
                try {
                  // 1. Upload file to Supabase Storage (with fallback in dev)
                  final url = await repo.uploadResume(
                    fileName: selectedFile!.name,
                    fileBytes: selectedFile!.bytes!,
                  );

                  // 2. Enqueue resume parse job
                  final jobId = await repo.enqueueResumeParse(resumeFileUrl: url);

                  if (!context.mounted) return;
                  Navigator.of(dialogContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Uploaded & queued parse (job $jobId). Refreshing...')),
                  );
                  Future.delayed(const Duration(milliseconds: 800), () {
                    ref.invalidate(candidatesFeedProvider);
                  });
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Processing failed: $e')),
                  );
                } finally {
                  if (dialogContext.mounted) setDialogState(() => isSubmitting = false);
                }
              }

              final cs = Theme.of(context).colorScheme;

              return AlertDialog(
                title: const Text('Parse resume (AI)'),
                content: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: isSubmitting ? null : pickFile,
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          height: 120,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.35),
                              width: 1.5,
                            ),
                            color: cs.surfaceContainerHighest.withValues(alpha: 0.14),
                          ),
                          child: selectedFile == null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.picture_as_pdf_rounded, size: 36, color: cs.primary),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Select PDF resume file',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.green.shade600, size: 28),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              selectedFile!.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${(selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
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
                    onPressed: isSubmitting || selectedFile == null ? null : submit,
                    child: isSubmitting
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Queue'),
                  ),
                ],
              );
            },
          );
        },
      );
    }

    return RefreshIndicator.adaptive(
      onRefresh: refresh,
      child: CustomScrollView(
        // Make pull-to-refresh work even when the list is short (no scroll extent).
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            pinned: true,
            title: const Text('Candidates'),
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Parse resume (AI)',
                onPressed: openResumeParseDialog,
                icon: const Icon(Icons.auto_awesome_rounded),
              ),
              IconButton(
                tooltip: 'Search',
                onPressed: () async {
                  final ctrl = TextEditingController(text: query);
                  final next = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Search'),
                      content: TextField(
                        controller: ctrl,
                        autofocus: true,
                        decoration: const InputDecoration(hintText: 'Type name/email/status...'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(''),
                          child: const Text('Clear'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                          child: const Text('Apply'),
                        ),
                      ],
                    ),
                  );
                  if (next == null) return;
                  ref.read(_candidatesQueryProvider.notifier).state = next;
                },
                icon: const Icon(Icons.search_rounded),
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            sliver: asyncCandidates.when(
              loading: () => SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) => const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: _CandidateCardSkeleton(),
                  ),
                  childCount: 6,
                ),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Failed to load candidates.\nMake sure backend is running on http://localhost:4000',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (items) {
                final q = query.trim().toLowerCase();
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

                if (items.isEmpty) {
                  return SliverToBoxAdapter(
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.inbox_rounded),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'No candidates yet.\nNext: resume parse will create candidates automatically.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CandidateCard(candidate: visible[i], index: i),
                    ),
                    childCount: visible.length,
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

final _candidatesQueryProvider = StateProvider<String>((ref) => '');

class _CandidateCard extends StatelessWidget {
  const _CandidateCard({required this.candidate, required this.index});

  final Candidate candidate;
  final int index;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final title = (candidate.name?.trim().isNotEmpty ?? false) ? candidate.name!.trim() : 'Unnamed candidate';
    final subtitle = candidate.email ?? candidate.status;

    return GlassCard(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening candidate...')),
        );
        context.push('/candidates/${candidate.id}');
      },
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: cs.surfaceContainerHighest.withValues(alpha: 0.9),
            child: Text(title.characters.first.toUpperCase(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
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
            child: Text(
              candidate.status,
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w900, color: cs.primary),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (40 * index).ms).slideY(begin: 0.04, curve: Curves.easeOutCubic);
  }
}

class _CandidateCardSkeleton extends StatelessWidget {
  const _CandidateCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: const [
          ShimmerBlock(height: 44, width: 44, radius: 22),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBlock(height: 12, width: double.infinity, radius: 8),
                SizedBox(height: 10),
                ShimmerBlock(height: 10, width: 200, radius: 8),
              ],
            ),
          ),
          SizedBox(width: 10),
          ShimmerBlock(height: 24, width: 80, radius: 12),
        ],
      ),
    );
  }
}
