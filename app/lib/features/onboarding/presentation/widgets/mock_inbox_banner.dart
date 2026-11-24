import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../ui_kit/ui_kit.dart';
import '../../../auth/data/mock_inbox.dart';
import '../../../../app/services.dart';

/// Mock flavor only: shows the code the fake server "emailed", with a
/// button to use it, so sign-in can be demoed without a mail server.
class MockInboxBanner extends StatelessWidget {
  const MockInboxBanner({super.key, required this.forEmail, required this.onUse});

  final String? forEmail;
  final ValueChanged<String> onUse;

  @override
  Widget build(BuildContext context) {
    final inbox = context.read<DevTools>().inbox;
    if (inbox == null) return const SizedBox.shrink();
    return ValueListenableBuilder<MockEmail?>(
      valueListenable: inbox,
      builder: (context, email, _) {
        if (email == null || email.to != forEmail) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(KSpace.lg, 0, KSpace.lg, KSpace.md),
          child: KBanner(
            tone: KBannerTone.warning,
            icon: Icons.mark_email_unread_outlined,
            child: Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Mock inbox · code '),
                        TextSpan(
                          text: email.code,
                          style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1.5),
                        ),
                      ],
                    ),
                  ),
                ),
                KButton(
                  label: 'Use code',
                  size: KButtonSize.small,
                  variant: KButtonVariant.dark,
                  onPressed: () => onUse(email.code),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
