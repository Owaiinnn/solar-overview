import 'package:flutter/material.dart';

import 'history.dart';
import 'history_controller.dart';
import 'history_graph.dart';

String _energy(double? wh) =>
    wh == null ? 'Unavailable' : '${(wh / 1000).toStringAsFixed(2)} kWh';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.controller,
    required this.openSettings,
  });
  final HistoryController controller;
  final VoidCallback openSettings;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _visible = HistorySource.values.toSet();
  bool _mppt = false;

  Future<void> _clearSavedHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear saved history?'),
        content: const Text(
          'Remove cached production history from this phone. Your connections and request waits stay saved. You can load history again from the providers.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.controller.clearSavedHistory();
  }

  Future<void> _pickDay() async {
    final controller = widget.controller;
    final latest = HistorySource.values
        .map(controller.today)
        .reduce((a, b) => a.isAfter(b) ? a : b);
    final picked = await showDatePicker(
      context: context,
      initialDate: controller.selectedDay.isAfter(latest)
          ? latest
          : controller.selectedDay,
      firstDate: DateTime(2000),
      lastDate: latest,
    );
    if (picked != null) controller.selectDay(picked);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final colors = Theme.of(context).colorScheme;
      final loaded = <HistorySource, ProductionHistory>{
        for (final source in _visible)
          if (controller.states[source]!.saved != null)
            source: controller.states[source]!.saved!.data,
      };
      final zones = loaded.values.map((data) => data.day.timeZone).toSet();
      final graphs = zones.length <= 1
          ? [loaded]
          : [
              for (final entry in loaded.entries) {entry.key: entry.value},
            ];
      final days = DateTime.utc(
        controller.selectedDay.year,
        controller.selectedDay.month + 1,
        0,
      ).day;
      return ListView(
        key: const PageStorageKey('history-page'),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Your production history',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Compare solar output and daily energy. Missing readings stay as gaps.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final source in HistorySource.values)
                FilterChip(
                  label: Text(historySourceName(source)),
                  selected: _visible.contains(source),
                  onSelected: (value) => setState(() {
                    if (value) {
                      _visible.add(source);
                    } else {
                      _visible.remove(source);
                    }
                  }),
                ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: 'Previous day',
                onPressed: () => controller.selectDay(
                  controller.selectedDay.subtract(const Duration(days: 1)),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDay,
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(historyDate(controller.selectedDay)),
                ),
              ),
              IconButton(
                tooltip: 'Next day',
                onPressed:
                    controller.selectedDay.isBefore(
                      HistorySource.values
                          .map(controller.today)
                          .reduce((a, b) => a.isAfter(b) ? a : b),
                    )
                    ? () => controller.selectDay(
                        controller.selectedDay.add(const Duration(days: 1)),
                      )
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!controller.initialized) const LinearProgressIndicator(),
          if (controller.storageError != null) ...[
            Text(
              controller.storageError!,
              style: TextStyle(color: colors.error),
            ),
            TextButton(
              onPressed: controller.initialize,
              child: const Text('Retry saved history'),
            ),
            TextButton(
              onPressed: _clearSavedHistory,
              child: const Text('Clear saved history'),
            ),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final source in HistorySource.values.where(
                _visible.contains,
              ))
                if (controller.identity(source) != null) _loadButton(source),
            ],
          ),
          if (loaded.isEmpty) _waitingChart(),
          for (final graph in graphs.where((graph) => graph.isNotEmpty)) ...[
            const SizedBox(height: 16),
            HistoryGraph(
              key: ValueKey('history-ac-${graph.values.first.day.timeZone}'),
              data: graph,
            ),
          ],
          if (loaded.containsKey(HistorySource.solax)) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Show SolaX DC inputs'),
              subtitle: const Text(
                'Separate from AC output; never added to production.',
              ),
              value: _mppt,
              onChanged: (value) => setState(() => _mppt = value),
            ),
            if (_mppt)
              HistoryGraph(
                data: {HistorySource.solax: loaded[HistorySource.solax]!},
                dc: true,
              ),
          ],
          const SizedBox(height: 16),
          for (final source in HistorySource.values.where(_visible.contains))
            _sourceCard(source),
          const SizedBox(height: 16),
          Card(
            child: ExpansionTile(
              key: const PageStorageKey('history-month-comparison'),
              title: Text(
                'Daily comparison · ${historyMonth(controller.selectedDay)}',
              ),
              subtitle: const Text(
                'Separate source totals in kWh. Tap a day to inspect it.',
              ),
              children: [
                for (var number = 1; number <= days; number++)
                  _dailyRow(
                    DateTime.utc(
                      controller.selectedDay.year,
                      controller.selectedDay.month,
                      number,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'History loads only when requested. Each source shares its 15-minute request wait with Details. Saved days open without API requests; reload to check for provider revisions.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Daily energy comes from provider statistics, not from integrating the graph. Today is incomplete; missing daily totals are unavailable. Curves and totals remain separate by source.',
          ),
        ],
      );
    },
  );

  Widget _loadButton(HistorySource source) {
    final controller = widget.controller;
    final state = controller.states[source]!;
    final enabled =
        controller.initialized &&
        controller.storageError == null &&
        !state.loading &&
        !controller.busy(source) &&
        controller.timeZone(source) != null &&
        controller.waitNotice(source) == null &&
        !controller.selectedDay.isAfter(controller.today(source));
    return FilledButton.tonalIcon(
      onPressed: enabled ? () => controller.load(source) : null,
      icon: const Icon(Icons.refresh),
      label: Text(
        '${state.saved == null ? 'Load' : 'Reload'} ${historySourceName(source)} history',
      ),
    );
  }

  Widget _waitingChart() {
    final controller = widget.controller;
    final loading = _visible.any(
      (source) => controller.states[source]!.loading,
    );
    return Card(
      key: const ValueKey('history-waiting-chart'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AC production power',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.show_chart, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    loading
                        ? 'Loading production history…'
                        : _visible.isEmpty
                        ? 'Select a source to view its graph.'
                        : 'No power history loaded for this day.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (loading) const LinearProgressIndicator(),
            for (final source in HistorySource.values.where(_visible.contains))
              if (controller.waitNotice(source) != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${historySourceName(source)}: ${controller.waitNotice(source)}',
                  ),
                ),
            if (_visible.contains(HistorySource.solax) &&
                controller.solax?.reconnectRequired == true)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'SolaX needs reconnection in Settings before its graph can load.',
                ),
              ),
            if (!loading && _visible.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _visible.any((source) => controller.identity(source) != null)
                      ? 'Load a connected source above to draw its power curve.'
                      : 'Connect a solar source in Settings to view its graph.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sourceCard(HistorySource source) {
    final controller = widget.controller;
    final state = controller.states[source]!;
    final name = historySourceName(source);
    final connected = controller.identity(source) != null;
    final zone = controller.timeZone(source);
    final daily = controller.dailyEnergy(source);
    final selectedEnergy = daily[historyDate(controller.selectedDay)];
    final wait = controller.waitNotice(source);
    final saved = state.saved;
    final count =
        saved?.data.samples.where((sample) => sample.watts != null).length ?? 0;
    return Card(
      key: ValueKey(source),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              _energy(selectedEnergy),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              source == HistorySource.solax
                  ? 'Plant AC output energy'
                  : 'Site production energy',
            ),
            if (source == HistorySource.solax)
              const Text(
                'Power covers the selected inverter; daily energy covers the plant.',
              ),
            if (historyDate(controller.selectedDay) ==
                historyDate(controller.today(source)))
              const Text('Today so far'),
            if (!connected) ...[
              Text('Connect $name to see its history.'),
              TextButton(
                onPressed: widget.openSettings,
                child: const Text('Open Settings'),
              ),
            ] else ...[
              if (source == HistorySource.solax &&
                  controller.solax?.reconnectRequired == true) ...[
                const Text(
                  'SolaX needs attention. Reconnect in Settings to load history.',
                ),
                TextButton(
                  onPressed: widget.openSettings,
                  child: const Text('Open Settings'),
                ),
              ],
              if (zone == null)
                const Text(
                  'Site timezone unavailable. Refresh this connection in Details first.',
                )
              else
                Text(zone),
              if (saved != null) ...[
                Text(
                  'Saved ${historyDate(siteToday(zone!, saved.fetchedAt)!)} · ${historyClock(saved.fetchedAt, zone)}',
                ),
                Text(
                  '$count of ${saved.data.samples.length} power samples available',
                ),
                if (count == 0)
                  const Text('No power readings were returned for this day.'),
              ] else
                const Text('No power history saved for this day.'),
              if (state.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                ),
              if (state.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (wait != null) Text(wait),
              if (controller.selectedDay.isAfter(controller.today(source)))
                const Text('This date is still in the future at the site.'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dailyRow(DateTime date) {
    final controller = widget.controller;
    return ListTile(
      dense: true,
      title: Text(historyDate(date)),
      selected: date == controller.selectedDay,
      subtitle: Text(
        HistorySource.values
            .where(_visible.contains)
            .map((source) {
              final value = controller.dailyEnergy(source)[historyDate(date)];
              return '${historySourceName(source)}: ${_energy(value)}';
            })
            .join(' · '),
      ),
      onTap: () => controller.selectDay(date),
    );
  }
}
