import 'package:flutter/material.dart';

/// Tarjeta esqueleto (skeleton loader) genérica para listas.
/// Muestra placeholders animados mientras cargan los datos reales.
class SkeletonCard extends StatelessWidget {
  /// Número de filas de información a mostrar en el esqueleto.
  final int infoRows;

  /// Si true, muestra una fila extra para descripción/nota.
  final bool showDescription;

  /// Altura de la tarjeta.
  final double? height;

  const SkeletonCard({
    super.key,
    this.infoRows = 3,
    this.showDescription = false,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Esqueleto del encabezado (título y estado)
            const Row(
              children: [
                Expanded(
                  child: _SkeletonLine(width: double.infinity, height: 16),
                ),
                SizedBox(width: 12),
                _SkeletonLine(width: 80, height: 24, borderRadius: 12),
              ],
            ),
            const SizedBox(height: 16),
            // Filas de información
            ...List.generate(infoRows, (rowIndex) {
              return Padding(
                padding: EdgeInsets.only(bottom: rowIndex == infoRows - 1 ? 0 : 10),
                child: const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonLine(width: 60, height: 12),
                          SizedBox(height: 4),
                          _SkeletonLine(width: double.infinity, height: 14),
                        ],
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SkeletonLine(width: 50, height: 12),
                          SizedBox(height: 4),
                          _SkeletonLine(width: double.infinity, height: 14),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Descripción opcional
            if (showDescription) ...[
              const SizedBox(height: 12),
              const _SkeletonLine(width: double.infinity, height: 40, borderRadius: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista de esqueletos para mostrar mientras carga.
class SkeletonList extends StatelessWidget {
  final int itemCount;
  final int infoRows;
  final bool showDescription;

  const SkeletonList({
    super.key,
    this.itemCount = 6,
    this.infoRows = 3,
    this.showDescription = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => SkeletonCard(
        infoRows: infoRows,
        showDescription: showDescription,
      ),
    );
  }
}

/// Línea de esqueleto individual (placeholder animado).
class _SkeletonLine extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const _SkeletonLine({
    required this.width,
    required this.height,
    this.borderRadius = 4,
  });

  @override
  State<_SkeletonLine> createState() => _SkeletonLineState();
}

class _SkeletonLineState extends State<_SkeletonLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest
                .withValues(alpha: _animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}