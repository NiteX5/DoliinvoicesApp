import 'package:flutter/material.dart';
import '../services/dolibarr_service.dart';
import '../models/project.dart';
import '../screens/base/base_list_screen.dart';
import '../widgets/shared/base_card.dart';
import '../widgets/shared/sort_menu.dart';
import '../widgets/shared/filter_chip.dart';
import 'project_form_screen.dart';

/// Pantalla de proyectos usando BaseListScreen para eliminar duplicación.
class ProjectsScreen extends BaseListScreen<Project> {
  ProjectsScreen({super.key});

  @override
  BaseListScreenConfig<Project> get config => BaseListScreenConfig(
    title: 'Proyectos',
    searchHint: 'Buscar por referencia, título, cliente...',
    sortOptions: [
      SortOption(value: 'date', label: 'Fecha', icon: Icons.calendar_today),
      SortOption(value: 'title', label: 'Título', icon: Icons.sort_by_alpha),
      SortOption(value: 'ref', label: 'Referencia', icon: Icons.receipt),
    ],
    filterChips: [
      FilterChipConfig(value: null, label: 'Todos', icon: Icons.list_alt, statusColor: Colors.blue, containerColor: Colors.blue, onContainerColor: Colors.white),
      FilterChipConfig(value: 0, label: 'Borrador', icon: Icons.edit_outlined, statusColor: Colors.orange, containerColor: Colors.orange, onContainerColor: Colors.white),
      FilterChipConfig(value: 1, label: 'En curso', icon: Icons.play_circle_outline, statusColor: Colors.blue, containerColor: Colors.blue, onContainerColor: Colors.white),
      FilterChipConfig(value: 2, label: 'Cerrado', icon: Icons.check_circle_outline, statusColor: Colors.green, containerColor: Colors.green, onContainerColor: Colors.white),
      FilterChipConfig(value: 3, label: 'Cancelado', icon: Icons.cancel_outlined, statusColor: Colors.red, containerColor: Colors.red, onContainerColor: Colors.white),
    ],
    defaultSortBy: 'date',
    defaultSortAscending: false,
    emptyState: EmptyStateConfig(
      icon: Icons.folder_open,
      title: 'No hay proyectos',
      subtitle: 'Comienza creando tu primer proyecto',
      actionLabel: 'Crear Proyecto',
      onAction: null,
    ),
  );

  @override
  Project itemFromJson(Map<String, dynamic> json) => Project.fromJson(json);

  @override
  List<String> getSearchFields(Project project) => [
        project.ref.toLowerCase(),
        project.title.toLowerCase(),
        (project.thirdPartyName ?? '').toLowerCase(),
        (project.description ?? '').toLowerCase(),
      ];

  @override
  int? getStatusValue(Project project) => project.status;

  @override
  Widget buildItemCard(BuildContext context, Project project, VoidCallback onTap, VoidCallback onDelete) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = project.status;

    final statusInfo = _getStatusInfo(status, colorScheme);

    return BaseListCard<Project>(
      item: project,
      onTap: onTap,
      onDelete: onDelete,
      config: BaseListCardConfig(
        title: project.ref,
        subtitle: project.title,
        statusText: statusInfo.text,
        statusIcon: statusInfo.icon,
        statusColor: statusInfo.color,
        statusContainerColor: statusInfo.containerColor,
        statusOnContainerColor: statusInfo.onContainerColor,
        infoRows: [
          InfoRowData(icon: Icons.business_outlined, label: 'Cliente', value: project.thirdPartyName ?? '—', iconColor: colorScheme.primary),
          InfoRowData(icon: Icons.calendar_today_outlined, label: 'Inicio', value: _formatDate(project.dateStart), iconColor: colorScheme.secondary),
          InfoRowData(icon: Icons.calendar_today, label: 'Fin', value: _formatDate(project.dateEnd), iconColor: colorScheme.tertiary),
          InfoRowData(icon: statusInfo.icon, label: 'Estado', value: statusInfo.text, iconColor: statusInfo.color),
        ],
        note: project.description?.isNotEmpty == true ? project.description : null,
      ),
    );
  }

  @override
  Future<void> onCreatePressed(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProjectFormScreen()),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRawItems(DolibarrService service, String apiKey) =>
      service.getProjects(apiKey);

  @override
  int? getItemId(Project project) => project.id;

  @override
  String getItemDisplayName(Project project) => project.title;

  @override
  Future<void> deleteFromApi(int id, DolibarrService service, String apiKey) =>
      service.deleteProject(id, apiKey);

  @override
  Future<void> navigateToDetail(BuildContext context, Project item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProjectFormScreen(project: item)),
    );
  }

  @override
  int compareDates(Project a, Project b) {
    final dateA = a.dateStart != null ? DateTime.tryParse(a.dateStart!) : null;
    final dateB = b.dateStart != null ? DateTime.tryParse(b.dateStart!) : null;
    if (dateA != null && dateB != null) return dateA.compareTo(dateB);
    if (dateA != null) return -1;
    if (dateB != null) return 1;
    return 0;
  }

  @override
  int compareReferences(Project a, Project b) => a.ref.compareTo(b.ref);

  @override
  int compareNames(Project a, Project b) => a.title.compareTo(b.title);

  // Helpers de estado y formato
  _StatusInfo _getStatusInfo(int? status, ColorScheme colorScheme) {
    switch (status) {
      case 0:
        return _StatusInfo(
          text: 'Borrador',
          icon: Icons.edit_outlined,
          color: colorScheme.secondary,
          containerColor: colorScheme.secondaryContainer,
          onContainerColor: colorScheme.onSecondaryContainer,
        );
      case 1:
        return _StatusInfo(
          text: 'En curso',
          icon: Icons.play_circle_outline,
          color: colorScheme.primary,
          containerColor: colorScheme.primaryContainer,
          onContainerColor: colorScheme.onPrimaryContainer,
        );
      case 2:
        return _StatusInfo(
          text: 'Cerrado',
          icon: Icons.check_circle_outline,
          color: colorScheme.tertiary,
          containerColor: colorScheme.tertiaryContainer,
          onContainerColor: colorScheme.onTertiaryContainer,
        );
      case 3:
        return _StatusInfo(
          text: 'Cancelado',
          icon: Icons.cancel_outlined,
          color: colorScheme.error,
          containerColor: colorScheme.errorContainer,
          onContainerColor: colorScheme.onErrorContainer,
        );
      default:
        return _StatusInfo(
          text: 'Desconocido',
          icon: Icons.help_outline,
          color: colorScheme.outline,
          containerColor: colorScheme.surfaceContainerHighest,
          onContainerColor: colorScheme.onSurfaceVariant,
        );
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}

class _StatusInfo {
  final String text;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final Color onContainerColor;
  _StatusInfo({required this.text, required this.icon, required this.color, required this.containerColor, required this.onContainerColor});
}