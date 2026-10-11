import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/app_providers.dart';

class ConnectivityBadge extends ConsumerWidget {
  const ConnectivityBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineStateProvider);
    final syncQueue = ref.watch(syncQueueProvider);
    final connectivityService = ref.read(connectivityServiceProvider);

    return InkWell(
      onTap: () {
        // Permitir alternar modo simulación offline al técnico/tester
        connectivityService.toggleSimulateOffline();
        ref.read(isOnlineStateProvider.notifier).updateStatus(connectivityService.isOnline);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              connectivityService.isSimulatedOffline
                  ? 'Modo sin cobertura (Offline) activado para pruebas de planta.'
                  : 'Modo con cobertura (Online) restablecido.',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: connectivityService.isSimulatedOffline
                ? AppColors.warning
                : AppColors.success,
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isOnline
              ? AppColors.success.withValues(alpha: 0.15)
              : AppColors.warning.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isOnline ? AppColors.success : AppColors.warning,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOnline ? AppColors.success : AppColors.warning,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isOnline
                  ? (syncQueue.isEmpty ? 'ONLINE' : 'ONLINE (${syncQueue.length} pend)')
                  : 'OFFLINE (${syncQueue.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isOnline ? AppColors.success : AppColors.warning,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

