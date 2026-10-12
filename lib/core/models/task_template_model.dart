import 'checklist_item_model.dart';
import 'work_order_model.dart';

class TaskTemplateModel {
  final String id;
  final String name; // ej: Protocolo Preventivo de Bombas Centrífugas
  final String description;
  final WorkOrderType type;
  final WorkOrderPriority defaultPriority;
  final int estimatedMinutes;
  final List<ChecklistItemModel> steps;

  const TaskTemplateModel({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.defaultPriority,
    required this.estimatedMinutes,
    required this.steps,
  });

  TaskTemplateModel copyWith({
    String? id,
    String? name,
    String? description,
    WorkOrderType? type,
    WorkOrderPriority? defaultPriority,
    int? estimatedMinutes,
    List<ChecklistItemModel>? steps,
  }) {
    return TaskTemplateModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      defaultPriority: defaultPriority ?? this.defaultPriority,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      steps: steps ?? this.steps,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is TaskTemplateModel && other.id == id);

  @override
  int get hashCode => id.hashCode;

  static List<TaskTemplateModel> getDefaultTemplates() {
    return [
      TaskTemplateModel(
        id: 'tpl-1',
        name: 'Protocolo Estándar: Bomba Centrífuga',
        description: 'Inspección de sello mecánico, alineación, vibraciones y presión de trabajo.',
        type: WorkOrderType.preventivo,
        defaultPriority: WorkOrderPriority.alta,
        estimatedMinutes: 45,
        steps: [
          const ChecklistItemModel(
            id: 'stp-1',
            title: 'Verificar ausencia de fugas en empaquetadura o sello mecánico',
            type: ChecklistItemType.booleanCheck,
          ),
          const ChecklistItemModel(
            id: 'stp-2',
            title: 'Medición de vibración en cojinetes lado acople (RMS)',
            type: ChecklistItemType.numericMeasurement,
            unit: 'mm/s',
            minAcceptable: 0.5,
            maxAcceptable: 4.5,
          ),
          const ChecklistItemModel(
            id: 'stp-3',
            title: 'Medición de presión manométrica en línea de descarga',
            type: ChecklistItemType.numericMeasurement,
            unit: 'bar',
            minAcceptable: 4.0,
            maxAcceptable: 6.5,
          ),
          const ChecklistItemModel(
            id: 'stp-4',
            title: 'Registro fotográfico del estado final del motor y bancada',
            type: ChecklistItemType.photoRequired,
          ),
        ],
      ),
      TaskTemplateModel(
        id: 'tpl-2',
        name: 'Protocolo Estándar: Extrusora y Reductor',
        description: 'Control de temperatura de zonas térmicas, nivel de aceite y tensión de correas.',
        type: WorkOrderType.preventivo,
        defaultPriority: WorkOrderPriority.normal,
        estimatedMinutes: 60,
        steps: [
          const ChecklistItemModel(
            id: 'stp-5',
            title: 'Inspección de nivel y color de aceite en caja reductora',
            type: ChecklistItemType.booleanCheck,
          ),
          const ChecklistItemModel(
            id: 'stp-6',
            title: 'Control termográfico de temperatura en cojinetes',
            type: ChecklistItemType.numericMeasurement,
            unit: '°C',
            minAcceptable: 35.0,
            maxAcceptable: 75.0,
          ),
          const ChecklistItemModel(
            id: 'stp-7',
            title: 'Verificar tensión y alineación de poleas/correas trapezoidales',
            type: ChecklistItemType.booleanCheck,
          ),
          const ChecklistItemModel(
            id: 'stp-8',
            title: 'Foto de comprobación de zona limpia y sin virutas',
            type: ChecklistItemType.photoRequired,
          ),
        ],
      ),
      TaskTemplateModel(
        id: 'tpl-3',
        name: 'Protocolo Estándar: Tablero Eléctrico BT',
        description: 'Apriete de bornes, termografía infrarroja y ensayo de protecciones diferenciales.',
        type: WorkOrderType.predictivo,
        defaultPriority: WorkOrderPriority.alta,
        estimatedMinutes: 30,
        steps: [
          const ChecklistItemModel(
            id: 'stp-9',
            title: 'Reapriete general de bornes y contactores con torquímetro',
            type: ChecklistItemType.booleanCheck,
          ),
          const ChecklistItemModel(
            id: 'stp-10',
            title: 'Medición de tensión entre fases R-S, S-T, T-R',
            type: ChecklistItemType.numericMeasurement,
            unit: 'V',
            minAcceptable: 370.0,
            maxAcceptable: 395.0,
          ),
          const ChecklistItemModel(
            id: 'stp-11',
            title: 'Ensayo y disparo de interruptores diferenciales (Test)',
            type: ChecklistItemType.booleanCheck,
          ),
          const ChecklistItemModel(
            id: 'stp-12',
            title: 'Foto panorámica del interior del tablero cerrado y señalizado',
            type: ChecklistItemType.photoRequired,
          ),
        ],
      ),
    ];
  }
}
