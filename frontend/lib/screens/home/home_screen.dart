/// Pantalla de Inicio.
///
/// El inventario de dispositivos, sus estados y las metricas provienen
/// de la API ([DevicesController]). La seccion de actividad reciente
/// sigue usando datos estaticos de demostracion hasta que el backend
/// exponga un modulo de eventos visible para el mediador.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../controllers/devices_controller.dart';
import '../../core/theme/cauce_colors.dart';
import '../../core/theme/cauce_theme.dart';
import '../../data/demo_data.dart';
import '../../models/device.dart';
import '../../widgets/cauce_headers.dart';
import '../../widgets/identity_widgets.dart';
import '../../widgets/organic_background.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onOpenDevices});

  /// Callback para "Ver todas" (salta a la pestana Dispositivos).
  final VoidCallback? onOpenDevices;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DevicesController>().ensureLoaded();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ColoredBox(color: CauceColors.peachSurface),
        const OrganicBackground(
          topRight: true,
          bottomLeft: false,
          baseColor: CauceColors.peachSurface,
        ),
        Column(
          children: [
            TabHeader(
              title: 'Inicio',
              onAvatarTap: () =>
                  Navigator.of(context).pushNamed(Routes.profile),
            ),
            Expanded(
              child: Consumer<DevicesController>(
                builder: (context, controller, _) {
                  return RefreshIndicator(
                    color: CauceColors.peachPrimary,
                    onRefresh: () => controller.refresh(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _RoomStatusBanner(
                            total: controller.devices.length,
                            online: controller.onlineCount,
                            offline: controller.offlineCount,
                          ),
                          const SizedBox(height: 8),
                          _MetricBadges(
                            online: controller.onlineCount,
                            active: controller.activeCount,
                            offline: controller.offlineCount,
                          ),
                          const SizedBox(height: 16),
                          if (controller.firstOffline != null) ...[
                            _UrgentAlertCard(
                                device: controller.firstOffline!),
                            const SizedBox(height: 24),
                          ],
                          _DevicesSection(
                            devices: controller.devices,
                            loading:
                                controller.status == DevicesLoadStatus.loading,
                            errorMessage: controller.status ==
                                    DevicesLoadStatus.error
                                ? controller.errorMessage
                                : null,
                            onRetry: () => controller.refresh(),
                            onOpenAll: widget.onOpenDevices,
                          ),
                          const SizedBox(height: 24),
                          const _RecentActivitySection(),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoomStatusBanner extends StatelessWidget {
  const _RoomStatusBanner({
    required this.total,
    required this.online,
    required this.offline,
  });

  final int total;
  final int online;
  final int offline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CauceColors.darkTeal,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: CauceColors.darkTeal.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: CauceColors.yellow,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'ESTADO DE LA SALA',
                style: TextStyle(
                  fontFamily: CauceTheme.displayFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: CauceColors.yellow,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: CauceColors.cream.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$total dispositivos',
                  style: const TextStyle(
                    fontFamily: CauceTheme.displayFont,
                    fontSize: 11,
                    color: CauceColors.cream,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              text: '$online Dispositivos en linea ',
              style: const TextStyle(
                fontFamily: CauceTheme.displayFont,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: CauceColors.cream,
              ),
              children: [
                if (offline > 0)
                  TextSpan(
                    text: ' - $offline sin conexion',
                    style: const TextStyle(
                      fontFamily: CauceTheme.displayFont,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: CauceColors.peachSecondaryFixedDim,
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

class _MetricBadges extends StatelessWidget {
  const _MetricBadges({
    required this.online,
    required this.active,
    required this.offline,
  });

  final int online;
  final int active;
  final int offline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricBadge(
            label: 'En linea',
            value: '$online',
            dotColor: CauceColors.teal,
            background: CauceColors.peachSurfaceContainer,
            valueColor: CauceColors.peachOnSurface,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricBadge(
            label: 'Activos',
            value: '$active',
            dotColor: CauceColors.peachPrimaryContainer,
            background: CauceColors.peachSecondaryContainer,
            valueColor: CauceColors.peachOnSecondaryContainer,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricBadge(
            label: 'Offline',
            value: '$offline',
            dotColor: CauceColors.error,
            background: CauceColors.peachSurfaceContainerHigh,
            valueColor: CauceColors.error,
          ),
        ),
      ],
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.background,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color dotColor;
  final Color background;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                    color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: CauceTheme.displayFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: CauceColors.peachOnSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: CauceTheme.displayFont,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _UrgentAlertCard extends StatelessWidget {
  const _UrgentAlertCard({required this.device});

  final Device device;

  void _notAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('El reinicio remoto de nodos llega en una fase posterior.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastSeen = device.relativeLastSeen;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CauceColors.maroon,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CauceColors.maroon.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CauceColors.cream.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.tv_off,
                    size: 22, color: CauceColors.peachSecondaryFixedDim),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            device.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: CauceTheme.displayFont,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: CauceColors.cream,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _AlertPill(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastSeen == null
                          ? 'El dispositivo nunca ha reportado un latido al '
                              'servidor. Verifica su conexion con la red de la sala.'
                          : 'Sin latidos desde el servidor $lastSeen. Verifica '
                              'la conexion del equipo con la red de la sala.',
                      style: const TextStyle(
                        fontFamily: CauceTheme.bodyFont,
                        fontSize: 12,
                        color: CauceColors.cream,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.router, size: 14, color: CauceColors.cream),
                const SizedBox(width: 6),
                Text(
                  'IP: ${device.ipAddress ?? 'no reportada'}',
                  style: TextStyle(
                    fontFamily: CauceTheme.bodyFont,
                    fontSize: 11,
                    color: CauceColors.cream.withValues(alpha: 0.8),
                  ),
                ),
                const Spacer(),
                _RebootButton(onTap: () => _notAvailable(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertPill extends StatelessWidget {
  const _AlertPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: CauceColors.error,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'DESCONECTADO',
        style: TextStyle(
          fontFamily: CauceTheme.bodyFont,
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _RebootButton extends StatelessWidget {
  const _RebootButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: CauceColors.peachPrimaryContainer,
        foregroundColor: CauceColors.cream,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: const StadiumBorder(),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.restart_alt, size: 16),
          SizedBox(width: 6),
          Text(
            'Reiniciar Nodo',
            style: TextStyle(
              fontFamily: CauceTheme.displayFont,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DevicesSection extends StatelessWidget {
  const _DevicesSection({
    required this.devices,
    required this.loading,
    required this.errorMessage,
    required this.onRetry,
    required this.onOpenAll,
  });

  final List<Device> devices;
  final bool loading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'DISPOSITIVOS',
              style: TextStyle(
                fontFamily: CauceTheme.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CauceColors.peachOnSurface,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: onOpenAll,
              style: TextButton.styleFrom(
                foregroundColor: CauceColors.peachPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text(
                'Ver todas',
                style: TextStyle(
                  fontFamily: CauceTheme.displayFont,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (loading && devices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: CircularProgressIndicator(
                color: CauceColors.peachPrimary,
              ),
            ),
          )
        else if (errorMessage != null && devices.isEmpty)
          _SectionError(message: errorMessage!, onRetry: onRetry)
        else if (devices.isEmpty)
          const _EmptyDevices()
        else
          for (final device in devices)
            _StationRow(device: device),
      ],
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CauceColors.peachSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.wifi_off, size: 26, color: CauceColors.maroon),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: CauceTheme.bodyFont,
              fontSize: 12,
              height: 1.4,
              color: CauceColors.peachOnSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CauceColors.peachSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.devices_other,
              size: 22, color: CauceColors.peachSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Todavia no hay dispositivos registrados en el servidor.',
              style: TextStyle(
                fontFamily: CauceTheme.bodyFont,
                fontSize: 12,
                height: 1.4,
                color: CauceColors.peachOnSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationRow extends StatelessWidget {
  const _StationRow({required this.device});

  final Device device;

  @override
  Widget build(BuildContext context) {
    final offline = !device.isOnline;
    final idle = device.deviceState == 'idle';
    final statusColor = offline
        ? CauceColors.error
        : idle
            ? CauceColors.peachPrimaryContainer
            : CauceColors.teal;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: offline
            ? CauceColors.peachSecondaryContainer
            : CauceColors.peachSurfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context)
              .pushNamed(Routes.deviceDetail, arguments: device),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: offline
                        ? CauceColors.cream
                        : CauceColors.peachSurfaceContainerHigh,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: offline
                      ? const Icon(Icons.tv_off,
                          size: 18, color: CauceColors.maroon)
                      : Image.asset(device.station.asset,
                          fit: BoxFit.contain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.type,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: CauceTheme.bodyFont,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: offline
                              ? CauceColors.peachOnSecondaryContainer
                              : CauceColors.peachOnSurfaceVariant,
                        ),
                      ),
                      Text(
                        device.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: CauceTheme.displayFont,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: offline
                              ? CauceColors.peachOnSecondaryContainer
                              : CauceColors.peachOnSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  device.statusLabel,
                  style: TextStyle(
                    fontFamily: CauceTheme.displayFont,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Text(
              'ACTIVIDAD RECIENTE',
              style: TextStyle(
                fontFamily: CauceTheme.displayFont,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: CauceColors.peachOnSurface,
              ),
            ),
            const Spacer(),
            Text(
              'Ultimos 30 min',
              style: TextStyle(
                fontFamily: CauceTheme.bodyFont,
                fontSize: 12,
                color: CauceColors.peachOnSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: CauceColors.peachSurfaceContainer,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              for (var i = 0; i < DemoData.recentActivity.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _RecentActivityItem(item: DemoData.recentActivity[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecentActivityItem extends StatelessWidget {
  const _RecentActivityItem({required this.item});

  final DemoActivity item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: CauceColors.peachSurfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: CauceColors.cream,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 18, color: CauceColors.teal),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: CauceTheme.displayFont,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: CauceColors.peachOnSurface,
                  ),
                ),
                Text(
                  item.subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: CauceTheme.bodyFont,
                    fontSize: 11,
                    color: CauceColors.peachOnSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.relativeTime,
            style: const TextStyle(
              fontFamily: CauceTheme.bodyFont,
              fontSize: 11,
              color: CauceColors.peachOnSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
