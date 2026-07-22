import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const _instagramId = '@wegovroom_.official';
  static const _instagramHandle = 'wegovroom_.official';
  static final _instagramWebUri = Uri.parse(
    'https://www.instagram.com/wegovroom_.official?igsh=d2pobmF1bzJqa2hl',
  );
  static final _instagramAppUri = Uri.parse(
    'instagram://user?username=$_instagramHandle',
  );
  static final _whatsAppCommitteeUri = Uri.parse(
    'https://chat.whatsapp.com/I2KTSE2MpM6DbOQzhlbqDk',
  );
  static const _whatsAppLabel = 'WeGoVroom WhatsApp committee';
  static const _supportEmail = 'wegovroom0191@gmail.com';
  static final _supportMailUri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {'subject': 'WeGoVroom Support'},
  );

  Future<void> _openInstagram(BuildContext context) async {
    if (!kIsWeb) {
      final opened = await launchUrl(
        _instagramAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
    }
    final opened = await launchUrl(
      _instagramWebUri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open Instagram')));
  }

  Future<void> _openWhatsAppCommittee(BuildContext context) async {
    final opened = await launchUrl(
      _whatsAppCommitteeUri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open WhatsApp link')),
    );
  }

  Future<void> _openSupportEmail(BuildContext context) async {
    final opened = await launchUrl(
      _supportMailUri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open email app')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Contact Us',
              style: theme.textTheme.headlineMedium?.copyWith(fontSize: r(25)),
            ),
            SizedBox(width: r(8)),
            const Icon(Icons.headset_mic_rounded, color: AppTheme.brandOrange),
          ],
        ),
      ),
      body: _PageBackground(
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(r(20), r(10), r(20), r(28)),
          children: [
            Text(
              "We're here to help and connect with you!",
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            SizedBox(height: r(18)),
            const Center(child: _SectionDots()),
            SizedBox(height: r(28)),
            _contactCard(
              context,
              icon: Icons.camera_alt_outlined,
              colors: const [Color(0xFFFF7A00), Color(0xFFC13584)],
              title: 'Instagram',
              value: _instagramId,
              action: 'Open Instagram',
              actionColor: AppTheme.brandOrange,
              onTap: () => _openInstagram(context),
            ),
            SizedBox(height: r(18)),
            _contactCard(
              context,
              icon: Icons.forum_rounded,
              colors: const [Color(0xFF25D366), Color(0xFF0B9F45)],
              title: 'WhatsApp Committee',
              value: _whatsAppLabel,
              action: 'Join WhatsApp Group',
              actionColor: const Color(0xFF20B653),
              onTap: () => _openWhatsAppCommittee(context),
            ),
            SizedBox(height: r(18)),
            _contactCard(
              context,
              icon: Icons.mail_rounded,
              colors: const [Color(0xFF3B82F6), Color(0xFF1559D6)],
              title: 'Email',
              value: _supportEmail,
              action: 'Email Us',
              actionColor: const Color(0xFF2F80ED),
              onTap: () => _openSupportEmail(context),
            ),
            SizedBox(height: r(24)),
            Container(
              padding: EdgeInsets.all(r(22)),
              decoration: BoxDecoration(
                gradient: theme.brightness == Brightness.dark
                    ? const LinearGradient(
                        colors: [Color(0xFF25205A), Color(0xFF171947)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFFFFF4E9), Color(0xFFFFE4C7)],
                      ),
                borderRadius: BorderRadius.circular(r(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'We value your feedback!',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: r(18),
                          ),
                        ),
                        SizedBox(height: r(10)),
                        Text(
                          'Reach out to us through any of the above channels.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.send_rounded,
                    color: AppTheme.brandOrange,
                    size: r(62),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactCard(
    BuildContext context, {
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String value,
    required String action,
    required Color actionColor,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(r(20)),
      decoration: _surface(context, r(24)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: r(58),
                height: r(58),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: r(30)),
              ),
              SizedBox(width: r(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    SizedBox(height: r(5)),
                    SelectableText(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: actionColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r(20)),
          Material(
            color: actionColor.withValues(alpha: isDark ? 0.05 : 0.09),
            borderRadius: BorderRadius.circular(r(18)),
            child: InkWell(
              borderRadius: BorderRadius.circular(r(18)),
              onTap: onTap,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r(18),
                  vertical: r(17),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r(18)),
                  border: Border.all(
                    color: actionColor.withValues(alpha: isDark ? 0.6 : 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, color: actionColor),
                    SizedBox(width: r(12)),
                    Expanded(
                      child: Text(
                        action,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: actionColor,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: actionColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _surface(BuildContext context, double radius) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BoxDecoration(
      color: isDark ? const Color(0xFF111B25) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : const Color(0xFFEAE6E0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}

class _PageBackground extends StatelessWidget {
  const _PageBackground({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF07131E), Color(0xFF0A1722)]
              : const [Color(0xFFFFFEFC), Color(0xFFFBF7F2)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child,
    );
  }
}

class _SectionDots extends StatelessWidget {
  const _SectionDots();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 3,
          decoration: BoxDecoration(
            color: AppTheme.brandOrange,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 7),
        ...List.generate(
          3,
          (_) => Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.only(right: 6),
            decoration: const BoxDecoration(
              color: AppTheme.brandOrange,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
