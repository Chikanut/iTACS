import 'dart:async';

import 'package:flutter/material.dart';

import '../globals.dart';
import '../services/app_session_controller.dart';
import 'access_denied_page.dart';
import 'email_check_page.dart';
import 'login_page.dart';
import 'main_scaffold.dart';

typedef SessionViewBuilder =
    Widget Function(BuildContext context, SessionController controller);

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.controller,
    this.loadingBuilder,
    this.loginBuilder,
    this.homeBuilder,
    this.accessDeniedBuilder,
  });

  final SessionController? controller;
  final SessionViewBuilder? loadingBuilder;
  final SessionViewBuilder? loginBuilder;
  final SessionViewBuilder? homeBuilder;
  final SessionViewBuilder? accessDeniedBuilder;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final SessionController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        AppSessionController(
          authService: Globals.authService,
          firebaseAuth: Globals.firebaseAuth,
          firestoreManager: Globals.firestoreManager,
          profileManager: Globals.profileManager,
        );

    unawaited(_controller.initialize());
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        switch (_controller.screen) {
          case SessionScreen.loading:
            return (widget.loadingBuilder ?? _defaultLoadingBuilder)(
              context,
              _controller,
            );
          case SessionScreen.signedOut:
            return (widget.loginBuilder ?? _defaultLoginBuilder)(
              context,
              _controller,
            );
          case SessionScreen.authenticated:
          case SessionScreen.offlineAuthenticated:
            return (widget.homeBuilder ?? _defaultHomeBuilder)(
              context,
              _controller,
            );
          case SessionScreen.accessDenied:
            return (widget.accessDeniedBuilder ?? _defaultAccessDeniedBuilder)(
              context,
              _controller,
            );
        }
      },
    );
  }

  Widget _defaultLoadingBuilder(
    BuildContext context,
    SessionController controller,
  ) {
    return const EmailCheckPage();
  }

  Widget _defaultLoginBuilder(
    BuildContext context,
    SessionController controller,
  ) {
    return LoginPage(sessionController: controller);
  }

  Widget _defaultHomeBuilder(
    BuildContext context,
    SessionController controller,
  ) {
    return MainScaffold(sessionController: controller);
  }

  Widget _defaultAccessDeniedBuilder(
    BuildContext context,
    SessionController controller,
  ) {
    return AccessDeniedPage(sessionController: controller);
  }
}
