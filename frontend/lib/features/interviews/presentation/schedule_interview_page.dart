import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:recruitment_app/features/candidates/application/candidates_providers.dart';
import 'package:recruitment_app/features/feed/application/jobs_providers.dart';
import 'package:recruitment_app/features/interviews/application/interviews_providers.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';

class ScheduleInterviewPage extends ConsumerStatefulWidget {
  const ScheduleInterviewPage({super.key});

  @override
  ConsumerState<ScheduleInterviewPage> createState() => _ScheduleInterviewPageState();
}

class _ScheduleInterviewPageState extends ConsumerState<ScheduleInterviewPage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCandidateId;
  String? _selectedJobId;
  DateTime? _scheduledDateTime;
  int _durationMinutes = 30;
  final _interviewerNameController = TextEditingController();
  final _notesController = TextEditingController();

  bool _saving = false;

  @override
  void dispose() {
    _interviewerNameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDateTime ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null) return;

    if (!mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_scheduledDateTime ?? now),
    );

    if (pickedTime == null) return;

    setState(() {
      _scheduledDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCandidateId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a candidate')),
      );
      return;
    }
    if (_selectedJobId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a job')),
      );
      return;
    }
    if (_scheduledDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date and time')),
      );
      return;
    }

    setState(() => _saving = true);

    final success = await ref.read(interviewsNotifierProvider.notifier).createInterview(
          candidateId: _selectedCandidateId!,
          jobId: _selectedJobId!,
          scheduledAt: _scheduledDateTime!,
          durationMinutes: _durationMinutes,
          interviewerName: _interviewerNameController.text.trim().isEmpty
              ? null
              : _interviewerNameController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interview scheduled successfully')),
      );
      context.go('/interviews');
    } else {
      final error = ref.read(interviewsNotifierProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to schedule interview: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final candidatesAsync = ref.watch(candidatesFeedProvider);
    final jobsAsync = ref.watch(jobsFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Interview'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Candidate Dropdown
                    candidatesAsync.when(
                      data: (candidates) => DropdownButtonFormField<String>(
                        value: _selectedCandidateId,
                        decoration: const InputDecoration(
                          labelText: 'Select Candidate',
                          prefixIcon: Icon(Icons.person_rounded),
                        ),
                        items: candidates.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(c.name ?? c.email ?? 'Unnamed Candidate'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedCandidateId = val;
                            if (val != null) {
                              final candidate = candidates.firstWhere((c) => c.id == val);
                              if (candidate.jobId != null) {
                                _selectedJobId = candidate.jobId;
                              }
                            }
                          });
                        },
                        validator: (v) => v == null ? 'Candidate is required' : null,
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, _) => Text('Error loading candidates: $err'),
                    ),
                    const SizedBox(height: 16),

                    // Job Dropdown
                    jobsAsync.when(
                      data: (jobs) => DropdownButtonFormField<String>(
                        value: _selectedJobId,
                        decoration: const InputDecoration(
                          labelText: 'Select Job',
                          prefixIcon: Icon(Icons.work_rounded),
                        ),
                        items: jobs.map((j) {
                          return DropdownMenuItem<String>(
                            value: j.id,
                            child: Text(j.title),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedJobId = val;
                          });
                        },
                        validator: (v) => v == null ? 'Job is required' : null,
                      ),
                      loading: () => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      error: (err, _) => Text('Error loading jobs: $err'),
                    ),
                    const SizedBox(height: 16),

                    // Scheduled At picker
                    InkWell(
                      onTap: _pickDateTime,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_month_rounded, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _scheduledDateTime == null
                                    ? 'Pick Date & Time'
                                    : DateFormat('MMM dd, yyyy - hh:mm a').format(_scheduledDateTime!),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: _scheduledDateTime == null
                                      ? theme.colorScheme.onSurfaceVariant
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down_rounded),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Duration Dropdown
                    DropdownButtonFormField<int>(
                      value: _durationMinutes,
                      decoration: const InputDecoration(
                        labelText: 'Duration',
                        prefixIcon: Icon(Icons.timer_rounded),
                      ),
                      items: const [
                        DropdownMenuItem(value: 15, child: Text('15 Minutes')),
                        DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                        DropdownMenuItem(value: 45, child: Text('45 Minutes')),
                        DropdownMenuItem(value: 60, child: Text('1 Hour')),
                        DropdownMenuItem(value: 90, child: Text('1.5 Hours')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _durationMinutes = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),

                    // Interviewer Name
                    TextFormField(
                      controller: _interviewerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Interviewer Name (optional)',
                        prefixIcon: Icon(Icons.person_pin_rounded),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Notes (optional)',
                        prefixIcon: Icon(Icons.note_alt_rounded),
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Scheduling...' : 'Schedule Interview'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
