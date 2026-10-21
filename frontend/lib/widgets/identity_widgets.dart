/// Widgets de identidad compartidos: badge LAN, chips de estado e
/// iconos de estacion de los dispositivos.
library;

import 'package:flutter/material.dart';

import '../core/config/api_config.dart';
import '../core/theme/cauce_colors.dart';
import '../core/theme/cauce_theme.dart';

/// Iconos de estacion disponibles en assets/Iconos_Dispositivos/
/// (orden del manual de marca: VR, Repositorio, Tactil, Audio, AR, Totem).
enum StationKind { vr, repositorio, tactil, audio, ar, totem }

extension StationKindAsset on StationKind {
  String get asset => switch (this) {
        StationKind.vr => 'assets/Iconos_Dispositivos/icono 1.png',
        StationKind.repositorio => 'assets/Iconos_Dispositivos/icono 2.png',
        StationKind.tactil => 'assets/Iconos_Dispositivos/icono 3.png',
        StationKind.audio => 'assets/Iconos_Dispositivos/icono 4.png',
        StationKind.ar => 'assets/Iconos_Dispositivos/icono 5.png',
        StationKind.totem => 'assets/Iconos_Dispositivos/icono 6.png',
      };
}

/// Pill "LAN ACTIVA" presente en todas las referencias.
class LanBadge extends StatelessWidget {
  const LanBadge({super.key, this.compact = false, this.backgroundColor, this.foregroundColor});

  final bool compact;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CauceColors.brown.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PulsingDot(color: CauceColors.success, size: 7),
          const SizedBox(width: 6),
          Text(
            'LAN ACTIVA',
            style: TextStyle(
              fontFamily: CauceTheme.bodyFont,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: foregroundColor ?? CauceColors.darkTeal,
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              '| ${ApiConfig.lanSubnet}',
              style: TextStyle(
                fontFamily: CauceTheme.bodyFont,
                fontSize: 10,
                color: (foregroundColor ?? CauceColors.brown).withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot({required this.color, this.size = 8});

  final Color color;
  final double size;

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_controller),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

/// Estados operativos de dispositivos/mostrados en tarjetas.
enum CauceStatus { online, alert, offline, active }

/// Chip de estado con punto de color, usado en las pantallas visuales.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.status,
    required this.label,
  });

  final CauceStatus status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = switch (status) {
      CauceStatus.online => (CauceColors.teal, Colors.white),
      CauceStatus.alert => (const Color(0xFF8A5A00), CauceColors.peachSurfaceContainerHighest),
      CauceStatus.offline => (CauceColors.maroon, CauceColors.peachErrorContainer),
      CauceStatus.active => (CauceColors.darkTeal, Colors.white),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(color: fg, size: 7),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: CauceTheme.bodyFont,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
