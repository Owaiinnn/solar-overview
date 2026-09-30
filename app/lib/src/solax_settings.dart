import 'package:flutter/material.dart';

import 'solax.dart';
import 'solax_controller.dart';
import 'solaredge.dart' show ReadingFreshness;

class SolaxSettingsCard extends StatefulWidget {
  const SolaxSettingsCard({super.key, this.controller, this.preview = false});
  final SolaxController? controller;
  final bool preview;
  @override
  State<SolaxSettingsCard> createState() => _SolaxSettingsCardState();
}

class _SolaxSettingsCardState extends State<SolaxSettingsCard> {
  final _id = TextEditingController();
  final _secret = TextEditingController();
  bool _replacing = false;
  bool _dedicated = false;
  @override
  void dispose() {
    _id.dispose();
    _secret.dispose();
    super.dispose();
  }

  void _clear() {
    _id.clear();
    _secret.clear();
    _dedicated = false;
  }

  Future<void> _discover() async {
    FocusScope.of(context).unfocus();
    if (await widget.controller!.discover(_id.text, _secret.text) && mounted) {
      setState(_clear);
    }
  }

  Future<void> _save() async {
    if (await widget.controller!.saveSelection() && mounted) {
      setState(() {
        _replacing = false;
        _clear();
      });
    }
  }

  Future<void> _remove() async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove SolaX connection?'),
        content: const Text(
          'Remove saved SolaX credentials, token and readings from this phone?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove SolaX'),
          ),
        ],
      ),
    );
    if (remove != true || !mounted) return;
    if (await widget.controller!.disconnect() && mounted) {
      setState(() {
        _replacing = false;
        _clear();
      });
    }
  }

  String _suffix(String value) =>
      value.length > 6 ? '…${value.substring(value.length - 6)}' : value;
  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (widget.preview || c == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SolaX',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                'Connect your SolaX inverter from the Android or iPhone app. Browser preview has no live connection.',
              ),
            ],
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'SolaX',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text('EU region · X1-Micro 2 in 1'),
              const SizedBox(height: 12),
              if (c.busy) const LinearProgressIndicator(),
              if (c.error != null)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    c.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!c.initialized)
                const Text('Opening SolaX connection…')
              else if (c.storageUnavailable) ...[
                const Text('SolaX secure storage needs attention.'),
                TextButton(
                  onPressed: c.busy ? null : c.initialize,
                  child: const Text('Retry SolaX storage'),
                ),
                TextButton(
                  onPressed: c.busy ? null : _remove,
                  child: const Text('Remove saved SolaX connection'),
                ),
              ] else if (c.selecting) ...[
                const Text('Choose the plant and inverter to monitor.'),
                DropdownButtonFormField<SolaxPlant>(
                  key: ValueKey(c.plants),
                  initialValue: c.selectedPlant,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'SolaX plant'),
                  items: [
                    for (var i = 0; i < c.plants.length; i++)
                      DropdownMenuItem(
                        value: c.plants[i],
                        child: Text(
                          'Plant ${i + 1} · ${_suffix(c.plants[i].id)}',
                        ),
                      ),
                  ],
                  onChanged: c.busy
                      ? null
                      : (plant) {
                          if (plant != null) c.selectPlant(plant);
                        },
                ),
                const SizedBox(height: 12),
                if (c.selectedPlant != null)
                  DropdownButtonFormField<SolaxDevice>(
                    key: ValueKey(c.devices),
                    initialValue: c.selectedDevice,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'SolaX inverter',
                    ),
                    items: [
                      for (final device in c.devices)
                        DropdownMenuItem(
                          value: device,
                          enabled: device.supported,
                          child: Text(
                            '${_suffix(device.sn)} · ${device.supported ? 'X1-Micro 2 in 1' : 'Unsupported model'}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: c.busy
                        ? null
                        : (device) {
                            if (device != null) c.selectDevice(device);
                          },
                  ),
                if (c.devices.isNotEmpty && !c.devices.any((d) => d.supported))
                  const Text(
                    'No supported inverter was found. This version supports the X1-Micro 2 in 1.',
                  ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: c.busy || c.selectedDevice == null ? null : _save,
                  child: const Text('Test & save SolaX connection'),
                ),
                TextButton(
                  onPressed: c.busy
                      ? null
                      : () {
                          c.cancelSelection();
                          setState(() {
                            _replacing = false;
                            _clear();
                          });
                        },
                  child: const Text('Cancel SolaX setup'),
                ),
              ] else if (c.connected && !_replacing) ...[
                const Text('SolaX connection saved on this phone'),
                if (c.reconnectRequired)
                  const Text(
                    'Reconnect with an application used only by this phone.',
                  ),
                if (c.reading case final reading?) ...[
                  const SizedBox(height: 12),
                  Text(switch (c.freshness) {
                    ReadingFreshness.recent => 'Recent SolaX reading',
                    ReadingFreshness.stale => 'Stale SolaX reading',
                    ReadingFreshness.unknown => 'SolaX freshness unavailable',
                  }),
                  if (c.usingSavedReading)
                    const Text('Showing the saved SolaX reading.'),
                  Text('Inverter status: ${reading.status}'),
                  Text('AC output: ${_value(reading.powerWatts, 'W')}'),
                  Text(
                    'Today’s inverter AC energy: ${_value(c.todayEnergyWh == null ? null : c.todayEnergyWh! / 1000, 'kWh')}',
                  ),
                  const Text(
                    'Device energy counters may reset or differ from plant totals.',
                  ),
                  Text(
                    'Source time (UTC): ${reading.reportedAtUtc?.toIso8601String() ?? 'Unavailable'}',
                  ),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: c.canRequest && !c.reconnectRequired
                          ? c.refresh
                          : null,
                      child: const Text('Refresh SolaX'),
                    ),
                    TextButton(
                      onPressed: c.busy
                          ? null
                          : () => setState(() {
                              _replacing = true;
                              _clear();
                            }),
                      child: const Text('Replace SolaX connection'),
                    ),
                    TextButton(
                      onPressed: c.busy ? null : _remove,
                      child: const Text('Remove SolaX connection'),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Use a separate SolaX developer application for each phone. Sharing an application disconnects the other phone. Enable Information Management and Monitoring Management access.',
                ),
                const SizedBox(height: 16),
                TextField(
                  key: const Key('solax-client-id'),
                  controller: _id,
                  enabled: !c.busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: const InputDecoration(
                    labelText: 'SolaX client ID',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('solax-secret'),
                  controller: _secret,
                  obscureText: true,
                  enabled: !c.busy,
                  autocorrect: false,
                  enableSuggestions: false,
                  enableIMEPersonalizedLearning: false,
                  decoration: const InputDecoration(
                    labelText: 'SolaX client secret',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _dedicated,
                  title: const Text(
                    'This application is used only on this phone',
                  ),
                  onChanged: c.busy
                      ? null
                      : (value) => setState(() => _dedicated = value ?? false),
                ),
                FilledButton(
                  onPressed: !c.canRequest || !_dedicated ? null : _discover,
                  child: const Text('Test SolaX & find plants'),
                ),
                if (_replacing)
                  TextButton(
                    onPressed: c.busy
                        ? null
                        : () => setState(() {
                            _replacing = false;
                            _clear();
                          }),
                    child: const Text('Cancel SolaX replacement'),
                  ),
              ],
              if (c.refreshNotice != null) Text(c.refreshNotice!),
            ],
          ),
        ),
      ),
    );
  }

  String _value(double? value, String unit) => value == null
      ? 'Unavailable'
      : '${value.toStringAsFixed(unit == 'kWh' ? 2 : 0)} $unit';
}
