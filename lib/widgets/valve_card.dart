import 'package:flutter/material.dart';
import '../models/valve_model.dart';

/// Tarjeta de válvula para usar en listas.
/// Verde = operativa / Naranja = mantención / Azul = bodega / Rojo = reemplazo
class ValveCard extends StatelessWidget {
  final Valve valve;
  final VoidCallback? onTap;
  final List<PopupMenuEntry<String>> menuItems;
  final void Function(String)? onMenuSelected;

  const ValveCard({
    super.key,
    required this.valve,
    this.onTap,
    this.menuItems = const [],
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final color = valve.status.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Ícono con color de estado
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.plumbing, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre + TAG
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            valve.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (valve.tag != null && valve.tag!.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          _TagChip(tag: valve.tag!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Estado + tipo
                    Row(
                      children: [
                        _StatusChip(status: valve.status),
                        const SizedBox(width: 8),
                        Text(
                          valve.valveType.label,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    // Seteo vs Corte
                    if (valve.setPoint != null || valve.cutPoint != null) ...[
                      const SizedBox(height: 4),
                      _PointsRow(valve: valve),
                    ],
                  ],
                ),
              ),
              if (menuItems.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: onMenuSelected,
                  itemBuilder: (_) => menuItems,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String tag;
  const _TagChip({required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ValveStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(
              color: status.color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PointsRow extends StatelessWidget {
  final Valve valve;
  const _PointsRow({required this.valve});

  @override
  Widget build(BuildContext context) {
    final unit = (valve.unit?.isNotEmpty == true) ? ' ${valve.unit}' : '';
    return Wrap(
      spacing: 12,
      children: [
        if (valve.setPoint != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.tune, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(
                'Seteo: ${valve.setPoint!.toStringAsFixed(1)}$unit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
        if (valve.cutPoint != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compress, size: 12, color: Colors.grey.shade500),
              const SizedBox(width: 3),
              Text(
                'Corte: ${valve.cutPoint!.toStringAsFixed(1)}$unit',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
      ],
    );
  }
}
