import 'package:flutter/material.dart';

import '../../ui/app_scaffold.dart';
import '../../ui/components/info_banner.dart';

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
              '- set `SUPABASE_URL` + `SUPABASE_ANON_KEY`',
        ),
      ],
    );
  }
}
