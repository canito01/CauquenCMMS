class SupabaseConfig {
  // Credenciales activas del proyecto Supabase:
  // Project ID: dwiycaghqyicyrlkymrw
  static const String supabaseUrl = 'https://dwiycaghqyicyrlkymrw.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImR3aXljYWdocXlpY3lybGt5bXJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2OTU0MjAsImV4cCI6MjEwNzI3MTQyMH0.YSBz-qsxt2aiGiJYIC7lJ5CdcTXFwqpf2TJ90uQFSwM';

  static bool get isConfigured =>
      supabaseUrl != 'https://tu-proyecto.supabase.co' &&
      supabaseAnonKey != 'tu-anon-key-aqui' &&
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty;
}
