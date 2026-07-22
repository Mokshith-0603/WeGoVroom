import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';

class FeedbackFormScreen extends StatelessWidget {
  const FeedbackFormScreen({super.key});

  static final Uri _feedbackFormUri = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSdQN7aSu0BooGD22RDYuB2H_NNhpIjOQIPl0BJo0HMNmNyGyg/viewform?usp=publish-editor',
  );
  static final Uri _reportIssueFormUri = Uri.parse(
    'https://docs.google.com/forms/d/e/1FAIpQLSfSCEyy7amDXHwwyQzAE_SIltxt71wPbcoad90xPQ-OaU85OQ/viewform?usp=publish-editor',
  );

  Future<void> _openLink(BuildContext context, Uri uri, String label) async {
    final opened = await launchUrl(
      uri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $label form')));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Flexible(
              child: Text(
                'Feedback/Report an Issue',
                style: theme.textTheme.titleLarge?.copyWith(fontSize: r(20)),
              ),
            ),
            SizedBox(width: r(8)),
            const Icon(Icons.rate_review_rounded, color: AppTheme.brandOrange),
          ],
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF07131E), Color(0xFF0A1722)]
                : const [Color(0xFFFFFEFC), Color(0xFFFBF7F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(r(20), r(4), r(20), r(28)),
          children: [
            Text(
              'Help us improve WeGoVroom',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              ),
            ),
            SizedBox(height: r(30)),
            _card(
              context,
              title: 'Feedback',
              subtitle: 'Share your feedback\nwith WeGoVroom',
              description:
                  'Your feedback helps us improve your experience and build a better app for you.',
              icon: Icons.rate_review_rounded,
              artIcon: Icons.assignment_rounded,
              color: AppTheme.brandOrange,
              buttonText: 'Open Feedback Form',
              onPressed: () =>
                  _openLink(context, _feedbackFormUri, 'feedback'),
            ),
            SizedBox(height: r(20)),
            _card(
              context,
              title: 'Report an Issue',
              subtitle: 'Report misbehavior,\nsafety, or service issues',
              description:
                  'Help us keep the community safe and fix issues quickly.',
              icon: Icons.warning_rounded,
              artIcon: Icons.gpp_maybe_rounded,
              color: const Color(0xFFFF3D5F),
              buttonText: 'Open Issue Report Form',
              onPressed: () =>
                  _openLink(context, _reportIssueFormUri, 'issue report'),
            ),
            SizedBox(height: r(24)),
            Container(
              padding: EdgeInsets.all(r(20)),
              decoration: _surface(context, r(22)),
              child: Row(
                children: [
                  Icon(
                    Icons.volunteer_activism_rounded,
                    color: AppTheme.brandOrange,
                    size: r(46),
                  ),
                  SizedBox(width: r(16)),
                  Expanded(
                    child: Text(
                      'Together, we can create a better and safer journey for everyone.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required IconData icon,
    required IconData artIcon,
    required Color color,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);
    final r = context.rs;
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(r(20)),
      decoration: _surface(context, r(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r(58),
                height: r(58),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.10 : 0.09),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: color, size: r(30)),
              ),
              const Spacer(),
              Icon(artIcon, color: color, size: r(78)),
            ],
          ),
          SizedBox(height: r(14)),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(fontSize: r(22)),
          ),
          SizedBox(height: r(12)),
          Text(
            subtitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontSize: r(20),
              height: 1.35,
            ),
          ),
          SizedBox(height: r(14)),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          SizedBox(height: r(22)),
          Material(
            color: isDark ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(r(20)),
            child: InkWell(
              borderRadius: BorderRadius.circular(r(20)),
              onTap: onPressed,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: r(18),
                  vertical: r(17),
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(r(20)),
                  border: Border.all(color: color, width: 1.2),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      color: isDark ? color : Colors.white,
                    ),
                    SizedBox(width: r(12)),
                    Expanded(
                      child: Text(
                        buttonText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: isDark ? color : Colors.white,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? color : Colors.white,
                    ),
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
      color: isDark ? const Color(0xFF101A24) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.09)
            : const Color(0xFFEAE6E0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
          blurRadius: 22,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }
}
