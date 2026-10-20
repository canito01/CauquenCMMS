import 'checklist_item_model.dart';
import 'workflow_stage_model.dart';
import 'work_order_model.dart';

class TaskTemplateModel {
  final String id;
  final String name; // ej: Protocolo Preventivo de Bombas Centrífugas
  final String description;
  final WorkOrderType type;
  final WorkOrderPriority defaultPriority;
  final int estimatedMinutes;
  final List<WorkflowStageModel> stages;
  final List<ChecklistItemModel> steps;

  const TaskTemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.defaultPriority,
    required this.estimatedMinutes,
    this.stages = const [],
    required this.steps,
  });

  /// Devuelve las etapas configuradas, o infiere las etapas a partir de los pasos de la plantilla.
  List<WorkflowStageModel> get resolvedStages {
    if (stages.isNotEmpty) return stages;
    if (steps.isEmpty) {
      return const [
        WorkflowStageModel(
          id: 'stg-1',
          name: 'Etapa 1: Procedimientos Iniciales',
          order: 1,
        )
      ];
    }
    final Map<String, WorkflowStageModel> stagesMap = {};
    int orderCounter = 1;
    for (final s in steps) {
      if (!stagesMap.containsKey(s.stageId)) {
        stagesMap[s.stageId] = WorkflowStageModel(
          id: s.stageId,
          name: s.stageName,
          order: orderCounter++,
        );
      }
    }
    return stagesMap.values.toList();
  }

  TaskTemplateModel copyWith({
    String? id,
    String? name,
    String? description,
    WorkOrderType? type,
    WorkOrderPriority? defaultPriority,
    int? estimatedMinutes,
    List<WorkflowStageModel>? stages,
    List<ChecklistItemModel>? steps,
  }) {
    return TaskTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      stages: stages ?? this.stages,
      steps: steps ?? this.steps,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'type': type.name,
      'defaultPriority': defaultPriority.name,
      'estimatedMinutes': estimatedMinutes,
      'stages': stages.map((s) => s.toMap()).toList(),
      'steps': steps.map((s) => s.toMap()).toList(),
    };
  }

  factory TaskTemplateModel.fromMap(Map<String, dynamic> map) {
    return TaskTemplateModel(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      type: WorkOrderType.values.byName(map['type'] as String? ?? 'preventivo'),
      defaultPriority: WorkOrderPriority.values.byName(map['defaultPriority'] as String? ?? 'normal'),
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt() ?? 45,
      stages: (map['stages'] as List? ?? [])
          .map((s) => WorkflowStageModel.fromMap(s as Map<String, dynamic>))
          .toList(),
      steps: (map['steps'] as List? ?? [])
          .map((s) => ChecklistItemModel.fromMap(s as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TaskTemplateModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  static List<TaskTemplateModel> getDefaultTemplates() {
    return [
      // 1. Caso de uso completo MaintainX: Grupo Generador, Luminarias y Limpieza (Todos los tipos de paso)
      TaskTemplateModel(
        id: 'tpl-maintainx-multistage',
        name: '⭐ Protocolo Integral: Generador, Luminarias & Limpieza (Completo)',
        description:
            'Protocolo multietapa con todos los tipos de paso: Sí/No, Selección Única, Medición con tolerancia (bar), Múltiples Fotos obligatorias, Casillas Múltiples, Foto Antes/Después y Nota Opcional.',
        type: WorkOrderType.preventivo,
        defaultPriority: WorkOrderPriority.urgente,
        estimatedMinutes: 90,
        stages: const [
          WorkflowStageModel(
            id: 'stg-demo-1',
            name: 'Etapa 1: Motor Generador, Líquidos y Tablero',
            description: 'Chequeo de motor, reinicio, control de fluidos, presión manométrica y fotos de motor/tablero',
            order: 1,
          ),
          WorkflowStageModel(
            id: 'stg-demo-2',
            name: 'Etapa 2: Control de Luminarias y Fotocélulas',
            description: 'Foto de luminarias apagadas, tapado de fotocélulas y verificación encendidas una a una',
            order: 2,
          ),
          WorkflowStageModel(
            id: 'stg-demo-3',
            name: 'Etapa 3: Limpieza General del Sector (Antes y Después)',
            description: 'Registro comparativo ANTES y DESPUÉS de la limpieza y observaciones finales',
            order: 3,
          ),
        ],
        steps: [
          // Etapa 1
          const ChecklistItemModel(
            id: 'gen-s1',
            stageId: 'stg-demo-1',
            stageName: 'Etapa 1: Motor Generador, Líquidos y Tablero',
            title: 'Chequear estado del motor generador y reiniciar controlador digital',
            description: 'Inspección Sí/No: Verificar que el motor arranque sin alarmas ni ruidos anómalos tras el reinicio.',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s2',
            stageId: 'stg-demo-1',
            stageName: 'Etapa 1: Motor Generador, Líquidos y Tablero',
            title: 'Estado de líquidos (Aceite de cárter y Refrigerante)',
            description: 'Selección única: Indique la condición encontrada al revisar niveles de fluidos.',
            type: ChecklistItemType.singleChoice,
            options: [
              'Niveles Óptimos (Entre MIN y MAX)',
              'Nivel Bajo - Se repuso fluido en el acto',
              'Fuga o contaminación detectada (Requiere correctivo)',
            ],
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s3',
            stageId: 'stg-demo-1',
            stageName: 'Etapa 1: Motor Generador, Líquidos y Tablero',
            title: 'Indicar presión manométrica del motor en marcha',
            description: 'Medición numérica con tolerancia: Ingrese el valor leído en el manómetro (Rango normal: 3.5 a 5.5 bar).',
            type: ChecklistItemType.numericMeasurement,
            unit: 'bar',
            minAcceptable: 3.5,
            maxAcceptable: 5.5,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s4',
            stageId: 'stg-demo-1',
            stageName: 'Etapa 1: Motor Generador, Líquidos y Tablero',
            title: 'Evidencia Fotográfica Triple: 1) Manómetro de presión, 2) Motor generador, 3) Tablero de conexiones',
            description: 'Paso con MÚLTIPLES FOTOS obligatorias (Mínimo 3 fotos requeridas en este mismo paso).',
            type: ChecklistItemType.photoRequired,
            minPhotos: 3,
            maxPhotos: 5,
            isRequired: true,
          ),

          // Etapa 2
          const ChecklistItemModel(
            id: 'gen-s5',
            stageId: 'stg-demo-2',
            stageName: 'Etapa 2: Control de Luminarias y Fotocélulas',
            title: 'Sacar foto a las luminarias del lugar APAGADAS',
            description: 'Evidencia previa: Tome 1 foto mostrando el circuito de iluminación apagado antes de la prueba.',
            type: ChecklistItemType.photoRequired,
            minPhotos: 1,
            maxPhotos: 3,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s6',
            stageId: 'stg-demo-2',
            stageName: 'Etapa 2: Control de Luminarias y Fotocélulas',
            title: 'Tapar fotocélulas y verificar encendido de luminarias una a una',
            description: 'Casillas múltiples: Cubra la fotocélula y tilde cada luminaria que encienda correctamente.',
            type: ChecklistItemType.multipleChoice,
            options: [
              'Luminaria #1 (Sector Generador) - Encendida OK',
              'Luminaria #2 (Pasillo Central) - Encendida OK',
              'Luminaria #3 (Frente a Tablero BT) - Encendida OK',
              'Luminaria #4 (Acceso Exterior) - Encendida OK',
            ],
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s7',
            stageId: 'stg-demo-2',
            stageName: 'Etapa 2: Control de Luminarias y Fotocélulas',
            title: 'Sacar fotos a las luminarias ENCENDIDAS (Mínimo 2 fotos)',
            description: 'Fotografíe las luminarias encendidas tras tapar las fotocélulas (mínimo 2 capturas obligatorias).',
            type: ChecklistItemType.photoRequired,
            minPhotos: 2,
            maxPhotos: 6,
            isRequired: true,
          ),

          // Etapa 3
          const ChecklistItemModel(
            id: 'gen-s8',
            stageId: 'stg-demo-3',
            stageName: 'Etapa 3: Limpieza General del Sector (Antes y Después)',
            title: 'Limpieza general del lugar: Foto ANTES y Foto DESPUÉS',
            description: 'Comparativa doble obligatoria: Tome la foto ANTES de limpiar y la foto DESPUÉS de finalizar el orden y barrido.',
            type: ChecklistItemType.photoBeforeAfter,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s9',
            stageId: 'stg-demo-3',
            stageName: 'Etapa 3: Limpieza General del Sector (Antes y Después)',
            title: 'Notas adicionales o solicitud de insumos (Paso Opcional)',
            description: 'Este paso está configurado como OPCIONAL para demostrar que permite avanzar sin bloquear el cierre.',
            type: ChecklistItemType.textObservation,
            isRequired: false,
          ),
        ],
      ),

      // 2. Bomba Centrífuga
      TaskTemplateModel(
        id: 'tpl-1',
        name: 'Protocolo Estándar: Bomba Centrífuga',
        description: 'Inspección de sello mecánico, alineación, vibraciones y presión de trabajo.',
        type: WorkOrderType.preventivo,
        defaultPriority: WorkOrderPriority.alta,
        estimatedMinutes: 45,
        stages: const [
          WorkflowStageModel(
            id: 'stg-bomba-1',
            name: 'Etapa 1: Inspección Mecánica & Sello',
            description: 'Verificación estanqueidad y fijaciones mecánicas',
            order: 1,
          ),
          WorkflowStageModel(
            id: 'stg-bomba-2',
            name: 'Etapa 2: Parámetros Hidráulicos & Evidencia',
            description: 'Medición de vibración, presión en línea y fotos de bancada',
            order: 2,
          ),
        ],
        steps: [
          const ChecklistItemModel(
            id: 'stp-1',
            stageId: 'stg-bomba-1',
            stageName: 'Etapa 1: Inspección Mecánica & Sello',
            title: 'Verificar ausencia de fugas en empaquetadura o sello mecánico',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-2',
            stageId: 'stg-bomba-2',
            stageName: 'Etapa 2: Parámetros Hidráulicos & Evidencia',
            title: 'Medición de vibración en cojinetes lado acople (RMS)',
            type: ChecklistItemType.numericMeasurement,
            unit: 'mm/s',
            minAcceptable: 0.5,
            maxAcceptable: 4.5,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-3',
            stageId: 'stg-bomba-2',
            stageName: 'Etapa 2: Parámetros Hidráulicos & Evidencia',
            title: 'Medición de presión manométrica en línea de descarga',
            type: ChecklistItemType.numericMeasurement,
            unit: 'bar',
            minAcceptable: 4.0,
            maxAcceptable: 6.5,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-4',
            stageId: 'stg-bomba-2',
            stageName: 'Etapa 2: Parámetros Hidráulicos & Evidencia',
            title: 'Registro fotográfico del estado final del motor y bancada',
            type: ChecklistItemType.photoRequired,
            isRequired: true,
          ),
        ],
      ),

      // 3. Extrusora y Reductor
      TaskTemplateModel(
        id: 'tpl-2',
        name: 'Protocolo Estándar: Extrusora y Reductor',
        description: 'Control de temperatura de zonas térmicas, nivel de aceite y tensión de correas.',
        type: WorkOrderType.preventivo,
        defaultPriority: WorkOrderPriority.normal,
        estimatedMinutes: 60,
        stages: const [
          WorkflowStageModel(
            id: 'stg-ext-1',
            name: 'Etapa 1: Transmisión Mecánica & Lubricación',
            description: 'Control de reductor, aceite y correas',
            order: 1,
          ),
          WorkflowStageModel(
            id: 'stg-ext-2',
            name: 'Etapa 2: Zona Térmica & Estado General',
            description: 'Termografía de rodamientos y verificación visual',
            order: 2,
          ),
        ],
        steps: [
          const ChecklistItemModel(
            id: 'stp-5',
            stageId: 'stg-ext-1',
            stageName: 'Etapa 1: Transmisión Mecánica & Lubricación',
            title: 'Inspección de nivel y color de aceite en caja reductora',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-6',
            stageId: 'stg-ext-2',
            stageName: 'Etapa 2: Zona Térmica & Estado General',
            title: 'Control termográfico de temperatura en cojinetes',
            type: ChecklistItemType.numericMeasurement,
            unit: '°C',
            minAcceptable: 35.0,
            maxAcceptable: 75.0,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-7',
            stageId: 'stg-ext-1',
            stageName: 'Etapa 1: Transmisión Mecánica & Lubricación',
            title: 'Verificar tensión y alineación de poleas/correas trapezoidales',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-8',
            stageId: 'stg-ext-2',
            stageName: 'Etapa 2: Zona Térmica & Estado General',
            title: 'Foto de comprobación de zona limpia y sin virutas',
            type: ChecklistItemType.photoRequired,
            isRequired: false,
          ),
        ],
      ),

      // 4. Tablero Eléctrico BT
      TaskTemplateModel(
        id: 'tpl-3',
        name: 'Protocolo Estándar: Tablero Eléctrico BT',
        description: 'Apriete de bornes, termografía infrarroja y ensayo de protecciones diferenciales.',
        type: WorkOrderType.predictivo,
        defaultPriority: WorkOrderPriority.alta,
        estimatedMinutes: 30,
        stages: const [
          WorkflowStageModel(
            id: 'stg-tab-1',
            name: 'Etapa 1: Seguridad & Desconexión',
            description: 'Pruebas de disparo y aprietes',
            order: 1,
          ),
          WorkflowStageModel(
            id: 'stg-tab-2',
            name: 'Etapa 2: Mediciones Eléctricas & Evidencia',
            description: 'Tensiones entre fases y registro fotográfico',
            order: 2,
          ),
        ],
        steps: [
          const ChecklistItemModel(
            id: 'stp-9',
            stageId: 'stg-tab-1',
            stageName: 'Etapa 1: Seguridad & Desconexión',
            title: 'Reapriete general de bornes y contactores con torquímetro',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-10',
            stageId: 'stg-tab-2',
            stageName: 'Etapa 2: Mediciones Eléctricas & Evidencia',
            title: 'Medición de tensión entre fases R-S, S-T, T-R',
            type: ChecklistItemType.numericMeasurement,
            unit: 'V',
            minAcceptable: 370.0,
            maxAcceptable: 395.0,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-11',
            stageId: 'stg-tab-1',
            stageName: 'Etapa 1: Seguridad & Desconexión',
            title: 'Ensayo y disparo de interruptores diferenciales (Test)',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'stp-12',
            stageId: 'stg-tab-2',
            stageName: 'Etapa 2: Mediciones Eléctricas & Evidencia',
            title: 'Foto panorámica del interior del tablero cerrado y señalizado',
            type: ChecklistItemType.photoRequired,
            isRequired: true,
          ),
        ],
      ),
    ];
  }
}
