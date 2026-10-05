import 'package:flutter/material.dart';

import 'p1.dart';
import 'p1_controller.dart';

class P1SettingsCard extends StatefulWidget {
  const P1SettingsCard({
    super.key,
    this.controller,
    this.preview = false,
    this.active = true,
  });
  final P1Controller? controller;
  final bool preview;
  final bool active;
  @override
  State<P1SettingsCard> createState() => _P1SettingsCardState();
}

class _P1SettingsCardState extends State<P1SettingsCard> {
  final _address = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _replacing = false;
  @override
  void didUpdateWidget(P1SettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller?.editingConnection = widget.active && _replacing;
  }

  @override
  void dispose() {
    widget.controller?.editingConnection = false;
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final success = await widget.controller!.connect(_address.text);
    if (!mounted || !success) return;
    FocusScope.of(context).unfocus();
    _address.clear();
    widget.controller?.editingConnection = false;
    setState(() => _replacing = false);
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove P1 connection?'),
        content: const Text(
          'Remove the P1 reader address and saved readings from this phone? This does not change the meter’s settings.',
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
    if (confirmed != true || !mounted) return;
    if (await widget.controller!.disconnect() && mounted) {
      _address.clear();
      widget.controller?.editingConnection = false;
      setState(() => _replacing = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.controller]),
    builder: (context, _) {
      final c = widget.controller;
      return _P1Card(
        children: [
          const Text(
            'Local monitoring only. Join the reader’s home network to connect.',
          ),
          const SizedBox(height: 8),
          if (widget.preview || c == null)
            const Text('Connect your P1 reader from the Android or iPhone app.')
          else ...[
            if (c.busy) const LinearProgressIndicator(),
            if (c.error != null)
              Text(
                c.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!c.initialized)
              const Text('Opening P1 connection…')
            else if (c.storageUnavailable) ...[
              FilledButton(
                onPressed: c.busy ? null : c.initialize,
                child: const Text('Retry P1 storage'),
              ),
              TextButton(
                onPressed: c.busy ? null : _remove,
                child: const Text('Remove P1 connection'),
              ),
            ] else if (c.connected && !_replacing) ...[
              const Text('P1 connection saved securely on this phone'),
              Text(c.address!.host),
              Text(c.status),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: c.busy
                        ? null
                        : () => setState(() {
                            c.editingConnection = true;
                            _replacing = true;
                            _address.text = c.address!.host;
                          }),
                    child: const Text('Replace P1 connection'),
                  ),
                  TextButton(
                    onPressed: c.busy ? null : _remove,
                    child: const Text('Remove P1 connection'),
                  ),
                ],
              ),
            ] else
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Enable local HTTP access for the P1 reader in its management app. This permits unencrypted local-network API access without authentication. This app only reads measurements.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('p1-address'),
                      controller: _address,
                      enabled: !c.busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'P1 reader IP address',
                        errorMaxLines: 3,
                        helperMaxLines: 2,
                        helperText:
                            'Private IPv4 address · port 8080 is automatic',
                      ),
                      validator: (value) {
                        try {
                          P1Address(value ?? '');
                          return null;
                        } on P1Failure catch (failure) {
                          return failure.message;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: c.canRequest ? _save : null,
                      child: Text(c.busy ? 'Connecting P1…' : 'Test & save P1'),
                    ),
                    if (_replacing)
                      TextButton(
                        onPressed: c.busy
                            ? null
                            : () {
                                _address.clear();
                                widget.controller?.editingConnection = false;
                                setState(() => _replacing = false);
                              },
                        child: const Text('Cancel P1 replacement'),
                      ),
                  ],
                ),
              ),
            if (c.wait > Duration.zero)
              Text('P1 request available in ${c.wait.inSeconds + 1}s.'),
            const SizedBox(height: 8),
            const Text(
              'Away from home, saved meter readings remain available in Details. If its address changes, replace this connection. Solar refresh waits are separate.',
            ),
          ],
        ],
      );
    },
  );
}

class P1DetailsCard extends StatelessWidget {
  const P1DetailsCard({super.key, this.controller, required this.openSettings});
  final P1Controller? controller;
  final VoidCallback openSettings;
  String _power(int? watts) =>
      watts == null ? 'Unavailable' : '${(watts / 1000).toStringAsFixed(3)} kW';
  String _energy(num? wh) =>
      wh == null ? 'Unavailable' : '${(wh / 1000).toStringAsFixed(3)} kWh';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller]),
    builder: (context, _) {
      final c = controller;
      final r = c?.reading;
      return _P1Card(
        children: [
          if (c?.busy ?? false) const LinearProgressIndicator(),
          if (c?.error != null)
            Text(
              c!.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (c != null && !c.initialized)
            const Text('Opening P1 connection…')
          else if (c?.storageUnavailable ?? false)
            TextButton(
              onPressed: c!.busy ? null : c.initialize,
              child: const Text('Retry P1 storage'),
            )
          else if (!(c?.connected ?? false)) ...[
            const Text('Connect your P1 reader to see grid import and export.'),
            FilledButton(
              onPressed: openSettings,
              child: const Text('Connect P1 meter'),
            ),
          ],
          if (c?.connected ?? false) ...[
            Text(
              c!.status,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              '${c.current ? 'Grid exchange' : 'Last measured grid exchange'}: ${switch (r?.direction) {
                GridDirection.importing => 'Importing',
                GridDirection.exporting => 'Exporting',
                GridDirection.balanced => 'No net exchange',
                _ => 'Unavailable',
              }}',
            ),
            Text(
              _power(r?.netWatts?.abs()),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (r?.netWatts == null)
              const Text(
                'Both import and export readings are needed to determine net exchange.',
              ),
            Text(
              'Meter time (Europe/Amsterdam): ${r == null ? 'Unavailable' : _meterTime(r.timestamp)}',
            ),
            if (c.measurementAge != null)
              Text(
                c.measurementAge!.isNegative
                    ? 'Meter clock is slightly ahead of this phone.'
                    : 'Measurement age: ${c.measurementAge!.inSeconds < 60 ? '${c.measurementAge!.inSeconds}s' : '${c.measurementAge!.inMinutes}m'}',
              ),
            OutlinedButton.icon(
              onPressed: c.canRequest ? c.refresh : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh P1 meter'),
            ),
            if (c.wait > Duration.zero)
              Text('Next P1 attempt in ${c.wait.inSeconds + 1}s.'),
            if (c.counterReset)
              const Text(
                'A tariff counter decreased during this connection. It may have reset or rolled over; no interval or daily energy is calculated.',
              ),
            ExpansionTile(
              title: const Text('Meter measurement details'),
              tilePadding: EdgeInsets.zero,
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (r != null)
                  Text(
                    'Measurement time (UTC): ${r.measuredAt.toIso8601String()}',
                  ),
                if (c.receivedAt != null)
                  Text('Received (UTC): ${c.receivedAt!.toIso8601String()}'),
                Text('Measured import: ${_power(r?.importWatts)}'),
                Text('Measured export: ${_power(r?.exportWatts)}'),
                const SizedBox(height: 8),
                Text(
                  'Cumulative import tariff 1: ${_energy(r?.fields['1-0:1.8.1'])}',
                ),
                Text(
                  'Cumulative import tariff 2: ${_energy(r?.fields['1-0:1.8.2'])}',
                ),
                Text(
                  'Cumulative export tariff 1: ${_energy(r?.fields['1-0:2.8.1'])}',
                ),
                Text(
                  'Cumulative export tariff 2: ${_energy(r?.fields['1-0:2.8.2'])}',
                ),
                const Text(
                  'These are meter totals, not today’s energy. Tariff 1/2 names do not assume your electricity contract.',
                ),
                const SizedBox(height: 8),
                for (var phase = 1; phase <= 3; phase++)
                  Text(
                    'L$phase: ${r?.fields['1-0:${phase * 2 + 1}2.7.0'] ?? 'Unavailable'} V · ${r?.fields['1-0:${phase * 2 + 1}1.7.0'] ?? 'Unavailable'} A',
                  ),
                const Text(
                  'Missing phases are unavailable, not zero. Phase readings may update at different times.',
                ),
                const Text(
                  'Source: electricity meter readings through your local P1 reader.',
                ),
              ],
            ),
            const Text(
              'Refreshes every 30 seconds while the app is open, backing off up to 5 minutes on failure. Meter readings become stale after 90 seconds. Away from home, only saved readings are available.',
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            'Grid exchange is not household consumption. Household use remains unavailable until meter coverage, battery AC power and measurement timing are verified.',
          ),
        ],
      );
    },
  );
  String _meterTime(String stamp) =>
      '20${stamp.substring(0, 2)}-${stamp.substring(2, 4)}-${stamp.substring(4, 6)} '
      '${stamp.substring(6, 8)}:${stamp.substring(8, 10)}:${stamp.substring(10, 12)} ${stamp.endsWith('S') ? 'CEST' : 'CET'}';
}

class _P1Card extends StatelessWidget {
  const _P1Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'P1 grid meter',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}
