# 🗺️ Roadmap de Próximas Implementaciones — Cauquén CMMS

Documento de planificación y especificación técnica de las próximas fases del proyecto.

---

## 📌 1. Autenticación y Control de Acceso (Login de Operadores)

### Objetivo
Permitir que cada técnico u operario inicie sesión de forma segura y personalizada con sus credenciales, vinculando su legajo, turno y especialidad a las órdenes ejecutadas.

### Requerimientos Funcionales
- **Pantalla de Login Móvil:**
  - Entrada de correo/legajo y contraseña con diseño industrial de alto contraste.
  - Validación de campos y retroalimentación visual de errores.
  - Opción de "Recordar sesión" con token seguro en almacenamiento local.
- **Sesión Persistente Offline-First:**
  - Los técnicos deben poder seguir operando con su sesión activa incluso si la aplicación se abre en un sector sin señal de planta (caché de token criptográfico / sesión local).
- **Integración con Supabase Auth & RLS:**
  - Creación de usuarios con roles en Supabase (`technician`, `supervisor`, `admin`).
  - Aplicación de políticas *Row Level Security (RLS)* para que cada operario solo vea o edite las órdenes asignadas a su turno/área, mientras los supervisores tienen visibilidad global.

---

## 📌 2. Panel Web de Gestión y Administración (Backoffice Central)

### Objetivo
Proveer a los jefes de mantenimiento, ingenieros de planta y supervisores de una interfaz de escritorio para administrar proyectos, recursos, inventarios y reportes.

### Módulos del Panel Web
1. **Gestión de Plantas y Proyectos:**
   - Estructura jerárquica de activos: Planta -> Sector / Nave -> Línea de Producción -> Máquina / Equipo.
2. **Administración de Usuarios y Cuadrillas:**
   - Alta, baja y modificación de técnicos, asignación de turnos (Mañana, Tarde, Noche) y especialidades (Mecánica, Eléctrica, Neumática).
3. **Control Centralizado de Órdenes de Trabajo (OT):**
   - Creación, calendarización y asignación de órdenes preventivas y correctivas.
   - Vista Kanban y calendario interactivo de mantenimientos programados.
   - Auditoría de órdenes cerradas: visualización de fotos de evidencia en alta definición, mediciones tomadas y firmas de conformidad.
4. **Gestión de Stock e Inventario de Repuestos:**
   - Catálogo de repuestos con código, descripción, ubicación en almacén y niveles de stock.
   - Alertas automáticas de reposición por stock crítico o consumo elevado.
5. **Métricas y KPIs Industriales:**
   - Dashboard ejecutivo con indicadores clave:
     - **MTTR** (*Mean Time to Repair* - Tiempo medio de reparación).
     - **MTBF** (*Mean Time Between Failures* - Tiempo medio entre fallas).
     - Porcentaje de cumplimiento de planes de mantenimiento preventivo.

---

## 📌 3. Decisión de Implementación Móvil en Celulares de Planta

### Comparativa de Alternativas

| Criterio | 🌐 Opción A: PWA (Web Instalable) | 📱 Opción B: APK Nativo Android | 🏢 Opción C: Tienda Privada / MDM |
| :--- | :--- | :--- | :--- |
| **Instalación** | Cero instalación. Se abre el link y se toca *"Agregar a pantalla principal"*. | Se descarga el archivo `.apk` y se instala en el celular. | Despliegue corporativo centralizado (Google Workspace / MDM). |
| **Actualizaciones** | **Instantáneas**. Cada compilación subida se actualiza en los celulares de inmediato. | Manual. Cada actualización requiere distribuir e instalar un nuevo `.apk`. | Automáticas mediante el canal corporativo. |
| **Acceso a Hardware** | Cámara, pantalla táctil, almacenamiento local, acelerómetro. | Acceso total a hardware (linterna, Bluetooth para escáneres industriales, vibración, etc.). | Acceso total con políticas de seguridad forzadas por la empresa. |
| **Experiencia de Usuario** | Modo pantalla completa sin barra de navegación, idéntica a una app nativa. | 100% nativa de Android con icono en el cajón de aplicaciones. | 100% nativa con perfiles de trabajo. |
| **Recomendado para:** | **Fase de Pruebas, Piloto y Despliegue Rápido** en cualquier celular sin configurar nada. | **Fase de Producción en Planta** para celulares o colectores rugerizados exclusivos de la empresa. | Grandes corporaciones con flotas de dispositivos administrados. |

### Enfoque Propuesto
Aprovechando que **Flutter genera ambos formatos desde el mismo código**:
1. **Corto Plazo (Validación y Testing):** Utilizar **PWA** para que los técnicos prueben de inmediato en sus celulares mediante la red local o link cloud sin lidiar con permisos de instalación.
2. **Mediano Plazo (Producción Oficial):** Generar el archivo `.apk` release firmado para instalar en los celulares de cuadrilla con acceso nativo optimizado.
