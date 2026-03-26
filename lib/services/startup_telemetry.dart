import 'package:flutter/foundation.dart';

class StartupTelemetry {
  final Stopwatch _stopwatch = Stopwatch();

  Duration? _snapshotHydratedAt;
  Duration? _shellShownAt;
  Duration? _onlineRevalidateFinishedAt;

  void startIfNeeded() {
    if (_stopwatch.isRunning) {
      return;
    }

    _stopwatch.start();
    debugPrint('[startup] main() started');
  }

  void markSnapshotHydrated() {
    _snapshotHydratedAt ??= _stopwatch.elapsed;
    debugPrint(
      '[startup] snapshot hydrated in ${_snapshotHydratedAt!.inMilliseconds}ms',
    );
  }

  void markShellShown() {
    _shellShownAt ??= _stopwatch.elapsed;
    debugPrint('[startup] shell shown in ${_shellShownAt!.inMilliseconds}ms');
  }

  void markOnlineRevalidateFinished({required bool readOnlyOffline}) {
    _onlineRevalidateFinishedAt ??= _stopwatch.elapsed;
    debugPrint(
      '[startup] online revalidate finished in '
      '${_onlineRevalidateFinishedAt!.inMilliseconds}ms '
      '(readOnlyOffline=$readOnlyOffline)',
    );
  }

  String buildSummary() {
    final snapshotMs = _snapshotHydratedAt?.inMilliseconds;
    final shellMs = _shellShownAt?.inMilliseconds;
    final validateMs = _onlineRevalidateFinishedAt?.inMilliseconds;
    return '[startup] summary snapshot=${snapshotMs ?? '-'}ms '
        'shell=${shellMs ?? '-'}ms '
        'revalidate=${validateMs ?? '-'}ms';
  }
}
