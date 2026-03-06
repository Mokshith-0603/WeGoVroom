import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const String _instagramId = '@wegovroom_.official';
  static const String _instagramHandle = 'wegovroom_.official';
  static final Uri _instagramWebUri = Uri.parse(
    'https://www.instagram.com/wegovroom_.official?igsh=d2pobmF1bzJqa2hl',
  );
  static final Uri _instagramAppUri = Uri.parse(
    'instagram://user?username=$_instagramHandle',
  );
  static final Uri _whatsAppCommitteeUri = Uri.parse(
    'https://chat.whatsapp.com/I2KTSE2MpM6DbOQzhlbqDk',
  );
  static const String _whatsAppLabel = 'WeGoVroom WhatsApp committee';
  static const String _supportEmail = 'wegovroom0191@gmail.com';
  static final Uri _supportMailUri = Uri(
    scheme: 'mailto',
    path: _supportEmail,
    queryParameters: {'subject': 'WeGoVroom Support'},
  );

  Future<void> _openInstagram(BuildContext context) async {
    if (!kIsWeb) {
      final openedApp = await launchUrl(
        _instagramAppUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedApp) return;
    }

    final openedWeb = await launchUrl(
      _instagramWebUri,
      mode: kIsWeb
          ? LaunchMode.platformDefault
          : LaunchMode.externalApplication,
    );
    if (openedWeb) {
      return;
    }

    if (!context.mounted) return;
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
    if (opened) return;

    if (!context.mounted) return;
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
    if (opened) return;

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open email app')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f7),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Contact Us'),
            SizedBox(width: 8),
            Icon(Icons.support_agent, color: Color(0xffff7a00), size: 20),
          ],
        ),
        backgroundColor: const Color(0xfff5f5f7),
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
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
                    const Icon(Icons.alternate_email, color: Color(0xffff7a00)),
                    const SizedBox(width: 8),
                    const Text(
                      'Instagram',
                      style: TextStyle(
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
                          colors: [
                            Color(0xfff58529),
                            Color(0xffdd2a7b),
                            Color(0xff8134af),
                            Color(0xff515bd4),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.camera_alt_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
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
          const SizedBox(height: 14),
          Container(
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
                    const Icon(Icons.groups_outlined, color: Color(0xffff7a00)),
                    const SizedBox(width: 8),
                    const Text(
                      'WhatsApp Committee',
                      style: TextStyle(
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
                            Color(0xffffb15c),
                            Color(0xffff8a00),
                            Color(0xffff7a00),
                          ],
                        ),
                      ),
                      child: const Icon(
                        Icons.forum_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const SelectableText(
                  _whatsAppLabel,
                  style: TextStyle(
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
                  onPressed: () => _openWhatsAppCommittee(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Join WhatsApp Group'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
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
                    const Icon(Icons.mail_outline, color: Color(0xffff7a00)),
                    const SizedBox(width: 8),
                    const Text(
                      'Email',
                      style: TextStyle(
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
                      child: const Icon(
                        Icons.mark_email_unread_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const SelectableText(
                  _supportEmail,
                  style: TextStyle(
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
                  onPressed: () => _openSupportEmail(context),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Email Us'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
