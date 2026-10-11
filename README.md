# 🦅 Cauquén CMMS

**Sistema Móvil de Gestión de Mantenimiento Asistido por Computadora (CMMS / GMAO)** diseñado con arquitectura **Offline-First** para técnicos de mantenimiento y operarios en plantas industriales.

---

## 📋 Descripción del Proyecto

Cauquén CMMS digitaliza y optimiza los flujos de trabajo de mantenimiento industrial en piso de planta. Permite a los técnicos ejecutar órdenes de trabajo, registrar mediciones de precisión, auditar anomalías con evidencia fotográfica y cerrar tareas con firma digital, asegurando operatividad continua incluso en zonas sin cobertura de red (subsuelos, naves industriales o salas de máquinas).

### ✨ Funcionalidades Principales

- **Gestión de Órdenes de Trabajo (OT):** Seguimiento de mantenimientos correctivos, preventivos y predictivos por nivel de criticidad (Baja, Normal, Alta, Urgente).
- **Planillas de Verificación & Mediciones:** Tareas booleanas y registro de variables de proceso (vibración, temperatura, presión) con validación automática de tolerancias aceptables.
- **Evidencias Fotográficas en Campo:** Captura directa desde la cámara del celular o galería con visor interactivo y zoom, almacenadas en la nube.
- **Control de Repuestos:** Registro en tiempo real de insumos consumidos con impacto en el inventario de almacén.
- **Cierre y Firma Digital:** Firma de conformidad en pantalla táctil, diagnóstico de causa raíz y observaciones técnicas finales.
- **Motor Offline-First:** Almacenamiento local persistente con cola de mutaciones y sincronización automática bidireccional al recuperar conexión.

---

## 🛠️ Stack Tecnológico

| Capa | Tecnología | Propósito |
| :--- | :--- | :--- |
| **Frontend Móvil & Web** | [Flutter](https://flutter.dev/) (Dart) | Aplicación multiplataforma de alto rendimiento y diseño ergonómico industrial. |
| **Estado Reactivo** | [Riverpod](https://riverpod.dev/) | Gestión de estado predecible y reactiva para el ciclo de vida de las órdenes. |
| **Navegación** | GoRouter | Enrutamiento declarativo y deep linking. |
| **Persistencia Local** | Local Cache & Preferences | Motor de almacenamiento en dispositivo para operación sin internet. |
| **Backend & Base de Datos** | [Supabase](https://supabase.com/) (PostgreSQL) | Base de datos relacional con políticas de seguridad RLS e índices optimizados. |
| **Almacenamiento Cloud** | Supabase Storage (`evidences`) | Bucket para archivo seguro de fotografías de auditoría y firmas digitales. |
| **Periféricos de Campo** | Cámara nativa & Digital Signature | Captura fotográfica con compresión y lienzo de firma táctil. |

---

## 🚀 Puesta en Marcha

### Prerrequisitos
- Flutter SDK (versión 3.24 o superior)
- Dart SDK
- Cuenta / Proyecto en Supabase (con el esquema `supabase_schema.sql` ejecutado)

### Instalación y Ejecución Local
```bash
# 1. Clonar el repositorio
git clone https://github.com/canito01/CauquenCMMS.git

# 2. Entrar a la carpeta del proyecto
cd CauquenCMMS

# 3. Instalar dependencias
flutter pub get

# 4. Ejecutar en desarrollo
flutter run

# O compilar versión Web de planta
flutter build web --release
```

---

## 📄 Licencia
Proyecto privado de uso industrial. Todos los derechos reservados.
