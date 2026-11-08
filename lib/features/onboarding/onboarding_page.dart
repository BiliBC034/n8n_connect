import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n.dart';
import '../startup/brand.dart';
import 'onboarding_service.dart';

/// First-run tutorial: five pages that explain what n8n Connect does.
///
/// The router shows it while [OnboardingService.done] is false. "Skip" and
/// the last button mark it as done, and the router then continues to the
/// normal flow.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    context.read<OnboardingService>().complete();
  }

  void _next(int pageCount) {
    if (_page == pageCount - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = [
      _Step(
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
      ),
      _Step(
        icon: Icons.dns_outlined,
        title: l10n.onboardingServerTitle,
        body: l10n.onboardingServerBody,
      ),
      _Step(
        icon: Icons.apps,
        title: l10n.onboardingAppsTitle,
        body: l10n.onboardingAppsBody,
      ),
      _Step(
        icon: Icons.bolt,
        title: l10n.onboardingActionsTitle,
        body: l10n.onboardingActionsBody,
      ),
      _Step(
        icon: Icons.notifications_active_outlined,
        title: l10n.onboardingPermissionsTitle,
        body: l10n.onboardingPermissionsBody,
      ),
    ];
    final isLast = _page == steps.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (index) => setState(() => _page = index),
                children: [for (final step in steps) _StepView(step: step)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PageDots(
                    count: steps.length,
                    current: _page,
                    label: l10n.onboardingPageLabel(_page + 1, steps.length),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Keeps its place on the last page so the buttons do
                      // not jump when "Skip" disappears.
                      Visibility(
                        visible: !isLast,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: TextButton(
                          onPressed: _finish,
                          child: Text(l10n.onboardingSkip),
                        ),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => _next(steps.length),
                        child: Text(
                          isLast ? l10n.onboardingDone : l10n.onboardingNext,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Content of one tutorial page. A null [icon] shows the app logo instead.
class _Step {
  const _Step({this.icon, required this.title, required this.body});

  final IconData? icon;
  final String title;
  final String body;
}

class _StepView extends StatelessWidget {
  const _StepView({required this.step});

  final _Step step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = step.icon;

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
          child: IntrinsicHeight(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon == null)
                  const BrandMark(size: 112)
                else
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 56,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                const SizedBox(height: 32),
                Text(
                  step.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 16),
                Text(
                  step.body,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Page indicator. The current page is a longer pill; announced as one
/// label ("Page 2 of 5") for screen readers.
class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.label,
  });

  final int count;
  final int current;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              width: i == current ? 24 : 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: i == current ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}
