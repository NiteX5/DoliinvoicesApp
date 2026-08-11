import 'package:flutter/material.dart';

/// Configuración para una opción de ordenamiento.
class SortOption {
  /// Valor único (ej: 'date', 'name', 'amount').
  final String value;

  /// Etiqueta visible (ej: 'Fecha', 'Nombre', 'Monto').
  final String label;

  /// Icono de la opción.
  final IconData icon;

  const SortOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

/// Menú desplegable de ordenamiento reutilizable.
class SortMenu extends StatelessWidget {
  /// Campo actualmente seleccionado para ordenar.
  final String currentSortBy;

  /// true = ascendente, false = descendente.
  final bool sortAscending;

  /// Opciones disponibles de ordenamiento.
  final List<SortOption> options;

  /// Callback al seleccionar nueva opción.
  final ValueChanged<String> onSortByChanged;

  /// Callback al invertir orden (misma opción seleccionada).
  final VoidCallback? onToggleOrder;

  const SortMenu({
    super.key,
    required this.currentSortBy,
    required this.sortAscending,
    required this.options,
    required this.onSortByChanged,
    this.onToggleOrder,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopupMenuButton<String>(
      initialValue: currentSortBy,
      onSelected: (value) {
        if (value == currentSortBy) {
          onToggleOrder?.call();
        } else {
          onSortByChanged(value);
        }
      },
      itemBuilder: (context) => options.map((option) {
        final isSelected = currentSortBy == option.value;
        return PopupMenuItem<String>(
          value: option.value,
          child: Row(
            children: [
              Icon(
                option.icon,
                size: 20,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(option.label),
              if (isSelected) ...[
                const Spacer(),
                Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                  color: colorScheme.primary,
                ),
              ],
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              _getCurrentLabel(),
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _getCurrentLabel() {
    final option = options.firstWhere(
      (o) => o.value == currentSortBy,
      orElse: () => options.first,
    );
    return option.label;
  }
}