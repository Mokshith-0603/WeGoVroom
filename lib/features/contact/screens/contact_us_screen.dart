import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const String _instagramId = '@wegovroom_.official';
  static const String _instagramUrl =
      'https://www.instagram.com/wegovroom_.official?igsh=d2pobmF1bzJqa2hl';

  Future<void> _openInstagram(BuildContext context) async {
    final uri = Uri.parse(_instagramUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Instagram')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Contact Us'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.alternate_email, color: Color(0xffff7a00)),
                  SizedBox(width: 8),
                  Text(
                    'Instagram',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const SelectableText(
                _instagramId,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xffff7a00),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xffff7a00),
                  foregroundColor: Colors.black,
                ),
                onPressed: () => _openInstagram(context),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open Instagram'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
