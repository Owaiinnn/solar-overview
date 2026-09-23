import 'package:flutter/material.dart';

import 'connection_controller.dart';

class SolarApp extends StatefulWidget {
  const SolarApp({super.key, required this.controller, this.preview = false});
  final ConnectionController controller;
  final bool preview;

  @override
  State<SolarApp> createState() => _SolarAppState();
}

class _SolarAppState extends State<SolarApp> {
  late int _tab;

  @override
  void initState() {
    super.initState();
    _tab = widget.preview ? 0 : 1;
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return MaterialApp(
      title: 'Solar overview',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => widget.preview
          ? ColoredBox(
              color: const Color(0xFFE4EBE5),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: child,
                ),
              ),
            )
          : child!,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF22634A)),
        scaffoldBackgroundColor: const Color(0xFFF5F7F3),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          filled: true,
          fillColor: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => Scaffold(
          appBar: AppBar(
            title: const Text('Solar overview'),
            backgroundColor: const Color(0xFFF5F7F3),
          ),
          body: SafeArea(
            child: Column(
              children: [
                if (controller.busy) const LinearProgressIndicator(),
                if (controller.error != null)
                  Semantics(
                    liveRegion: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Card(
                        color: Theme.of(context).colorScheme.errorContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(controller.error!),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: !controller.initialized
                      ? const Center(
                          child: Text('Opening your saved connection…'),
                        )
                      : IndexedStack(
                          index: _tab,
                          children: [
                            OverviewPage(
                              controller: controller,
                              openSettings: () => setState(() => _tab = 1),
                            ),
                            SettingsPage(
                              controller: controller,
                              preview: widget.preview,
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: controller.busy
                ? null
                : (index) => setState(() => _tab = index),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.wb_sunny_outlined),
                selectedIcon: Icon(Icons.wb_sunny),
                label: 'Overview',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.preview = false,
  });
  final ConnectionController controller;
  final bool preview;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
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
          'The saved SolarEdge key will be removed from this phone. You can connect again later.',
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
    final controller = widget.controller;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your connections',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text('Connect SolarEdge to see what your panels are producing.'),
        const SizedBox(height: 24),
        Card(
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
                    'Explore the app with sample readings. Connect your real SolarEdge account from the Android or iPhone app.',
                  ),
                ] else if (controller.storageUnavailable) ...[
                  const Text(
                    'Your phone’s saved connection could not be opened.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: controller.busy
                            ? null
                            : controller.initialize,
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
        const SizedBox(height: 16),
        if (!widget.preview)
          const Text(
            'Your key stays in this phone’s protected storage and is used only to contact SolarEdge. Enter it separately on each phone.',
          ),
        const SizedBox(height: 24),
        if (widget.preview)
          const Text('No API key is needed for this preview.')
        else if (!controller.isSample)
          OutlinedButton(
            onPressed: controller.busy ? null : controller.showSample,
            child: const Text('Try sample data'),
          )
        else
          OutlinedButton(
            onPressed: controller.busy ? null : controller.leaveSample,
            child: const Text('Leave sample mode'),
          ),
        if (controller.isSample)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Sample mode is on. The Overview uses example readings.',
            ),
          ),
        const SizedBox(height: 24),
        Text('Coming later', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'PowerFlex battery and its two panels · Household smart meter',
        ),
      ],
    );
  }
}

class OverviewPage extends StatelessWidget {
  const OverviewPage({
    super.key,
    required this.controller,
    required this.openSettings,
  });
  final ConnectionController controller;
  final VoidCallback openSettings;

  @override
  Widget build(BuildContext context) {
    final data = controller.overview;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your solar, at a glance',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 12),
        Text(
          controller.isSample
              ? 'SAMPLE DATA · Example readings'
              : 'SolarEdge panels',
        ),
        const SizedBox(height: 24),
        if (!controller.connected && !controller.isSample) ...[
          const Text('Connect your SolarEdge site to see production here.'),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: openSettings,
            child: const Text('Connect SolarEdge'),
          ),
        ] else ...[
          _ReadingCard(
            label: 'Reported production',
            value: data?.powerWatts == null
                ? 'Unavailable'
                : '${(data!.powerWatts! / 1000).toStringAsFixed(2)} kW',
            icon: Icons.wb_sunny_outlined,
          ),
          const SizedBox(height: 12),
          _ReadingCard(
            label: 'Today’s energy',
            value: data?.energyWh == null
                ? 'Unavailable'
                : '${(data!.energyWh! / 1000).toStringAsFixed(2)} kWh',
            icon: Icons.bolt_outlined,
          ),
          const SizedBox(height: 16),
          if (!controller.isSample) ...[
            Text(
              'Last reported: ${data?.reportedAt ?? 'unavailable'}${data?.reportedAt == null ? '' : ' (site time)'}',
            ),
            const SizedBox(height: 8),
            const Text(
              'Cloud readings may lag behind your panels. Refresh is available every five minutes.',
            ),
            if (controller.error != null)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Any readings shown are from the last successful request.',
                ),
              ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.busy ? null : controller.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh readings'),
            ),
          ],
        ],
        const SizedBox(height: 28),
        const Text(
          'Your other energy sources',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        const Text(
          'PowerFlex solar & battery: not connected\nHousehold consumption: not connected',
        ),
        const SizedBox(height: 16),
        const Text(
          'Combined production and spare power for appliances will be available once those sources are connected.',
        ),
      ],
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(label),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.headlineMedium),
        ],
      ),
    ),
  );
}
