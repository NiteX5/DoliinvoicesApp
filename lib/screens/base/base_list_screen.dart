import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/dolibarr_service.dart';
import '../../widgets/shared/search_app_bar.dart';
import '../../widgets/shared/filter_chip.dart';
import '../../widgets/shared/sort_menu.dart';
import '../../widgets/shared/skeleton_loader.dart';

/// Configuración genérica para una pantalla de lista.
class BaseListScreenConfig<T> {
  /// Título de la pantalla (ej: 'Facturas', 'Proveedores', 'Proyectos').
  final String title;

  /// Pista del campo de búsqueda.
  final String searchHint;

  /// Opciones de ordenamiento.
  final List<SortOption> sortOptions;

  /// Chips de filtro de estado.
  final List<FilterChipConfig> filterChips;

  /// Campo de ordenamiento por defecto.
  final String defaultSortBy;

  /// Orden por defecto (true = ascendente).
  final bool defaultSortAscending;

  /// Configuración del estado vacío.
  final EmptyStateConfig emptyState;

  const BaseListScreenConfig({
    required this.title,
    required this.searchHint,
    required this.sortOptions,
    required this.filterChips,
    required this.defaultSortBy,
    required this.defaultSortAscending,
    required this.emptyState,
  });
}

/// Configuración para el estado vacío.
class EmptyStateConfig {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateConfig({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });
}

/// Callback genérico para convertir JSON a modelo T.
typedef ItemFromJson<T> = T Function(Map<String, dynamic> json);

/// Callback para obtener campos de búsqueda de un item.
typedef SearchFieldsGetter<T> = List<String> Function(T item);

/// Callback para obtener valor de estado de un item (para filtro).
typedef StatusGetter<T> = int? Function(T item);

/// Callback para construir la tarjeta personalizada de un item.
typedef ItemCardBuilder<T> = Widget Function(
  BuildContext context,
  T item,
  VoidCallback onTap,
  VoidCallback onDelete,
);

/// Callback para crear nuevo item (navegar a formulario).
typedef OnCreatePressed = Future<void> Function(BuildContext context);

/// Clase base para pantallas de lista con búsqueda, filtrado, ordenamiento y pull-to-refresh.
///
/// Elimina duplicación entre InvoicesScreen, SuppliersScreen, ProjectsScreen.
///
/// Uso:
/// ```dart
/// class InvoicesScreen extends BaseListScreen<SupplierInvoice> {
///   // Implementar métodos abstractos
/// }
/// ```
abstract class BaseListScreen<T> extends StatefulWidget {
  const BaseListScreen({super.key});

  /// Configuración de la pantalla (título, hints, opciones, etc.).
  BaseListScreenConfig<T> get config;

  /// Convierte JSON crudo de Dolibarr a modelo T.
  T itemFromJson(Map<String, dynamic> json);

  /// Retorna lista de campos string para búsqueda en el item.
  List<String> getSearchFields(T item);

  /// Retorna el valor de estado del item (para filtro de chips).
  int? getStatusValue(T item);

  /// Construye la tarjeta personalizada para el item.
  Widget buildItemCard(BuildContext context, T item, VoidCallback onTap, VoidCallback onDelete);

  /// Navega al formulario de creación. Recibe context para navegación.
  Future<void> onCreatePressed(BuildContext context);

  /// Opcional: Carga datos adicionales (proveedores, proyectos) para enriquecer items.
  Future<void> loadAdditionalData(DolibarrService service, String apiKey) async {}

  /// Opcional: Enriquece un item con datos adicionales.
  T enrichItem(T item) => item;

  /// Obtiene datos crudos de la API (subclases implementan).
  Future<List<Map<String, dynamic>>> fetchRawItems(DolibarrService service, String apiKey);

  /// Obtiene ID del item para eliminación.
  int? getItemId(T item);

  /// Obtiene nombre legible del item para diálogos.
  String getItemDisplayName(T item);

  /// Elimina item via API.
  Future<void> deleteFromApi(int id, DolibarrService service, String apiKey);

  /// Navega a detalle/edición del item (opcional).
  Future<void> navigateToDetail(BuildContext context, T item) async {}

  // Métodos de comparación - subclases pueden sobrescribir
  int compareDates(T a, T b) => 0;
  int compareAmounts(T a, T b) => 0;
  int compareReferences(T a, T b) => 0;
  int compareNames(T a, T b) => 0;
  int compareCustomField(T a, T b, String field) => 0;

  @override
  State<BaseListScreen<T>> createState() => _BaseListScreenState<T>();
}

class _BaseListScreenState<T> extends State<BaseListScreen<T>> {
  late List<T> _items;
  late List<T> _filteredItems;
  bool _isLoading = true;
  String? _errorMessage;
  bool _initialized = false;

  late DolibarrService _dolibarrService;
  late String _apiKey;

  // Estado de búsqueda y filtros
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int? _statusFilter;
  String _sortBy = '';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchControllerChanged);
    _sortBy = widget.config.defaultSortBy;
    _sortAscending = widget.config.defaultSortAscending;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchControllerChanged() {
    _onSearchChanged(_searchController.text);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final authService = context.read<AuthService>();
    _dolibarrService = context.read<DolibarrService>();
    _apiKey = authService.apiKey!;
    _initialized = true;
    loadData();
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase().trim();
      applyFiltersAndSort();
    });
  }

  /// Método público para que subclases puedan forzar recarga.
  Future<void> loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rawItems = await widget.fetchRawItems(_dolibarrService, _apiKey);
      await widget.loadAdditionalData(_dolibarrService, _apiKey);

      setState(() {
        _items = rawItems
            .map((json) => widget.itemFromJson(json))
            .map(widget.enrichItem)
            .toList();
        applyFiltersAndSort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al cargar ${widget.config.title.toLowerCase()}: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> refresh() => loadData();

  void applyFiltersAndSort() {
    var filtered = _items.where((item) {
      // Filtro de búsqueda
      if (_searchQuery.isNotEmpty) {
        final fields = widget.getSearchFields(item);
        if (!fields.any((f) => f.toLowerCase().contains(_searchQuery))) {
          return false;
        }
      }

      // Filtro de estado
      if (_statusFilter != null && widget.getStatusValue(item) != _statusFilter) {
        return false;
      }

      return true;
    }).toList();

    // Ordenamiento
    filtered.sort((a, b) {
      int comparison = 0;
      switch (_sortBy) {
        case 'date':
          comparison = compareDates(a, b);
          break;
        case 'amount':
          comparison = compareAmounts(a, b);
          break;
        case 'reference':
        case 'ref':
          comparison = widget.compareReferences(a, b);
          break;
        case 'name':
        case 'title':
        case 'supplier':
          comparison = widget.compareNames(a, b);
          break;
        case 'city':
        case 'giro':
          comparison = widget.compareCustomField(a, b, _sortBy);
          break;
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() {
      _filteredItems = filtered;
    });
  }

  // Métodos de comparación por defecto (subclases sobrescriben en widget)
  int compareDates(T a, T b) => 0;
  int compareAmounts(T a, T b) => 0;
  int compareReferences(T a, T b) => 0;
  int compareNames(T a, T b) => 0;
  int compareCustomField(T a, T b, String field) => 0;

  Future<void> deleteItem(T item) async {
    final itemId = widget.getItemId(item);
    if (itemId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Eliminar ${widget.config.title.replaceAll('s', '')}'),
        content: Text('¿Estás seguro de eliminar ${widget.getItemDisplayName(item)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await widget.deleteFromApi(itemId, _dolibarrService, _apiKey);
        if (!mounted) return;
        await loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    '${widget.config.title.replaceAll('s', '')} eliminado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  /// Subclases pueden sobrescribir para navegar a edición.
  Future<void> navigateToDetail(T item) async {
    await widget.navigateToDetail(context, item);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? buildLoadingState()
          : _errorMessage != null
              ? buildErrorState(context)
              : _filteredItems.isEmpty
                  ? buildEmptyState(context)
                  : buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => widget.onCreatePressed(context),
        icon: const Icon(Icons.add),
        label: Text('Nuevo ${widget.config.title.replaceAll('s', '')}'),
      ),
    );
  }

  Widget buildLoadingState() {
    return const SkeletonList(
      itemCount: 6,
      infoRows: 3,
      showDescription: true,
    );
  }

  Widget buildErrorState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error al cargar ${widget.config.title.toLowerCase()}',
              style: textTheme.headlineSmall?.copyWith(color: colorScheme.error),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSearchOrFilter = _searchQuery.isNotEmpty || _statusFilter != null;
    final config = widget.config.emptyState;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasSearchOrFilter ? Icons.search_off : config.icon,
              size: 64,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              hasSearchOrFilter
                  ? 'No se encontraron ${widget.config.title.toLowerCase()}'
                  : config.title,
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              hasSearchOrFilter
                  ? 'Intenta cambiar los filtros o la búsqueda'
                  : config.subtitle,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (!hasSearchOrFilter && config.actionLabel != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: config.onAction,
                icon: const Icon(Icons.add),
                label: Text(config.actionLabel!),
              ),
            ] else if (hasSearchOrFilter) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _statusFilter = null);
                  applyFiltersAndSort();
                },
                icon: const Icon(Icons.clear_all),
                label: const Text('Limpiar filtros'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildList() {
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        slivers: [
          SearchAppBar(
            config: SearchAppBarConfig(
              title: widget.config.title,
              searchHint: widget.config.searchHint,
              sortOptions: widget.config.sortOptions,
              filterChips: widget.config.filterChips,
              currentSortBy: _sortBy,
              sortAscending: _sortAscending,
              statusFilter: _statusFilter,
              searchQuery: _searchQuery,
              totalCount: _items.length,
              filteredCount: _filteredItems.length,
            ),
            callbacks: SearchAppBarCallbacks(
              onSearchChanged: _onSearchChanged,
              onSearchCleared: () {
                _searchController.clear();
              },
              onSortByChanged: (value) {
                setState(() {
                  if (_sortBy == value) {
                    _sortAscending = !_sortAscending;
                  } else {
                    _sortBy = value;
                    _sortAscending = value == 'date' || value == 'ref' ? false : true;
                  }
                  applyFiltersAndSort();
                });
              },
              onToggleSortOrder: () {
                setState(() {
                  _sortAscending = !_sortAscending;
                  applyFiltersAndSort();
                });
              },
              onStatusFilterChanged: (value) {
                setState(() {
                  _statusFilter = value;
                  applyFiltersAndSort();
                });
              },
              onRefresh: refresh,
            ),
          ),
          FilterChipsBar(
            filterChips: widget.config.filterChips,
            selectedFilter: _statusFilter,
            onFilterChanged: (value) {
              setState(() {
                _statusFilter = value;
                applyFiltersAndSort();
              });
            },
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverList.separated(
              itemCount: _filteredItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = _filteredItems[index];
                return widget.buildItemCard(
                  context,
                  item,
                  () async {
                    await navigateToDetail(item);
                    refresh();
                  },
                  () => deleteItem(item),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}