import 'package:flutter_foreground_task/flutter_foreground_task.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // no-op: the main isolate handles BLE; this task just keeps the process alive
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Send a lightweight heartbeat to main isolate; main can ignore if not needed
    FlutterForegroundTask.sendDataToMain({'heartbeat': timestamp.millisecondsSinceEpoch});
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // cleanup if needed
  }
}
