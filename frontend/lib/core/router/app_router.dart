import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:recruitment_app/features/shell/presentation/shell_scaffold.dart';
import 'package:recruitment_app/features/dashboard/presentation/dashboard_page.dart';
import 'package:recruitment_app/features/dashboard/presentation/candidate_dashboard_page.dart';
import 'package:recruitment_app/features/search/presentation/search_page.dart';
import 'package:recruitment_app/features/feed/presentation/feed_page.dart';
import 'package:recruitment_app/features/feed/presentation/create_job_page.dart';
import 'package:recruitment_app/features/feed/presentation/job_details_page.dart';
import 'package:recruitment_app/features/candidates/presentation/candidates_page.dart';
import 'package:recruitment_app/features/candidates/presentation/candidate_details_page.dart';
import 'package:recruitment_app/features/pipeline/presentation/pipeline_page.dart';
import 'package:recruitment_app/features/settings/presentation/settings_page.dart';
import 'package:recruitment_app/features/auth/application/auth_providers.dart';
import 'package:recruitment_app/features/interviews/presentation/interviews_list_page.dart';
import 'package:recruitment_app/features/interviews/presentation/schedule_interview_page.dart';
import 'package:recruitment_app/features/auth/presentation/login_page.dart';
import 'package:recruitment_app/features/auth/presentation/onboarding_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final loggingIn = state.uri.path == '/login';
      if (!authState.isAuthenticated) {
        return loggingIn ? null : '/login';
      }

      // Seeker role routing restrictions
      final rawRole = authState.dbUser?.role?.toString().toUpperCase().trim();
      if (rawRole == 'JOB_SEEKER') {
        final path = state.uri.path;
        final isAllowed = path == '/dashboard' ||
            path == '/feed' ||
            (path.startsWith('/jobs/') && path != '/jobs/new') ||
            path == '/settings' ||
            path == '/onboarding' ||
            path == '/login';
        
        // Block candidates from recruiter-only paths like /candidates, /pipeline, /search, /interviews
        final isRecruiterOnly = path == '/candidates' || 
            path.startsWith('/candidates/') || 
            path == '/pipeline' || 
            path == '/search' || 
            path == '/interviews' || 
            path.startsWith('/interviews/') ||
            path == '/jobs/new';

        if (!isAllowed || isRecruiterOnly) {
          return '/dashboard';
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fade(state, const LoginPage()),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fade(state, const OnboardingPage()),
      ),
      ShellRoute(
        builder: (context, state, child) => ShellScaffold(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            pageBuilder: (context, state) {
              if (authState.dbUser == null) {
                return _fade(state, const Scaffold(body: Center(child: CircularProgressIndicator())));
              }
              final role = authState.dbUser?.role;
              if (role == 'JOB_SEEKER') {
                return _fade(state, const CandidateDashboardPage());
              }
              return _fade(state, const DashboardPage());
            },
          ),
          GoRoute(
            path: '/search',
            pageBuilder: (context, state) => _fade(state, const SearchPage()),
          ),
          GoRoute(
            path: '/feed',
            pageBuilder: (context, state) => _fade(state, const FeedPage()),
          ),
          GoRoute(
            path: '/jobs/new',
            pageBuilder: (context, state) => _fade(state, const CreateJobPage()),
          ),
          GoRoute(
            path: '/jobs/:id',
            pageBuilder: (context, state) => _fade(
              state,
              JobDetailsPage(jobId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/candidates',
            pageBuilder: (context, state) => _fade(state, const CandidatesPage()),
          ),
          GoRoute(
            path: '/candidates/:id',
            pageBuilder: (context, state) => _fade(
              state,
              CandidateDetailsPage(candidateId: state.pathParameters['id']!),
            ),
          ),
          GoRoute(
            path: '/pipeline',
            pageBuilder: (context, state) => _fade(state, const PipelinePage()),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _fade(state, const SettingsPage()),
          ),
          GoRoute(
            path: '/interviews',
            pageBuilder: (context, state) => _fade(state, const InterviewsListPage()),
          ),
          GoRoute(
            path: '/interviews/new',
            pageBuilder: (context, state) => _fade(state, const ScheduleInterviewPage()),
          ),
        ],
      ),
    ],
  );
});

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(opacity: curved, child: child);
    },
  );
}
