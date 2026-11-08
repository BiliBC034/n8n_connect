import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:n8n_connect/features/share/share_intake.dart';
import 'package:n8n_connect/features/share/share_page.dart';
import 'package:n8n_connect/generated/l10n.dart';

/// Same localization setup as the app, pinned to English.
Widget _app(SharedContent? content) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.delegate.supportedLocales,
  home: Provider<ShareIntake>.value(
    value: ShareIntake(),
    child: SharePage(content: content),
  ),
);

void main() {
  setUpAll(() => AppLocalizations.delegate.load(const Locale('en')));

  testWidgets('shows the nothing-to-share message without content', (
    tester,
  ) async {
    await tester.pumpWidget(_app(null));

    final l10n = AppLocalizations.current;
    expect(find.text(l10n.shareTitle), findsOneWidget);
    expect(find.text(l10n.shareNothingToShare), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(_sendButton(l10n.shareSendButton), findsNothing);
  });

  testWidgets('shows subject, text, note field and send button', (
    tester,
  ) async {
    const content = SharedContent(
      text: 'https://example.com/article',
      subject: 'Great article',
    );
    await tester.pumpWidget(_app(content));

    final l10n = AppLocalizations.current;
    expect(find.text('Great article'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == content.text,
      ),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text(l10n.shareNoteLabel), findsOneWidget);
    expect(_sendButton(l10n.shareSendButton), findsOneWidget);
    expect(find.text(l10n.shareNothingToShare), findsNothing);
  });

  testWidgets('omits the subject when there is none', (tester) async {
    const content = SharedContent(text: 'Just some text');
    await tester.pumpWidget(_app(content));

    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == content.text,
      ),
      findsOneWidget,
    );
    expect(
      _sendButton(AppLocalizations.current.shareSendButton),
      findsOneWidget,
    );
  });
}

/// The send button. `FilledButton.icon` builds a subclass, so `byType` would
/// not match it; look for any FilledButton above the label instead.
Finder _sendButton(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is FilledButton),
);
