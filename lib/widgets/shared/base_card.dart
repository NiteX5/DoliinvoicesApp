import 'package:flutter/material.dart';
import 'info_row.dart';

/// Configuración para una tarjeta de lista base.
class BaseListCardConfig<T> {
  /// Título principal (ej: número de factura, nombre proveedor, referencia proyecto).
  final String title;

  /// Subtítulo opcional (ej: ref. proveedor, contacto).
  final String? subtitle;

  /// Texto del badge de estado (ej: 'Pagada', 'Activo', 'En curso').
  final String statusText;

  /// Icono del badge de estado.
  final IconData statusIcon;

  /// Color del badge de estado.
  final Color statusColor;

  /// Color de fondo del badge.
  final Color statusContainerColor;

  /// Color del texto/icono del badge.
  final Color statusOnContainerColor;

  /// Filas de información a mostrar (icono, etiqueta, valor, color, destacado).
  final List<InfoRowData> infoRows;

  /// Nota opcional al final (ej: nota pública, descripción).
  final String? note;

  const BaseListCardConfig({
    required this.title,
    this.subtitle,
    required this.statusText,
    required this.statusIcon,
    required this.statusColor,
    required this.statusContainerColor,
    required this.statusOnContainerColor,
    required this.infoRows,
    this.note,
  });
}

/// Datos para una fila de InfoRow.
class InfoRowData {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool isHighlighted;

  const InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.isHighlighted = false,
  });
}

/// Tarjeta base reutilizable para listas (facturas, proveedores, proyectos).
/// Incluye encabezado con título, estado, divisor, filas de información y nota opcional.
class BaseListCard<T> extends StatelessWidget {
  final BaseListCardConfig<T> config;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final T item;

  const BaseListCard({
    super.key,
    required this.config,
    required this.onTap,
    this.onDelete,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.1),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Encabezado: título, subtítulo y estado
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.title,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (config.subtitle != null &&
                            config.subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            config.subtitle!,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Badge Status
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: config.statusContainerColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: config.statusColor.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          config.statusIcon,
                          size: 14,
                          color: config.statusOnContainerColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          config.statusText,
                          style: textTheme.labelSmall?.copyWith(
                            color: config.statusOnContainerColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Divider
              Divider(
                height: 1,
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 12),

              // Filas de información
              ...config.infoRows.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return Column(
                  children: [
                    InfoRow(
                      icon: row.icon,
                      label: row.label,
                      value: row.value,
                      iconColor: row.iconColor,
                      isHighlighted: row.isHighlighted,
                    ),
                    if (index < config.infoRows.length - 1)
                      const SizedBox(height: 10),
                  ],
                );
              }),

              // Nota opcional
              if (config.note != null && config.note!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.note_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.note!,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}