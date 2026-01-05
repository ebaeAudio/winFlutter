import 'package:flutter/material.dart';

import '../../ui/app_scaffold.dart';
import '../../ui/components/info_banner.dart';
import '../../ui/spacing.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'Setup required',
      children: [
        InfoBanner(
          title: 'Supabase isn’t configured yet',
          tone: InfoBannerTone.warning,
          message: 'To use real auth/data:\n'
              '- copy `assets/env.example` → `assets/env`\n'
              '- set `SUPABASE_URL` + `SUPABASE_ANON_KEY`\n\n'
              'Or use demo mode:\n'
              '- set `DEMO_MODE=true` in `assets/env`, or\n'
              '- run with `--dart-define=DEMO_MODE=true`',
        ),
        Gap.h16,
        Text(
          'Tip: demo mode is perfect for UI iteration — no network needed.',
        ),
      ],
    );
  }
}
