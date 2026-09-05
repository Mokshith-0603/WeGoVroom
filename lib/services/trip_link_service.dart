import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class TripLinkService {
  TripLinkService._();

  static final TripLinkService instance = TripLinkService._();

  static const String host = 'wegovroom-e77c2.web.app';
  static const String androidPackageId = 'com.wegovroom.app';

  final AppLinks _appLinks = AppLinks();

  Stream<Uri> get uriStream => _appLinks.uriLinkStream;

  Uri tripUri(String tripId) {
    return Uri(scheme: 'https', host: host, pathSegments: ['trip', tripId]);
  }

  String? tripIdFromUri(Uri uri) {
    if (uri.scheme == 'wegovroom' && uri.host == 'trip') {
      final customSchemeTripId = uri.pathSegments.firstOrNull?.trim();
      if (customSchemeTripId != null && customSchemeTripId.isNotEmpty) {
        return customSchemeTripId;
      }
    }

    final fromQuery = uri.queryParameters['tripId']?.trim();
    if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

    final pathSegments = uri.pathSegments;
    if (pathSegments.length >= 2 &&
        pathSegments.first == 'trip' &&
        pathSegments[1].trim().isNotEmpty) {
      return pathSegments[1].trim();
    }

    final fragment = uri.fragment;
    if (fragment.isEmpty) return null;
    final queryStart = fragment.indexOf('?');
    if (queryStart == -1) return null;
    final query = fragment.substring(queryStart + 1);
    return Uri.splitQueryString(query)['tripId']?.trim();
  }

  Future<String?> getInitialTripId() async {
    if (kIsWeb) return tripIdFromUri(Uri.base);

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) return tripIdFromUri(initialUri);
    } catch (_) {}

    return null;
  }

  String shareText({
    required String tripId,
    required Map<String, dynamic> trip,
  }) {
    final from = (trip['from'] ?? '').toString().trim();
    final to = (trip['to'] ?? '').toString().trim();
    final route = [from, to].where((v) => v.isNotEmpty).join(' to ');
    final link = tripUri(tripId).toString();

    if (route.isEmpty) {
      return 'Join my WeGoVroom trip: $link';
    }

    return 'Join my WeGoVroom trip from $route: $link';
  }

  Future<void> shareTrip({
    required String tripId,
    required Map<String, dynamic> trip,
  }) {
    return Share.share(
      shareText(tripId: tripId, trip: trip),
      subject: 'Join my WeGoVroom trip',
    );
  }

  Future<bool> shareTripToWhatsApp({
    required String tripId,
    required Map<String, dynamic> trip,
  }) async {
    final text = Uri.encodeComponent(shareText(tripId: tripId, trip: trip));
    final whatsappUri = Uri.parse('whatsapp://send?text=$text');
    final webWhatsappUri = Uri.parse('https://wa.me/?text=$text');

    if (await canLaunchUrl(whatsappUri)) {
      return launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    }

    return launchUrl(webWhatsappUri, mode: LaunchMode.externalApplication);
  }

  Uri playStoreUri() {
    return Uri.parse(
      'https://play.google.com/store/apps/details?id=$androidPackageId',
    );
  }
}
