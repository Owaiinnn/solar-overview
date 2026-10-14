import 'package:flutter/material.dart';

import 'battery_controller.dart';
import 'connection_controller.dart';
import 'home_energy.dart';
import 'p1_controller.dart';
import 'production_total.dart';
import 'solar_freshness.dart';
import 'solar_scene.dart';
import 'solax_controller.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.solax,
    required this.active,
    required this.openDetails,
    this.battery,
    this.p1,
  });

  final ConnectionController controller;
  final SolaxController? solax;
  final BatteryController? battery;
  final P1Controller? p1;
  final bool active;
  final VoidCallback openDetails;

  String _status({
    required bool initialized,
    required bool connected,
    required bool attention,
    required bool busy,
    required ReadingFreshness freshness,
    required bool saved,
    required bool hasPower,
  }) {
    if (!initialized) return 'Loading';
    if (attention) return 'Needs attention';
    if (!connected) return 'Not connected';
    if (busy) return 'Refreshing';
    if (freshness == ReadingFreshness.stale) return 'Stale';
    if (freshness != ReadingFreshness.recent || !hasPower) return 'Unavailable';
    return saved ? 'Recent · saved' : 'Recent';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, solax, battery, p1]),
    builder: (context, _) {
      final colors = Theme.of(context).colorScheme;
      final total = ProductionTotal(controller, solax);
      final watts = total.watts;
      final batteryState = HomeBatteryState.fromController(battery);
      final gridState = HomeGridState.fromController(p1);
      final loading =
          !controller.initialized ||
          (controller.connected && controller.busy) ||
          (solax != null &&
              (!solax!.initialized || (solax!.connected && solax!.busy)));
      final coverage = loading && watts == null
          ? 'Checking your solar sources'
          : total.coverage;
      final message = loading
          ? 'Fetching your solar readings…'
          : total.timeMismatch
          ? 'Source times are over 5 minutes apart. Total unavailable.'
          : watts != null
          ? watts == 0
                ? 'No production reported${total.partial ? ' by this source' : ''}.'
                : 'Recent cloud readings · not instantaneous'
          : 'No compatible recent readings. See Details to connect or refresh.';
      final edgeStatus = _status(
        initialized: controller.initialized,
        connected: controller.connected,
        attention: controller.storageUnavailable || controller.error != null,
        busy: controller.busy,
        freshness: controller.freshness,
        saved: controller.usingSavedReading,
        hasPower: total.sources.containsKey('SolarEdge'),
      );
      final xStatus = _status(
        initialized: solax?.initialized ?? true,
        connected: solax?.connected ?? false,
        attention:
            (solax?.storageUnavailable ?? false) ||
            (solax?.reconnectRequired ?? false) ||
            solax?.error != null,
        busy: solax?.busy ?? false,
        freshness: solax?.freshness ?? ReadingFreshness.unknown,
        saved: solax?.usingSavedReading ?? false,
        hasPower: total.sources.containsKey('SolaX'),
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight == 0) return const SizedBox.shrink();
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey('home-scroll'),
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 520,
                        minHeight: (constraints.maxHeight - 120).clamp(
                          0.0,
                          double.infinity,
                        ),
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              total.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text.rich(
                              watts == null
                                  ? TextSpan(
                                      text: loading
                                          ? 'Loading…'
                                          : 'Unavailable',
                                    )
                                  : TextSpan(
                                      children: [
                                        TextSpan(
                                          text: (watts / 1000).toStringAsFixed(
                                            2,
                                          ),
                                        ),
                                        const TextSpan(
                                          text: ' kW',
                                          style: TextStyle(
                                            fontSize: 24,
                                            letterSpacing: 0,
                                          ),
                                        ),
                                      ],
                                    ),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: watts == null ? 32 : 52,
                                height: 1.15,
                                letterSpacing: -1.5,
                                fontWeight: FontWeight.w700,
                                color: colors.brightness == Brightness.dark
                                    ? colors.onSurface
                                    : const Color(0xFF174C39),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              coverage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              message,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  minHeight: 300,
                                ),
                                child: SolarScene(
                                  active: active,
                                  production: total.presentation,
                                  loading: loading,
                                  battery: batteryState,
                                  grid: gridState,
                                ),
                              ),
                            ),
                            if (batteryState.visible || gridState.visible) ...[
                              Builder(
                                builder: (context) {
                                  final contentWidth =
                                      (constraints.maxWidth - 48).clamp(
                                        0.0,
                                        520.0,
                                      );
                                  final stacked =
                                      contentWidth < 300 ||
                                      MediaQuery.textScalerOf(context)
                                              .scale(14) >
                                          20;
                                  final cards = [
                                    if (batteryState.visible)
                                      _EnergyStatus(
                                        title: 'Battery',
                                        status: batteryState.status,
                                        value: batteryState.levelLabel,
                                        power: batteryState.powerLabel,
                                        qualification:
                                            batteryState.qualification,
                                        semantics: batteryState.semantics,
                                      ),
                                    if (gridState.visible)
                                      _EnergyStatus(
                                        title: 'Grid',
                                        status: gridState.status,
                                        value: gridState.powerLabel,
                                        qualification: gridState.qualification,
                                        semantics: gridState.semantics,
                                      ),
                                  ];
                                  return Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      for (final card in cards)
                                        SizedBox(
                                          width: stacked || cards.length == 1
                                              ? contentWidth
                                              : (contentWidth - 12) / 2,
                                          child: card,
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 12),
                            ],
                            Text(
                              batteryState.visible || gridState.visible
                                  ? 'Separate reported readings, not synchronized flows. '
                                        'Sky and light are decorative. Arrows do not establish '
                                        'wiring or the battery’s charging source.'
                                  : 'Sky, light and rays are decorative, not live weather.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SourceStatus(
                                  name: 'SolarEdge',
                                  status: edgeStatus,
                                ),
                                _SourceStatus(name: 'SolaX', status: xStatus),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          animationDuration: Duration.zero,
                        ),
                        onPressed: openDetails,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('View details'),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

class _SourceStatus extends StatelessWidget {
  const _SourceStatus({required this.name, required this.status});
  final String name;
  final String status;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        '$name · $status',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ),
  );
}

class _EnergyStatus extends StatelessWidget {
  const _EnergyStatus({
    required this.title,
    required this.status,
    required this.qualification,
    required this.semantics,
    this.value,
    this.power,
  });

  final String title;
  final String status;
  final String? value;
  final String? power;
  final String qualification;
  final String semantics;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: semantics,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(status, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (value != null) Text(value!),
            if (power != null) Text(power!),
            const SizedBox(height: 4),
            Text(
              qualification,
              style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
