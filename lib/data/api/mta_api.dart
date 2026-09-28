import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/preferences/shared_preference_manager.dart';

class MtaStatus {
  final bool mtaEnabled;
  final bool mtaReady;
  final bool online;
  final MtaActiveTrip? activeTrip;

  const MtaStatus({
    required this.mtaEnabled,
    required this.mtaReady,
    required this.online,
    required this.activeTrip,
  });

  factory MtaStatus.fromJson(Map<String, dynamic> json) {
    final activeTripJson = json['activeTrip'];
    return MtaStatus(
      mtaEnabled: json['mtaEnabled'] == true,
      mtaReady: json['mtaReady'] == true,
      online: json['online'] == true,
      activeTrip: activeTripJson is Map
          ? MtaActiveTrip.fromJson(Map<String, dynamic>.from(activeTripJson))
          : null,
    );
  }
}

class MtaActiveTrip {
  final String tripId;
  final String status;
  final String partnerConfirmationStatus;
  final DateTime? partnerConfirmationAttemptedAt;
  final String? partnerConfirmationError;

  const MtaActiveTrip({
    required this.tripId,
    required this.status,
    required this.partnerConfirmationStatus,
    required this.partnerConfirmationAttemptedAt,
    required this.partnerConfirmationError,
  });

  factory MtaActiveTrip.fromJson(Map<String, dynamic> json) => MtaActiveTrip(
        tripId: json['tripId']?.toString() ?? '',
        status: json['status']?.toString() ?? 'unknown',
        partnerConfirmationStatus:
            json['partnerConfirmationStatus']?.toString() ?? 'unknown',
        partnerConfirmationAttemptedAt: DateTime.tryParse(
          json['partnerConfirmationAttemptedAt']?.toString() ?? '',
        ),
        partnerConfirmationError:
            json['partnerConfirmationError']?.toString(),
      );
}

class MtaOffer {
  final String offerId;
  final String tripId;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String dropoffAddress;
  final double dropoffLat;
  final double dropoffLng;
  final DateTime? scheduledTime;
  final DateTime? expiresAt;
  final String currency;
  final int priceCents;
  final int? driverPayoutCents;
  final String partner;

  const MtaOffer({
    required this.offerId,
    required this.tripId,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffAddress,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.scheduledTime,
    required this.expiresAt,
    required this.currency,
    required this.priceCents,
    required this.driverPayoutCents,
    required this.partner,
  });

  factory MtaOffer.fromJson(Map<String, dynamic> json) {
    final pickup = _map(json['pickup']);
    final dropoff = _map(json['dropoff']);
    return MtaOffer(
      offerId: json['offerId']?.toString() ?? '',
      tripId: json['tripId']?.toString() ?? '',
      pickupAddress: pickup['address']?.toString() ?? '',
      pickupLat: _number(pickup['lat']),
      pickupLng: _number(pickup['lng']),
      dropoffAddress: dropoff['address']?.toString() ?? '',
      dropoffLat: _number(dropoff['lat']),
      dropoffLng: _number(dropoff['lng']),
      scheduledTime: DateTime.tryParse(json['scheduledTime']?.toString() ?? ''),
      expiresAt: DateTime.tryParse(json['expiresAt']?.toString() ?? ''),
      currency: json['currency']?.toString() ?? '',
      priceCents: (json['priceCents'] as num?)?.toInt() ?? 0,
      driverPayoutCents: (json['driverPayoutCents'] as num?)?.toInt(),
      partner: json['partner']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
}

class MtaAcceptanceResult {
  final String tripId;
  final String partnerConfirmationStatus;
  final DateTime? partnerConfirmationAttemptedAt;
  final String? partnerConfirmationError;

  const MtaAcceptanceResult({
    required this.tripId,
    required this.partnerConfirmationStatus,
    required this.partnerConfirmationAttemptedAt,
    required this.partnerConfirmationError,
  });
}

class MtaApi {
  static const String _configuredBaseUrl =
      String.fromEnvironment('MTA_API_BASE_URL');
  static const String termsVersion = 'mta-driver-consent-v1';

  final SharedPreferenceManager _preferences;
  final http.Client _client;
  bool? _mtaEnabledFromServer;

  bool get isEnabledByServer => _mtaEnabledFromServer == true;

  MtaApi(this._preferences, {http.Client? client})
      : _client = client ?? http.Client();

  Uri _uri(String path) {
    final base = _configuredBaseUrl.trim();
    if (base.isEmpty) {
      throw const MtaApiException(
        'MTA is unavailable: configure --dart-define=MTA_API_BASE_URL.',
      );
    }
    final normalized = base.endsWith('/') ? base : '$base/';
    final uri = Uri.parse(normalized);
    if ((uri.scheme != 'https' && uri.scheme != 'http') || uri.host.isEmpty) {
      throw const MtaApiException(
        'MTA is unavailable: MTA_API_BASE_URL must be a valid HTTP(S) URL.',
      );
    }
    return uri.resolve(path);
  }

  Map<String, String> _headers({bool json = false, String? idempotencyKey}) {
    final token = _preferences.getAuthorization();
    if (token == null || token.isEmpty) {
      throw const MtaApiException('MTA request failed: sign in again.');
    }
    return {
      'Authorization': token.toLowerCase().startsWith('bearer ')
          ? token
          : 'Bearer $token',
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
      if (idempotencyKey != null) 'Idempotency-Key': idempotencyKey,
    };
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
  }) async {
    try {
      final uri = _uri(path);
      final headers = _headers(
        json: body != null,
        idempotencyKey: idempotencyKey,
      );
      final pending = switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const {}),
          ),
        _ => throw const MtaApiException('Unsupported MTA request.'),
      };
      final response = await pending.timeout(const Duration(seconds: 12));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        String? detail;
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody is Map) {
            detail = errorBody['error']?.toString() ??
                errorBody['message']?.toString();
          }
        } catch (_) {
          // Keep the safe HTTP status message for non-JSON error responses.
        }
        throw MtaApiException(
          detail == null || detail.isEmpty
              ? 'MTA request failed (HTTP ${response.statusCode}).'
              : 'MTA request failed: $detail',
          outcomeUnknown: response.statusCode >= 500,
        );
      }
      if (response.body.isEmpty) return <String, dynamic>{};
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['data'] is Map) {
        return Map<String, dynamic>.from(decoded['data'] as Map);
      }
      return decoded;
    } on MtaApiException {
      rethrow;
    } on TimeoutException {
      throw const MtaApiException(
        'MTA request timed out; its outcome is unknown.',
        outcomeUnknown: true,
      );
    } on http.ClientException {
      throw const MtaApiException(
        'MTA connection failed; the request outcome is unknown.',
        outcomeUnknown: true,
      );
    } catch (_) {
      throw const MtaApiException(
        'Could not connect to MTA. Check your connection and try again.',
        outcomeUnknown: true,
      );
    }
  }

  Future<MtaStatus> getStatus() async {
    final data = await _request('GET', 'status');
    if (data is! Map) {
      throw const MtaApiException('MTA returned an invalid status response.');
    }
    final status = MtaStatus.fromJson(Map<String, dynamic>.from(data));
    _mtaEnabledFromServer = status.mtaEnabled;
    return status;
  }

  Future<MtaStatus> setConsent({
    required bool accepted,
    required String name,
    required String phone,
    required String vehicle,
    String? licensePlate,
    String? tlcLicenseNumber,
  }) async {
    await _request('POST', 'consent', body: {
      'accepted': accepted,
      'termsVersion': termsVersion,
      'driver': {
        'name': name,
        'phone': phone,
        'vehicle': vehicle,
        if (licensePlate != null && licensePlate.isNotEmpty)
          'licensePlate': licensePlate,
        if (tlcLicenseNumber != null && tlcLicenseNumber.isNotEmpty)
          'tlcLicenseNumber': tlcLicenseNumber,
      },
    });
    // Status is authoritative; consent response is not assumed to carry
    // readiness or the server's final enabled state.
    return getStatus();
  }

  Future<void> updateLocation({
    double? latitude,
    double? longitude,
    DateTime? timestamp,
    required bool online,
    required bool available,
  }) async {
    if (online &&
        (latitude == null || longitude == null || timestamp == null)) {
      throw const MtaApiException(
        'A current GPS fix is required to update MTA while online.',
      );
    }
    await _request('POST', 'location', body: {
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
      if (timestamp != null)
        'timestamp': timestamp.toUtc().toIso8601String(),
      'online': online,
      'available': available,
    });
  }

  Future<void> setOfflineAvailabilityIfEnabled() async {
    if (_mtaEnabledFromServer == null) await getStatus();
    if (!isEnabledByServer) return;
    await updateLocation(online: false, available: false);
  }

  Future<List<MtaOffer>> getOffers() async {
    final data = await _request('GET', 'offers');
    if (data is! Map || data['offers'] is! List) {
      throw const MtaApiException('MTA returned an invalid offers response.');
    }
    return (data['offers'] as List)
        .whereType<Map>()
        .map((offer) => MtaOffer.fromJson(Map<String, dynamic>.from(offer)))
        .where((offer) => offer.tripId.isNotEmpty)
        .toList();
  }

  Future<MtaAcceptanceResult?> respondToOffer(
    MtaOffer offer, {
    required bool accept,
  }) async {
    final action = accept ? 'accept' : 'reject';
    final data = await _request(
      'POST',
      'offers/${Uri.encodeComponent(offer.tripId)}/$action',
      body: const {},
      idempotencyKey: 'mta-${offer.offerId}-$action',
    );
    if (!accept) return null;
    if (data is Map && data['accepted'] == false) {
      throw const MtaApiException('MTA did not accept the offer.');
    }
    if (data is! Map || data['accepted'] != true) {
      throw const MtaApiException(
        'MTA acceptance response was incomplete; the outcome is unknown.',
        outcomeUnknown: true,
      );
    }
    return MtaAcceptanceResult(
      tripId: data['tripId']?.toString() ?? offer.tripId,
      partnerConfirmationStatus:
          data['partnerConfirmationStatus']?.toString() ??
              data['partnerConfirmation']?.toString() ??
              'unknown',
      partnerConfirmationAttemptedAt: DateTime.tryParse(
        data['partnerConfirmationAttemptedAt']?.toString() ?? '',
      ),
      partnerConfirmationError:
          data['partnerConfirmationError']?.toString(),
    );
  }

  void dispose() => _client.close();
}

class MtaApiException implements Exception {
  final String message;
  final bool outcomeUnknown;
  const MtaApiException(this.message, {this.outcomeUnknown = false});
  @override
  String toString() => message;
}