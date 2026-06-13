import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:recruitment_app/shared/services/socket_service.dart';
import 'package:recruitment_app/features/auth/application/auth_providers.dart';

class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.candidateId,
    this.applicationId,
    this.newStage,
    this.isRead = false,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final DateTime createdAt;
  final String? candidateId;
  final String? applicationId;
  final String? newStage;
  final bool isRead;

  NotificationItem copyWith({
    bool? isRead,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      body: body,
      createdAt: createdAt,
      candidateId: candidateId,
      applicationId: applicationId,
      newStage: newStage,
      isRead: isRead ?? this.isRead,
    );
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService();
});

class NotificationList extends StateNotifier<List<NotificationItem>> {
  NotificationList(this._ref) : super([]) {
    _init();
  }

  final Ref _ref;

  void _init() {
    _ref.listen<AppAuthState>(authNotifierProvider, (previous, next) {
      if (next.isAuthenticated) {
        // Prefer database user ID (dbUser.id) over Supabase sub ID (user.id)
        // because the backend emits to the DB ID.
        final userId = next.dbUser?.id ?? next.user?.id;
        final email = next.dbUser?.email ?? next.user?.email;
        
        if (userId != null) {
          _ref.read(socketServiceProvider).connect(
            userId: userId,
            email: email,
            onNotificationReceived: (data) {
              _handleIncomingNotification(data);
            },
          );
        }
      } else {
        _ref.read(socketServiceProvider).disconnect();
      }
    }, fireImmediately: true);
  }

  void _handleIncomingNotification(Map<String, dynamic> data) {
    final type = data['type'] as String? ?? 'UNKNOWN';
    String title = 'Notification';
    String body = 'New event received';
    String? candidateId;
    String? applicationId;
    String? newStage;

    if (type == 'RESUME_PARSED') {
      final name = data['name'] as String? ?? 'Candidate';
      candidateId = data['candidateId'] as String?;
      title = 'Resume Parsed';
      body = 'Successfully parsed resume for $name';
    } else if (type == 'STAGE_CHANGED') {
      applicationId = data['applicationId'] as String?;
      newStage = data['newStage'] as String? ?? 'APPLIED';
      title = 'Application Status Updated';
      body = 'Application moved to stage $newStage';
    } else if (type == 'INTERVIEW_REMINDER') {
      final candidateName = data['candidateName'] as String? ?? 'Candidate';
      final minutesLeft = data['minutesLeft'] ?? 30;
      title = 'Upcoming Interview Reminder';
      body = 'Interview with $candidateName starts in $minutesLeft minutes!';
    } else if (type == 'CANDIDATE_APPLIED') {
      final candidateName = data['candidateName'] as String? ?? 'Candidate';
      final jobTitle = data['jobTitle'] as String? ?? 'Job';
      candidateId = data['candidateId'] as String?;
      applicationId = data['applicationId'] as String?;
      title = 'New Candidate Application';
      body = '$candidateName has applied for your job "$jobTitle"!';
    } else if (type == 'APPLICATION_VIEWED') {
      final jobTitle = data['jobTitle'] as String? ?? 'a job';
      applicationId = data['applicationId'] as String?;
      title = 'Application Under Review';
      body = 'A recruiter is currently reviewing your application for "$jobTitle".';
    }

    final item = NotificationItem(
      id: const Uuid().v4(),
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      candidateId: candidateId,
      applicationId: applicationId,
      newStage: newStage,
    );

    state = [item, ...state];
  }

  void markAsRead(String id) {
    state = [
      for (final item in state)
        if (item.id == id) item.copyWith(isRead: true) else item,
    ];
  }

  void markAllAsRead() {
    state = [
      for (final item in state) item.copyWith(isRead: true),
    ];
  }

  void clearAll() {
    state = [];
  }
}

final notificationsProvider = StateNotifierProvider<NotificationList, List<NotificationItem>>((ref) {
  return NotificationList(ref);
});
