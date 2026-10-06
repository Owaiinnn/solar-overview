import 'package:flutter/material.dart';

import 'connection_controller.dart';
import 'p1_controller.dart';
import 'p1_widgets.dart';
import 'solaredge_settings.dart';
import 'solax_controller.dart';
import 'solax_settings.dart';

class SettingsPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
        SolarEdgeSettingsCard(controller: controller, preview: preview),
        const SizedBox(height: 16),
        if (!preview)
          const Text(
            'Your key stays in this phone’s protected storage and is used only to contact SolarEdge. Enter it separately on each phone.',
          ),
        const SizedBox(height: 24),
        if (preview) ...[
          const Text('No API key is needed for this preview.'),
          const SizedBox(height: 24),
        ],
        SolaxSettingsCard(controller: solax, preview: preview),
        const SizedBox(height: 24),
        P1SettingsCard(controller: p1, preview: preview, active: active),
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
