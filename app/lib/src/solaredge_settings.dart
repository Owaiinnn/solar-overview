import 'package:flutter/material.dart';

import 'connection_controller.dart';

class SolarEdgeSettingsCard extends StatefulWidget {
  const SolarEdgeSettingsCard({
    super.key,
    required this.controller,
    this.preview = false,
  });

  final ConnectionController controller;
  final bool preview;

  @override
  State<SolarEdgeSettingsCard> createState() => _SolarEdgeSettingsCardState();
}

class _SolarEdgeSettingsCardState extends State<SolarEdgeSettingsCard>
    with AutomaticKeepAliveClientMixin<SolarEdgeSettingsCard> {
  @override
  bool get wantKeepAlive => true;

  final _form = GlobalKey<FormState>();
  final _site = TextEditingController();
  final _key = TextEditingController();
  bool _replacing = false;
  bool _showKey = false;

  @override
  void dispose() {
    _site.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final success = await widget.controller.connect(_site.text, _key.text);
    if (!mounted || !success) return;
    FocusScope.of(context).unfocus();
    _key.clear();
    _site.clear();
    setState(() {
      _replacing = false;
      _showKey = false;
    });
  }

  Future<void> _remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this connection?'),
        content: const Text(
          'The saved SolarEdge key and readings will be removed from this phone. The refresh wait will still apply.',
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
    final success = await widget.controller.disconnect();
    if (!mounted || !success) return;
    _key.clear();
    _site.clear();
    setState(() {
      _replacing = false;
      _showKey = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final controller = widget.controller;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.solar_power_outlined),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'SolarEdge',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.preview) ...[
                const Text(
                  'Browser preview',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Explore the app’s screens here. Connect your SolarEdge account from the Android or iPhone app to see real readings.',
                ),
              ] else if (controller.storageUnavailable) ...[
                const Text(
                  'Your phone’s saved connection or readings need attention.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: controller.busy ? null : controller.initialize,
                      child: const Text('Retry storage'),
                    ),
                    TextButton(
                      onPressed: controller.busy ? null : _remove,
                      child: const Text('Remove saved connection'),
                    ),
                  ],
                ),
              ] else if (controller.connected && !_replacing) ...[
                const Text(
                  'Connection saved on this phone',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text('Site ${controller.siteId}'),
                if (controller.refreshNotice != null)
                  Text(controller.refreshNotice!),
                const Text('API key saved securely'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: controller.busy
                          ? null
                          : () => setState(() {
                              _replacing = true;
                              _site.text = controller.siteId!;
                            }),
                      child: const Text('Replace connection'),
                    ),
                    TextButton(
                      onPressed: controller.busy ? null : _remove,
                      child: const Text('Remove connection'),
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
                        'Enter your details once. We’ll check the connection before saving them on this phone.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('site-id'),
                        controller: _site,
                        enabled: !controller.busy,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Site ID',
                          helperText: 'The site ID supplied by SolarEdge',
                        ),
                        validator: (value) =>
                            RegExp(r'^\d+$').hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter your numeric site ID.',
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        key: const Key('api-key'),
                        controller: _key,
                        enabled: !controller.busy,
                        obscureText: !_showKey,
                        autocorrect: false,
                        enableSuggestions: false,
                        enableIMEPersonalizedLearning: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!controller.busy) _save();
                        },
                        decoration: InputDecoration(
                          labelText: 'API key',
                          helperText: 'Your 32-character SolarEdge key',
                          suffixIcon: IconButton(
                            tooltip: _showKey ? 'Hide key' : 'Show key',
                            onPressed: controller.busy
                                ? null
                                : () => setState(() => _showKey = !_showKey),
                            icon: Icon(
                              _showKey
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            RegExp(r'^[a-zA-Z0-9]{32}$')
                                .hasMatch(value?.trim() ?? '')
                            ? null
                            : 'Enter a 32-character API key.',
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: controller.busy ? null : _save,
                        icon: const Icon(Icons.lock_outline),
                        label: Text(
                          controller.busy
                              ? 'Connecting…'
                              : 'Test & save connection',
                        ),
                      ),
                      if (_replacing)
                        TextButton(
                          onPressed: controller.busy
                              ? null
                              : () {
                                  _key.clear();
                                  setState(() {
                                    _replacing = false;
                                    _showKey = false;
                                  });
                                },
                          child: const Text('Cancel replacement'),
                        ),
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
