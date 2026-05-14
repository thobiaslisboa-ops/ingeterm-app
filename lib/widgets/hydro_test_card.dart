import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/hydro_test_model.dart';

class HydroTestCard extends StatelessWidget {
  final HydroTest test;
  final VoidCallback onTap;

  const HydroTestCard({
    super.key,
    required this.test,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ResultIcon(resultado: test.resultado),
              const SizedBox(width: 14),
              Expanded(child: _CardBody(test: test)),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ícono de resultado a la izquierda ─────────────────────────────────────

class _ResultIcon extends StatelessWidget {
  final HydroTestResult? resultado;
  const _ResultIcon({required this.resultado});

  @override
  Widget build(BuildContext context) {
    final color = resultado?.color ?? Colors.grey;
    final icon = resultado?.icon ?? Icons.help_outline;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

// ── Cuerpo de la card ─────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final HydroTest test;
  const _CardBody({required this.test});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(test.fechaPrueba);
    final numLabel = test.numeroPrueba != null
        ? 'Prueba #${test.numeroPrueba}'
        : 'Prueba Hidrostática';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              numLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (test.certificadoGenerado) ...[
              const SizedBox(width: 8),
              const _CertBadge(),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            if (test.presionPrueba != null)
              _InfoChip(
                label:
                    '${test.presionPrueba!.toStringAsFixed(1)} ${test.unidadPresion}',
                icon: Icons.compress,
              ),
            if (test.duracionMinutos != null)
              _InfoChip(
                label: '${test.duracionMinutos} min',
                icon: Icons.timer_outlined,
              ),
            if (test.resultado != null)
              _ResultChip(resultado: test.resultado!),
          ],
        ),
      ],
    );
  }
}

// ── Subwidgets privados ────────────────────────────────────────────────────

class _CertBadge extends StatelessWidget {
  const _CertBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 12, color: Colors.blue[700]),
          const SizedBox(width: 3),
          Text(
            'Certificado',
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _InfoChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[600]),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }
}

class _ResultChip extends StatelessWidget {
  final HydroTestResult resultado;
  const _ResultChip({required this.resultado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: resultado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        resultado.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: resultado.color,
        ),
      ),
    );
  }
}
