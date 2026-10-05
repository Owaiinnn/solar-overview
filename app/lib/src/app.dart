import 'dart:async';

import 'package:flutter/material.dart';

import 'connection_controller.dart';
import 'overview.dart';
import 'p1_controller.dart';
import 'p1_widgets.dart';
import 'home.dart';
import 'solax_controller.dart';
import 'solax_settings.dart';

class SolarApp extends StatefulWidget {
  const SolarApp({
    super.key,
    required this.controller,
    this.preview = false,
    this.solax,
    this.p1,
  });
  final P1Controller? p1;
  final SolaxController? solax;
  final ConnectionController controller;
  final bool preview;

  @override
  State<SolarApp> createState() => _SolarAppState();
}

enum _AppTab { home, appliances, history, settings }

class _SolarAppState extends State<SolarApp> with WidgetsBindingObserver {
  Timer? _freshnessTimer;
  Timer? _p1Timer;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _syncP1(state == null || state == AppLifecycleState.resumed);
    _freshnessTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      widget.controller.updateFreshness();
      widget.solax?.updateFreshness();
    });
  }

  void _syncP1(bool foreground) {
    _p1Timer?.cancel();
    widget.p1?.setForeground(foreground);
    if (foreground && widget.p1 != null) {
      _p1Timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => widget.p1?.tick(),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _syncP1(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      widget.controller.updateFreshness();
      widget.solax?.updateFreshness();
    }
  }

  @override
  void dispose() {
    _freshnessTimer?.cancel();
    _p1Timer?.cancel();
    widget.p1?.setForeground(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  _AppTab _tab = _AppTab.home;

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
        builder: (context, _) => PopScope(
          canPop: !(_tab == _AppTab.home && _showDetails),
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) setState(() => _showDetails = false);
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                _tab == _AppTab.home
                    ? (_showDetails ? 'Details' : 'Your solar home')
                    : 'Solar overview',
              ),
              leading: _tab == _AppTab.home && _showDetails
                  ? IconButton(
                      tooltip: 'Back to Home',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => setState(() => _showDetails = false),
                    )
                  : null,
              backgroundColor: const Color(0xFFF5F7F3),
            ),
            body: SafeArea(
              child: Column(
                children: [
                  if (_tab == _AppTab.settings && controller.busy)
                    const LinearProgressIndicator(),
                  if (_tab == _AppTab.settings && controller.error != null)
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
                    child: IndexedStack(
                      index: _tab.index,
                      children: [
                        IndexedStack(
                          index: _showDetails ? 1 : 0,
                          children: [
                            HomePage(
                              controller: controller,
                              solax: widget.solax,
                              active: _tab == _AppTab.home && !_showDetails,
                              openDetails: () =>
                                  setState(() => _showDetails = true),
                            ),
                            OverviewPage(
                              p1: widget.p1,
                              controller: controller,
                              solax: widget.solax,
                              openSettings: () =>
                                  setState(() => _tab = _AppTab.settings),
                            ),
                          ],
                        ),
                        const _ComingSoonPage(
                          title: 'Plan your appliance use',
                          icon: Icons.local_laundry_service_outlined,
                          description:
                              'Appliance planning is coming later. '
                              'You’ll be able to compare estimated appliance '
                              'demand with available power once your energy '
                              'sources are connected.',
                        ),
                        const _ComingSoonPage(
                          title: 'Your production history',
                          icon: Icons.show_chart,
                          description:
                              'Production history is coming later. '
                              'Your SolarEdge history will appear here once '
                              'history charts are available.',
                        ),
                        SettingsPage(
                          p1: widget.p1,
                          active: _tab == _AppTab.settings,
                          controller: controller,
                          preview: widget.preview,
                          solax: widget.solax,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: (index) => setState(() {
                _tab = _AppTab.values[index];
                if (_tab == _AppTab.home) _showDetails = false;
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.wb_sunny_outlined),
                  selectedIcon: Icon(Icons.wb_sunny),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_laundry_service_outlined),
                  selectedIcon: Icon(Icons.local_laundry_service),
                  label: 'Appliances',
                ),
                NavigationDestination(
                  icon: Icon(Icons.show_chart),
                  label: 'History',
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
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.preview = false,
    this.active = true,
    this.solax,
    this.p1,
  });
  final P1Controller? p1;
  final SolaxController? solax;
  final ConnectionController controller;
  final bool preview;
  final bool active;

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
    final controller = widget.controller;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Your connections',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect your solar sources to see what your panels are producing.',
        ),
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
        const SizedBox(height: 16),
        if (!widget.preview)
          const Text(
            'Your key stays in this phone’s protected storage and is used only to contact SolarEdge. Enter it separately on each phone.',
          ),
        const SizedBox(height: 24),
        if (widget.preview) ...[
          const Text('No API key is needed for this preview.'),
          const SizedBox(height: 24),
        ],
        SolaxSettingsCard(controller: widget.solax, preview: widget.preview),
        const SizedBox(height: 24),
        P1SettingsCard(
          controller: widget.p1,
          preview: widget.preview,
          active: widget.active,
        ),
        const SizedBox(height: 24),
        Text('Coming later', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'PowerFlex battery: unavailable — integration coming later.',
        ),
      ],
    );
  }
}

class _ComingSoonPage extends StatelessWidget {
  const _ComingSoonPage({
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 24),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                'Coming later',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(description),
            ],
          ),
        ),
      ),
    ],
  );
}
