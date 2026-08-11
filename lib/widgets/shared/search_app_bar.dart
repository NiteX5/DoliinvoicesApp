import 'package:flutter/material.dart';
import 'sort_menu.dart';
import 'filter_chip.dart';

/// Configuración para la barra de búsqueda de una lista.
class SearchAppBarConfig {
  /// Título de la barra (ej: 'Facturas', 'Proveedores', 'Proyectos').
  final String title;

  /// Texto de pista del campo de búsqueda.
  final String searchHint;

  /// Opciones de ordenamiento disponibles.
  final List<SortOption> sortOptions;

  /// Chips de filtro de estado.
  final List<FilterChipConfig> filterChips;

  /// Campo de ordenamiento actual.
  final String currentSortBy;

  /// true = ascendente, false = descendente.
  final bool sortAscending;

  /// Filtro de estado actual (null = todos).
  final int? statusFilter;

  /// Texto de búsqueda actual.
  final String searchQuery;

  /// Total de elementos (sin filtrar).
  final int totalCount;

  /// Elementos filtrados actualmente.
  final int filteredCount;

  const SearchAppBarConfig({
    required this.title,
    required this.searchHint,
    required this.sortOptions,
    required this.filterChips,
    required this.currentSortBy,
    required this.sortAscending,
    required this.statusFilter,
    required this.searchQuery,
    required this.totalCount,
    required this.filteredCount,
  });
}

/// Callbacks para la barra de búsqueda.
class SearchAppBarCallbacks {
  /// Al cambiar texto de búsqueda.
  final ValueChanged<String> onSearchChanged;

  /// Al limpiar búsqueda.
  final VoidCallback onSearchCleared;

  /// Al cambiar ordenamiento.
  final ValueChanged<String> onSortByChanged;

  /// Al invertir orden (misma opción).
  final VoidCallback onToggleSortOrder;

  /// Al cambiar filtro de estado.
  final ValueChanged<int?> onStatusFilterChanged;

  /// Al refrescar (pull-to-refresh).
  final Future<void> Function() onRefresh;

  const SearchAppBarCallbacks({
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onSortByChanged,
    required this.onToggleSortOrder,
    required this.onStatusFilterChanged,
    required this.onRefresh,
  });
}

/// Barra de búsqueda reutilizable con SliverAppBar flotante, contador, ordenamiento y filtros.
class SearchAppBar extends StatelessWidget {
  final SearchAppBarConfig config;
  final SearchAppBarCallbacks callbacks;

  const SearchAppBar({
    super.key,
    required this.config,
    required this.callbacks,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SliverAppBar(
      floating: true,
      snap: true,
      pinned: false,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Text(config.title),
      automaticallyImplyLeading: false,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              // Campo de búsqueda
              TextField(
                onChanged: callbacks.onSearchChanged,
                decoration: InputDecoration(
                  hintText: config.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: config.searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: callbacks.onSearchCleared,
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Contador + Menú ordenamiento
              Row(
                children: [
                  Text(
                    '${config.filteredCount} de ${config.totalCount} ${config.title.toLowerCase()}',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  SortMenu(
                    currentSortBy: config.currentSortBy,
                    sortAscending: config.sortAscending,
                    options: config.sortOptions,
                    onSortByChanged: callbacks.onSortByChanged,
                    onToggleOrder: callbacks.onToggleSortOrder,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chips de filtro horizontales reutilizables.
class FilterChipsBar extends StatelessWidget {
  final List<FilterChipConfig> filterChips;
  final int? selectedFilter;
  final ValueChanged<int?> onFilterChanged;

  const FilterChipsBar({
    super.key,
    required this.filterChips,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filterChips
                .map((chip) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: StatusFilterChip(
                        config: chip,
                        selectedValue: selectedFilter,
                        onSelected: onFilterChanged,
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}