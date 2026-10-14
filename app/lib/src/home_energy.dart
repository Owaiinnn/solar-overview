import 'battery.dart';
import 'battery_controller.dart';
import 'p1.dart';
import 'p1_controller.dart';

enum LocalReadingQuality {
  notConfigured,
  loading,
  recent,
  saved,
  stale,
  offline,
  storageError,
  missing,
  invalidTime,
}

String _qualityLabel(LocalReadingQuality quality) => switch (quality) {
  LocalReadingQuality.notConfigured => 'Not connected',
  LocalReadingQuality.loading => 'Loading',
  LocalReadingQuality.recent => 'Recent',
  LocalReadingQuality.saved => 'Saved · current status unavailable',
  LocalReadingQuality.stale => 'Stale · current status unavailable',
  LocalReadingQuality.offline => 'Offline or failed · check Details',
  LocalReadingQuality.storageError => 'Storage needs attention',
  LocalReadingQuality.missing => 'No reading available',
  LocalReadingQuality.invalidTime => 'Reading time unavailable',
};

String energyPowerLabel(num watts) => watts.abs() < 1000
    ? '${watts.abs().toStringAsFixed(0)} W'
    : '${(watts.abs() / 1000).toStringAsFixed(2)} kW';

class HomeBatteryState {
  const HomeBatteryState({
    this.quality = LocalReadingQuality.notConfigured,
    this.percent,
    this.state = BatteryState.unknown,
    this.packWatts,
    this.conflict = false,
    this.refreshing = false,
  });

  factory HomeBatteryState.fromController(BatteryController? controller) {
    if (controller == null) return const HomeBatteryState();
    final reading = controller.reading;
    final age = controller.receiptAge;
    final quality = controller.storageUnavailable
        ? LocalReadingQuality.storageError
        : !controller.initialized
        ? LocalReadingQuality.loading
        : !controller.connected
        ? LocalReadingQuality.notConfigured
        : controller.error != null
        ? LocalReadingQuality.offline
        : reading == null
        ? controller.busy
              ? LocalReadingQuality.loading
              : LocalReadingQuality.missing
        : age == null || age.isNegative
        ? LocalReadingQuality.invalidTime
        : age >= BatteryController.receiptWindow
        ? LocalReadingQuality.stale
        : controller.recentlyReceived
        ? LocalReadingQuality.recent
        : LocalReadingQuality.saved;
    return HomeBatteryState(
      quality: quality,
      percent: reading?.percent,
      state: reading?.state ?? BatteryState.unknown,
      packWatts: reading?.packWatts,
      conflict: reading?.statePowerConflict ?? false,
      refreshing: controller.busy,
    );
  }

  final LocalReadingQuality quality;
  final double? percent;
  final BatteryState state;
  final double? packWatts;
  final bool conflict;
  final bool refreshing;

  bool get visible => quality != LocalReadingQuality.notConfigured;
  bool get recent => quality == LocalReadingQuality.recent;
  bool get inconsistent =>
      conflict ||
      (packWatts == 0 &&
          (state == BatteryState.charging ||
              state == BatteryState.discharging));
  BatteryState get reportedState =>
      recent && !inconsistent ? state : BatteryState.unknown;
  bool get moving =>
      packWatts != null &&
      ((reportedState == BatteryState.charging && packWatts! < 0) ||
          (reportedState == BatteryState.discharging && packWatts! > 0));
  String get status => quality == LocalReadingQuality.loading
      ? 'Loading'
      : switch (reportedState) {
          BatteryState.charging => 'Charging',
          BatteryState.discharging => 'Discharging',
          BatteryState.idle => 'Idle',
          BatteryState.unknown => 'Unavailable',
        };
  String get levelLabel => percent == null
      ? 'Level unavailable'
      : '${recent ? '' : 'Last known · '}${percent!.toStringAsFixed(0)}%';
  String? get powerLabel => recent && !inconsistent && packWatts != null
      ? '${energyPowerLabel(packWatts!)} pack DC'
      : null;
  String get qualification => recent
      ? inconsistent
            ? 'State and power disagree'
            : '${refreshing ? 'Refreshing' : 'Reported'} · source time unknown'
      : _qualityLabel(quality);
  String get semantics =>
      'Battery. $levelLabel. $status. ${powerLabel ?? ''}. $qualification.';
}

class HomeGridState {
  const HomeGridState({
    this.quality = LocalReadingQuality.notConfigured,
    this.direction = GridDirection.unavailable,
    this.watts,
    this.refreshing = false,
  });

  factory HomeGridState.fromController(P1Controller? controller) {
    if (controller == null) return const HomeGridState();
    final reading = controller.reading;
    final age = controller.receiptAge;
    final measuredAge = controller.measurementAge;
    final quality = controller.storageUnavailable
        ? LocalReadingQuality.storageError
        : !controller.initialized
        ? LocalReadingQuality.loading
        : !controller.connected
        ? LocalReadingQuality.notConfigured
        : controller.error != null
        ? LocalReadingQuality.offline
        : reading == null
        ? controller.busy
              ? LocalReadingQuality.loading
              : LocalReadingQuality.missing
        : age == null ||
              age.isNegative ||
              measuredAge == null ||
              measuredAge < -P1Controller.clockTolerance
        ? LocalReadingQuality.invalidTime
        : age >= P1Controller.freshnessWindow ||
              measuredAge >= P1Controller.freshnessWindow
        ? LocalReadingQuality.stale
        : controller.current
        ? LocalReadingQuality.recent
        : LocalReadingQuality.saved;
    return HomeGridState(
      quality: quality,
      direction: reading?.direction ?? GridDirection.unavailable,
      watts: reading?.netWatts,
      refreshing: controller.busy,
    );
  }

  final LocalReadingQuality quality;
  final GridDirection direction;
  final int? watts;
  final bool refreshing;

  bool get visible => quality != LocalReadingQuality.notConfigured;
  bool get eligible =>
      quality == LocalReadingQuality.recent &&
      switch (direction) {
        GridDirection.importing => watts != null && watts! > 0,
        GridDirection.exporting => watts != null && watts! < 0,
        GridDirection.balanced => watts == 0,
        GridDirection.unavailable => false,
      };
  bool get moving => eligible && direction != GridDirection.balanced;
  String get status => quality == LocalReadingQuality.loading
      ? 'Loading'
      : !eligible
      ? 'Unavailable'
      : switch (direction) {
          GridDirection.importing => 'Importing',
          GridDirection.exporting => 'Exporting',
          GridDirection.balanced => 'No net exchange',
          GridDirection.unavailable => 'Unavailable',
        };
  String? get powerLabel => eligible ? energyPowerLabel(watts!) : null;
  String get qualification => quality == LocalReadingQuality.recent
      ? eligible
            ? '${refreshing ? 'Refreshing' : 'Recent'} · meter reading'
            : 'Grid direction unconfirmed'
      : _qualityLabel(quality);
  String get semantics => 'Grid. $status. ${powerLabel ?? ''}. $qualification.';
}
