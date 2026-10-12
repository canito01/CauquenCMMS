import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/services/app_providers.dart';
import 'core/services/local_storage_service.dart';
import 'core/services/supabase_sync_service.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar servicio Cloud Supabase si está configurado
  await SupabaseSyncService.initializeIfConfigured();

  // Inicializar almacenamiento local y sembrar datos si es primer inicio
  final storageService = await LocalStorageService.init();

  runApp(
    ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storageService),
      ],
      child: const SistemaMaxiApp(),
    ),
  );
}

class SistemaMaxiApp extends ConsumerWidget {
  const SistemaMaxiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Cauquén CMMS - Gestión de Mantenimiento Industrial',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
