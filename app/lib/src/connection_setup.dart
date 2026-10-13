import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'battery_controller.dart';
import 'connection_controller.dart';
import 'connection_import.dart';
import 'overview.dart';
import 'p1_controller.dart';
import 'solax_controller.dart';

class ConnectionDetailsPage extends StatefulWidget {
  const ConnectionDetailsPage({
    super.key,
    required this.controller,
    required this.openSettings,
    this.solax,
    this.p1,
    this.battery,
    this.preview = false,
  });
  final ConnectionController controller;
  final SolaxController? solax;
  final P1Controller? p1;
  final BatteryController? battery;
  final VoidCallback openSettings;
  final bool preview;

  @override
  State<ConnectionDetailsPage> createState() => _ConnectionDetailsPageState();
}

class _ConnectionDetailsPageState extends State<ConnectionDetailsPage> {
  bool _importSession = false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      widget.controller,
      widget.solax,
      widget.p1,
      widget.battery,
    ]),
    builder: (context, _) {
      final ready =
          widget.controller.initialized &&
          (widget.solax?.initialized ?? true) &&
          (widget.p1?.initialized ?? true) &&
          (widget.battery?.initialized ?? true);
      final attention =
          widget.controller.storageUnavailable ||
          (widget.solax?.storageUnavailable ?? false) ||
          (widget.p1?.storageUnavailable ?? false) ||
          (widget.battery?.storageUnavailable ?? false);
      final connected =
          widget.controller.connected ||
          (widget.solax?.connected ?? false) ||
          (widget.p1?.connected ?? false) ||
          (widget.battery?.connected ?? false);
      if (!widget.preview &&
          (_importSession || (ready && !attention && !connected))) {
        return ConnectionSetupPage(
          controller: widget.controller,
          solax: widget.solax,
          p1: widget.p1,
          battery: widget.battery,
          onStarted: () => setState(() => _importSession = true),
          onFinished: () => setState(() => _importSession = false),
          openSettings: widget.openSettings,
        );
      }
      return OverviewPage(
        controller: widget.controller,
        solax: widget.solax,
        p1: widget.p1,
        battery: widget.battery,
        openSettings: widget.openSettings,
        configuredOnly: !widget.preview,
      );
    },
  );
}

class ConnectionSetupPage extends StatefulWidget {
  const ConnectionSetupPage({
    super.key,
    required this.controller,
    required this.onStarted,
    required this.onFinished,
    required this.openSettings,
    this.solax,
    this.p1,
    this.battery,
    this.chooseFile,
  });
  final ConnectionController controller;
  final SolaxController? solax;
  final P1Controller? p1;
  final BatteryController? battery;
  final VoidCallback onStarted;
  final VoidCallback onFinished;
  final VoidCallback openSettings;
  final Future<XFile?> Function()? chooseFile;

  @override
  State<ConnectionSetupPage> createState() => _ConnectionSetupPageState();
}

class _ConnectionSetupPageState extends State<ConnectionSetupPage> {
  final _json = TextEditingController();
  final _scroll = ScrollController();
  ConnectionImport? _candidate;
  Map<String, bool>? _results;
  String? _error;
  bool _busy = false;
  bool _showJson = false;

  @override
  void dispose() {
    _json.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _review(String text) {
    try {
      final candidate = ConnectionImport.parse(text);
      setState(() {
        _candidate = candidate;
        _error = null;
        _json.clear();
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
      FocusScope.of(context).unfocus();
    } on ConnectionImportFailure catch (failure) {
      setState(() => _error = failure.message);
    }
  }

  Future<void> _loadFile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final file =
          await (widget.chooseFile?.call() ??
              openFile(
                acceptedTypeGroups: const [
                  XTypeGroup(
                    label: 'JSON setup',
                    extensions: ['json'],
                    mimeTypes: ['application/json'],
                    uniformTypeIdentifiers: ['public.json'],
                  ),
                ],
              ));
      if (file == null || !mounted) return;
      if (await file.length() > ConnectionImport.maxBytes) {
        throw const ConnectionImportFailure(
          'Choose a JSON file smaller than 32 KB.',
        );
      }
      final text = await file.readAsString();
      if (mounted) _review(text);
    } catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure is ConnectionImportFailure ? failure.message : 'Could not open that file. Choose a JSON file or paste its contents.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (_busy || _candidate == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    widget.onStarted();
    try {
      final results = await _candidate!.save(
        controller: widget.controller,
        solaxController: widget.solax,
        p1Controller: widget.p1,
        batteryController: widget.battery,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _candidate = null;
        });
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    } catch (failure) {
      if (mounted) {
        setState(
          () => _error = failure is ConnectionImportFailure
              ? failure.message
              : 'Could not save connections. Check Settings before retrying.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    controller: _scroll,
    padding: const EdgeInsets.all(24),
    children: [
      Text(
        'Set up your connections',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      const Text(
        'Restore your connections from a JSON file, paste its contents, or enter each connection manually.',
      ),
      const SizedBox(height: 24),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) ...[
        Semantics(
          liveRegion: true,
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (_results case final results?) ...[
        for (final entry in results.entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              entry.value ? Icons.check_circle_outline : Icons.error_outline,
            ),
            title: Text(entry.key),
            subtitle: Text(
              entry.value
                  ? 'Saved · readings not checked yet'
                  : 'Not saved · finish in Manual setup',
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Refresh readings in Details or reopen the app to connect. The meter and battery need your home network.',
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : widget.onFinished,
          child: const Text('Continue to details'),
        ),
      ] else if (_candidate case final candidate?) ...[
        Text(
          'Ready to save: ${candidate.sources.join(', ')}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        const Text(
          'Save on this phone now, even when offline. Connection details will be checked when readings are requested.',
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _save,
          icon: const Icon(Icons.lock_outline),
          label: const Text('Save connections'),
        ),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _candidate = null),
          child: const Text('Choose different JSON'),
        ),
      ] else ...[
        FilledButton.icon(
          onPressed: _busy ? null : _loadFile,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('Load JSON file'),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const Key('connection-json'),
          controller: _json,
          enabled: !_busy,
          obscureText: !_showJson,
          maxLines: _showJson ? 8 : 1,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          decoration: InputDecoration(
            labelText: 'Paste JSON',
            suffixIcon: IconButton(
              onPressed: _busy
                  ? null
                  : () => setState(() => _showJson = !_showJson),
              tooltip: _showJson ? 'Hide JSON' : 'Show JSON',
              icon: Icon(
                _showJson
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _busy ? null : () => _review(_json.text),
          child: const Text('Review JSON'),
        ),
        ExpansionTile(
          title: const Text('JSON template'),
          children: [
            const Text(
              'Replace the placeholders and remove any source you do not use. SolaX uses EU access and inverter model 28.',
            ),
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(
                  const ClipboardData(text: ConnectionImport.template),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Template copied')),
                  );
                }
              },
              icon: const Icon(Icons.copy_outlined),
              label: const Text('Copy template'),
            ),
            const SelectableText(ConnectionImport.template),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Your JSON contains private keys. Keep your copy somewhere private. Imported connections use this phone’s protected storage.',
        ),
      ],
      const SizedBox(height: 16),
      TextButton(
        onPressed: _busy
            ? null
            : () {
                _json.clear();
                setState(() {
                  _candidate = null;
                  _results = null;
                });
                widget.onFinished();
                widget.openSettings();
              },
        child: const Text('Manual setup'),
      ),
    ],
  );
}
