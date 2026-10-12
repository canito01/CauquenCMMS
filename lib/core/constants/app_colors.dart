import 'package:flutter/material.dart';

/// Paleta de Diseño Oficial Cauquén CMMS (SaaS Minimalista Industrial)
class AppColors {
  // --- Fondos ---
  static const Color background = Color(0xFFFFFFFF); // Blanco limpio
  static const Color surface = Color(0xFFFFFFFF); // Superficie principal blanca
  static const Color surfaceSecondary = Color(0xFFF8F9FA); // Blanco tiza / neutro muy suave
  static const Color surfaceElevated = Color(0xFFF1F3F5); // Contenedor secundario neutro
  static const Color surfaceLight = Color(0xFFFAFAFA); // Gris neutro ultra suave para tablas/paneles
  
  // --- Identidad de Marca (Paleta Cauquén) ---
  static const Color primary = Color(0xFF4E3629); // Marrón castaño / tierra industrial SaaS
  static const Color primaryDark = Color(0xFF3E2B21); // Marrón castaño profundo
  static const Color primaryWarm = Color(0xFF5C4033); // Marrón cálido para acentos móviles
  static const Color primaryHover = Color(0xFF3E2B21); // Marrón oscuro hover
  static const Color primaryLight = Color(0xFF8D6E63); // Tono tierra suave para detalles
  static const Color primaryContainer = Color(0xFFF5EFEB); // Fondo sutil con tinte marrón tierra
  
  // --- Alertas y Estados Funcionales ---
  static const Color danger = Color(0xFFD32F2F); // Rojo bermellón (Averías críticas / Breakdowns / Urgente)
  static const Color dangerContainer = Color(0xFFFFEBEE); // Fondo sutil de alerta
  static const Color warning = Color(0xFFF57C00); // Ámbar anaranjado para "En Proceso"
  static const Color warningContainer = Color(0xFFFFF3E0);
  static const Color success = Color(0xFF2E7D32); // Verde bosque para "Finalizada" / Conectado
  static const Color successContainer = Color(0xFFE8F5E9);
  static const Color paused = Color(0xFF7B1FA2); // Violeta neutro para tareas pausadas
  static const Color pausedContainer = Color(0xFFF3E5F5);
  
  // --- Textos y Tipografía ---
  static const Color textPrimary = Color(0xFF1E1E1E); // Negro neutro (AA/AAA contraste)
  static const Color textSecondary = Color(0xFF6B7280); // Gris neutro para subtítulos y metadatos
  static const Color textMuted = Color(0xFF9CA3AF); // Gris suave para hints y etiquetas terciarias
  
  // --- Bordes y Separadores (1px delgados y limpios) ---
  static const Color border = Color(0xFFE5E7EB); // Gris neutro delgado para tarjetas y divisiones
  static const Color borderLight = Color(0xFFF0F2F5); // Divisor ultra sutil
  
  // --- Estados de Conectividad ---
  static const Color online = Color(0xFF2E7D32);
  static const Color offline = Color(0xFFF57C00);
  static const Color syncError = Color(0xFFD32F2F);
}
