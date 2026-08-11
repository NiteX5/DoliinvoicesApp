import 'package:flutter/material.dart';

/// Fila de información reutilizable para mostrar un icono, etiqueta y valor.
/// Usado en tarjetas de lista (facturas, proveedores, proyectos).
class InfoRow extends StatelessWidget {
  /// Icono a mostrar a la izquierda de la etiqueta.
  final IconData icon;

  /// Etiqueta descriptiva (ej: 'Proveedor', 'Fecha', 'Total').
  final String label;

  /// Valor a mostrar (ej: nombre del proveedor, fecha formateada, monto).
  final String value;

  /// Color del icono y la etiqueta. Por defecto usa el color primario del tema.
  final Color iconColor;

  /// Si true, destaca el valor con color primario y peso de fuente mayor.
  final bool isHighlighted;

  /// Crea una fila de información.
  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icono + Etiqueta
        Row(
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Valor
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            color: isHighlighted ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            fontSize: isHighlighted ? 15 : 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}