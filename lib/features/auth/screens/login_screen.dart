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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: isMobile ? AppColors.surfaceSecondary : AppColors.background,
      appBar: isMobile
          ? AppBar(
              backgroundColor: AppColors.primary,
              elevation: 0,
              title: Row(
                children: const [
                  Text('🦅', style: TextStyle(fontSize: 20)),
                  SizedBox(width: 8),
                  Text(
                    'Cauquén CMMS',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              actions: const [
                Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: ConnectivityBadge(),
                ),
              ],
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 14 : 24,
              vertical: isMobile ? 16 : 28,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 460),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!isMobile) ...[
                    const Align(
                      alignment: Alignment.topRight,
                      child: ConnectivityBadge(),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Logo y Marca Industrial (Paleta Cauquén / MaintainX)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                          child: const Center(
                            child: Text(
                              '🦅',
                              style: TextStyle(fontSize: 34),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Cauquén CMMS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Gestión de Mantenimiento Industrial • Planta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Tarjeta del Formulario (Ocupa 100% del ancho en móvil)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ACCESO AL SISTEMA',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Selector de Perfil / Destino (Web vs Móvil)
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _idController.text = 'SUP-1020';
                                    _passwordController.text = 'password123';
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: _idController.text.contains('SUP')
                                        ? AppColors.primaryContainer
                                        : AppColors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _idController.text.contains('SUP')
                                          ? AppColors.primary
                                          : AppColors.border,
                                      width: _idController.text.contains('SUP') ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: const [
                                      Icon(Icons.computer, size: 20, color: AppColors.primary),
                                      SizedBox(height: 4),
                                      Text(
                                        'PORTAL WEB',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Supervisor / Admin',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() {
                                    _idController.text = 'TEC-4482';
                                    _passwordController.text = 'password123';
                                  });
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: !_idController.text.contains('SUP')
                                        ? AppColors.warningContainer
                                        : AppColors.surfaceSecondary,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: !_idController.text.contains('SUP')
                                          ? AppColors.warning
                                          : AppColors.border,
                                      width: !_idController.text.contains('SUP') ? 2 : 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: const [
                                      Icon(Icons.phone_android, size: 20, color: AppColors.warning),
                                      SizedBox(height: 4),
                                      Text(
                                        'APP MÓVIL',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'Operario Técnico',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.warning,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Campo: Legajo / Correo
                        TextField(
                          controller: _idController,
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => setState(() {}),
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            labelText: 'Legajo o Correo de Planta',
                            hintText: 'Ej: SUP-1020 o TEC-4482',
                            prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.primary),
                            filled: true,
                            fillColor: AppColors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Campo: Contraseña
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _handleLogin(),
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
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
                            fillColor: AppColors.surfaceSecondary,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

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
                                'Mantener sesión activa en este dispositivo',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),

                        // Mensaje de Error
                        if (authState.errorMessage != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.dangerContainer,
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
                                    style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Botón Ingresar (100% Ancho)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
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
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.4),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Accesos Rápidos para Prueba de Operarios
                  const Text(
                    'ACCESO RÁPIDO PARA PRUEBAS (1-TAP)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  ...(() {
                    final sorted = List<UserModel>.from(mockUsers)
                      ..sort((a, b) => b.role.index.compareTo(a.role.index)); // Supervisor primero
                    return sorted.map((user) {
                      final isTech = user.role == UserRole.technician;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _handleQuickLogin(user),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isTech
                                    ? AppColors.warning.withValues(alpha: 0.45)
                                    : AppColors.primary.withValues(alpha: 0.5),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 19,
                                  backgroundColor: isTech
                                      ? AppColors.warningContainer
                                      : AppColors.primaryContainer,
                                  child: Icon(
                                    isTech ? Icons.phone_android : Icons.computer,
                                    size: 19,
                                    color: isTech ? AppColors.warning : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              user.name,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isTech
                                                  ? AppColors.warningContainer
                                                  : AppColors.primaryContainer,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isTech ? '📱 MÓVIL' : '🖥️ ADMIN',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                color: isTech ? AppColors.warning : AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
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
                    });
                  })(),

                  const SizedBox(height: 12),
                  Text(
                    isOnline
                        ? '🟢 Conexión directa a PostgreSQL y Storage de Supabase'
                        : '🟠 Modo Autónomo Offline (Planta sin cobertura)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
