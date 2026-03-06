import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
    if (opened) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Could not open $label form')));
  }

  Widget _card({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData leadingIcon,
    required IconData badgeIcon,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: const [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(leadingIcon, color: const Color(0xffff7a00)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xffffc27a),
                      Color(0xffff9c1a),
                      Color(0xffff7a00),
                    ],
                  ),
                ),
                child: Icon(badgeIcon, color: Colors.white, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xffff7a00),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xffff7a00),
              foregroundColor: Colors.black,
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.open_in_new),
            label: Text(buttonText),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f7),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Feedback/Report an Issue'),
            SizedBox(width: 8),
            Icon(Icons.feedback_outlined, color: Color(0xffff7a00), size: 20),
          ],
        ),
        backgroundColor: const Color(0xfff5f5f7),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            context: context,
            title: 'Feedback',
            subtitle: 'Share your feedback with WeGoVroom',
            leadingIcon: Icons.rate_review_outlined,
            badgeIcon: Icons.rate_review,
            buttonText: 'Open Feedback Form',
            onPressed: () => _openLink(context, _feedbackFormUri, 'feedback'),
          ),
          const SizedBox(height: 14),
          _card(
            context: context,
            title: 'Report an Issue',
            subtitle: 'Report misbehavior, safety, or service issues',
            leadingIcon: Icons.report_problem_outlined,
            badgeIcon: Icons.gpp_maybe_outlined,
            buttonText: 'Open Issue Report Form',
            onPressed: () =>
                _openLink(context, _reportIssueFormUri, 'issue report'),
          ),
        ],
      ),
    );
  }
}
