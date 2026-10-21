/// Pestana Dispositivos: inventario registrado en el backend.
///
/// La lista y el estado de cada dispositivo (conectividad + estado
/// operativo) provienen de GET /api/devices a traves de
/// [DevicesController]. La busqueda filtra el inventario en memoria;
/// los filtros rapidos, el Control Maestro y las acciones por tarjeta
/// todavia no estan conectados a la API.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../controllers/devices_controller.dart';
import '../../core/theme/cauce_colors.dart';
import '../../core/theme/cauce_theme.dart';
import '../../models/device.dart';
import '../../widgets/cauce_headers.dart';
import '../../widgets/identity_widgets.dart';
import '../../widgets/organic_background.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DevicesController>().ensureLoaded();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _notAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Las operaciones sobre dispositivos llegan en una fase posterior.'),
      ),
    );
  }

  List<Device> _filtered(List<Device> devices) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return devices;
    return devices
        .where((d) =>
            d.name.toLowerCase().contains(query) ||
            d.type.toLowerCase().contains(query) ||
            d.deviceUid.toLowerCase().contains(query) ||
            (d.ipAddress ?? '').contains(query))
        .toList();
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
              title: 'Dispositivos',
              onAvatarTap: () =>
                  Navigator.of(context).pushNamed(Routes.profile),
            ),
            Expanded(
              child: Consumer<DevicesController>(
                builder: (context, controller, _) {
                  if (controller.status == DevicesLoadStatus.loading &&
                      controller.devices.isEmpty) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: CauceColors.peachPrimary,
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      RefreshIndicator(
                        color: CauceColors.peachPrimary,
                        onRefresh: () => controller.refresh(),
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 140),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _MasterControlCard(
                                deviceCount: controller.devices.length,
                                onAction: () => _notAvailable(context),
                              ),
                              const SizedBox(height: 16),
                              _SearchBar(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                              ),
                              const SizedBox(height: 12),
                              const _FilterChips(),
                              const SizedBox(height: 16),
                              ..._buildBody(context, controller),
                            ],
                          ),
                        ),
                      ),
                      // Mismo comportamiento que "Nuevo Medio" en la
                      // biblioteca: accion flotante, no boton estatico.
                      Positioned(
                        right: 16,
                        bottom: 16,
                        child: FloatingActionButton.extended(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(Routes.deviceRegister),
                          backgroundColor:
                              CauceColors.peachPrimaryContainer,
                          foregroundColor: Colors.white,
                          icon: const Icon(Icons.add_circle, size: 22),
                          label: const Text(
                            'Anadir Dispositivo',
                            style: TextStyle(
                              fontFamily: CauceTheme.bodyFont,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _buildBody(
      BuildContext context, DevicesController controller) {
    if (controller.status == DevicesLoadStatus.error &&
        controller.devices.isEmpty) {
      return [
        _NoticeCard(
          icon: Icons.wifi_off,
          message: controller.errorMessage ??
              'No fue posible consultar el inventario.',
          actionLabel: 'Reintentar',
          onAction: () => controller.refresh(),
        ),
      ];
    }
    final devices = _filtered(controller.devices);
    if (controller.devices.isNotEmpty && devices.isEmpty) {
      return [
        const _NoticeCard(
          icon: Icons.search_off,
          message: 'Ningun dispositivo coincide con la busqueda.',
        ),
      ];
    }
    if (devices.isEmpty) {
      return [
        const _NoticeCard(
          icon: Icons.devices_other,
          message:
              'Todavia no hay dispositivos registrados. Vincula el primero '
              'para verlo aqui con su estado.',
        ),
      ];
    }
    return [
      for (final device in devices) ...[
        _DeviceCard(
          device: device,
          onAction: () => _notAvailable(context),
        ),
        const SizedBox(height: 12),
      ],
    ];
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
        children: [
          Icon(icon, size: 32, color: CauceColors.peachSecondary),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: CauceTheme.bodyFont,
              fontSize: 13,
              height: 1.4,
              color: CauceColors.peachOnSurfaceVariant,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: CauceColors.peachPrimaryContainer,
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _MasterControlCard extends StatelessWidget {
  const _MasterControlCard({required this.deviceCount, required this.onAction});

  final int deviceCount;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CauceColors.darkTeal,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CauceColors.darkTeal.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bolt,
                    size: 22, color: CauceColors.yellow),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Control Maestro de Sala',
                        style: TextStyle(
                          fontFamily: CauceTheme.displayFont,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$deviceCount dispositivos vinculados',
                        style: TextStyle(
                          fontFamily: CauceTheme.bodyFont,
                          fontSize: 11,
                          color: CauceColors.cream.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.expand_less,
                    size: 22, color: Colors.white.withValues(alpha: 0.8)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Column(
              children: [
                _MasterAction(
                  color: CauceColors.teal,
                  icon: Icons.power_settings_new,
                  title: 'Encender Sala',
                  subtitle: 'Activar $deviceCount dispositivos',
                  onAction: onAction,
                ),
                const SizedBox(height: 12),
                _MasterAction(
                  color: CauceColors.maroon,
                  icon: Icons.power_off,
                  title: 'Apagar Sala',
                  subtitle: 'Suspender circuito',
                  onAction: onAction,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MasterAction extends StatelessWidget {
  const _MasterAction({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onAction,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onAction,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pin, size: 13, color: CauceColors.yellow),
                    const SizedBox(width: 4),
                    Text(
                      'PIN',
                      style: TextStyle(
                        fontFamily: CauceTheme.displayFont,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: CauceColors.yellow,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: CauceTheme.displayFont,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontFamily: CauceTheme.bodyFont,
                        fontSize: 12,
                        color: CauceColors.cream.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 26, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search,
                    size: 20, color: CauceColors.peachOnSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    enabled: true,
                    onChanged: onChanged,
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre, sala o IP...',
                      border: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(
                      fontFamily: CauceTheme.bodyFont,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: CauceColors.peachSurfaceContainer,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.tune,
              size: 18, color: CauceColors.peachOnSurface),
        ),
      ],
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips();

  static const _filters = [
    ('Todas', true),
    ('VR', false),
    ('AR', false),
    ('Tactiles', false),
    ('Totems', false),
    ('Televisores', false),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, selected) = _filters[index];
          return Container(
            padding: EdgeInsets.symmetric(
                horizontal: selected ? 20 : 16, vertical: 8),
            decoration: BoxDecoration(
              color: selected
                  ? CauceColors.peachPrimary
                  : Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: CauceTheme.displayFont,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : CauceColors.peachOnSurface,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onAction});

  final Device device;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final offline = !device.isOnline;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            Navigator.of(context).pushNamed(Routes.deviceDetail, arguments: device),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: offline
                          ? CauceColors.peachErrorContainer
                          : CauceColors.peachSurfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: offline
                        ? const Icon(Icons.tv_off,
                            size: 26, color: CauceColors.maroon)
                        : Image.asset(device.station.asset,
                            fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: CauceTheme.displayFont,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: CauceColors.peachOnSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          device.subtitle,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: CauceTheme.bodyFont,
                            fontSize: 12,
                            color: offline
                                ? CauceColors.maroon
                                : CauceColors.peachOnSurfaceVariant,
                            fontWeight:
                                offline ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(
                      status: device.cauceStatus, label: device.statusLabel),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: offline
                      ? CauceColors.peachErrorContainer.withValues(alpha: 0.4)
                      : CauceColors.peachSurfaceContainerLow
                          .withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      offline ? Icons.schedule : Icons.lan,
                      size: 16,
                      color: offline
                          ? CauceColors.maroon
                          : CauceColors.peachOnSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        offline
                            ? (device.relativeLastSeen == null
                                ? 'Nunca se ha comunicado'
                                : 'Ultimo latido ${device.relativeLastSeen}')
                            : (device.ipAddress ?? 'IP no reportada'),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: CauceTheme.displayFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: CauceColors.peachOnSurfaceVariant,
                        ),
                      ),
                    ),
                    if (!offline) ...[
                      Text(
                        device.relativeLastSeen ?? '',
                        style: const TextStyle(
                          fontFamily: CauceTheme.displayFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: CauceColors.peachOnSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      InkWell(
                        onTap: onAction,
                        child: const _RoundIcon(
                            icon: Icons.replay),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: onAction,
                        child: const _RoundIcon(icon: Icons.tune),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: CauceColors.peachSecondary),
    );
  }
}
