import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/work_order_model.dart';
import '../../../core/services/app_providers.dart';
import '../../common/connectivity_badge.dart';
import '../widgets/report_breakdown_sheet.dart';
import '../widgets/work_order_card.dart';

class WorkOrdersListScreen extends ConsumerStatefulWidget {
  const WorkOrdersListScreen({super.key});

  @override
  ConsumerState<WorkOrdersListScreen> createState() => _WorkOrdersListScreenState();
}

class _WorkOrdersListScreenState extends ConsumerState<WorkOrdersListScreen> {
  String _searchQuery = '';
  WorkOrderStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final workOrders = ref.watch(workOrdersProvider);

    final filteredOrders = workOrders.where((order) {
      if (_selectedStatus != null && order.status != _selectedStatus) {
        return false;
      }
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesNumber = order.orderNumber.toLowerCase().contains(query);
        final matchesTitle = order.title.toLowerCase().contains(query);
        final matchesAsset = order.asset.code.toLowerCase().contains(query) ||
            order.asset.name.toLowerCase().contains(query);
        if (!matchesNumber && !matchesTitle && !matchesAsset) {
          return false;
        }
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Órdenes de Trabajo'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: ConnectivityBadge(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => ReportBreakdownSheet.show(context),
        backgroundColor: AppColors.danger,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alert_rounded, size: 18),
        label: const Text('Reportar Avería', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
      ),
      body: Column(
        children: [
          // Campo de búsqueda
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar por OT, equipo (ej. BOM-002) o falla...',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                isDense: true,
              ),
            ),
          ),

          // Chips de filtro por estado
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip('Todas (${workOrders.length})', null),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'En Proceso (${workOrders.where((o) => o.status == WorkOrderStatus.enProceso).length})',
                  WorkOrderStatus.enProceso,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Pendientes (${workOrders.where((o) => o.status == WorkOrderStatus.pendiente).length})',
                  WorkOrderStatus.pendiente,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Pausadas (${workOrders.where((o) => o.status == WorkOrderStatus.pausada).length})',
                  WorkOrderStatus.pausada,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Finalizadas (${workOrders.where((o) => o.status == WorkOrderStatus.finalizada).length})',
                  WorkOrderStatus.finalizada,
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Listado
          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.filter_list_off, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'No se encontraron órdenes de trabajo',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                        ),
                        if (_selectedStatus != null || _searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedStatus = null;
                                _searchQuery = '';
                              });
                            },
                            child: const Text('Limpiar filtros'),
                          ),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async {
                      await ref.read(syncQueueProvider.notifier).syncAllBidirectional();
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return WorkOrderCard(
                          order: order,
                          onTap: () {
                            context.push('/order/${order.id}');
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, WorkOrderStatus? status) {
    final isSelected = _selectedStatus == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textSecondary,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
      side: BorderSide(
        color: isSelected ? AppColors.primary : AppColors.border,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}

