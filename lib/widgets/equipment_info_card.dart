import 'package:flutter/material.dart';
import '../models/equipment_model.dart';

/// Card resumen de equipo — para uso en listas y dashboards.
/// Muestra: nombre, tipo, estado, TAG, presión de operación y ubicación.
class EquipmentInfoCard extends StatelessWidget {
  final Equipment equipment;
  final VoidCallback? onTap;
  final List<PopupMenuEntry<String>> menuItems;
  final void Function(String)? onMenuSelected;

  const EquipmentInfoCard({
    super.key,
    required this.equipment,
    this.onTap,
    this.menuItems = const [],
    this.onMenuSelected,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = equipment.status.color;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: statusColor.withValues(alpha: 0.25)),
      ),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Ícono de tipo con color de estado
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(equipment.type.icon, color: statusColor, size: 24),
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
                            equipment.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (equipment.tag?.isNotEmpty == true) ...[
                          const SizedBox(width: 6),
                          _TagChip(tag: equipment.tag!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Tipo + Estado
                    Row(
                      children: [
                        Text(
                          equipment.type.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(status: equipment.status),
                      ],
                    ),
                    // Presión + Ubicación
                    if (equipment.operatingPressure != null ||
                        _locationText(equipment).isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (equipment.operatingPressure != null) ...[
                            Icon(Icons.speed,
                                size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Text(
                              '${equipment.operatingPressure!.toStringAsFixed(1)} bar',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                            ),
                            const SizedBox(width: 10),
                          ],
                          if (_locationText(equipment).isNotEmpty) ...[
                            Icon(Icons.location_on,
                                size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _locationText(equipment),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (menuItems.isNotEmpty)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: onMenuSelected,
                  itemBuilder: (_) => menuItems,
                )
              else
                const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  static String _locationText(Equipment e) {
    final parts = [e.plant, e.area, e.line]
        .where((p) => p?.isNotEmpty == true)
        .map((p) => p!)
        .toList();
    if (parts.isNotEmpty) return parts.join(' › ');
    return e.locationDescription ?? '';
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
  final EquipmentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 11, color: status.color),
          const SizedBox(width: 3),
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
