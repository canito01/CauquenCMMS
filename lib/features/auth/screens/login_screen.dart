import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/app_providers.dart';
import '../../../core/services/mock_data_service.dart';
import '../../common/connectivity_badge.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _idController = TextEditingController(text: 'TEC-4482');
  final TextEditingController _passwordController = TextEditingController(text: 'password123');
  bool _obscurePassword = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final success = await ref.read(authProvider.notifier).login(
          identifier: _idController.text,
          password: _passwordController.text,
        );

    if (success && mounted) {
      final user = ref.read(authProvider).user;
      if (user?.role == UserRole.supervisor || user?.role == UserRole.admin) {
        context.go('/admin');
      } else {
        context.go('/');
      }
    }
  }

  Future<void> _handleQuickLogin(UserModel user) async {
    await ref.read(authProvider.notifier).quickLoginAs(user);
    if (mounted) {
      if (user.role == UserRole.supervisor || user.role == UserRole.admin) {
        context.go('/admin');
      } else {
        context.go('/');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isOnline = ref.watch(isOnlineStateProvider);
    final mockUsers = MockDataService.getMockUsers();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Badge Superior de Conectividad
                  Align(
                    alignment: Alignment.topRight,
                    child: const ConnectivityBadge(),
                  ),
                  const SizedBox(height: 12),

                  // Logo y Marca Industrial
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Center(
                        child: Text(
                          '🦅',
                          style: TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Cauquén CMMS',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Gestión de Mantenimiento Industrial • Planta',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Tarjeta del Formulario
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ACCESO DE CUADRILLA',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Campo: Legajo / Correo
                        TextField(
                          controller: _idController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Legajo o Correo de Planta',
                            hintText: 'Ej: TEC-4482 o correo@planta.com',
                            prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Campo: Contraseña
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleLogin(),
                          decoration: InputDecoration(
                            labelText: 'Contraseña de Acceso',
                            hintText: '••••••••',
                            prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Fila Recordar Sesión
                        Row(
                          children: [
                            Checkbox(
                              value: _rememberMe,
                              activeColor: AppColors.primary,
                              onChanged: (val) {
                                setState(() {
                                  _rememberMe = val ?? true;
                                });
                              },
                            ),
                            const Expanded(
                              child: Text(
                                'Mantener sesión activa en este móvil',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),

                        // Mensaje de Error
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.danger),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    authState.errorMessage!,
                                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Botón Ingresar
                        ElevatedButton.icon(
                          onPressed: authState.isLoading ? null : _handleLogin,
                          icon: authState.isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.login),
                          label: Text(
                            authState.isLoading ? 'AUTENTICANDO...' : 'INGRESAR A PLANTA',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Accesos Rápidos para Prueba de Operarios
                  const Text(
                    'ACCESO RÁPIDO PARA PRUEBAS (1-TAP)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...mockUsers.map((user) {
                    final isTech = user.role == UserRole.technician;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _handleQuickLogin(user),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isTech
                                  ? AppColors.primary.withValues(alpha: 0.3)
                                  : AppColors.warning.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: isTech
                                    ? AppColors.primary.withValues(alpha: 0.2)
                                    : AppColors.warning.withValues(alpha: 0.2),
                                child: Icon(
                                  isTech ? Icons.engineering : Icons.verified_user,
                                  size: 20,
                                  color: isTech ? AppColors.primary : AppColors.warning,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.name,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '${user.badge} • ${user.roleDisplayName}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),
                  Text(
                    isOnline
                        ? '🟢 Conexión directa a PostgreSQL y Storage de Supabase'
                        : '🟠 Modo Autónomo Offline (Planta sin cobertura)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

