class WebPushEnvironment {
  static bool get isIosBrowser => false;

  static bool get isStandaloneDisplayMode => false;

  static bool get shouldShowIosInstallBanner => false;

  static bool get hasDriveReconnectParam => false;

  static void clearDriveReconnectParam() {}

  static void clearPushQueryParameters() {}
}
