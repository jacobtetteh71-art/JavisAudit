// ============================================================
// screens/help_manual_screen.dart  –  Help & User Manual
// ============================================================
// A self-contained, offline reference screen that lives in the
// Drawer (and as a quick-access icon on the Dashboard AppBar).
// Three tabs:
//   1. Getting Started — a numbered walkthrough for brand-new users
//   2. Features         — what each part of the app does
//   3. Troubleshooting  — plain-language fixes for the issues users
//                          most commonly run into
//
// All illustrations are drawn with CustomPainter / plain widgets —
// no image assets required — using the app's existing AppColors so
// this screen always matches the rest of JavisAudit automatically.
// ============================================================

import 'package:flutter/material.dart';

import '../utils/utils.dart';

class HelpManualScreen extends StatelessWidget {
  const HelpManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Help & User Manual'),
          bottom: TabBar(
            indicatorColor: AppColors.gold,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Getting Started'),
              Tab(text: 'Features'),
              Tab(text: 'Troubleshooting'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _GettingStartedTab(),
            _FeaturesTab(),
            _TroubleshootingTab(),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// TAB 1 — Getting Started
// ================================================================

class _GettingStartedTab extends StatelessWidget {
  const _GettingStartedTab();

  static const _steps = [
    _Step(
      title: 'Create or restore your account',
      body: 'On the welcome screen, tap "Create Account" to start fresh, or '
          '"Sign In" if you already used JavisAudit on another phone — '
          'signing in with the same email or Google account brings back '
          'your business data and PIN through Cloud Sync.',
    ),
    _Step(
      title: 'Set up your business profile',
      body: 'Enter your business name, owner name, and — if you have them — '
          'your GRA TIN and VAT number. You can always edit these later from '
          'Settings.',
    ),
    _Step(
      title: 'Secure the app',
      body: 'Choose a 4-digit PIN to unlock JavisAudit, and set a backup '
          'password in case you ever forget it. JavisAudit locks itself '
          'automatically whenever you leave the app.',
    ),
    _Step(
      title: 'Record your first transaction',
      body: 'From the Dashboard, use the Income, Expenses or Sales tab and '
          'tap the + button to log your first entry. Add a category and, '
          'optionally, a photo of the receipt.',
    ),
    _Step(
      title: 'Turn on Cloud Sync (optional but recommended)',
      body: 'Open the menu → Cloud Sync → sign in → "Sync Now". This backs '
          'up your ledger so you never lose data if you change phones, and '
          'lets you keep working from more than one device.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Center(child: CustomPaint(size: const Size(120, 100), painter: _MoneyFlowPainter())),
        const SizedBox(height: 12),
        const Text(
          'Welcome to JavisAudit',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 6),
        const Text(
          'Track income, expenses, sales and VAT — all stored on your '
          'device, with optional cloud backup. Here\'s how to get set up.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
        ),
        const SizedBox(height: 24),
        for (int i = 0; i < _steps.length; i++)
          _StepRow(index: i + 1, step: _steps[i], isLast: i == _steps.length - 1),
      ],
    );
  }
}

class _Step {
  final String title;
  final String body;
  const _Step({required this.title, required this.body});
}

class _StepRow extends StatelessWidget {
  final int index;
  final _Step step;
  final bool isLast;
  const _StepRow({required this.index, required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: const BoxDecoration(color: AppColors.gold, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '$index',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.border)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(step.body, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// TAB 2 — Features
// ================================================================

class _FeaturesTab extends StatelessWidget {
  const _FeaturesTab();

  static final _features = [
    _Feature(
      icon: Icons.dashboard_outlined,
      title: 'Dashboard Overview',
      subtitle: 'Your business at a glance',
      illustration: const _IconBadge(icon: Icons.dashboard_outlined),
      bullets: const [
        'KPI cards show this month\'s income, expenses and profit',
        'A 6-month chart compares income against expenses',
        'A VAT progress bar shows how close you are to threshold',
        'Pull down on the dashboard to refresh with the latest data',
      ],
    ),
    _Feature(
      icon: Icons.swap_vert,
      title: 'Income & Expenses',
      subtitle: 'Every cedi in, every cedi out',
      illustration: CustomPaint(size: const Size(72, 72), painter: _MoneyFlowPainter(compact: true)),
      bullets: const [
        'Tap the + button on the Income or Expenses tab to add an entry',
        'Attach a category and, optionally, a photo of the receipt',
        'Recurring expenses can be saved as templates so you don\'t retype them',
        'Everything is saved to your device immediately — no internet needed',
      ],
    ),
    _Feature(
      icon: Icons.point_of_sale_outlined,
      title: 'Sales & Invoices',
      subtitle: 'Log sales and send professional invoices',
      illustration: const _IconBadge(icon: Icons.receipt_long_outlined),
      bullets: const [
        'Record each sale with quantity, price and customer (optional)',
        'Generate a PDF invoice or receipt and share it directly from the app',
        'The Customer Ledger keeps track of who still owes you money',
      ],
    ),
    _Feature(
      icon: Icons.gpp_maybe_outlined,
      title: 'VAT Tracker',
      subtitle: 'Stay ahead of GRA VAT registration',
      illustration: CustomPaint(size: const Size(72, 72), painter: _GaugePainter(percent: 0.62)),
      bullets: const [
        'Automatically totals your taxable sales for the year',
        'Shows how close you are to the mandatory VAT registration threshold',
        'Uses the current Ghana Revenue Authority rates and rules',
      ],
    ),
    _Feature(
      icon: Icons.bar_chart,
      title: 'Reports & Analytics',
      subtitle: 'Understand your numbers',
      illustration: const _IconBadge(icon: Icons.insights_outlined),
      bullets: const [
        'Financial Reports summarise income, expenses and profit by period',
        'Analytics and Sales Performance highlight trends over time',
        'The Year-End Financial Report is ready to hand to your accountant or GRA',
      ],
    ),
    _Feature(
      icon: Icons.cloud_sync_outlined,
      title: 'Cloud Sync & Backup',
      subtitle: 'Never lose your data',
      illustration: CustomPaint(size: const Size(72, 72), painter: _SyncCyclePainter()),
      bullets: const [
        'Sign in once, then tap "Sync Now" any time you have internet',
        'Restores your full ledger and PIN automatically on a new phone',
        '"Backup & Restore" also creates a local backup file on your device',
      ],
    ),
    _Feature(
      icon: Icons.lock_outline,
      title: 'Security & PIN Lock',
      subtitle: 'Your business data, protected',
      illustration: CustomPaint(size: const Size(72, 72), painter: _ShieldLockPainter()),
      bullets: const [
        'JavisAudit locks itself automatically when you leave the app',
        'Unlock with your PIN, or fingerprint/face if your phone supports it',
        'Forgot your PIN? Use the backup password you set during onboarding',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _features.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final f = _features[i];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              leading: f.illustration,
              title: Text(f.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppColors.textPrimary)),
              subtitle: Text(f.subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final b in f.bullets)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 5, right: 8),
                                child: Icon(Icons.circle, size: 5, color: AppColors.gold),
                              ),
                              Expanded(
                                child: Text(b, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Feature {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget illustration;
  final List<String> bullets;
  _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.bullets,
  });
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  const _IconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.primary, size: 22),
    );
  }
}

// ================================================================
// TAB 3 — Troubleshooting
// ================================================================

class _TroubleshootingTab extends StatelessWidget {
  const _TroubleshootingTab();

  static const _faqs = [
    _Faq(
      icon: Icons.login,
      question: '"Could not sign in with Google"',
      answer: 'Check your internet connection and make sure Google Play '
          'Services is up to date, then try again. If it still fails, use '
          '"Sign In" with your email and password instead from the same '
          'Cloud Sync screen — either method reaches the same account and '
          'the same data.',
    ),
    _Faq(
      icon: Icons.system_update_alt,
      question: 'A new version won\'t install over my current app',
      answer: 'This usually means the new copy was built differently from '
          'the one already on your phone, so Android treats it as a '
          'different app. First back up your data (menu → Backup & Restore, '
          'or Cloud Sync if you\'re signed in), then uninstall the old '
          'version before installing the new one. Signing back in with '
          'Cloud Sync restores everything.',
    ),
    _Faq(
      icon: Icons.password,
      question: 'I forgot my PIN',
      answer: 'On the lock screen, tap "Forgot PIN? Use password instead" '
          'and enter the backup password you created during setup. From '
          'there you can set a new PIN.',
    ),
    _Faq(
      icon: Icons.sync_problem_outlined,
      question: 'My data isn\'t syncing across devices',
      answer: 'Open the menu → Cloud Sync and confirm you\'re signed in to '
          'the same account on both devices, check that you have an '
          'internet connection, then tap "Sync Now" on each device. If two '
          'devices have different data, you\'ll be asked which copy to '
          'keep.',
    ),
    _Faq(
      icon: Icons.calculate_outlined,
      question: 'My VAT or totals look wrong',
      answer: 'Double-check the date range you\'re viewing on that screen, '
          'and confirm every sale or expense was saved under the right '
          'date and category — a single entry in the wrong month is the '
          'most common cause.',
    ),
    _Faq(
      icon: Icons.notifications_off_outlined,
      question: 'Notifications aren\'t showing up',
      answer: 'Open your phone\'s Settings → Apps → JavisAudit → '
          'Notifications and make sure they\'re allowed. Also check that '
          'battery optimization isn\'t set to restrict JavisAudit in the '
          'background, which can silently block reminders.',
    ),
    _Faq(
      icon: Icons.camera_alt_outlined,
      question: 'Camera or photo picker won\'t open',
      answer: 'Go to your phone\'s Settings → Apps → JavisAudit → '
          'Permissions and turn on Camera and Photos/Storage. Android '
          'usually asks for this the first time you try to attach a '
          'receipt — if you tapped "Deny" then, it has to be re-enabled '
          'manually.',
    ),
    _Faq(
      icon: Icons.phonelink_setup_outlined,
      question: 'I got a new phone — how do I get my data back?',
      answer: 'Install JavisAudit, and on the welcome screen choose "Sign '
          'In" (not "Create Account"), then sign in with the same email or '
          'Google account you used before. Your business profile, ledger '
          'and PIN are restored automatically through Cloud Sync.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      itemCount: _faqs.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Common issues and how to fix them',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          );
        }
        final f = _faqs[i - 1];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              leading: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(color: AppColors.goldLight, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(f.icon, color: AppColors.gold, size: 18),
              ),
              title: Text(f.question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppColors.textPrimary)),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(f.answer, style: const TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.45)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Faq {
  final IconData icon;
  final String question;
  final String answer;
  const _Faq({required this.icon, required this.question, required this.answer});
}

// ================================================================
// Custom-painted illustrations
// ================================================================

/// A wallet with a green arrow flowing in (income) and a red arrow
/// flowing out (expense) — used on the Getting Started header and
/// the Income & Expenses feature card.
class _MoneyFlowPainter extends CustomPainter {
  final bool compact;
  _MoneyFlowPainter({this.compact = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final walletRect = Rect.fromLTWH(w * 0.18, h * 0.30, w * 0.64, h * 0.5);
    final walletPaint = Paint()..color = AppColors.primary;
    final walletBorder = RRect.fromRectAndRadius(walletRect, const Radius.circular(10));
    canvas.drawRRect(walletBorder, walletPaint);

    // Wallet flap / clasp
    final claspPaint = Paint()..color = AppColors.gold;
    canvas.drawCircle(Offset(w * 0.5, h * 0.55), compact ? 5 : 7, claspPaint);

    if (!compact) {
      // Income arrow (into the wallet, from top-left) — green
      final incomePaint = Paint()
        ..color = AppColors.income
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final incomeStart = Offset(w * 0.06, h * 0.06);
      final incomeEnd = Offset(w * 0.30, h * 0.30);
      canvas.drawLine(incomeStart, incomeEnd, incomePaint);
      _arrowHead(canvas, incomeEnd, incomeStart, AppColors.income);

      // Expense arrow (out of the wallet, to top-right) — red
      final expensePaint = Paint()
        ..color = AppColors.expense
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final expenseStart = Offset(w * 0.70, h * 0.30);
      final expenseEnd = Offset(w * 0.94, h * 0.06);
      canvas.drawLine(expenseStart, expenseEnd, expensePaint);
      _arrowHead(canvas, expenseEnd, expenseStart, AppColors.expense);
    }
  }

  void _arrowHead(Canvas canvas, Offset tip, Offset from, Color color) {
    final dir = (tip - from);
    final angle = dir.direction;
    const arrowLen = 7.0;
    const arrowAngle = 0.5;
    final p1 = tip - Offset.fromDirection(angle - arrowAngle, arrowLen);
    final p2 = tip - Offset.fromDirection(angle + arrowAngle, arrowLen);
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _MoneyFlowPainter oldDelegate) => oldDelegate.compact != compact;
}

/// Two curved arrows chasing each other in a circle, with a phone on
/// one side and a cloud on the other — used for Cloud Sync.
class _SyncCyclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.30;

    final arcPaint1 = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final arcPaint2 = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -2.5, 2.0, false, arcPaint1);
    canvas.drawArc(rect, 0.6, 2.0, false, arcPaint2);

    // Arrowhead on each arc's leading edge
    final tip1 = center + Offset.fromDirection(-0.5, radius);
    final tip2 = center + Offset.fromDirection(2.6, radius);
    _arrowDot(canvas, tip1, AppColors.primary);
    _arrowDot(canvas, tip2, AppColors.gold);

    // Cloud icon (top)
    final cloudPaint = Paint()..color = AppColors.primary.withOpacity(0.15);
    final cloudCenter = Offset(center.dx, center.dy - radius * 0.05);
    canvas.drawCircle(cloudCenter + const Offset(-8, 2), 9, cloudPaint);
    canvas.drawCircle(cloudCenter + const Offset(6, -2), 10, cloudPaint);
    canvas.drawCircle(cloudCenter + const Offset(0, 4), 8, cloudPaint);
  }

  void _arrowDot(Canvas canvas, Offset p, Color color) {
    canvas.drawCircle(p, 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SyncCyclePainter oldDelegate) => false;
}

/// A semi-circular gauge with a filled arc showing progress toward
/// the VAT threshold.
class _GaugePainter extends CustomPainter {
  final double percent; // 0.0 – 1.0
  _GaugePainter({required this.percent});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(size.width * 0.08, size.height * 0.15, size.width * 0.84, size.width * 0.84);
    const start = 3.14159; // 180°
    const sweepTotal = 3.14159; // half circle

    final track = Paint()
      ..color = AppColors.border
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweepTotal, false, track);

    final fill = Paint()
      ..color = percent >= 0.9 ? AppColors.expense : AppColors.gold
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, start, sweepTotal * percent.clamp(0.0, 1.0), false, fill);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) => oldDelegate.percent != percent;
}

/// A shield outline with a small padlock in the centre — used for
/// the Security & PIN Lock feature card.
class _ShieldLockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shieldPath = Path()
      ..moveTo(w * 0.5, h * 0.08)
      ..lineTo(w * 0.82, h * 0.20)
      ..lineTo(w * 0.82, h * 0.52)
      ..cubicTo(w * 0.82, h * 0.78, w * 0.66, h * 0.90, w * 0.5, h * 0.94)
      ..cubicTo(w * 0.34, h * 0.90, w * 0.18, h * 0.78, w * 0.18, h * 0.52)
      ..lineTo(w * 0.18, h * 0.20)
      ..close();

    canvas.drawPath(shieldPath, Paint()..color = AppColors.primaryLight);
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke,
    );

    // Padlock body
    final lockBody = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(w * 0.5, h * 0.58), width: w * 0.26, height: h * 0.20),
      const Radius.circular(3),
    );
    canvas.drawRRect(lockBody, Paint()..color = AppColors.gold);

    // Padlock shackle
    final shacklePaint = Paint()
      ..color = AppColors.gold
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final shackleRect = Rect.fromCenter(center: Offset(w * 0.5, h * 0.44), width: w * 0.16, height: h * 0.16);
    canvas.drawArc(shackleRect, 3.14159, 3.14159, false, shacklePaint);
  }

  @override
  bool shouldRepaint(covariant _ShieldLockPainter oldDelegate) => false;
}
