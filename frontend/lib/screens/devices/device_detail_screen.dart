/// Detalle de dispositivo.
///
/// Los datos del encabezado y la tarjeta de informacion provienen del
/// inventario real ([Device]), refrescado por el sondeo del
/// inventario. El monitor de emision sigue siendo composicion visual
/// de la referencia (el backend aun no expone reproduccion); las
/// acciones remotas de energia (encender/apagar pantalla) si son
/// reales y viajan por el canal WebSocket del dispositivo.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/devices_controller.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/cauce_colors.dart';
import '../../core/theme/cauce_theme.dart';
import '../../models/device.dart';
import '../../widgets/cauce_headers.dart';
import '../../widgets/organic_background.dart';

class DeviceDetailScreen extends StatelessWidget {
  const DeviceDetailScreen({super.key, required this.device});

  /// Dispositivo del inventario recibido desde la lista.
  final Device device;

  void _notAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('El control remoto de dispositivos llega en una fase posterior.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DevicesController>(
      builder: (context, controller, _) {
        final current = _latestFrom(controller);
        return Scaffold(
          backgroundColor: CauceColors.peachSurface,
          body: Stack(
            children: [
              const OrganicBackground(
                topRight: true,
                bottomLeft: true,
                baseColor: CauceColors.peachSurface,
              ),
              Column(
                children: [
                  StackHeader(
                    title: 'Detalle Dispositivo',
                    onAvatarTap: () =>
                        Navigator.of(context).pushNamed('/profile'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(24, 16, 24, 32 + MediaQuery.paddingOf(context).bottom),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TitleBlock(device: current),
                          const SizedBox(height: 16),
                          _StreamMonitorCard(onAction: () => _notAvailable(context)),
                          const SizedBox(height: 16),
                          _TelemetryCard(device: current),
                          const SizedBox(height: 16),
                          _ActionButtons(device: current),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Version mas reciente del dispositivo segun el sondeo del
  /// inventario (mismo ciclo que alimenta la lista). Si el polling
  /// no lo trae, se conserva el snapshot recibido por argumento.
  Device _latestFrom(DevicesController controller) {
    for (final d in controller.devices) {
      if (d.id == device.id) return d;
    }
    return device;
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        device.isOnline ? CauceColors.teal : CauceColors.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                device.name.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: CauceTheme.displayFont,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: CauceColors.maroon,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: CauceColors.cream,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    device.statusLabel,
                    style: TextStyle(
                      fontFamily: CauceTheme.bodyFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: CauceColors.darkTeal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _WsChannelIndicator(connected: device.wsConnected),
        const SizedBox(height: 4),
        Text(
          device.type,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: CauceTheme.bodyFont,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: CauceColors.peachOnSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Indicador del canal WebSocket de playback, debajo del nombre:
/// punto relleno + etiqueta corta. Estado binario, sin animacion.
/// Independiente del chip de conectividad (heartbeat): un dispositivo
/// vivo puede no tener canal abierto.
class _WsChannelIndicator extends StatelessWidget {
  const _WsChannelIndicator({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: connected
          ? 'Canal WebSocket conectado'
          : 'Canal WebSocket desconectado',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: connected
                    ? CauceColors.success
                    : CauceColors.peachSecondary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              connected ? 'Canal en vivo' : 'Canal en espera',
              style: TextStyle(
                fontFamily: CauceTheme.bodyFont,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: CauceColors.peachSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamMonitorCard extends StatelessWidget {
  const _StreamMonitorCard({required this.onAction});

  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CauceColors.cream,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: CauceColors.creamPrimary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_circle,
                    size: 20, color: CauceColors.creamPrimary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ESTADO',
                      style: TextStyle(
                        fontFamily: CauceTheme.displayFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                        color: CauceColors.peachSecondary,
                      ),
                    ),
                    const Text(
                      'Nombre_Video',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: CauceTheme.displayFont,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: CauceColors.darkTeal,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: CauceColors.peachSurfaceContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'Calidad',
                  style: TextStyle(
                    fontFamily: CauceTheme.displayFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: CauceColors.creamPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 144,
              color: CauceColors.darkTeal,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _WavePainter()),
                  ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: CauceColors.yellow,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'Modo reproduccion',
                          style: TextStyle(
                            fontFamily: CauceTheme.bodyFont,
                            fontSize: 11,
                            color: CauceColors.cream,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: Text(
                      'Bitrate: 42.8 Mb/s',
                      style: TextStyle(
                        fontFamily: CauceTheme.bodyFont,
                        fontSize: 11,
                        color: CauceColors.cream.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: CauceColors.peachSurfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'CONTROL DE EMISION',
                      style: TextStyle(
                        fontFamily: CauceTheme.displayFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: CauceColors.peachSecondary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: CauceColors.peachSurfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Loop 01/08',
                        style: TextStyle(
                          fontFamily: CauceTheme.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: CauceColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _RoundControl(
                      icon: Icons.skip_previous,
                      onTap: onAction,
                    ),
                    const SizedBox(width: 8),
                    _RoundControl(
                      icon: Icons.pause,
                      big: true,
                      accent: CauceColors.teal,
                      onTap: onAction,
                    ),
                    const SizedBox(width: 8),
                    _RoundControl(
                      icon: Icons.skip_next,
                      onTap: onAction,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onAction,
                        style: FilledButton.styleFrom(
                          backgroundColor: CauceColors.creamPrimary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.playlist_play, size: 18),
                        label: const Text(
                          'Cambiar Contenido',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: CauceTheme.displayFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.onTap,
    this.big = false,
    this.accent = CauceColors.cream,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool big;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final size = big ? 42.0 : 36.0;
    return Material(
      color: accent == CauceColors.cream
          ? CauceColors.cream
          : accent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: big ? 22 : 20,
            color: accent == CauceColors.cream
                ? CauceColors.darkTeal
                : CauceColors.cream,
          ),
        ),
      ),
    );
  }
}

class _TelemetryCard extends StatelessWidget {
  const _TelemetryCard({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Direccion IP', device.ipAddress ?? 'No reportada'),
      ('Identificador', device.deviceUid),
      ('Puerto', device.port?.toString() ?? 'Sin definir'),
      ('Ultima conexion', device.relativeLastSeen ?? 'Sin latidos'),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CauceColors.cream,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.memory, size: 18, color: CauceColors.teal),
              const SizedBox(width: 8),
              const Text(
                'INFORMACION',
                style: TextStyle(
                  fontFamily: CauceTheme.displayFont,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: CauceColors.darkTeal,
                ),
              ),
              const Spacer(),
              Text(
                device.isOnline ? 'Sincronizado' : 'Sin conexion',
                style: TextStyle(
                  fontFamily: CauceTheme.displayFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color:
                      device.isOnline ? CauceColors.teal : CauceColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              for (final (label, value) in stats)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CauceColors.peachSurfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: CauceTheme.bodyFont,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                          color: CauceColors.peachSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: CauceTheme.displayFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: CauceColors.darkTeal,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: CauceColors.peachSurfaceContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.router, size: 16, color: CauceColors.teal),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aplicacion actual',
                    style: TextStyle(
                      fontFamily: CauceTheme.displayFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: CauceColors.peachSecondary,
                    ),
                  ),
                ),
                Text(
                  device.currentApplication ?? 'No reportada',
                  style: const TextStyle(
                    fontFamily: CauceTheme.displayFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CauceColors.darkTeal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Acciones remotas de energia sobre el canal WebSocket del
/// dispositivo (POST /api/devices/{uid}/power). Encender = salir de
/// espera; Apagar = entrar en espera (el equipo sigue latiendo).
///
/// Sin canal vivo los pills se muestran deshabilitados y el tap avisa
/// (nunca queda muerto); durante el envio se bloquean para evitar
/// doble tap. El comando es fire-and-forget: no se altera
/// optimistamente el estado mostrado, lo trae el polling.
class _ActionButtons extends StatefulWidget {
  const _ActionButtons({required this.device});

  final Device device;

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _sending = false;

  void _handleTap(String action) {
    if (_sending) return;
    if (!widget.device.wsConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('El dispositivo no tiene canal en vivo; conectalo primero.'),
        ),
      );
      return;
    }
    _confirm(action);
  }

  Future<void> _send(String action) async {
    if (_sending) return;
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<DevicesController>().service;
    setState(() => _sending = true);
    try {
      await service.sendPowerCommand(widget.device.deviceUid, action);
      messenger.showSnackBar(
        const SnackBar(
          content:
              Text('Comando enviado. El estado se actualizara en unos segundos.'),
        ),
      );
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(_messageFor(e))));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el comando al servidor.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _messageFor(ApiException e) {
    if (e.statusCode == 409) {
      return 'El dispositivo no tiene canal en vivo; conectalo primero.';
    }
    if (e.isAuthError) {
      return 'No tienes permiso para controlar este dispositivo.';
    }
    return e.message;
  }

  void _confirm(String action) {
    final isOn = action == 'on';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: CauceColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: CauceColors.peachSurfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOn ? Icons.power_settings_new : Icons.bedtime,
                size: 28,
                color: isOn ? CauceColors.success : CauceColors.error,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isOn ? 'ENCENDER PANTALLA' : 'APAGAR PANTALLA',
              style: const TextStyle(
                fontFamily: CauceTheme.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CauceColors.maroon,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOn
                  ? 'La pantalla saldra del modo espera.'
                  : 'La pantalla entrara en modo espera; el dispositivo sigue conectado y enviando latidos.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: CauceTheme.bodyFont,
                fontSize: 13,
                height: 1.4,
                color: CauceColors.peachOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _send(action);
                },
                style: FilledButton.styleFrom(
                  backgroundColor:
                      isOn ? CauceColors.success : CauceColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: Text(isOn ? 'Encender' : 'Apagar'),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.device.wsConnected && !_sending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ACCIONES',
          style: TextStyle(
            fontFamily: CauceTheme.displayFont,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: CauceColors.peachSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _ActionPill(
                icon: Icons.power_settings_new,
                label: 'Encender',
                color: CauceColors.success,
                enabled: enabled,
                onTap: () => _handleTap('on'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionPill(
                icon: Icons.bedtime,
                label: 'Apagar',
                color: CauceColors.error,
                enabled: enabled,
                onTap: () => _handleTap('off'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  /// false = sin canal WS o envio en curso: pill atenuado. El tap
  /// sigue respondiendo con un aviso; nunca queda muerto.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final accent = enabled ? color : color.withValues(alpha: 0.35);
    return Material(
      color: enabled
          ? CauceColors.peachSurfaceContainer
          : CauceColors.peachSurfaceContainer.withValues(alpha: 0.5),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: CauceTheme.displayFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ondas fluidas de la vista previa de emision (referencia Stitch).
class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Curva sinuosa tipo "cauce", rellena hasta el fondo.
    Path sine(double base, double amp, double phase) {
      final path = Path()..moveTo(0, size.height);
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        final x = t * size.width;
        final y = base + amp * math.sin(t * 3.1416 * 2.5 + phase);
        path.lineTo(x, y);
      }
      path.lineTo(size.width, size.height);
      path.close();
      return path;
    }

    final teal = Paint()..color = CauceColors.teal.withValues(alpha: 0.55);
    final orange = Paint()
      ..color = CauceColors.peachPrimaryContainer.withValues(alpha: 0.45);

    canvas.drawPath(sine(size.height * 0.42, 16, 0), teal);
    canvas.drawPath(sine(size.height * 0.55, 12, 1.6), orange);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
