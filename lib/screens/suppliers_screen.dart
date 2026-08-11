import 'package:flutter/material.dart';
import '../services/dolibarr_service.dart';
import '../models/supplier.dart';
import '../screens/base/base_list_screen.dart';
import '../widgets/shared/base_card.dart';
import '../widgets/shared/sort_menu.dart';
import '../widgets/shared/filter_chip.dart';
import 'supplier_form_screen.dart';

/// Pantalla de proveedores usando BaseListScreen para eliminar duplicación.
class SuppliersScreen extends BaseListScreen<Supplier> {
  SuppliersScreen({super.key});

  @override
  BaseListScreenConfig<Supplier> get config => BaseListScreenConfig(
    title: 'Proveedores',
    searchHint: 'Buscar por nombre, RUT, email, ciudad, giro...',
    sortOptions: [
      SortOption(value: 'name', label: 'Nombre', icon: Icons.sort_by_alpha),
      SortOption(value: 'rut', label: 'RUT', icon: Icons.numbers),
      SortOption(value: 'city', label: 'Ciudad', icon: Icons.location_city),
      SortOption(value: 'giro', label: 'Giro', icon: Icons.work_outline),
    ],
    filterChips: [
      FilterChipConfig(value: null, label: 'Todos', icon: Icons.list_alt, statusColor: Colors.blue, containerColor: Colors.blue, onContainerColor: Colors.white),
      FilterChipConfig(value: 1, label: 'Activo', icon: Icons.check_circle_outline, statusColor: Colors.green, containerColor: Colors.green, onContainerColor: Colors.white),
      FilterChipConfig(value: 0, label: 'Inactivo', icon: Icons.block_outlined, statusColor: Colors.red, containerColor: Colors.red, onContainerColor: Colors.white),
    ],
    defaultSortBy: 'name',
    defaultSortAscending: true,
    emptyState: EmptyStateConfig(
      icon: Icons.business_center,
      title: 'No hay proveedores',
      subtitle: 'Comienza agregando tu primer proveedor',
      actionLabel: 'Agregar Proveedor',
      onAction: null,
    ),
  );

  @override
  Supplier itemFromJson(Map<String, dynamic> json) => Supplier.fromJson(json);

  @override
  List<String> getSearchFields(Supplier supplier) => [
        supplier.name.toLowerCase(),
        (supplier.rut ?? '').toLowerCase(),
        (supplier.email ?? '').toLowerCase(),
        (supplier.city ?? '').toLowerCase(),
        (supplier.giro ?? '').toLowerCase(),
      ];

  @override
  int? getStatusValue(Supplier supplier) => supplier.status;

  @override
  Widget buildItemCard(BuildContext context, Supplier supplier, VoidCallback onTap, VoidCallback onDelete) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = supplier.status;

    final statusInfo = _getStatusInfo(status, colorScheme);

    return BaseListCard<Supplier>(
      item: supplier,
      onTap: onTap,
      onDelete: onDelete,
      config: BaseListCardConfig(
        title: supplier.name,
        subtitle: supplier.contactName?.isNotEmpty == true ? supplier.contactName : null,
        statusText: statusInfo.text,
        statusIcon: statusInfo.icon,
        statusColor: statusInfo.color,
        statusContainerColor: statusInfo.containerColor,
        statusOnContainerColor: statusInfo.onContainerColor,
        infoRows: [
          InfoRowData(icon: Icons.badge_outlined, label: 'RUT', value: supplier.rut ?? '—', iconColor: colorScheme.primary),
          InfoRowData(icon: Icons.email_outlined, label: 'Email', value: supplier.email ?? '—', iconColor: colorScheme.secondary),
          InfoRowData(icon: Icons.location_city, label: 'Ciudad', value: supplier.city ?? '—', iconColor: colorScheme.tertiary),
          InfoRowData(icon: Icons.public_outlined, label: 'País', value: supplier.country ?? '—', iconColor: colorScheme.tertiary),
          InfoRowData(icon: Icons.work_outline, label: 'Giro', value: supplier.giro ?? '—', iconColor: colorScheme.primary),
          InfoRowData(icon: Icons.phone_outlined, label: 'Teléfono', value: supplier.phone ?? '—', iconColor: colorScheme.secondary),
        ],
      ),
    );
  }

  @override
  Future<void> onCreatePressed(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SupplierFormScreen()),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRawItems(DolibarrService service, String apiKey) =>
      service.getSuppliers(apiKey);

  @override
  int? getItemId(Supplier supplier) => supplier.id;

  @override
  String getItemDisplayName(Supplier supplier) => supplier.name;

  @override
  Future<void> deleteFromApi(int id, DolibarrService service, String apiKey) =>
      service.deleteSupplier(id, apiKey);

  @override
  Future<void> navigateToDetail(BuildContext context, Supplier item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SupplierFormScreen(supplier: item)),
    );
  }

  @override
  int compareNames(Supplier a, Supplier b) => a.name.compareTo(b.name);

  @override
  int compareCustomField(Supplier a, Supplier b, String field) {
    switch (field) {
      case 'rut':
        return (a.rut ?? '').compareTo(b.rut ?? '');
      case 'city':
        return (a.city ?? '').compareTo(b.city ?? '');
      case 'giro':
        return (a.giro ?? '').compareTo(b.giro ?? '');
      default:
        return 0;
    }
  }

  // Helpers de estado
  _StatusInfo _getStatusInfo(int? status, ColorScheme colorScheme) {
    switch (status) {
      case 0:
        return _StatusInfo(
          text: 'Inactivo',
          icon: Icons.block_outlined,
          color: colorScheme.error,
          containerColor: colorScheme.errorContainer,
          onContainerColor: colorScheme.onErrorContainer,
        );
      case 1:
        return _StatusInfo(
          text: 'Activo',
          icon: Icons.check_circle_outlined,
          color: colorScheme.primary,
          containerColor: colorScheme.primaryContainer,
          onContainerColor: colorScheme.onPrimaryContainer,
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
}

class _StatusInfo {
  final String text;
  final IconData icon;
  final Color color;
  final Color containerColor;
  final Color onContainerColor;
  _StatusInfo({required this.text, required this.icon, required this.color, required this.containerColor, required this.onContainerColor});
}