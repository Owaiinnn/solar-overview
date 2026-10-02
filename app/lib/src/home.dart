import 'package:flutter/material.dart';

import 'connection_controller.dart';
import 'production_total.dart';
import 'solar_scene.dart';
import 'solaredge.dart';
import 'solax_controller.dart';

/// A compact view of the same guarded AC subtotal used by Details.
class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.solax,
    required this.active,
    required this.openDetails,
  });

  final ConnectionController controller;
  final SolaxController? solax;
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
    listenable: Listenable.merge([controller, solax]),
    builder: (context, _) {
      final total = ProductionTotal(controller, solax);
      final watts = total.watts;
      final partial = total.sources.length == 1;
      final loading =
          !controller.initialized ||
          (controller.connected && controller.busy) ||
          (solax != null &&
              (!solax!.initialized || (solax!.connected && solax!.busy)));
      final title = partial
          ? 'Partial solar production'
          : 'Combined solar production';
      final coverage = loading && watts == null
          ? 'Checking your solar sources'
          : partial
          ? '${total.sources.keys.single} only · 1 of 2 sources'
          : 'SolarEdge + SolaX · ${total.sources.length} of 2 sources';
      final message = loading
          ? 'Fetching your solar readings…'
          : total.timeMismatch
          ? 'Source times are over 5 minutes apart. Total unavailable.'
          : watts != null
          ? watts == 0
                ? 'No production reported${partial ? ' by this source' : ''}.'
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
          return SingleChildScrollView(
            key: const PageStorageKey('home-scroll'),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 520,
                  minHeight: constraints.maxHeight - 24,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        watts == null
                            ? TextSpan(
                                text: loading ? 'Loading…' : 'Unavailable',
                              )
                            : TextSpan(
                                children: [
                                  TextSpan(
                                    text: (watts / 1000).toStringAsFixed(2),
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
                          color: const Color(0xFF174C39),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        coverage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 80),
                          child: SolarScene(
                            active: active,
                            producing: watts != null && watts > 0,
                            loading: loading,
                          ),
                        ),
                      ),
                      const Text(
                        'Illustrative scene · not live weather or flow',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF52645B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _SourceStatus(name: 'SolarEdge', status: edgeStatus),
                          _SourceStatus(name: 'SolaX', status: xStatus),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: openDetails,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('View details'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
      color: const Color(0xFFE7EDE5),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        '$name · $status',
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 12, color: Color(0xFF294B3C)),
      ),
    ),
  );
}
