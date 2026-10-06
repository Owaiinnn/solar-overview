import 'package:flutter/material.dart';

import 'connection_controller.dart';
import 'p1_controller.dart';
import 'p1_widgets.dart';
import 'production_total.dart';
import 'solar_freshness.dart';
import 'solax_controller.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.controller,
    required this.openSettings,
    this.solax,
    this.p1,
  });

  final P1Controller? p1;
  final ConnectionController controller;
  final SolaxController? solax;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller, solax]),
    builder: (context, _) => ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your solar readings',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        _productionTotal(),
        const SizedBox(height: 16),
        _solarEdge(),
        const SizedBox(height: 16),
        _solax(),
        const SizedBox(height: 16),
        P1DetailsCard(controller: p1, openSettings: openSettings),
        const SizedBox(height: 16),
        const _SourceCard(
          title: 'Your other energy sources',
          children: [
            Text('PowerFlex battery: unavailable — integration coming later.'),
            SizedBox(height: 8),
            Text(
              'Household consumption: unavailable — compatible measurements and meter coverage need verification.',
            ),
            SizedBox(height: 8),
            Text(
              'Spare power for appliances is unavailable until household '
              'and relevant battery flows are measured.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Power (W / kW) is the rate of production. Energy '
          '(Wh / kWh) accumulates over time. 1 kW = 1,000 W; '
          '1 kWh = 1,000 Wh.',
        ),
      ],
    ),
  );

  Widget _productionTotal() {
    final total = ProductionTotal(controller, solax);
    return _SourceCard(
      title: total.title,
      children: [
        _Measurement(label: total.coverage, value: _kilo(total.watts, 'kW')),
        if (total.timeMismatch)
          const Text(
            'Readings are more than five minutes apart. '
            'A combined reading is unavailable.',
          )
        else if (total.partial)
          const Text(
            'The other source is disconnected, missing, stale or needs '
            'attention. This is a subtotal, not whole-home solar production.',
          )
        else if (total.watts == null)
          const Text('No compatible recent power readings are available.'),
        const Text(
          'Uses reported solar-only AC output, including recent saved '
          'readings. Both readings must be under 30 minutes old and within '
          'five minutes of each other. Cloud readings are not instantaneous.',
        ),
      ],
    );
  }

  Widget _solarEdge() {
    final c = controller;
    final data = c.overview;
    return _SourceCard(
      title: 'SolarEdge panels',
      children: [
        if (c.busy) const LinearProgressIndicator(),
        if (c.error != null) _SourceError(c.error!),
        if (!c.initialized)
          const Text('Opening SolarEdge connection…')
        else if (!c.connected && !c.storageUnavailable) ...[
          const Text('Connect your SolarEdge site to see production here.'),
          FilledButton(
            onPressed: openSettings,
            child: const Text('Connect SolarEdge'),
          ),
        ],
        if (c.storageUnavailable) ...[
          const Text('SolarEdge secure storage needs attention.'),
          TextButton(
            onPressed: c.busy ? null : c.initialize,
            child: const Text('Retry storage'),
          ),
        ],
        if (c.connected) ...[
          _Freshness(source: 'SolarEdge', freshness: c.freshness),
          if (c.usingSavedReading)
            const Text(
              'Showing saved readings from the last successful request.',
            ),
          _Measurement(
            label: 'Reported production',
            value: _kilo(data?.powerWatts, 'kW'),
          ),
          _Measurement(
            label: 'Today’s energy',
            value: _kilo(c.todayEnergyWh, 'kWh'),
          ),
          Text(
            'Last reported: ${data?.reportedAt ?? 'unavailable'}'
            '${data?.reportedAt == null ? '' : ' (${data?.timeZone ?? 'site timezone unavailable'})'}',
          ),
          if (c.todayEnergyWh == null && data?.energyWh != null)
            const Text(
              'Today’s energy is unavailable until a reading dated today '
              'in the site timezone arrives.',
            ),
          const Text(
            'Cloud readings may lag behind your panels. '
            'Refresh is available every 15 minutes.',
          ),
          const Text('Energy source: SolarEdge site daily production.'),
          OutlinedButton.icon(
            onPressed: c.busy || c.storageUnavailable || !c.canRequest
                ? null
                : c.refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh readings'),
          ),
        ],
        if (c.refreshNotice != null) Text(c.refreshNotice!),
      ],
    );
  }

  Widget _solax() {
    final c = solax;
    final data = c?.reading;
    return _SourceCard(
      title: 'SolaX panels',
      children: [
        if (c?.busy ?? false) const LinearProgressIndicator(),
        if (c?.error != null) _SourceError(c!.error!),
        if (c != null && !c.initialized)
          const Text('Opening SolaX connection…')
        else if (!(c?.connected ?? false) &&
            !(c?.storageUnavailable ?? false)) ...[
          const Text('Connect your SolaX inverter to see production here.'),
          FilledButton(
            onPressed: openSettings,
            child: const Text('Connect SolaX'),
          ),
        ],
        if (c?.storageUnavailable ?? false) ...[
          const Text('SolaX secure storage needs attention.'),
          TextButton(
            onPressed: c!.busy ? null : c.initialize,
            child: const Text('Retry SolaX storage'),
          ),
        ],
        if (c != null && c.connected) ...[
          _Freshness(source: 'SolaX', freshness: c.freshness),
          if (c.usingSavedReading)
            const Text('Showing the saved SolaX reading.'),
          _Measurement(
            label: 'Reported AC output',
            value: _kilo(data?.powerWatts, 'kW'),
          ),
          _Measurement(
            label: 'Today’s inverter AC energy (device counter)',
            value: _kilo(c.todayEnergyWh, 'kWh'),
          ),
          const Text(
            'Device energy counters may reset or differ from plant totals. '
            'A verified daily total is not yet available.',
          ),
          if (c.todayEnergyWh == null && data?.dailyEnergyWh != null)
            const Text(
              'Today’s counter is unavailable until a reading dated today '
              'in the plant timezone arrives.',
            ),
          Text('Inverter status: ${data?.status ?? 'Unavailable'}'),
          Text(
            'Source time (UTC): ${data?.reportedAtUtc?.toIso8601String() ?? 'Unavailable'}',
          ),
          Text('Plant timezone: ${data?.timeZone ?? 'Unavailable'}'),
          if (c.reconnectRequired)
            TextButton(
              onPressed: openSettings,
              child: const Text('Reconnect SolaX in Settings'),
            ),
          OutlinedButton.icon(
            onPressed: c.canRequest && !c.reconnectRequired ? c.refresh : null,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh SolaX'),
          ),
          ExpansionTile(
            title: const Text('SolaX source details'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 12),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('DC panel inputs — not added to AC inverter output.'),
              for (final channel in [1, 2]) ...[
                const SizedBox(height: 12),
                Text(
                  'MPPT $channel (DC)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('Power: ${_value(data?.mpptPowerWatts(channel), 'W')}'),
                Text(
                  'Voltage: ${_value(data?.mpptVoltageVolts(channel), 'V')}',
                ),
                Text('Current: ${_value(data?.mpptCurrentAmps(channel), 'A')}'),
              ],
              const SizedBox(height: 12),
              Text(
                'Inverter temperature: ${_value(data?.temperatureCelsius, '°C')}',
              ),
              Text(
                'Lifetime inverter AC energy: ${_kilo(data?.lifetimeEnergyWh, 'kWh')}',
              ),
              const SizedBox(height: 8),
              const Text(
                'Source: SolaX device telemetry. Power: acPower1; '
                'daily / lifetime AC energy: dailyACOutput / totalACOutput. '
                'Plant totals and PV yield are separate measurements and '
                'are never substituted. All details use the source time above.',
              ),
            ],
          ),
        ],
        if (c?.refreshNotice != null) Text(c!.refreshNotice!),
      ],
    );
  }
}

String _kilo(double? value, String unit) => value == null
    ? 'Unavailable'
    : '${(value / 1000).toStringAsFixed(2)} $unit';
String _value(double? value, String unit) =>
    value == null ? 'Unavailable' : '${value.toStringAsFixed(1)} $unit';

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _Freshness extends StatelessWidget {
  const _Freshness({required this.source, required this.freshness});
  final String source;
  final ReadingFreshness freshness;
  @override
  Widget build(BuildContext context) => Text(switch (freshness) {
    ReadingFreshness.recent => 'Recent $source reading',
    ReadingFreshness.stale => 'Stale $source reading — 30 minutes or older',
    ReadingFreshness.unknown => '$source freshness unavailable',
  }, style: const TextStyle(fontWeight: FontWeight.w600));
}

class _SourceError extends StatelessWidget {
  const _SourceError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _Measurement extends StatelessWidget {
  const _Measurement({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
      ],
    ),
  );
}
