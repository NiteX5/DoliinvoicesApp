import 'package:flutter/material.dart';

/// Configuración para un chip de filtro de estado.
class FilterChipConfig {
  /// Valor del filtro (null = 'Todos').
  final int? value;

  /// Etiqueta visible (ej: 'Activo', 'Pagada', 'Borrador').
  final String label;

  /// Icono del chip.
  final IconData icon;

  /// Color asociado al estado (para badge seleccionado).
  final Color statusColor;

  /// Color de fondo cuando está seleccionado.
  final Color containerColor;

  /// Color del texto/icono cuando está seleccionado.
  final Color onContainerColor;

  const FilterChipConfig({
    required this.value,
    required this.label,
    required this.icon,
    required this.statusColor,
    required this.containerColor,
    required this.onContainerColor,
  });
}

/// Chip de filtro reutilizable para listas con estados (facturas, proveedores, proyectos).
/// Muestra icono, etiqueta y badge circular cuando está seleccionado.
class StatusFilterChip extends StatelessWidget {
  /// Configuración del chip.
  final FilterChipConfig config;

  /// Valor actualmente seleccionado (null = 'Todos').
  final int? selectedValue;

  /// Callback al cambiar selección.
  final ValueChanged<int?> onSelected;

  const StatusFilterChip({
    super.key,
    required this.config,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = selectedValue == config.value;

    return FilterChip(
      selected: isSelected,
      onSelected: (selected) => onSelected(selected ? config.value : null),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: 16,
            color: isSelected
                ? config.statusColor
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(config.label),
        ],
      ),
      avatar: isSelected
          ? CircleAvatar(
              radius: 10,
              backgroundColor: config.statusColor,
              child: Icon(
                config.icon,
                size: 12,
                color: colorScheme.onPrimary,
              ),
            )
          : null,
      showCheckmark: false,
      selectedColor: config.containerColor,
      checkmarkColor: config.onContainerColor,
      labelStyle: TextStyle(
        color: isSelected
            ? config.onContainerColor
            : colorScheme.onSurfaceVariant,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? config.statusColor
            : colorScheme.outlineVariant,
        width: isSelected ? 1.5 : 1,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// Helper para crear chips de filtro "Todos" (sin color de estado).
FilterChipConfig allFilterChipConfig({
  required String label,
  required IconData icon,
  required ColorScheme colorScheme,
}) {
  return FilterChipConfig(
    value: null,
    label: label,
    icon: icon,
    statusColor: colorScheme.primary,
    containerColor: colorScheme.primaryContainer,
    onContainerColor: colorScheme.onPrimaryContainer,
  );
}