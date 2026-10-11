import 'package:flutter/material.dart';

class AppColors {
  // Primarios y fondos industriales
  static const Color background = Color(0xFF0F172A); // Slate 900
  static const Color surface = Color(0xFF1E293B); // Slate 800
  static const Color surfaceElevated = Color(0xFF334155); // Slate 700
  static const Color surfaceLight = Color(0xFFF8FAFC); // Slate 50 para modo claro
  
  // Acentos funcionales y de seguridad industrial
  static const Color primary = Color(0xFF2563EB); // Azul industrial / eléctrico
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color warning = Color(0xFFF59E0B); // Ámbar de advertencia / En Proceso
  static const Color danger = Color(0xFFEF4444); // Rojo detención / Urgente
  static const Color success = Color(0xFF10B981); // Verde operativo / Completado
  static const Color paused = Color(0xFF8B5CF6); // Violeta / Pausada por repuesto
  
  // Textos y contrastes
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  
  // Bordes y divisores
  static const Color border = Color(0xFF334155);
  static const Color borderLight = Color(0xFF475569);
  
  // Estados de conectividad
  static const Color online = Color(0xFF10B981);
  static const Color offline = Color(0xFFF59E0B);
  static const Color syncError = Color(0xFFEF4444);
}

