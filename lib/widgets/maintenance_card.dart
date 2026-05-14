// lib/widgets/maintenance_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/maintenance_model.dart';

class MaintenanceCard extends StatelessWidget {
  final MaintenanceModel maintenance;
  final String? clienteNombre;
  final String? equipoNombre;
  final VoidCallback? onTap;

  const MaintenanceCard({
    super.key,
    required this.maintenance,
    this.clienteNombre,
    this.equipoNombre,
    this.onTap,
  });

  // ── Colores por estado ──────────────────────────────────────────────────────

  static Color estadoColor(EstadoMantencion estado) {
    switch (estado) {
      case EstadoMantencion.programada:
        return const Color(0xFF1A5DB5);
      case EstadoMantencion.enEjecucion:
        return const Color(0xFFE8690A);
      case EstadoMantencion.finalizada:
        return const Color(0xFF4CAF50);
      case EstadoMantencion.cerrada:
        return const Color(0xFF9E9E9E);
    }
  }

  static IconData estadoIcon(EstadoMantencion estado) {
    switch (estado) {
      case EstadoMantencion.programada:
        return Icons.calendar_today;
      case EstadoMantencion.enEjecucion:
        return Icons.engineering;
      case EstadoMantencion.finalizada:
        return Icons.check_circle;
      case EstadoMantencion.cerrada:
        return Icons.lock_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = estadoColor(maintenance.estado);
    final duracion = maintenance.duracionMinutos;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3), width: 1),
      ),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Fila superior: número + estado chip ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A5DB5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'OT-${maintenance.numeroOrden.toString().padLeft(4, '0')}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A5DB5),
                      ),
                    ),
                  ),
                  const Spacer(),
                  _EstadoChip(estado: maintenance.estado),
                ],
              ),
              const SizedBox(height: 10),
              // ── Título ──
              Text(
                maintenance.titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // ── Cliente / Equipo ──
              if (equipoNombre != null || clienteNombre != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [
                          if (clienteNombre != null) clienteNombre!,
                          if (equipoNombre != null) equipoNombre!,
                        ].join(' → '),
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (maintenance.tiposTrabajo.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: maintenance.tiposTrabajo
                      .map((t) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A5DB5)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: const Color(0xFF1A5DB5)
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF1A5DB5),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 8),
              // ── Fila inferior: fecha + duración + % items ──
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 13, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd/MM/yyyy').format(maintenance.creadoEn),
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  if (duracion != null) ...[
                    const SizedBox(width: 12),
                    Icon(Icons.timer_outlined,
                        size: 13, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDuracion(duracion),
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                  const Spacer(),
                  if (maintenance.totalItems > 0)
                    _ProgressBadge(
                      completados: maintenance.itemsCompletados,
                      total: maintenance.totalItems,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuracion(int minutos) {
    if (minutos < 60) return '${minutos}min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}

// ── _EstadoChip ───────────────────────────────────────────────────────────────

class _EstadoChip extends StatelessWidget {
  final EstadoMantencion estado;

  const _EstadoChip({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = MaintenanceCard.estadoColor(estado);
    final icon = MaintenanceCard.estadoIcon(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            estado.label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── _ProgressBadge ────────────────────────────────────────────────────────────

class _ProgressBadge extends StatelessWidget {
  final int completados;
  final int total;

  const _ProgressBadge({required this.completados, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (completados / total * 100).round();
    final color = pct == 100 ? const Color(0xFF4CAF50) : Colors.grey[600]!;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.checklist, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          '$completados/$total ($pct%)',
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
