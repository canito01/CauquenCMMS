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
      // 1. Caso de uso completo MaintainX: Grupo Generador, Luminarias y Limpieza
      TaskTemplateModel(
        id: 'tpl-maintainx-multistage',
        name: 'Mantenimiento Integral: Generador, Luminarias & Planta',
        description:
            'Protocolo multietapa: 1) Chequeo motor y manómetros, 2) Test de fotocélulas e iluminación, 3) Limpieza y orden de nave.',
        type: WorkOrderType.preventivo,
        defaultPriority: WorkOrderPriority.alta,
        estimatedMinutes: 90,
        stages: const [
          WorkflowStageModel(
            id: 'stg-gen-1',
            name: 'Etapa 1: Motor Generador & Presión de Fluidos',
            description: 'Reinicio, verificación de líquidos, medición de presión y tablero de control',
            order: 1,
          ),
          WorkflowStageModel(
            id: 'stg-gen-2',
            name: 'Etapa 2: Inspección de Luminarias & Fotocélulas',
            description: 'Foto de luminarias apagadas, tapado de fotocélulas y comprobación encendida',
            order: 2,
          ),
          WorkflowStageModel(
            id: 'stg-gen-3',
            name: 'Etapa 3: Limpieza y Despeje General de Nave',
            description: 'Registro fotográfico antes y después, y retiro de residuos industriales',
            order: 3,
          ),
        ],
        steps: [
          // Etapa 1
          const ChecklistItemModel(
            id: 'gen-s1',
            stageId: 'stg-gen-1',
            stageName: 'Etapa 1: Motor Generador & Presión de Fluidos',
            title: 'Chequear estado del motor y reinicio de controlador digital',
            description: 'Comprobar ausencia de códigos de falla en el display antes del arranque.',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s2',
            stageId: 'stg-gen-1',
            stageName: 'Etapa 1: Motor Generador & Presión de Fluidos',
            title: 'Verificar nivel de líquidos (aceite motor y refrigerante)',
            description: 'El nivel de cárter debe estar entre las marcas MIN y MAX de la varilla.',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s3',
            stageId: 'stg-gen-1',
            stageName: 'Etapa 1: Motor Generador & Presión de Fluidos',
            title: 'Indicar presión manométrica de aceite en régimen (bar)',
            description: 'Lectura nominal en caliente debe situarse entre 3.5 y 5.5 bar.',
            type: ChecklistItemType.numericMeasurement,
            unit: 'bar',
            minAcceptable: 3.5,
            maxAcceptable: 5.5,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s4',
            stageId: 'stg-gen-1',
            stageName: 'Etapa 1: Motor Generador & Presión de Fluidos',
            title: 'Fotografía obligatoria del manómetro indicando la presión',
            description: 'Capturar el dial del manómetro analógico con buena iluminación.',
            type: ChecklistItemType.photoRequired,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s5',
            stageId: 'stg-gen-1',
            stageName: 'Etapa 1: Motor Generador & Presión de Fluidos',
            title: 'Foto del estado general del grupo generador y limpieza',
            description: 'Fotografía panorámica del grupo generador en su cabina acústica.',
            type: ChecklistItemType.photoRequired,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s6',
            stageId: 'stg-gen-1',
            stageName: 'Etapa 1: Motor Generador & Presión de Fluidos',
            title: 'Foto del tablero de conexiones y borneras de potencia',
            description: 'Verificar que las tapas plásticas de seguridad estén colocadas.',
            type: ChecklistItemType.photoRequired,
            isRequired: true,
          ),

          // Etapa 2
          const ChecklistItemModel(
            id: 'gen-s7',
            stageId: 'stg-gen-2',
            stageName: 'Etapa 2: Inspección de Luminarias & Fotocélulas',
            title: 'Foto de las luminarias de la nave apagadas',
            description: 'Fotografía de la nave antes del testeo de fotocontrol.',
            type: ChecklistItemType.photoRequired,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s8',
            stageId: 'stg-gen-2',
            stageName: 'Etapa 2: Inspección de Luminarias & Fotocélulas',
            title: 'Tapar las fotocélulas de control con protector opaco',
            description: 'Simular condición nocturna para forzar la conmutación de contactores.',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s9',
            stageId: 'stg-gen-2',
            stageName: 'Etapa 2: Inspección de Luminarias & Fotocélulas',
            title: 'Foto de las luminarias encendidas (verificación una a una)',
            description: 'Capturar una foto por cada luminaria encendida (mínimo 3 fotos requeridas).',
            type: ChecklistItemType.photoRequired,
            minPhotos: 3,
            maxPhotos: 8,
            isRequired: true,
          ),

          // Etapa 3
          const ChecklistItemModel(
            id: 'gen-s10',
            stageId: 'stg-gen-3',
            stageName: 'Etapa 3: Limpieza y Despeje General de Nave',
            title: 'Registro fotográfico ANTES y DESPUÉS de la limpieza',
            description: 'Toma obligatoria del sector previo al barrido y posterior al acondicionamiento.',
            type: ChecklistItemType.photoBeforeAfter,
            isRequired: true,
          ),
          const ChecklistItemModel(
            id: 'gen-s11',
            stageId: 'stg-gen-3',
            stageName: 'Etapa 3: Limpieza y Despeje General de Nave',
            title: 'Despeje de pasillos técnicos y disposición final de residuos',
            description: 'Garantizar vías de escape libres de obstáculos según norma de seguridad.',
            type: ChecklistItemType.booleanCheck,
            isRequired: true,
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
