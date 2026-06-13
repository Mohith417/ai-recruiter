import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:recruitment_app/shared/services/api_client.dart';

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

class DbUser {
  DbUser({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    required this.role,
  });

  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String role;

  factory DbUser.fromJson(Map<String, dynamic> json) {
    return DbUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      role: json['role'] as String? ?? 'JOB_SEEKER',
    );
  }
}

class AppAuthState {
  AppAuthState({
    required this.isAuthenticated,
    this.user,
    this.session,
    this.dbUser,
  });

  final bool isAuthenticated;
  final User? user;
  final Session? session;
  final DbUser? dbUser;
}

class AuthNotifier extends StateNotifier<AppAuthState> {
  AuthNotifier(this._client) : super(AppAuthState(isAuthenticated: false)) {
    _init();
  }

  final SupabaseClient? _client;
  final Dio _dio = ApiClient.create();

  void _init() {
    if (_client == null) {
      state = AppAuthState(
        isAuthenticated: false,
      );
      return;
    }

    final session = _client.auth.currentSession;
    state = AppAuthState(
      isAuthenticated: session != null,
      user: session?.user,
      session: session,
    );
    if (session != null) {
      loadProfile();
    }

    _client.auth.onAuthStateChange.listen((data) {
      state = AppAuthState(
        isAuthenticated: data.session != null,
        user: data.session?.user,
        session: data.session,
      );
      if (data.session != null) {
        loadProfile();
      }
    });
  }

  Future<void> loadProfile() async {
    try {
      final res = await _dio.get('/me');
      final data = res.data as Map<String, dynamic>;
      final dbUser = DbUser.fromJson(data['user'] as Map<String, dynamic>);
      state = AppAuthState(
        isAuthenticated: state.isAuthenticated,
        user: state.user,
        session: state.session,
        dbUser: dbUser,
      );
    } catch (e) {
      // ignore
    }
  }

  Future<bool> updateProfile({String? name, String? avatarUrl, String? role}) async {
    try {
      final payload = <String, dynamic>{
        if (name != null) 'name': name,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        if (role != null) 'role': role,
      };
      final res = await _dio.patch('/me', data: payload);
      final data = res.data as Map<String, dynamic>;
      final dbUser = DbUser.fromJson(data['user'] as Map<String, dynamic>);
      
      state = AppAuthState(
        isAuthenticated: state.isAuthenticated,
        user: state.user,
        session: state.session,
        dbUser: dbUser,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<String> uploadAvatar({
    required String fileName,
    required List<int> fileBytes,
  }) async {
    try {
      if (_client == null) throw Exception('Supabase client is not initialized');
      final supabase = _client;
      final path = 'public/${DateTime.now().millisecondsSinceEpoch}_$fileName';
      
      await supabase.storage.from('avatars').uploadBinary(
        path,
        Uint8List.fromList(fileBytes),
      );
      
      return supabase.storage.from('avatars').getPublicUrl(path);
    } catch (e) {
      // Fallback: Upload photo to local Express backend storage if Supabase storage is not configured.
      try {
        final base64Str = base64Encode(fileBytes);
        final res = await _dio.post(
          '/upload',
          data: {
            'fileName': fileName,
            'base64': base64Str,
          },
        );
        final data = res.data as Map<String, dynamic>;
        return data['url'] as String;
      } catch (err) {
        // Ultimate fallback
        return 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/200';
      }
    }
  }

  Future<void> signIn(String email, String password, {String? role}) async {
    if (_client == null) {
      final res = await _dio.post('/auth/v1/login', data: {
        'email': email,
        'password': password,
        if (role != null) 'role': role,
      });
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final dbUser = DbUser.fromJson(data['user'] as Map<String, dynamic>);
      
      ApiClient.activeToken = token;
      state = AppAuthState(
        isAuthenticated: true,
        dbUser: dbUser,
      );
      return;
    }
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    if (_client == null) {
      final res = await _dio.post('/auth/v1/google-login', data: {
        'email': 'google-candidate@local.test',
      });
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final dbUser = DbUser.fromJson(data['user'] as Map<String, dynamic>);
      
      ApiClient.activeToken = token;
      state = AppAuthState(
        isAuthenticated: true,
        dbUser: dbUser,
      );
      return;
    }
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signUp(String email, String password, {String? role}) async {
    if (_client == null) {
      final res = await _dio.post('/auth/v1/signup', data: {
        'email': email,
        'password': password,
        if (role != null) 'role': role,
      });
      final data = res.data as Map<String, dynamic>;
      final token = data['token'] as String;
      final dbUser = DbUser.fromJson(data['user'] as Map<String, dynamic>);
      
      ApiClient.activeToken = token;
      state = AppAuthState(
        isAuthenticated: true,
        dbUser: dbUser,
      );
      return;
    }
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    ApiClient.activeToken = null;
    if (_client == null) {
      state = AppAuthState(isAuthenticated: false);
      return;
    }
    await _client.auth.signOut();
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return AuthNotifier(client);
});
