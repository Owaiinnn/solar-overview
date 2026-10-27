import 'package:flutter/material.dart';

import 'tibber.dart';
import 'tibber_controller.dart';

String _price(double? value, String currency) =>
    value == null ? 'Unavailable' : '${value.toStringAsFixed(4)} $currency/kWh';
String _two(int value) => value.toString().padLeft(2, '0');
String _time(TibberHome home, DateTime time) {
  final local = home.local(time);
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '−' : '+';
  final minutes = offset.inMinutes.abs();
  return '${_two(local.hour)}:${_two(local.minute)} UTC$sign${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}

String _range(TibberHome home, PriceInterval price) =>
    '${_time(home, price.start)} – ${_time(home, price.end)}';
String _date(TibberHome home, DateTime time) {
  final local = home.local(time);
  return '${local.year}-${_two(local.month)}-${_two(local.day)}';
}

class TibberPricesPage extends StatelessWidget {
  const TibberPricesPage({
    super.key,
    this.controller,
    required this.openSettings,
  });
  final TibberController? controller;
  final VoidCallback openSettings;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    if (c == null) {
      return const Center(
        child: Text('Connect Tibber on your phone to see electricity prices.'),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final home = c.home;
        final current = c.current;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Electricity prices',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text('Tibber purchase prices per kWh'),
            const SizedBox(height: 16),
            if (c.busy) const LinearProgressIndicator(),
            if (c.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Semantics(liveRegion: true, child: Text(c.error!)),
              ),
            if (c.authorizationRequired)
              const Text('Reconnect Tibber in Settings to update prices.'),
            if (c.storageUnavailable)
              TextButton(
                onPressed: c.busy ? null : c.initialize,
                child: const Text('Retry Tibber storage'),
              ),
            if (!c.initialized)
              const Text('Opening saved prices…')
            else if (home == null) ...[
              const Text(
                'Connect your Tibber account to see the current price and today’s and tomorrow’s schedules.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: openSettings,
                child: const Text('Set up Tibber'),
              ),
            ] else ...[
              Text('${home.name} · ${home.timeZone}'),
              Text('Requested resolution: ${home.resolution.label}'),
              if (c.receivedAt != null)
                Text(
                  '${c.saved || c.error != null ? 'Saved schedule' : 'Schedule updated'} · ${_date(home, c.receivedAt!)} ${_time(home, c.receivedAt!)}',
                ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current price',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current == null
                            ? 'Unavailable'
                            : _price(current.total, current.currency),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (current != null) ...[
                        Text(_range(home, current)),
                        const SizedBox(height: 8),
                        Text(
                          'Energy: ${_price(current.energy, current.currency)}',
                        ),
                        Text(
                          'Tax component: ${_price(current.tax, current.currency)}',
                        ),
                      ] else
                        Text(
                          home.activeSubscription
                              ? 'The saved schedule does not cover this interval.'
                              : 'No running Tibber electricity subscription is available.',
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'API total = energy + tax components. Contract fees and export compensation are not verified here.',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    c.canRequest && !c.authorizationRequired && !c.editing
                    ? c.refresh
                    : null,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh prices'),
              ),
              if (c.wait > Duration.zero)
                Text(
                  'Next request available in ${(c.wait.inSeconds / 60).ceil()} min.',
                ),
              if (home.activeSubscription) ...[
                const SizedBox(height: 16),
                _DayPrices(home: home, controller: c, offset: 0),
                const SizedBox(height: 16),
                _DayPrices(home: home, controller: c, offset: 1),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _DayPrices extends StatelessWidget {
  const _DayPrices({
    required this.home,
    required this.controller,
    required this.offset,
  });
  final TibberHome home;
  final TibberController controller;
  final int offset;
  @override
  Widget build(BuildContext context) {
    final now = controller.now;
    final rows = home.forDay(now, offset);
    final available = rows.where((p) => p.total != null).length;
    final expected = home.expectedIntervals(now, offset);
    final day = home.day(now, offset);
    final title = offset == 0 ? 'Today' : 'Tomorrow';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title · ${_date(home, day)}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              offset == 1
                  ? 'Tomorrow’s prices are not available in the saved schedule yet. They may not be published.'
                  : 'No prices available for today.',
            ),
          )
        else ...[
          Text(
            '$available of $expected intervals available${available < expected ? ' · incomplete coverage' : ''}',
          ),
          ExpansionTile(
            key: ValueKey('tibber-day-$offset'),
            tilePadding: EdgeInsets.zero,
            title: Text('View $title prices'),
            children: [
              for (var index = 0; index < expected; index++)
                _PriceRow(
                  home: home,
                  start: day.toUtc().add(
                    Duration(minutes: index * home.resolution.minutes),
                  ),
                  rows: rows,
                  now: now,
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.home,
    required this.start,
    required this.rows,
    required this.now,
  });
  final TibberHome home;
  final DateTime start;
  final List<PriceInterval> rows;
  final DateTime now;
  @override
  Widget build(BuildContext context) {
    final matching = rows.where((p) => p.start == start);
    final price = matching.isEmpty ? null : matching.single;
    final current = price?.contains(now) ?? false;
    final interval =
        price ??
        PriceInterval(
          start: start,
          end: start.add(Duration(minutes: home.resolution.minutes)),
          currency: '',
        );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      selected: current,
      title: Text(
        '${current ? 'Now · ' : ''}${price == null ? 'Unavailable' : _price(price.total, price.currency)}',
      ),
      subtitle: Text(_range(home, interval)),
    );
  }
}

class TibberSettingsCard extends StatefulWidget {
  const TibberSettingsCard({
    super.key,
    this.controller,
    this.preview = false,
    this.active = true,
  });
  final TibberController? controller;
  final bool preview;
  final bool active;
  @override
  State<TibberSettingsCard> createState() => _TibberSettingsCardState();
}

class _TibberSettingsCardState extends State<TibberSettingsCard> {
  final _token = TextEditingController();
  PriceResolution _resolution = PriceResolution.quarterHourly;
  String? _selected;
  bool _editing = false;
  @override
  void didUpdateWidget(TibberSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active && !widget.active) {
      _token.clear();
      _selected = null;
      _editing = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller?.finishEditing();
      });
    }
  }

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  void _cancel() {
    _token.clear();
    widget.controller?.finishEditing();
    setState(() {
      _editing = false;
      _selected = null;
    });
  }

  Future<void> _discover() async {
    final c = widget.controller!;
    final success = await c.discover(_token.text, _resolution);
    if (!mounted) return;
    _token.clear();
    if (!widget.active) {
      c.finishEditing();
      return;
    }
    if (success) {
      setState(
        () => _selected = c.candidates.length == 1
            ? c.candidates.single.id
            : null,
      );
    }
  }

  Future<void> _remove() async {
    final c = widget.controller!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Tibber connection?'),
        content: const Text(
          'Remove the token and saved price schedule from this phone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await c.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c == null || widget.preview) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('Tibber · Set up electricity prices on your phone.'),
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tibber electricity prices',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Your personal token stays in this phone’s protected storage and is sent only to Tibber.',
              ),
              if (c.busy) const LinearProgressIndicator(),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(liveRegion: true, child: Text(c.error!)),
                ),
              if (c.storageUnavailable)
                TextButton(
                  onPressed: c.busy ? null : c.initialize,
                  child: const Text('Retry Tibber storage'),
                ),
              if (c.home != null) ...[
                const SizedBox(height: 12),
                Text('${c.home!.name} · ${c.home!.timeZone}'),
                Text(
                  c.authorizationRequired
                      ? 'Authorization required'
                      : 'Connection saved',
                ),
              ],
              if (!_editing)
                Wrap(
                  spacing: 12,
                  children: [
                    TextButton(
                      onPressed:
                          !c.initialized || c.busy || c.storageUnavailable
                          ? null
                          : () {
                              c.beginEditing();
                              setState(() => _editing = true);
                            },
                      child: Text(
                        c.connected
                            ? 'Replace Tibber connection'
                            : 'Connect Tibber',
                      ),
                    ),
                    if (c.connected)
                      TextButton(
                        onPressed: c.busy || c.storageUnavailable
                            ? null
                            : _remove,
                        child: const Text('Remove Tibber'),
                      ),
                  ],
                )
              else ...[
                const SizedBox(height: 16),
                if (c.candidates.isEmpty) ...[
                  TextField(
                    key: const Key('tibber-token'),
                    controller: _token,
                    enabled: !c.busy,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    enableIMEPersonalizedLearning: false,
                    decoration: const InputDecoration(
                      labelText: 'Tibber personal token',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<PriceResolution>(
                    initialValue: _resolution,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Price resolution',
                    ),
                    items: PriceResolution.values
                        .map(
                          (r) =>
                              DropdownMenuItem(value: r, child: Text(r.label)),
                        )
                        .toList(),
                    onChanged: c.busy
                        ? null
                        : (value) => setState(() => _resolution = value!),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose the resolution supported by your contract. Confirm prices against the Tibber app.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: c.canRequest ? _discover : null,
                    child: const Text('Test token & find homes'),
                  ),
                ] else ...[
                  DropdownButtonFormField<String>(
                    key: ValueKey(c.candidates),
                    initialValue: _selected,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Tibber home'),
                    items: c.candidates
                        .asMap()
                        .entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.value.id,
                            child: Text(
                              '${e.key + 1}. ${e.value.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: c.busy
                        ? null
                        : (value) => setState(() => _selected = value),
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: 8),
                    Builder(
                      builder: (_) {
                        final home = c.candidates.singleWhere(
                          (h) => h.id == _selected,
                        );
                        return Text(
                          '${home.timeZone} · ${home.activeSubscription ? '${home.prices.length} price intervals returned' : 'No running subscription'}',
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: c.busy || _selected == null
                        ? null
                        : () async {
                            final success = await c.saveHome(_selected!);
                            if (success && mounted) _cancel();
                          },
                    child: const Text('Save Tibber connection'),
                  ),
                ],
                if (c.wait > Duration.zero)
                  Text(
                    'Next request available in ${(c.wait.inSeconds / 60).ceil()} min.',
                  ),
                TextButton(
                  onPressed: c.busy ? null : _cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
