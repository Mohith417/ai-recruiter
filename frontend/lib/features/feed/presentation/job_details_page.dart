import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

import 'package:recruitment_app/features/feed/application/jobs_providers.dart';
import 'package:recruitment_app/features/feed/domain/job.dart';
import 'package:recruitment_app/features/applications/application/applications_providers.dart';
import 'package:recruitment_app/features/applications/domain/application.dart';
import 'package:recruitment_app/features/candidates/application/candidates_providers.dart';
import 'package:recruitment_app/features/candidates/domain/candidate.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';
import 'package:recruitment_app/features/auth/application/auth_providers.dart';

class JobDetailsPage extends ConsumerWidget {
  const JobDetailsPage({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final authState = ref.watch(authNotifierProvider);

    final jobAsync = ref.watch(jobByIdProvider(jobId));
    final candidatesAsync = ref.watch(candidatesByJobProvider(jobId));
    final applicationsAsync = ref.watch(applicationsByJobProvider(jobId));
    final applicationsRepo = ref.read(applicationsRepositoryProvider);

    final rawRole = authState.dbUser?.role?.toString().toUpperCase().trim();
    final isCandidate = rawRole == 'JOB_SEEKER';
    final isRecruiterOrAdmin = (rawRole == 'RECRUITER' ||
        rawRole == 'ADMIN' ||
        rawRole == 'HR_MANAGER' ||
        rawRole == 'COMPANY') && !isCandidate;

    String salaryText(Job job) {
      if (job.salaryMin == null && job.salaryMax == null) return 'Salary not disclosed';
      final fmt = NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 0);
      final min = job.salaryMin != null ? fmt.format(job.salaryMin) : null;
      final max = job.salaryMax != null ? fmt.format(job.salaryMax) : null;
      if (min != null && max != null) return '$min – $max';
      return min ?? max ?? 'Salary not disclosed';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job'),
        backgroundColor: theme.scaffoldBackgroundColor,
        actions: isRecruiterOrAdmin
            ? [
                IconButton(
                  tooltip: 'Parse resume (AI)',
                  onPressed: () => _openResumeParseDialog(context, ref, jobId),
                  icon: const Icon(Icons.auto_awesome_rounded),
                ),
                IconButton(
                  tooltip: 'Open pipeline',
                  onPressed: () => context.push('/pipeline?jobId=$jobId'),
                  icon: const Icon(Icons.view_kanban_rounded),
                ),
                IconButton(
                  tooltip: 'Add candidate',
                  onPressed: () async {
                    final repo = ref.read(candidatesRepositoryProvider);
                    final nameCtrl = TextEditingController();
                    final emailCtrl = TextEditingController();
                    final resumeCtrl = TextEditingController();
                    var isSubmitting = false;

                    await showDialog<void>(
                      context: context,
                      builder: (dialogContext) {
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
                                  jobId: jobId,
                                );
                                ref.invalidate(candidatesByJobProvider(jobId));
                                ref.invalidate(candidatesFeedProvider);
                                if (!context.mounted) return;
                                Navigator.of(dialogContext).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Candidate added')),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Add failed: $e')),
                                );
                              } finally {
                                if (dialogContext.mounted) setDialogState(() => isSubmitting = false);
                              }
                            }

                            return AlertDialog(
                              title: const Text('Add candidate to this job'),
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
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                ),
              ]
            : null,
      ),
      body: jobAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GlassCard(
              padding: const EdgeInsets.all(14),
              child: Text('Failed to load job.\n$e', style: theme.textTheme.bodyMedium),
            ),
          ),
        ),
        data: (job) {
          final date = DateFormat('yyyy-MM-dd HH:mm').format(job.createdAt.toLocal());
          final description = job.description?.trim();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.place_rounded, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            job.location ?? 'Location: —',
                            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.payments_rounded, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            salaryText(job),
                            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 18),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Created: $date',
                            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 12),
                GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Description',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
              if (isCandidate) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await applicationsRepo.applyToJob(jobId: jobId);
                      ref.invalidate(applicationsByJobProvider(jobId));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Application submitted')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Apply failed: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Apply to this job'),
                ),
              ],
              if (isRecruiterOrAdmin) ...[
                const SizedBox(height: 16),
                Text(
                  'Applications',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...applicationsAsync.when(
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Failed to load applications.\n$e',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  data: (applications) {
                    if (applications.isEmpty) {
                      return [
                        GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Text(
                            'No applications yet for this job.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ];
                    }

                    return applications
                        .map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _JobApplicationTile(
                              application: a,
                              onStageChanged: (stage) async {
                                await applicationsRepo.updateStage(
                                  applicationId: a.id,
                                  stage: stage,
                                );
                                ref.invalidate(applicationsByJobProvider(jobId));
                              },
                            ),
                          ),
                        )
                        .toList();
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Candidates for this job',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                ...candidatesAsync.when(
                  loading: () => [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                  error: (e, _) => [
                    GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Text(
                        'Failed to load candidates.\n$e',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  data: (candidates) {
                    if (candidates.isEmpty) {
                      return [
                        GlassCard(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const Icon(Icons.people_outline_rounded),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No candidates linked yet.\nUse + to add manually or ✨ to parse a resume.',
                                  style: theme.textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];
                    }

                    return candidates
                        .map(
                          (c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _JobCandidateTile(candidate: c),
                          ),
                        )
                        .toList();
                  },
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _JobApplicationTile extends StatelessWidget {
  const _JobApplicationTile({
    required this.application,
    required this.onStageChanged,
  });

  final JobApplication application;
  final ValueChanged<String> onStageChanged;

  static const _stages = <String>[
    'APPLIED',
    'SCREENED',
    'INTERVIEW',
    'OFFER',
    'HIRED',
    'REJECTED',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title = application.applicantName?.trim().isNotEmpty == true
        ? application.applicantName!.trim()
        : (application.applicantEmail ?? 'Applicant');

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                if (application.applicantEmail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    application.applicantEmail!,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          DropdownButton<String>(
            value: _stages.contains(application.stage) ? application.stage : 'APPLIED',
            items: _stages
                .map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) {
              if (v == null || v == application.stage) return;
              onStageChanged(v);
            },
          ),
        ],
      ),
    );
  }
}

class _JobCandidateTile extends StatelessWidget {
  const _JobCandidateTile({required this.candidate});

  final Candidate candidate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final title =
        (candidate.name?.trim().isNotEmpty ?? false) ? candidate.name!.trim() : 'Unnamed candidate';

    return GlassCard(
      onTap: () => context.push('/candidates/${candidate.id}'),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  candidate.email ?? candidate.status,
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
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
    );
  }
}

Future<void> _openResumeParseDialog(BuildContext context, WidgetRef ref, String jobId) async {
  final repo = ref.read(candidatesRepositoryProvider);

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
              final queueJobId = await repo.enqueueResumeParse(
                resumeFileUrl: url,
                jobId: jobId,
              );

              if (!context.mounted) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Uploaded & queued parse (job $queueJobId). Refreshing...')),
              );
              Future.delayed(const Duration(milliseconds: 900), () {
                ref.invalidate(candidatesByJobProvider(jobId));
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
            title: const Text('Parse resume for this job (AI)'),
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
