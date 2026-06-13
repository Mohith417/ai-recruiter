import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:recruitment_app/app.dart';
import 'package:recruitment_app/core/constants/app_licenses.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerAppLicenses();

  // Optional: configure API endpoints / Supabase keys via .env
  // NOTE: On Flutter Web, flutter_dotenv loads via assets/.env, so we ship a default .env.
  await dotenv.load(fileName: '.env', isOptional: true);

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    );
  } else {
    debugPrint('WARNING: Supabase credentials are not set. Auth calls will fail.');
  }

  runApp(const ProviderScope(child: RecruitmentApp()));
}
