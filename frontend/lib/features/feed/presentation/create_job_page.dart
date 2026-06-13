import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recruitment_app/features/feed/application/jobs_providers.dart';
import 'package:recruitment_app/shared/widgets/glass_card.dart';

class CreateJobPage extends ConsumerStatefulWidget {
  const CreateJobPage({super.key});

  @override
  ConsumerState<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends ConsumerState<CreateJobPage> {
  final _formKey = GlobalKey<FormState>();

  final _title = TextEditingController(text: 'Junior Flutter Dev');
  final _description = TextEditingController(text: 'Simple test job description.');
  final _location = TextEditingController(text: 'Remote');
  final _salaryMin = TextEditingController(text: '1000');
  final _salaryMax = TextEditingController(text: '2000');

  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _location.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    super.dispose();
  }

  int? _tryParseInt(String s) {
    final v = int.tryParse(s.trim());
    return v;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(jobsRepositoryProvider);
      await repo.createJob(
        title: _title.text.trim(),
        description: _description.text.trim(),
        location: _location.text.trim(),
        salaryMin: _tryParseInt(_salaryMin.text),
        salaryMax: _tryParseInt(_salaryMax.text),
      );
      ref.invalidate(jobsFeedProvider);
      if (!mounted) return;
      context.go('/feed');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job created')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create job: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create job'),
        backgroundColor: theme.scaffoldBackgroundColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) => (v == null || v.trim().length < 3) ? 'Title too short' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _description,
                      decoration: const InputDecoration(labelText: 'Description'),
                      minLines: 3,
                      maxLines: 6,
                      validator: (v) => (v == null || v.trim().length < 10) ? 'Description too short' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _location,
                      decoration: const InputDecoration(labelText: 'Location (optional)'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMin,
                            decoration: const InputDecoration(labelText: 'Salary min (optional)'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              return int.tryParse(v.trim()) == null ? 'Must be a number' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _salaryMax,
                            decoration: const InputDecoration(labelText: 'Salary max (optional)'),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              return int.tryParse(v.trim()) == null ? 'Must be a number' : null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_rounded),
                  label: Text(_saving ? 'Creating...' : 'Create job'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

