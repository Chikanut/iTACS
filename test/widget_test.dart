import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/pages/auth_gate.dart';
import 'package:flutter_application_1/services/app_session_controller.dart';

void main() {
  group('AuthGate session routing', () {
    testWidgets('shows login when there is no active session', (
      WidgetTester tester,
    ) async {
      final controller = FakeSessionController(
        initialScreen: SessionScreen.signedOut,
      );

      await tester.pumpWidget(buildHarness(controller));
      await tester.pump();

      expect(find.text('LOGIN'), findsOneWidget);
    });

    testWidgets('opens home after bootstrap with a restored session', (
      WidgetTester tester,
    ) async {
      final controller = FakeSessionController(
        initialScreen: SessionScreen.loading,
        onInitialize: (controller) async {
          controller.setScreen(SessionScreen.authenticated);
        },
      );

      await tester.pumpWidget(buildHarness(controller));
      await tester.pump();

      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('shows access denied when validation fails', (
      WidgetTester tester,
    ) async {
      final controller = FakeSessionController(
        initialScreen: SessionScreen.loading,
        onInitialize: (controller) async {
          controller.setScreen(SessionScreen.accessDenied);
        },
      );

      await tester.pumpWidget(buildHarness(controller));
      await tester.pump();

      expect(find.text('DENIED'), findsOneWidget);
    });

    testWidgets('returns to login after logout from the authenticated state', (
      WidgetTester tester,
    ) async {
      final controller = FakeSessionController(
        initialScreen: SessionScreen.authenticated,
      );

      await tester.pumpWidget(buildHarness(controller));
      await tester.pump();

      expect(find.text('HOME'), findsOneWidget);

      await tester.tap(find.byKey(const Key('logout-button')));
      await tester.pump();

      expect(find.text('LOGIN'), findsOneWidget);
      expect(controller.signOutCalls, 1);
    });
  });
}

Widget buildHarness(FakeSessionController controller) {
  return MaterialApp(
    home: AuthGate(
      controller: controller,
      loadingBuilder: (context, sessionController) =>
          const Scaffold(body: Center(child: Text('LOADING'))),
      loginBuilder: (context, sessionController) =>
          const Scaffold(body: Center(child: Text('LOGIN'))),
      homeBuilder: (context, sessionController) => Scaffold(
        body: Center(
          child: ElevatedButton(
            key: const Key('logout-button'),
            onPressed: sessionController.signOut,
            child: const Text('HOME'),
          ),
        ),
      ),
      accessDeniedBuilder: (context, sessionController) =>
          const Scaffold(body: Center(child: Text('DENIED'))),
    ),
  );
}

class FakeSessionController extends SessionController {
  FakeSessionController({
    required SessionScreen initialScreen,
    this.onInitialize,
  }) : _screen = initialScreen;

  final Future<void> Function(FakeSessionController controller)? onInitialize;

  SessionScreen _screen;
  int signOutCalls = 0;

  @override
  SessionScreen get screen => _screen;

  @override
  Future<void> initialize() async {
    if (onInitialize != null) {
      await onInitialize!(this);
    }
  }

  @override
  Future<void> revalidate() async {}

  @override
  Future<void> signIn(BuildContext context) async {}

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    setScreen(SessionScreen.signedOut);
  }

  void setScreen(SessionScreen nextScreen) {
    _screen = nextScreen;
    notifyListeners();
  }
}
