import 'package:flutter/material.dart';

import 'battery.dart';
import 'battery_controller.dart';

class BatterySettingsCard extends StatefulWidget {
  const BatterySettingsCard({super.key, this.controller, this.preview = false});
  final BatteryController? controller;
  final bool preview;
  @override
  State<BatterySettingsCard> createState() => _BatterySettingsCardState();
}

class _BatterySettingsCardState extends State<BatterySettingsCard> {
  final _address = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _replacing = false;
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
        title: const Text('Remove battery connection?'),
        content: const Text(
          'Remove the battery address and saved readings from this phone? This does not change the battery’s settings.',
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
      return _BatteryCard(
        children: [
          const Text(
            'Local monitoring only. Join the battery’s home network to connect.',
          ),
          const SizedBox(height: 8),
          if (widget.preview || c == null)
            const Text('Connect your battery from the Android or iPhone app.')
          else ...[
            if (c.busy) const LinearProgressIndicator(),
            if (c.error != null)
              Text(
                c.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!c.initialized)
              const Text('Opening battery connection…')
            else if (c.storageUnavailable) ...[
              FilledButton(
                onPressed: c.busy ? null : c.initialize,
                child: const Text('Retry battery storage'),
              ),
              TextButton(
                onPressed: c.busy ? null : _remove,
                child: const Text('Remove battery connection'),
              ),
            ] else if (c.connected && !_replacing) ...[
              const Text('Battery connection saved securely on this phone'),
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
                    child: const Text('Replace battery connection'),
                  ),
                  TextButton(
                    onPressed: c.busy ? null : _remove,
                    child: const Text('Remove battery connection'),
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
                      'Enable HTTP in the INDEVOLT app. This permits unencrypted local-network API access without authentication. This app only reads measurements.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('battery-address'),
                      controller: _address,
                      enabled: !c.busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Battery IP address',
                        errorMaxLines: 3,
                        helperMaxLines: 2,
                        helperText:
                            'Private IPv4 address · port 8080 is automatic',
                      ),
                      validator: (value) {
                        try {
                          BatteryAddress(value ?? '');
                          return null;
                        } on BatteryFailure catch (failure) {
                          return failure.message;
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: c.canRequest ? _save : null,
                      child: Text(
                        c.busy ? 'Connecting battery…' : 'Test & save battery',
                      ),
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
                        child: const Text('Cancel battery replacement'),
                      ),
                  ],
                ),
              ),
            if (c.wait > Duration.zero)
              Text('Battery request available in ${c.wait.inSeconds + 1}s.'),
            const SizedBox(height: 8),
            const Text(
              'Away from home, saved readings remain available in Details. If its address changes, replace this connection. Solar refresh waits are separate.',
            ),
          ],
        ],
      );
    },
  );
}

class BatteryDetailsCard extends StatelessWidget {
  const BatteryDetailsCard({
    super.key,
    this.controller,
    required this.openSettings,
  });
  final BatteryController? controller;
  final VoidCallback openSettings;
  String _value(double? value, String unit, {int decimals = 0}) => value == null
      ? 'Unavailable'
      : '${value.toStringAsFixed(decimals)} $unit';
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([controller]),
    builder: (context, _) {
      final c = controller;
      final r = c?.reading;
      final recent = c?.recentlyReceived ?? false;
      final age = c?.receiptAge;
      final ageLabel = age == null || age.isNegative
          ? 'Unknown'
          : age.inSeconds < 60
          ? '${age.inSeconds}s ago'
          : age.inMinutes < 60
          ? '${age.inMinutes}m ago'
          : '${age.inHours}h ago';
      return _BatteryCard(
        children: [
          if (c?.busy ?? false) const LinearProgressIndicator(),
          if (c?.error != null)
            Text(
              c!.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (c != null && !c.initialized)
            const Text('Opening battery connection…')
          else if (c?.storageUnavailable ?? false)
            TextButton(
              onPressed: c!.busy ? null : c.initialize,
              child: const Text('Retry battery storage'),
            )
          else if (!(c?.connected ?? false)) ...[
            const Text(
              'Connect your INDEVOLT battery to see its readings here.',
            ),
            FilledButton(
              onPressed: openSettings,
              child: const Text('Connect battery'),
            ),
          ],
          if (c?.connected ?? false) ...[
            Text(
              c!.status,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              '${recent ? 'Reported' : 'Saved'} battery level: ${_value(r?.percent, '%')}',
            ),
            Text(
              '${recent ? 'Reported' : 'Last reported'} state: ${switch (r?.state) {
                BatteryState.charging => 'Charging',
                BatteryState.discharging => 'Discharging',
                BatteryState.idle => 'Idle',
                _ => 'Unknown',
              }}',
            ),
            Text(
              '${recent ? 'Reported' : 'Saved'} pack DC power: ${_value(r?.packWatts, 'W')}',
            ),
            if (r?.statePowerConflict ?? false)
              const Text(
                'Reported state and power disagree. Battery flow is unconfirmed.',
              ),
            const Text(
              'Pack power: negative = charging; positive = discharging. This is not household AC power or solar production.',
            ),
            const SizedBox(height: 12),
            Text('Received: $ageLabel'),
            if (c.receivedAt != null)
              Text('Receipt time (UTC): ${c.receivedAt!.toIso8601String()}'),
            const Text(
              'Measurement time is unavailable. A recent response does not confirm that the device’s measurements are current.',
            ),
            OutlinedButton.icon(
              onPressed: c.canRequest ? c.refresh : null,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh battery'),
            ),
            if (c.wait > Duration.zero)
              Text('Next battery attempt in ${c.wait.inSeconds + 1}s.'),
            ExpansionTile(
              title: const Text('Battery measurement details'),
              tilePadding: EdgeInsets.zero,
              children: [
                Text(
                  'Reported inverter AC power: ${_value(r?.inverterAcWatts, 'W')}',
                ),
                Text(
                  'Reported total AC power: ${_value(r?.totalAcWatts, 'W')}',
                ),
                const Text(
                  'AC power uses the opposite sign: positive input, negative output. Total AC may include bypass flow; its wiring boundaries remain unverified.',
                ),
                Text(
                  'Last reported daily charge counter: ${_value(r?.dailyChargeKwh, 'kWh', decimals: 3)}',
                ),
                Text(
                  'Last reported daily discharge counter: ${_value(r?.dailyDischargeKwh, 'kWh', decimals: 3)}',
                ),
                const Text(
                  'Daily counters are device-reported values. Reset timing and completeness are unverified; these are not confirmed totals for today.',
                ),
                const Text(
                  'Available energy: unavailable until usable capacity and reserve are verified.',
                ),
              ],
            ),
            const Text(
              'Refreshes every 30 seconds while the app is open; failed requests back off up to 5 minutes. After 90 seconds without success, readings are saved only.',
            ),
          ],
        ],
      );
    },
  );
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'INDEVOLT PowerFlex battery',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}
