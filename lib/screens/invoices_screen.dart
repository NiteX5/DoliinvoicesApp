import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/dolibarr_service.dart';
import '../models/supplier_invoice.dart';
import '../screens/base/base_list_screen.dart';
import '../widgets/shared/base_card.dart';
import '../widgets/shared/sort_menu.dart';
import '../widgets/shared/filter_chip.dart';
import 'invoice_form_screen.dart';

/// Pantalla de facturas de proveedores usando BaseListScreen para eliminar duplicación.
class InvoicesScreen extends BaseListScreen<SupplierInvoice> {
  InvoicesScreen({super.key});

  // Mapas de consulta para completar nombres de proveedor y proyecto
  final Map<String, String> _supplierMap = {};
  final Map<String, String> _projectMap = {};

  @override
  BaseListScreenConfig<SupplierInvoice> get config => BaseListScreenConfig(
    title: 'Facturas',
    searchHint: 'Buscar por referencia, proveedor, proyecto...',
    sortOptions: [
      SortOption(value: 'date', label: 'Fecha', icon: Icons.calendar_today),
      SortOption(value: 'amount', label: 'Monto', icon: Icons.attach_money),
      SortOption(value: 'reference', label: 'Referencia', icon: Icons.receipt),
      SortOption(value: 'supplier', label: 'Proveedor', icon: Icons.business),
    ],
    filterChips: [
      FilterChipConfig(value: null, label: 'Todos', icon: Icons.list_alt, statusColor: Colors.blue, containerColor: Colors.blue, onContainerColor: Colors.white),
      FilterChipConfig(value: 0, label: 'Borrador', icon: Icons.edit_outlined, statusColor: Colors.orange, containerColor: Colors.orange, onContainerColor: Colors.white),
      FilterChipConfig(value: 1, label: 'Validada', icon: Icons.verified_outlined, statusColor: Colors.teal, containerColor: Colors.teal, onContainerColor: Colors.white),
      FilterChipConfig(value: 2, label: 'Pagada', icon: Icons.check_circle_outline, statusColor: Colors.green, containerColor: Colors.green, onContainerColor: Colors.white),
    ],
    defaultSortBy: 'date',
    defaultSortAscending: false,
    emptyState: EmptyStateConfig(
      icon: Icons.receipt_long,
      title: 'No hay facturas',
      subtitle: 'Comienza creando tu primera factura',
      actionLabel: 'Crear Factura',
      onAction: null,
    ),
  );

  @override
  SupplierInvoice itemFromJson(Map<String, dynamic> json) => SupplierInvoice.fromJson(json);

  @override
  List<String> getSearchFields(SupplierInvoice invoice) => [
        invoice.ref.toLowerCase(),
        (invoice.supplierName ?? '').toLowerCase(),
        (invoice.refSupplier ?? '').toLowerCase(),
        (invoice.projectName ?? '').toLowerCase(),
        (invoice.notePublic ?? '').toLowerCase(),
      ];

  @override
  int? getStatusValue(SupplierInvoice invoice) => invoice.status;

  @override
  Widget buildItemCard(BuildContext context, SupplierInvoice invoice, VoidCallback onTap, VoidCallback onDelete) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = invoice.status;

    final statusInfo = _getStatusInfo(status, colorScheme);

    return BaseListCard<SupplierInvoice>(
      item: invoice,
      onTap: onTap,
      onDelete: onDelete,
      config: BaseListCardConfig(
        title: invoice.ref,
        subtitle: invoice.refSupplier?.isNotEmpty == true ? 'Ref. proveedor: ${invoice.refSupplier}' : null,
        statusText: statusInfo.text,
        statusIcon: statusInfo.icon,
        statusColor: statusInfo.color,
        statusContainerColor: statusInfo.containerColor,
        statusOnContainerColor: statusInfo.onContainerColor,
        infoRows: [
          InfoRowData(icon: Icons.business_outlined, label: 'Proveedor', value: invoice.supplierName ?? '—', iconColor: colorScheme.primary),
          InfoRowData(icon: Icons.calendar_today_outlined, label: 'Fecha', value: _formatDate(invoice.date), iconColor: colorScheme.secondary),
          InfoRowData(icon: Icons.folder_outlined, label: 'Proyecto', value: invoice.projectName ?? '—', iconColor: colorScheme.tertiary),
          InfoRowData(icon: Icons.attach_money_outlined, label: 'Total', value: _formatAmount(invoice.totalTtc), iconColor: colorScheme.primary, isHighlighted: true),
          if (invoice.totalVat != null && invoice.totalVat! > 0)
            InfoRowData(icon: Icons.receipt_outlined, label: 'Base imponible', value: invoice.totalHt != null ? _formatAmount(invoice.totalHt) : '—', iconColor: colorScheme.outline),
          if (invoice.totalVat != null && invoice.totalVat! > 0)
            InfoRowData(icon: Icons.percent_outlined, label: 'IVA', value: _formatAmount(invoice.totalVat), iconColor: colorScheme.outline),
        ],
        note: invoice.notePublic?.isNotEmpty == true ? invoice.notePublic : null,
      ),
    );
  }

  @override
  Future<void> onCreatePressed(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const InvoiceFormScreen()),
    );
  }

  @override
  Future<void> loadAdditionalData(DolibarrService service, String apiKey) async {
    final suppliersList = await service.getSuppliers(apiKey);
    final projectsList = await service.getProjects(apiKey);

    _supplierMap.clear();
    _projectMap.clear();
    for (final s in suppliersList) {
      if (s['id'] != null) {
        _supplierMap[s['id'].toString()] = s['name']?.toString() ?? s['label']?.toString() ?? '';
      }
    }
    for (final p in projectsList) {
      if (p['id'] != null) {
        _projectMap[p['id'].toString()] = p['title']?.toString() ?? p['label']?.toString() ?? '';
      }
    }
  }

  @override
  SupplierInvoice enrichItem(SupplierInvoice invoice) {
    var enriched = invoice;
    if ((enriched.supplierName ?? '').isEmpty && enriched.fkSoc != null) {
      final name = _supplierMap[enriched.fkSoc.toString()];
      if (name != null && name.isNotEmpty) {
        enriched = enriched.copyWith(supplierName: name);
      }
    }
    if ((enriched.projectName ?? '').isEmpty && enriched.fkProject != null) {
      final name = _projectMap[enriched.fkProject.toString()];
      if (name != null && name.isNotEmpty) {
        enriched = enriched.copyWith(projectName: name);
      }
    }
    return enriched;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRawItems(DolibarrService service, String apiKey) =>
      service.getSupplierInvoices(apiKey);

  @override
  int? getItemId(SupplierInvoice invoice) => invoice.id;

  @override
  String getItemDisplayName(SupplierInvoice invoice) => invoice.ref;

  @override
  Future<void> deleteFromApi(int id, DolibarrService service, String apiKey) =>
      service.deleteSupplierInvoice(id, apiKey);

  @override
  Future<void> navigateToDetail(BuildContext context, SupplierInvoice item) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => InvoiceFormScreen(invoice: item)),
    );
  }

  @override
  int compareDates(SupplierInvoice a, SupplierInvoice b) {
    final dateA = a.date != null ? DateTime.tryParse(a.date!) : null;
    final dateB = b.date != null ? DateTime.tryParse(b.date!) : null;
    if (dateA != null && dateB != null) return dateA.compareTo(dateB);
    if (dateA != null) return -1;
    if (dateB != null) return 1;
    return 0;
  }

  @override
  int compareAmounts(SupplierInvoice a, SupplierInvoice b) =>
      (a.totalTtc ?? 0).compareTo(b.totalTtc ?? 0);

  @override
  int compareReferences(SupplierInvoice a, SupplierInvoice b) => a.ref.compareTo(b.ref);

  @override
  int compareNames(SupplierInvoice a, SupplierInvoice b) =>
      (a.supplierName ?? '').compareTo(b.supplierName ?? '');

  // Helpers de estado
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
          text: 'Validada',
          icon: Icons.verified_outlined,
          color: colorScheme.tertiary,
          containerColor: colorScheme.tertiaryContainer,
          onContainerColor: colorScheme.onTertiaryContainer,
        );
      case 2:
        return _StatusInfo(
          text: 'Pagada',
          icon: Icons.check_circle_outline,
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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM/yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _formatAmount(double? amount) {
    if (amount == null) return '—';
    final formatter = NumberFormat.currency(locale: 'es_ES', symbol: '\$ ', decimalDigits: 2);
    return formatter.format(amount);
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