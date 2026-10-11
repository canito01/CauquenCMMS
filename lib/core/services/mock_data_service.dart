import '../models/asset_model.dart';
import '../models/checklist_item_model.dart';
import '../models/spare_part_model.dart';
import '../models/work_order_model.dart';

class MockDataService {
  static List<AssetModel> getAssets() {
    return const [
      AssetModel(
        id: 'ast-1',
        code: 'BOM-002',
        name: 'Bomba Centrífuga Principal de Enfriamiento',
        location: 'Sector Calderas / Circuito Secundario',
        criticality: 'ALTA',
        status: 'OPERATIVO',
        lastMaintenance: '15/09/2026',
      ),
      AssetModel(
        id: 'ast-2',
        code: 'EXT-014',
        name: 'Extrusora de Polímeros Línea 2',
        location: 'Nave Industrial B / Extrusión',
        criticality: 'ALTA',
        status: 'EN_MANTENIMIENTO',
        lastMaintenance: '28/08/2026',
      ),
      AssetModel(
        id: 'ast-3',
        code: 'ENV-005',
        name: 'Envasadora Automática Rotativa',
        location: 'Sector Envasado / Línea 1',
        criticality: 'MEDIA',
        status: 'OPERATIVO',
        lastMaintenance: '02/10/2026',
      ),
      AssetModel(
        id: 'ast-4',
        code: 'TAB-400',
        name: 'Tablero Principal de Potencia BT',
        location: 'Subestación Eléctrica 1',
        criticality: 'ALTA',
        status: 'OPERATIVO',
        lastMaintenance: '10/06/2026',
      ),
    ];
  }

  static List<SparePartModel> getSpareParts() {
    return const [
      SparePartModel(
        id: 'sp-1',
        code: 'ROD-6204-2RS',
        description: 'Rodamiento blindado rígido de bolas 20x47x14',
        locationWarehouse: 'Almacén Central - Estante A-04',
        stockAvailable: 14,
        unit: 'un',
      ),
      SparePartModel(
        id: 'sp-2',
        code: 'RET-35-52-7',
        description: 'Retén de aceite doble labio NBR 35x52x7',
        locationWarehouse: 'Almacén Central - Estante A-12',
        stockAvailable: 8,
        unit: 'un',
      ),
      SparePartModel(
        id: 'sp-3',
        code: 'COR-SPZ-1250',
        description: 'Correa trapezoidal SPZ 1250 dentada',
        locationWarehouse: 'Almacén Central - Estante C-01',
        stockAvailable: 6,
        unit: 'un',
      ),
      SparePartModel(
        id: 'sp-4',
        code: 'ACE-ISO-VG-68',
        description: 'Aceite sintético para reductores industriales VG 68',
        locationWarehouse: 'Depósito de Lubricantes - Tambor 2',
        stockAvailable: 45,
        unit: 'l',
      ),
    ];
  }

  static List<WorkOrderModel> getInitialWorkOrders() {
    final assets = getAssets();
    final parts = getSpareParts();

    return [
      WorkOrderModel(
        id: 'wo-101',
        orderNumber: 'OT-2026-0891',
        title: 'Mantenimiento Preventivo Semestral y Cambio de Rodamientos',
        description:
            'Desmontaje de polea motriz, inspección de juego axial en rodamientos, reemplazo preventivo y relubricación con grasa de alta temperatura.',
        type: WorkOrderType.preventivo,
        priority: WorkOrderPriority.alta,
        status: WorkOrderStatus.enProceso,
        asset: assets[1], // EXT-014
        technicianName: 'Maximiliano Rossi',
        technicianBadge: 'TEC-4482',
        scheduledDate: DateTime.now(),
        startedAt: DateTime.now().subtract(const Duration(minutes: 42)),
        elapsedMinutes: 42,
        safetyProtocols: [
          'Bloqueo y Etiquetado LOTO (Corte general tablero EXT-014)',
          'Uso obligatorio de Guantes de Nitrilo y Gafas de impacto',
          'Verificación de ausencia de tensión con multímetro CAT III',
        ],
        checklist: [
          const ChecklistItemModel(
            id: 'chk-1',
            title: 'Verificación de consignación y bloqueo de energía (LOTO)',
            description: 'Colocar candado y tarjeta personal en seccionador QF2.',
            type: ChecklistItemType.booleanCheck,
            isCompleted: true,
          ),
          const ChecklistItemModel(
            id: 'chk-2',
            title: 'Temperatura en descansos previo al desmontaje',
            description: 'Medición con pirómetro láser en apoyo delantero.',
            type: ChecklistItemType.numericMeasurement,
            numericValue: 68.5,
            unit: '°C',
            minAcceptable: 30.0,
            maxAcceptable: 75.0,
            isCompleted: true,
          ),
          const ChecklistItemModel(
            id: 'chk-3',
            title: 'Desmontaje de tapa y extracción de rodamiento dañado',
            description: 'Utilizar extractor mecánico de 3 garras hidráulico.',
            type: ChecklistItemType.booleanCheck,
            isCompleted: true,
          ),
          const ChecklistItemModel(
            id: 'chk-4',
            title: 'Montaje por inducción térmica de rodamiento nuevo',
            description: 'Calentar hasta 110°C máximo antes del calce.',
            type: ChecklistItemType.booleanCheck,
            isCompleted: false,
          ),
          const ChecklistItemModel(
            id: 'chk-5',
            title: 'Alineación láser de poleas y tensión de correas',
            description: 'Deflexión recomendada: 4.2 mm a 25 N.',
            type: ChecklistItemType.numericMeasurement,
            numericValue: null,
            unit: 'mm',
            minAcceptable: 3.8,
            maxAcceptable: 4.6,
            isCompleted: false,
          ),
        ],
        spareParts: [
          parts[0].copyWith(consumedQuantity: 2), // 2 rodamientos
        ],
        syncStatus: SyncStatus.synced,
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
      WorkOrderModel(
        id: 'wo-102',
        orderNumber: 'OT-2026-0892',
        title: 'Fuga de lubricante en sello mecánico y vibración excesiva',
        description:
            'Operador reporta goteo continuo de refrigerante y ruido anormal en cuerpo de voluta. Requiere desarme para inspección de sello y empaquetadura.',
        type: WorkOrderType.correctivo,
        priority: WorkOrderPriority.urgente,
        status: WorkOrderStatus.pendiente,
        asset: assets[0], // BOM-002
        technicianName: 'Maximiliano Rossi',
        technicianBadge: 'TEC-4482',
        scheduledDate: DateTime.now(),
        safetyProtocols: [
          'Drenaje y purga de cañería con aislamiento de válvulas de retención',
          'Protección ocular contra salpicaduras químicas',
        ],
        checklist: [
          const ChecklistItemModel(
            id: 'chk-201',
            title: 'Cierre y traba de válvulas de aspiración e impulsión',
            type: ChecklistItemType.booleanCheck,
          ),
          const ChecklistItemModel(
            id: 'chk-202',
            title: 'Presión residual manométrica antes de abrir voluta',
            type: ChecklistItemType.numericMeasurement,
            unit: 'bar',
            minAcceptable: 0.0,
            maxAcceptable: 0.2,
          ),
          const ChecklistItemModel(
            id: 'chk-203',
            title: 'Inspección de desgaste en caras de carburo del sello mecánico',
            type: ChecklistItemType.booleanCheck,
          ),
        ],
        spareParts: [
          parts[1].copyWith(consumedQuantity: 1),
        ],
        syncStatus: SyncStatus.synced,
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      WorkOrderModel(
        id: 'wo-103',
        orderNumber: 'OT-2026-0888',
        title: 'Inspección Termográfica y Ajuste de Bornes en Tablero BT',
        description:
            'Termografía de barras principales con cámara FLIR. Re-torqueo de tornillería en interruptores termomagnéticos según tabla de apriete DIN.',
        type: WorkOrderType.predictivo,
        priority: WorkOrderPriority.normal,
        status: WorkOrderStatus.finalizada,
        asset: assets[3], // TAB-400
        technicianName: 'Maximiliano Rossi',
        technicianBadge: 'TEC-4482',
        scheduledDate: DateTime.now().subtract(const Duration(days: 1)),
        startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 4)),
        completedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
        elapsedMinutes: 115,
        safetyProtocols: [
          'Traje Arc-Flash categoría 2 y pantalla facial dieléctrica',
          'Herramientas aisladas 1000V con certificación VDE',
        ],
        checklist: [
          const ChecklistItemModel(
            id: 'chk-301',
            title: 'Medición de temperatura máxima en punto crítico (Barra R)',
            type: ChecklistItemType.numericMeasurement,
            numericValue: 44.2,
            unit: '°C',
            minAcceptable: 20.0,
            maxAcceptable: 55.0,
            isCompleted: true,
          ),
          const ChecklistItemModel(
            id: 'chk-302',
            title: 'Torque de apriete en interruptor general (45 Nm)',
            type: ChecklistItemType.booleanCheck,
            isCompleted: true,
          ),
        ],
        rootCause: 'Aflojamiento por vibraciones en bornes de fase S.',
        technicianNotes: 'Se ajustaron todas las conexiones a torque nominal. Sin puntos calientes residuales.',
        supervisorSignature: 'FirmaDigital_Sup_Alvarez_OK',
        syncStatus: SyncStatus.synced,
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      WorkOrderModel(
        id: 'wo-104',
        orderNumber: 'OT-2026-0885',
        title: 'Calibración de dosificador y cambio de ventosas de vacío',
        description: 'Reemplazo de ventosas de silicona desgastadas. Calibración de caudalímetro neumático.',
        type: WorkOrderType.rutina,
        priority: WorkOrderPriority.baja,
        status: WorkOrderStatus.pausada,
        pauseReason: 'En espera de repuestos especiales (Ventosas de silicona 40mm solicitadas a compras).',
        asset: assets[2], // ENV-005
        technicianName: 'Maximiliano Rossi',
        technicianBadge: 'TEC-4482',
        scheduledDate: DateTime.now().subtract(const Duration(hours: 5)),
        startedAt: DateTime.now().subtract(const Duration(hours: 4)),
        elapsedMinutes: 35,
        checklist: [
          const ChecklistItemModel(
            id: 'chk-401',
            title: 'Prueba de estanqueidad en circuito de vacío',
            type: ChecklistItemType.numericMeasurement,
            numericValue: -0.85,
            unit: 'bar',
            minAcceptable: -0.95,
            maxAcceptable: -0.70,
            isCompleted: true,
          ),
        ],
        syncStatus: SyncStatus.synced,
        updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
    ];
  }
}

