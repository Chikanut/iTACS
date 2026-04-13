import "package:web/web.dart" as web;

class WebPushEnvironment {
  static bool get isIosBrowser {
    final userAgent = web.window.navigator.userAgent.toLowerCase();
    return userAgent.contains("iphone") ||
        userAgent.contains("ipad") ||
        userAgent.contains("ipod");
  }

  static bool get isStandaloneDisplayMode =>
      web.window.matchMedia("(display-mode: standalone)").matches;

  static bool get shouldShowIosInstallBanner =>
      isIosBrowser && !isStandaloneDisplayMode;

  static bool get hasDriveReconnectParam =>
      Uri.base.queryParameters.containsKey('driveReconnect');

  static void clearDriveReconnectParam() {
    final uri = Uri.base;
    if (!uri.queryParameters.containsKey('driveReconnect')) return;

    final sanitizedParameters = Map<String, String>.from(uri.queryParameters)
      ..remove('driveReconnect');

    final sanitizedUri = uri.replace(
      queryParameters: sanitizedParameters.isEmpty ? null : sanitizedParameters,
    );
    final query = sanitizedUri.hasQuery ? '?${sanitizedUri.query}' : '';
    final hash = sanitizedUri.hasFragment ? '#${sanitizedUri.fragment}' : '';

    web.window.history.replaceState(
      null,
      '',
      '${sanitizedUri.path}$query$hash',
    );
  }

  static void clearPushQueryParameters() {
    final uri = Uri.base;
    if (!uri.queryParameters.keys.any((key) => key.startsWith("push"))) {
      return;
    }

    final sanitizedParameters = Map<String, String>.from(uri.queryParameters)
      ..removeWhere((key, _) => key.startsWith("push"));

    final sanitizedUri = uri.replace(queryParameters: sanitizedParameters);
    final query = sanitizedUri.hasQuery ? "?${sanitizedUri.query}" : "";
    final hash = sanitizedUri.hasFragment ? "#${sanitizedUri.fragment}" : "";

    web.window.history.replaceState(
      null,
      "",
      "${sanitizedUri.path}$query$hash",
    );
  }
}
