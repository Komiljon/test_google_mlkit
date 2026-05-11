import 'dart:io' show Platform;

/// True в **iOS Simulator**: нет полноценного ARKit для примерки, нативный слой только шумит в логах.
///
/// См. обсуждение в экране примерки: [AugenView] на симуляторе не монтируем.
bool get isIosSimulatorForAr {
  if (!Platform.isIOS) return false;
  return Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
      Platform.environment['SIMULATOR_UDID'] != null;
}

/// Короткая подсказка пользователю, если [AugenController.isARSupported] вернул false.
String get arUnavailableUserHint {
  if (Platform.isIOS) {
    return 'Запускайте на физическом iPhone с ARKit (обычно iPhone 6s и новее) и iOS не ниже целевой версии проекта. '
        'Симулятор Xcode AR не поддерживает — нужно реальное устройство.';
  }
  return 'Запускайте на устройстве с ARCore и камерой. В эмуляторе AR недоступен.';
}
