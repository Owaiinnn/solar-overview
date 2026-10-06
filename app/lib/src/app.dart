import 'dart:async';

import 'package:flutter/material.dart';

import 'connection_controller.dart';
import 'home.dart';
import 'overview.dart';
import 'p1_controller.dart';
import 'settings.dart';
import 'solax_controller.dart';

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
