import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/socket_constants.dart';
import '../core/localization/app_strings.dart';
import '../core/localization/string_constants.dart';
import '../core/managers/firebase_topic_manager.dart';
import '../core/managers/notification_manager.dart';
import '../models/requests/firebase_device_token_request.dart';
import '../core/managers/location_manager.dart';
import '../core/managers/location_service_manager.dart';
import '../core/managers/socket_manager.dart';
import '../core/utils/driver_location_provider.dart';
import '../core/map/models/map_types.dart';
import '../core/preferences/shared_preference_manager.dart';
import '../core/providers/app_providers.dart';
import '../data/api/response_state.dart';
import '../data/api/server_config.dart';
import '../data/api/mta_api.dart';
import '../data/repository/app_repository.dart';
import '../data/repository/history_repository.dart';
import '../models/requests/business_type_request.dart';
import '../models/requests/workflow_request.dart';
import '../models/requests/entity_detail_request.dart';
import '../models/requests/online_request.dart';
import '../models/requests/pick_vehicle_request.dart';
import '../models/missing_info_item.dart';
import '../models/responses/socket/socket_driver_live_location_response.dart';
import 'document_viewmodel.dart' show DocumentStatus;
import '../models/responses/auth/entity_detail_response.dart';
import '../models/responses/home/business_type_response.dart';
import '../models/requests/checkr_request.dart';
import '../models/responses/home/information_status_response.dart';
import '../models/responses/home/subscription_detail_response.dart';

/// Entity status constants matching backend values
class EntityStatus {
  static const int pending = 1;
  static const int decline = 2;
  static const int approve = 3;
  static const int block = 4;
  static const int offline = 5;
  static const int available = 6;
  static const int inBooking = 7;
  static const int availableForShare = 8;
  static const int nearAvailable = 9;

  static bool isOnlineStatus(int? status) {
    return status == available ||
        status == inBooking ||
        status == availableForShare ||
        status == nearAvailable;
  }
}

class HomeState {
  final bool isOnline;
  final bool isOnlineLoading;
  final String todayEarning;
  final String currencySign;

  // Zone queue
  final String zoneQueue;

  // Driver type flags
  final bool isHubDriver;
  final bool isPartnerDriver;

  // Vehicle state
  final bool isVehiclePickedUp;
  final bool isDriverVehicleRequired;

  // Location
  final double? currentLatitude;
  final double? currentLongitude;

  // Map pin
  final String? mapPinUrl;

  // Heat map
  final bool isHeatMapEnabled;

  // Cash booking wallet warning
  final bool isCreditStatusOk;
  final String cashBookingMinimumWallet;

  // Missing info / block / decline / approval
  final List<MissingInfoItem> missingInfoItems;
  final bool isBlockStatus;
  final bool isDeclineStatus;
  final String blockedUserMessage;
  final bool showApprovalScreen;

  // Subscription
  final VehicleSubscription? subscriptionDetail;
  final bool showSubscriptionInfoBottomSheet;
  final String? subscriptionInfoTitle;
  final String? subscriptionInfoPrice;
  final String? subscriptionInfoDescription;
  final bool isSubscriptionOptional;

  // Bidding
  final bool showBidding;

  // Create Request (driver-initiated taxi trip)
  final bool showCreateRequest;

  // Going-to address
  final String? goingToAddressTitle;
  final String? goingToAddressAddress;

  // Booking navigation
  final String? navigateToBookingId;

  // Snackbar
  final String? snackBarMessage;
  final bool isSnackBarError;
  final bool isMtaEnabled;
  final bool isMtaReady;
  final List<MtaOffer> mtaOffers;
  final MtaActiveTrip? activeMtaTrip;
  final String? mtaAcceptanceOutcomeUnknownTripId;
  final String? mtaOfferFailure;
  final String? mtaRespondingTripId;

  const HomeState({
    this.isOnline = false,
    this.isOnlineLoading = false,
    this.todayEarning = '0.00',
    this.currencySign = '\$',
    this.zoneQueue = '',
    this.isHubDriver = false,
    this.isPartnerDriver = false,
    this.isVehiclePickedUp = false,
    this.isDriverVehicleRequired = false,
    this.currentLatitude,
    this.currentLongitude,
    this.mapPinUrl,
    this.isHeatMapEnabled = false,
    this.isCreditStatusOk = true,
    this.cashBookingMinimumWallet = '',
    this.missingInfoItems = const [],
    this.isBlockStatus = false,
    this.isDeclineStatus = false,
    this.blockedUserMessage = '',
    this.showApprovalScreen = false,
    this.subscriptionDetail,
    this.showSubscriptionInfoBottomSheet = false,
    this.subscriptionInfoTitle,
    this.subscriptionInfoPrice,
    this.subscriptionInfoDescription,
    this.isSubscriptionOptional = true,
    this.showBidding = false,
    this.showCreateRequest = false,
    this.goingToAddressTitle,
    this.goingToAddressAddress,
    this.navigateToBookingId,
    this.snackBarMessage,
    this.isSnackBarError = false,
    this.isMtaEnabled = false,
    this.isMtaReady = false,
    this.mtaOffers = const [],
    this.activeMtaTrip,
    this.mtaAcceptanceOutcomeUnknownTripId,
    this.mtaOfferFailure,
    this.mtaRespondingTripId,
  });

  HomeState copyWith({
    bool? isOnline,
    bool? isOnlineLoading,
    String? todayEarning,
    String? currencySign,
    String? zoneQueue,
    bool? isHubDriver,
    bool? isPartnerDriver,
    bool? isVehiclePickedUp,
    bool? isDriverVehicleRequired,
    double? currentLatitude,
    double? currentLongitude,
    String? mapPinUrl,
    bool? isHeatMapEnabled,
    bool? isCreditStatusOk,
    String? cashBookingMinimumWallet,
    List<MissingInfoItem>? missingInfoItems,
    bool? isBlockStatus,
    bool? isDeclineStatus,
    String? blockedUserMessage,
    bool? showApprovalScreen,
    VehicleSubscription? subscriptionDetail,
    bool? showSubscriptionInfoBottomSheet,
    String? subscriptionInfoTitle,
    String? subscriptionInfoPrice,
    String? subscriptionInfoDescription,
    bool? isSubscriptionOptional,
    bool? showBidding,
    bool? showCreateRequest,
    String? goingToAddressTitle,
    String? goingToAddressAddress,
    bool clearGoingToAddress = false,
    String? navigateToBookingId,
    bool clearBookingNavigation = false,
    String? snackBarMessage,
    bool? isSnackBarError,
    bool clearSnackBar = false,
    bool? isMtaEnabled,
    bool? isMtaReady,
    List<MtaOffer>? mtaOffers,
    MtaActiveTrip? activeMtaTrip,
    bool clearActiveMtaTrip = false,
    String? mtaAcceptanceOutcomeUnknownTripId,
    bool clearMtaAcceptanceOutcomeUnknown = false,
    String? mtaOfferFailure,
    bool clearMtaOfferFailure = false,
    String? mtaRespondingTripId,
    bool clearMtaRespondingTripId = false,
  }) {
    return HomeState(
      isOnline: isOnline ?? this.isOnline,
      isOnlineLoading: isOnlineLoading ?? this.isOnlineLoading,
      todayEarning: todayEarning ?? this.todayEarning,
      currencySign: currencySign ?? this.currencySign,
      zoneQueue: zoneQueue ?? this.zoneQueue,
      isHubDriver: isHubDriver ?? this.isHubDriver,
      isPartnerDriver: isPartnerDriver ?? this.isPartnerDriver,
      isVehiclePickedUp: isVehiclePickedUp ?? this.isVehiclePickedUp,
      isDriverVehicleRequired:
          isDriverVehicleRequired ?? this.isDriverVehicleRequired,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
      mapPinUrl: mapPinUrl ?? this.mapPinUrl,
      isHeatMapEnabled: isHeatMapEnabled ?? this.isHeatMapEnabled,
      isCreditStatusOk: isCreditStatusOk ?? this.isCreditStatusOk,
      cashBookingMinimumWallet:
          cashBookingMinimumWallet ?? this.cashBookingMinimumWallet,
      missingInfoItems: missingInfoItems ?? this.missingInfoItems,
      isBlockStatus: isBlockStatus ?? this.isBlockStatus,
      isDeclineStatus: isDeclineStatus ?? this.isDeclineStatus,
      blockedUserMessage: blockedUserMessage ?? this.blockedUserMessage,
      showApprovalScreen: showApprovalScreen ?? this.showApprovalScreen,
      subscriptionDetail: subscriptionDetail ?? this.subscriptionDetail,
      showSubscriptionInfoBottomSheet: showSubscriptionInfoBottomSheet ?? this.showSubscriptionInfoBottomSheet,
      subscriptionInfoTitle: subscriptionInfoTitle ?? this.subscriptionInfoTitle,
      subscriptionInfoPrice: subscriptionInfoPrice ?? this.subscriptionInfoPrice,
      subscriptionInfoDescription: subscriptionInfoDescription ?? this.subscriptionInfoDescription,
      isSubscriptionOptional: isSubscriptionOptional ?? this.isSubscriptionOptional,
      showBidding: showBidding ?? this.showBidding,
      showCreateRequest: showCreateRequest ?? this.showCreateRequest,
      goingToAddressTitle: clearGoingToAddress
          ? null
          : (goingToAddressTitle ?? this.goingToAddressTitle),
      goingToAddressAddress: clearGoingToAddress
          ? null
          : (goingToAddressAddress ?? this.goingToAddressAddress),
      navigateToBookingId: clearBookingNavigation
          ? null
          : (navigateToBookingId ?? this.navigateToBookingId),
      snackBarMessage:
          clearSnackBar ? null : (snackBarMessage ?? this.snackBarMessage),
      isSnackBarError:
          clearSnackBar ? false : (isSnackBarError ?? this.isSnackBarError),
      isMtaEnabled: isMtaEnabled ?? this.isMtaEnabled,
      isMtaReady: isMtaReady ?? this.isMtaReady,
      mtaOffers: mtaOffers ?? this.mtaOffers,
      activeMtaTrip: clearActiveMtaTrip
          ? null
          : (activeMtaTrip ?? this.activeMtaTrip),
      mtaAcceptanceOutcomeUnknownTripId: clearMtaAcceptanceOutcomeUnknown
          ? null
          : (mtaAcceptanceOutcomeUnknownTripId ??
              this.mtaAcceptanceOutcomeUnknownTripId),
      mtaOfferFailure:
          clearMtaOfferFailure ? null : (mtaOfferFailure ?? this.mtaOfferFailure),
      mtaRespondingTripId: clearMtaRespondingTripId
          ? null
          : (mtaRespondingTripId ?? this.mtaRespondingTripId),
    );
  }
}

class HomeViewModel extends StateNotifier<HomeState> {
  final AppRepository _repository;
  final HistoryRepository _historyRepository;
  final SharedPreferenceManager _sharedPref;
  final SocketManager _socketManager;
  final LocationServiceManager _locationServiceManager;
  final DriverLocationProvider _driverLocationProvider;
  final MtaApi _mtaApi;

  Entity? _entity;
  Setting? _setting;
  StreamSubscription<DriverLocation>? _filteredLocationSubscription;
  StreamSubscription<SocketDriverLiveLocationResponse>? _ackSubscription;
  StreamSubscription<Position>? _uiLocationSubscription;
  StreamSubscription<Map<String, dynamic>>? _nativeMtaLocationSubscription;
  Timer? _mtaRefreshTimer;
  bool _mtaRefreshInProgress = false;
  bool _mtaActionInProgress = false;
  bool _mtaLocationSendInProgress = false;
  bool _isDisposed = false;
  String? _lastMtaError;
  DriverLocation? _latestMtaLocation;
  ({DriverLocation location, bool online})? _pendingMtaLocation;
  bool _isMtaAppForeground = true;

  HomeViewModel(
    this._repository,
    this._historyRepository,
    this._sharedPref,
    this._socketManager,
    this._locationServiceManager,
    this._driverLocationProvider,
    this._mtaApi,
  ) : super(const HomeState()) {
    // Push-driven, not socket-driven — register it up front so an approval
    // that lands while the driver is still on the "Not approved yet" screen
    // (where the socket isn't connected) is still picked up.
    _listenEntityStatusNotification();
  }

  // ── Location disclosure (Google Play prominent disclosure) ──────

  bool get hasAcceptedLocationDisclosure =>
      _sharedPref.getLocationDisclosureAccepted();

  Future<void> acceptLocationDisclosure() =>
      _sharedPref.setLocationDisclosureAccepted(true);

  // ── Initialization ──────────────────────────────────────────────

  void init() {
    startMtaPolling();
    _loadInitialState();
    _checkProfileStatus();
    _getCurrentLocation();
    _startUiLocationStream();
    _connectSocket();
    getEntityDetail();
    _updateDeviceToken();
  }

  void startMtaPolling() {
    if (_isDisposed || !_sharedPref.isLoggedIn()) return;
    _ensureMtaPollingTimer();
    resumeMtaPolling();
  }

  void _ensureMtaPollingTimer() {
    if (_mtaRefreshTimer?.isActive != true) {
      _mtaRefreshTimer = Timer.periodic(
        const Duration(seconds: 8),
        (_) => _refreshMta(),
      );
    }
  }

  void _loadInitialState() {
    _entity = _sharedPref.getEntity();
    _setting = _sharedPref.getSetting();

    final isOnline = EntityStatus.isOnlineStatus(_entity?.status);
    final isHubDriver = _entity?.type == EntityType.admin;
    final isPartnerDriver = _entity?.type == EntityType.partner;
    final isVehiclePickedUp =
        _entity?.typeId != null && (_entity?.typeId?.isNotEmpty ?? false);
    final isHeatMapEnabled = _sharedPref.getIsHeatMap();

    state = state.copyWith(
      isOnline: isOnline,
      todayEarning: _formatPrice(_entity?.earning ?? 0),
      currencySign: _setting?.currencySign ?? '\$',
      isHubDriver: isHubDriver,
      isPartnerDriver: isPartnerDriver,
      isVehiclePickedUp: isVehiclePickedUp,
      isDriverVehicleRequired: _entity?.isDriverVehicleRequired ?? false,
      mapPinUrl: _entity?.vehicleType?.mapPinUrl,
      isHeatMapEnabled: isHeatMapEnabled,
      showBidding: isOnline && _isBiddingAllowed(),
      showCreateRequest: isOnline && _isCreateRequestAllowed(),
    );

    // Load going-to address
    _loadGoingToAddress();

    // Always start GPS for UI map pin (regardless of online/offline)
    _driverLocationProvider.startGps(_sharedPref);
    _setupLocationStreams();

    // Restore native location service + ack if driver was online
    if (isOnline || _sharedPref.getIsOnline()) {
      _locationServiceManager.startService(serverUrl: ServerConfig.socketBaseUrl);
      _driverLocationProvider.startAckListening(_locationServiceManager);
    }
    _refreshMta();

    // Load subscription info for hub drivers
    if (isHubDriver) {
      getSubscriptionInfo();
    }

    // Load heat map if enabled
    if (isHeatMapEnabled) {
      fetchHeatMap();
    }
  }

  Future<void> _getCurrentLocation() async {
    final result = await LocationManager.instance.getCurrentLocation();
    if (result is LocationSuccess) {
      state = state.copyWith(
        currentLatitude: result.location.latitude,
        currentLongitude: result.location.longitude,
      );
    }
  }

  // ── Currency Formatting ─────────────────────────────────────────

  String _formatPrice(double value) {
    final decimals = _setting?.decimalPointValue ?? 2;
    final formatted = value.toStringAsFixed(decimals);
    final currency = _setting?.currencySign ?? '\$';
    final position = _setting?.setCurrencySign ?? SetCurrencySign.left;

    if (position == SetCurrencySign.right) {
      return '$formatted$currency';
    }
    return '$currency$formatted';
  }

  // ── Socket Connection ──────────────────────────────────────────

  void _connectSocket() {
    _socketManager.connect(onConnected: () {
      // Emit SIGN_UP event on connection
      _socketManager.emitEvent(
        SocketConstants.eventSignUp,
        ackCallback: (ackData) {
          debugPrint('HomeViewModel: SIGN_UP ack received -> $ackData');
        },
      );

      // Send initial location to get zone queue ack (mirrors Kotlin's
      // updateLocationToServer() on socket connect)
      _emitInitialLocation();

      // Listen for events
      _listenZoneQueue();
      _listenAutoOffline();
      _listenNewBooking();
      _listenBookingStatus();
    });
  }

  /// Push the driver's position to the server on the **Dart** socket.
  ///
  /// The native LocationService keeps its own socket and never emits SIGN_UP
  /// (the server allows one socket per driver), so anything it sends is not
  /// tied to this driver and the customer's `api/location/{bookingId}` stays
  /// empty — "Booking location not found". Native Android has no such split:
  /// its LocationService shares the one signed-up singleton socket. Emitting
  /// here puts the location back on the authenticated connection.
  void _emitLiveLocation(DriverLocation location) {
    if (!_socketManager.isConnected()) return;

    _socketManager.emitEvent(
      SocketConstants.driverLiveLocation,
      data: {
        'locations': [
          {
            'latitude': location.latitude,
            'longitude': location.longitude,
            'time': DateTime.now().millisecondsSinceEpoch,
            'speed': location.speed,
            'bearing': location.bearing,
          }
        ],
      },
      ackCallback: (ackData) {
        if (ackData is Map) {
          _handleLocationAckResponse(
            SocketDriverLiveLocationResponse.fromJson(
              Map<String, dynamic>.from(ackData),
            ),
          );
        }
      },
    );
  }

  void _emitInitialLocation() {
    final lat = state.currentLatitude;
    final lng = state.currentLongitude;
    if (lat == null || lng == null) return;

    _socketManager.emitEvent(
      SocketConstants.driverLiveLocation,
      data: {
        'locations': [
          {
            'latitude': lat,
            'longitude': lng,
            'time': DateTime.now().millisecondsSinceEpoch,
            'speed': 0,
            'bearing': 0,
          }
        ],
      },
      ackCallback: (ackData) {
        if (ackData is Map) {
          final response = SocketDriverLiveLocationResponse.fromJson(
            Map<String, dynamic>.from(ackData),
          );
          _setDriverZoneQueue(response);
        }
      },
    );
  }

  /// Admin approve/decline/block arrives as a push with `status=ENTITY_STATUS`
  /// and `id` set to the new entity status. Native reloads the entity on it
  /// (`HomeUIEvent.NewNotification` -> `getEntityDetail()`), which is what
  /// swaps the "Not approved yet" screen for the live home screen.
  void _listenEntityStatusNotification() {
    NotificationManager.instance.onEntityStatusChanged = (status) {
      const handled = [
        EntityStatus.pending,
        EntityStatus.decline,
        EntityStatus.approve,
        EntityStatus.block,
      ];
      if (!handled.contains(status)) return;

      debugPrint('HomeViewModel: ENTITY_STATUS push ($status) - reloading entity');
      getEntityDetail();
    };
  }

  void _listenZoneQueue() {
    _socketManager.listenEvent(
      SocketConstants.eventDriverZoneQueueNumber,
      (data) {
        if (data is Map) {
          final response = SocketDriverLiveLocationResponse.fromJson(
            Map<String, dynamic>.from(data),
          );
          _setDriverZoneQueue(response);
        }
      },
    );
  }

  void _listenAutoOffline() {
    _socketManager.listenEvent(
      SocketConstants.eventDriverAutoOffline,
      (data) async {
        debugPrint('HomeViewModel: auto offline received');
        await _sharedPref.putIsOnline(false);
        state = state.copyWith(
          isOnline: false,
          isOnlineLoading: false,
          zoneQueue: '',
          showBidding: false,
          showCreateRequest: false,
          clearGoingToAddress: true,
        );
        _driverLocationProvider.stopAckListening();
        await _locationServiceManager.stopService();
        _unsubscribeFirebaseTopics();
        await _notifyMtaOffline();
        _refreshMta();
        debugPrint('HomeViewModel: auto offline applied');
      },
    );
  }

  void _listenNewBooking() {
    _socketManager.listenEvent(
      SocketConstants.eventGetNewBooking,
      (data) {
        debugPrint('HomeViewModel: new booking received -> $data');
        final map = data is Map ? data : {};
        final bookingId = map['bookingId']?.toString();
        if (bookingId != null && bookingId.isNotEmpty) {
          _locationServiceManager.setHasBooking(true);
          state = state.copyWith(navigateToBookingId: bookingId);
        }
      },
    );
  }

  void _listenBookingStatus() {
    _socketManager.listenEvent(
      SocketConstants.bookingStatus,
      (data) {
        debugPrint('HomeViewModel: booking status received -> $data');
        final map = data is Map ? data : {};
        final status = map['status'] as int?;
        final bookingId = map['bookingId']?.toString();
        final driverId = map['driverId']?.toString();

        if (driverId == _entity?.id &&
            bookingId != null &&
            bookingId.isNotEmpty) {
          if (status == BookingStatus.accepted ||
              status == BookingStatus.inRoute) {
            state = state.copyWith(navigateToBookingId: bookingId);
          }
        }
      },
    );
  }

  void clearBookingNavigation() {
    state = state.copyWith(clearBookingNavigation: true);
  }

  // ── Online / Offline Toggle ────────────────────────────────────

  Future<void> toggleOnlineOffline() async {
    if (state.isOnlineLoading) return;

    // Don't allow going online if there are issues
    if (!state.isOnline && shouldHideGoButton) return;

    if (state.isOnline) {
      await goOffline();
    } else {
      await goOnline();
    }
  }

  Future<void> goOnline() async {
    state = state.copyWith(isOnlineLoading: true);

    // Ensure we have current location
    if (state.currentLatitude == null || state.currentLongitude == null) {
      await _getCurrentLocation();
    }

    if (state.currentLatitude == null || state.currentLongitude == null) {
      _showErrorSnackBar(
        getString(appStr.errorLocationNotAvailable, 'error_location_not_available'),
      );
      state = state.copyWith(isOnlineLoading: false);
      return;
    }

    // Step 1: Call businessType API to get bookingTypes (priceModes)
    final businessTypeRequest = BusinessTypeRequest(
      address: BusinessTypeAddress(
        latitude: state.currentLatitude,
        longitude: state.currentLongitude,
        countryCode: _entity?.countryCode,
      ),
    );

    final businessTypeResponse =
        await _repository.getBusinessType(businessTypeRequest);

    if (businessTypeResponse is Error) {
      state = state.copyWith(isOnlineLoading: false);
      _showErrorSnackBar(businessTypeResponse.error?.message ?? 'Something went wrong');
      return;
    }

    final businessTypes = businessTypeResponse is Success<BusinessTypeResponse>
        ? businessTypeResponse.data?.businessTypes
        : null;

    if (businessTypes == null || businessTypes.isEmpty) {
      state = state.copyWith(isOnlineLoading: false);
      _showErrorSnackBar(
        'Business is not available in your city',
      );
      return;
    }

    final apiBookingTypes = businessTypeResponse is Success<BusinessTypeResponse>
        ? (businessTypeResponse.data?.bookingTypes ?? const <int>[])
        : const <int>[];
    // Build price modes per business (mirrors native wsOnline) so delivery
    // (5,6), service, courier etc. are all requested — otherwise the server
    // won't dispatch those order types to this driver. Union with anything the
    // businessType API returned, as a safety net.
    final priceModeSet = <int>{
      ..._priceModesForBusinesses(businessTypes),
      ...apiBookingTypes,
    };
    final List<int> priceModes = priceModeSet.isNotEmpty
        ? (priceModeSet.toList()..sort())
        : [PriceMode.normal, PriceMode.sharing, PriceMode.rental];

    // Step 2: Call online API
    final request = OnlineRequest(
      businessTypes: businessTypes,
      priceModes: priceModes,
      latitude: state.currentLatitude,
      longitude: state.currentLongitude,
      businessLocation: (state.currentLatitude != null && state.currentLongitude != null)
          ? OnlineLocationRequest(
              type: 'Point',
              coordinates: [state.currentLongitude!, state.currentLatitude!],
            )
          : null,
    );

    final response = await _repository.online(request);

    if (response is Success) {
      await _sharedPref.putIsOnline(true);

      state = state.copyWith(
        isOnline: true,
        isOnlineLoading: false,
        showBidding: _isBiddingAllowed(),
        showCreateRequest: _isCreateRequestAllowed(),
      );

      // Start native location service + ack (GPS already running from init)
      await _locationServiceManager.startService(serverUrl: ServerConfig.socketBaseUrl);
      _driverLocationProvider.startAckListening(_locationServiceManager);

      // Subscribe to Firebase topics
      _subscribeFirebaseTopics();
      _queueLatestMtaLocation(online: true);
      _refreshMta();

      // Refresh entity detail after going online
      getEntityDetail();

      debugPrint('HomeViewModel: went online');
    } else {
      state = state.copyWith(isOnlineLoading: false);
      _showErrorSnackBar(response.message);
    }
  }

  Future<void> goOffline() async {
    state = state.copyWith(isOnlineLoading: true);
    await _performOffline();
  }

  Future<void> _performOffline() async {
    final response = await _repository.offline();

    if (response is Success) {
      await _sharedPref.putIsOnline(false);

      state = state.copyWith(
        isOnline: false,
        isOnlineLoading: false,
        zoneQueue: '',
        showBidding: false,
        showCreateRequest: false,
        clearGoingToAddress: true,
      );

      // Stop ack + native service (GPS keeps running for UI)
      _driverLocationProvider.stopAckListening();
      await _locationServiceManager.stopService();

      // Unsubscribe from Firebase topics
      _unsubscribeFirebaseTopics();
      await _notifyMtaOffline();
      _refreshMta();

      debugPrint('HomeViewModel: went offline');
    } else {
      state = state.copyWith(isOnlineLoading: false);
      _showErrorSnackBar(response.message);
    }
  }

  // ── UI Location Stream (works offline, like Kotlin's locationUtil.startLocationUpdates) ──

  /// Separate Geolocator stream for home screen UI (map pin + camera).
  /// Runs regardless of online/offline status — no foreground service needed.
  void _startUiLocationStream() {
    _uiLocationSubscription?.cancel();
    _uiLocationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      state = state.copyWith(
        currentLatitude: position.latitude,
        currentLongitude: position.longitude,
      );
    });
  }

  // ── Location Streams ─────────────────────────────────────────

  void _setupLocationStreams() {
    // Filtered stream → UI state updates (smooth map pin movement)
    _filteredLocationSubscription?.cancel();
    _filteredLocationSubscription =
        _driverLocationProvider.locationStream.listen((location) {
      state = state.copyWith(
        currentLatitude: location.latitude,
        currentLongitude: location.longitude,
      );
      _emitLiveLocation(location);
    });

    // The native location service continues emitting sensor fixes while the
    // app is backgrounded. Use its original timestamp; never re-stamp a cached
    // map coordinate as a fresh MTA location.
    _nativeMtaLocationSubscription?.cancel();
    _nativeMtaLocationSubscription =
        _locationServiceManager.locationStream.listen(_onNativeMtaLocation);

    // Ack stream → zone queue updates (from server response to DRIVER_LIVE_LOCATION)
    _ackSubscription?.cancel();
    _ackSubscription =
        _driverLocationProvider.ackStream.listen(_handleLocationAckResponse);
  }

  Future<void> _refreshMta() async {
    if (!_sharedPref.isLoggedIn()) {
      stopMtaPolling();
      return;
    }
    if (_mtaRefreshInProgress) return;
    _mtaRefreshInProgress = true;
    try {
      final status = await _mtaApi.getStatus();
      if (_isDisposed) return;
      _lastMtaError = null;
      final wasEnabled = state.isMtaEnabled;
      final wasReady = state.isMtaReady;
      _applyMtaStatus(status);
      if (status.mtaEnabled &&
          state.isOnline &&
          (!wasEnabled || (!wasReady && status.mtaReady))) {
        final latestLocation = _latestMtaLocation;
        if (latestLocation != null) {
          _queueMtaLocation(latestLocation, online: true);
        }
      }
      if (status.mtaEnabled && state.isOnline) {
        final previousOfferIds =
            state.mtaOffers
                .map((offer) =>
                    offer.offerId.isNotEmpty ? offer.offerId : offer.tripId)
                .toSet();
        final offers = await _mtaApi.getOffers();
        if (_isDisposed) return;
        final activeOffers = offers
            .where((offer) =>
                offer.expiresAt == null ||
                offer.expiresAt!.isAfter(DateTime.now()))
            .toList();
        state = state.copyWith(mtaOffers: activeOffers);
        if (!_isMtaAppForeground &&
            activeOffers.any((offer) => !previousOfferIds.contains(
                  offer.offerId.isNotEmpty ? offer.offerId : offer.tripId,
                ))) {
          await NotificationManager.instance.showNotification(
            title: 'New MTA trip offer',
            body: 'Open the app to review the offer.',
            payload: 'mta-offer',
            isHighPriority: true,
          );
        }
      } else {
        state = state.copyWith(mtaOffers: const []);
      }
    } on MtaApiException catch (error) {
      if (!_isDisposed) _reportMtaError(error.message);
    } catch (_) {
      if (!_isDisposed) _reportMtaError('Unable to load MTA trip offers.');
    } finally {
      _mtaRefreshInProgress = false;
    }
  }

  void _applyMtaStatus(MtaStatus status) {
    final activeTrip =
        status.activeTrip != null && status.activeTrip!.tripId.isNotEmpty
            ? status.activeTrip
            : null;
    if (!status.mtaEnabled) _latestMtaLocation = null;
    state = state.copyWith(
      isMtaEnabled: status.mtaEnabled,
      isMtaReady: status.mtaReady,
      mtaOffers: status.mtaEnabled ? state.mtaOffers : const [],
      activeMtaTrip: activeTrip,
      clearActiveMtaTrip: activeTrip == null,
    );
    if (activeTrip != null &&
        activeTrip.tripId == state.mtaAcceptanceOutcomeUnknownTripId) {
      state = state.copyWith(
        clearMtaAcceptanceOutcomeUnknown: true,
        clearMtaOfferFailure: true,
      );
    }
  }

  void stopMtaPolling() {
    _mtaRefreshTimer?.cancel();
    _mtaRefreshTimer = null;
    if (state.mtaOffers.isNotEmpty ||
        state.activeMtaTrip != null ||
        state.mtaAcceptanceOutcomeUnknownTripId != null ||
        state.mtaOfferFailure != null) {
      state = state.copyWith(
        mtaOffers: const [],
        clearActiveMtaTrip: true,
        clearMtaAcceptanceOutcomeUnknown: true,
        clearMtaOfferFailure: true,
      );
    }
  }

  void setMtaAppForeground(bool isForeground) {
    _isMtaAppForeground = isForeground;
    if (isForeground) startMtaPolling();
  }

  Future<void> resumeMtaPolling() async {
    if (_isDisposed || !_sharedPref.isLoggedIn()) return;
    _ensureMtaPollingTimer();
    await _refreshMta();
  }

  void _onNativeMtaLocation(Map<String, dynamic> event) {
    final latitudeValue = event['latitude'];
    final longitudeValue = event['longitude'];
    final timestampValue = event['time'];
    if (latitudeValue is! num ||
        longitudeValue is! num ||
        timestampValue is! num) {
      return;
    }
    final location = DriverLocation(
      latitude: latitudeValue.toDouble(),
      longitude: longitudeValue.toDouble(),
      speed: (event['speed'] as num?)?.toDouble() ?? 0,
      bearing: (event['bearing'] as num?)?.toDouble() ?? 0,
      time: timestampValue.toInt(),
    );
    if (!state.isMtaEnabled || !_mtaApi.isEnabledByServer) return;
    _latestMtaLocation = location;
    if (state.isOnline) {
      _queueMtaLocation(location, online: true);
    }
  }

  void _queueMtaLocation(DriverLocation location, {required bool online}) {
    if (!state.isMtaEnabled ||
        !_mtaApi.isEnabledByServer ||
        !_sharedPref.isLoggedIn() ||
        (_sharedPref.getAuthorization()?.isEmpty ?? true)) {
      return;
    }
    final sensorTime =
        DateTime.fromMillisecondsSinceEpoch(location.time, isUtc: true);
    final age = DateTime.now().toUtc().difference(sensorTime);
    // Old cached sensor fixes must not renew the backend's location TTL.
    if (age.isNegative || age > const Duration(seconds: 30)) return;
    _pendingMtaLocation = (location: location, online: online);
    if (_mtaLocationSendInProgress) return;
    _drainMtaLocationQueue();
  }

  void _queueLatestMtaLocation({required bool online}) {
    final location = _latestMtaLocation;
    if (location != null) _queueMtaLocation(location, online: online);
  }

  Future<void> _notifyMtaOffline() async {
    try {
      await _mtaApi.setOfflineAvailabilityIfEnabled();
    } on MtaApiException catch (error) {
      if (!_isDisposed) _reportMtaError(error.message);
    } catch (_) {
      if (!_isDisposed) {
        _reportMtaError('Unable to notify MTA that you are offline.');
      }
    }
  }

  Future<void> _drainMtaLocationQueue() async {
    if (_mtaLocationSendInProgress) return;
    _mtaLocationSendInProgress = true;
    try {
      while (_pendingMtaLocation != null && !_isDisposed) {
        final pending = _pendingMtaLocation!;
        _pendingMtaLocation = null;
        final location = pending.location;
        final sensorTime =
            DateTime.fromMillisecondsSinceEpoch(location.time, isUtc: true);
        final age = DateTime.now().toUtc().difference(sensorTime);
        if (age.isNegative || age > const Duration(seconds: 30)) continue;
        if (!state.isMtaEnabled ||
            !_mtaApi.isEnabledByServer ||
            !_sharedPref.isLoggedIn() ||
            (_sharedPref.getAuthorization()?.isEmpty ?? true)) {
          continue;
        }
        try {
          await _mtaApi.updateLocation(
            latitude: location.latitude,
            longitude: location.longitude,
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              location.time,
              isUtc: true,
            ),
            online: pending.online,
            available: pending.online && state.isMtaReady,
          );
        } on MtaApiException catch (error) {
          if (!_isDisposed) _reportMtaError(error.message);
        } catch (_) {
          if (!_isDisposed) {
            _reportMtaError('Unable to update MTA location.');
          }
        }
      }
    } finally {
      _mtaLocationSendInProgress = false;
      if (_pendingMtaLocation != null && !_isDisposed) {
        _drainMtaLocationQueue();
      }
    }
  }

  void _reportMtaError(String message) {
    if (_isDisposed) return;
    if (_lastMtaError == message) return;
    _lastMtaError = message;
    _showErrorSnackBar(message);
  }

  Future<void> respondToMtaOffer(
    MtaOffer offer, {
    required bool accept,
  }) async {
    if (_mtaActionInProgress) return;
    _mtaActionInProgress = true;
    state = state.copyWith(
      mtaRespondingTripId: offer.tripId,
      clearMtaOfferFailure: true,
    );
    try {
      final result = await _mtaApi.respondToOffer(offer, accept: accept);
      if (_isDisposed) return;
      state = state.copyWith(
        mtaOffers: state.mtaOffers
            .where((item) => item.tripId != offer.tripId)
            .toList(),
        activeMtaTrip: accept
            ? MtaActiveTrip(
                tripId: result?.tripId ?? offer.tripId,
                status: 'booked',
                partnerConfirmationStatus:
                    result?.partnerConfirmationStatus ?? 'unknown',
                partnerConfirmationAttemptedAt:
                    result?.partnerConfirmationAttemptedAt,
                partnerConfirmationError:
                    result?.partnerConfirmationError,
              )
            : null,
        clearActiveMtaTrip: !accept,
        clearMtaAcceptanceOutcomeUnknown: true,
        clearMtaOfferFailure: true,
        clearMtaRespondingTripId: true,
      );
      _lastMtaError = null;
      // MTA trips deliberately do not navigate to Core's booking flow.
      await _refreshMta();
    } on MtaApiException catch (error) {
      if (_isDisposed) return;
      if (accept && error.outcomeUnknown) {
        state = state.copyWith(
          mtaAcceptanceOutcomeUnknownTripId: offer.tripId,
          mtaOfferFailure:
              'Acceptance outcome unknown; checking the latest MTA status.',
          clearMtaRespondingTripId: true,
        );
        _reportMtaError(
          'MTA did not return an acceptance result. Checking trip status.',
        );
        try {
          final status = await _mtaApi.getStatus();
          if (_isDisposed) return;
          _lastMtaError = null;
          _applyMtaStatus(status);
        } on MtaApiException catch (statusError) {
          if (!_isDisposed) _reportMtaError(statusError.message);
        } catch (_) {
          if (!_isDisposed) {
            _reportMtaError('Unable to verify the MTA trip status.');
          }
        }
        if (_isDisposed) return;
        if (state.activeMtaTrip?.tripId != offer.tripId) {
          state = state.copyWith(
            mtaOfferFailure:
                'Acceptance outcome remains unknown. MTA has not confirmed '
                'whether this trip is booked; do not assume the request failed.',
          );
        }
        return;
      }
      state = state.copyWith(
        mtaOfferFailure:
            '${accept ? 'Acceptance' : 'Rejection'} failed: ${error.message}',
        clearMtaRespondingTripId: true,
      );
      _reportMtaError(error.message);
    } catch (_) {
      if (_isDisposed) return;
      state = state.copyWith(
        mtaOfferFailure: accept
            ? 'Acceptance failed: MTA could not accept this offer.'
            : 'Rejection failed: MTA could not reject this offer.',
        clearMtaRespondingTripId: true,
      );
      _reportMtaError('Unable to respond to this MTA offer.');
    } finally {
      _mtaActionInProgress = false;
    }
  }

  void _handleLocationAckResponse(SocketDriverLiveLocationResponse response) {
    _setDriverZoneQueue(response);
  }

  void _setDriverZoneQueue(SocketDriverLiveLocationResponse response) {
    final zoneId = response.zoneId ?? '';
    final zoneName = response.zoneName ?? '';
    final queueNumber = response.zoneQueueNumber ?? 0;

    final zoneQueue = zoneId.isNotEmpty && queueNumber > 0
        ? getString(appStr.descriptionZoneQueueNo, 'description_zone_queue_no')
            .replacePlaceholders({
            StringConstant.zoneName: zoneName,
            StringConstant.number: queueNumber,
          })
        : '';

    state = state.copyWith(zoneQueue: zoneQueue);
  }

  // ── Entity Detail ──────────────────────────────────────────────

  Future<void> getEntityDetail() async {
    final response = await _repository.getEntityDetail(
      EntityDetailRequest(countryCode: _entity?.countryCode),
    );

    if (response is Success<EntityDetailResponse>) {
      final entityDetail = response.data;
      if (entityDetail == null) return;

      final entity = entityDetail.entity;
      final setting = entityDetail.setting;

      if (entity != null) {
        _entity = entity;
        await _sharedPref.setEntity(entity);
      }
      if (setting != null) {
        _setting = setting;
        await _sharedPref.setSetting(setting);
      }

      final isOnline = EntityStatus.isOnlineStatus(entity?.status);
      final isHubDriver = entity?.type == EntityType.admin;
      final isPartnerDriver = entity?.type == EntityType.partner;
      final isVehiclePickedUp =
          entity?.typeId != null && (entity?.typeId?.isNotEmpty ?? false);

      state = state.copyWith(
        isOnline: isOnline,
        todayEarning: _formatPrice(entity?.earning ?? 0),
        currencySign: setting?.currencySign ?? _setting?.currencySign ?? '\$',
        isHubDriver: isHubDriver,
        isPartnerDriver: isPartnerDriver,
        isVehiclePickedUp: isVehiclePickedUp,
        isDriverVehicleRequired: entity?.isDriverVehicleRequired ?? false,
        mapPinUrl: entity?.vehicleType?.mapPinUrl,
        showBidding: isOnline && _isBiddingAllowed(),
      );

      // Load going-to address from entity
      _loadGoingToAddress();

      // If server says online but location service isn't running, start it
      if (isOnline) {
        final isServiceRunning = await _locationServiceManager.isRunning();
        if (!isServiceRunning) {
          await _locationServiceManager.startService(serverUrl: ServerConfig.socketBaseUrl);
          _driverLocationProvider.startAckListening(_locationServiceManager);
        }
      }

      // Re-check profile status after entity update
      _checkProfileStatus();

      // Fetch information status (missing info, subscription) — same as Kotlin
      getInformationStatus();

      // Check for active bookings and navigate
      _checkActiveBookings(entity);
    }
  }

  void _checkActiveBookings(Entity? entity) {
    if (entity == null) return;
    final allBookingIds = [
      ...(entity.bookingIds ?? []),
      ...(entity.fixedGroupBookingIds ?? []),
      ...(entity.runningFixedGroupBookingIds ?? []),
      ...(entity.scheduleBookingIds ?? []),
    ];

    // Update hasBooking flag (matches Kotlin BookingList.setHasBooking)
    _locationServiceManager.setHasBooking(allBookingIds.isNotEmpty);

    if (allBookingIds.isNotEmpty) {
      final bType = entity.businessTypes?.firstOrNull;
      if (bType == BusinessType.taxi || bType == BusinessType.courier) {
        state = state.copyWith(navigateToBookingId: allBookingIds.first);
      }
    }
  }

  /// Show create request only when:
  /// - countryId is not empty (iOS/Kotlin: unverified driver sees nothing)
  /// - business type is TAXI (1) or SERVICE (4)
  /// Price modes (booking types) per business, mirroring native wsOnline:
  /// taxi→[1,2,3,7], quickCommerce→[4], delivery→[5,6], service→[8,9,10],
  /// courier→[41,42,43,44].
  List<int> _priceModesForBusinesses(List<int> businessTypes) {
    final modes = <int>{};
    for (final bt in businessTypes) {
      switch (bt) {
        case 1: // taxi
          modes.addAll([1, 2, 3, 7]);
        case 2: // quick commerce
          modes.add(4);
        case 3: // delivery
          modes.addAll([5, 6]);
        case 4: // service
          modes.addAll([8, 9, 10]);
        case 5: // courier
          modes.addAll([41, 42, 43, 44]);
      }
    }
    return modes.toList();
  }

  /// Bidding is a taxi-only feature, so a driver who doesn't serve taxi has no
  /// use for the button. Native gates it the same way
  /// (HomeViewModel.kt:1720: `isOnline && entity.businessTypes.contains(TAXI)`);
  /// here it was left on for anyone who went online.
  bool _isBiddingAllowed() =>
      _entity?.businessTypes?.contains(BusinessType.taxi) == true;

  bool _isCreateRequestAllowed() {
    final countryId = _entity?.countryId;
    if (countryId == null || countryId.isEmpty) return false;
    final types = _entity?.businessTypes;
    if (types == null) return false;
    return types.contains(1) || types.contains(4);
  }

  // ── Going-to Address ──────────────────────────────────────────

  void _loadGoingToAddress() {
    final selectedAddr = _entity?.selectedAddress;
    if (selectedAddr != null &&
        (selectedAddr.address?.isNotEmpty ?? false)) {
      state = state.copyWith(
        goingToAddressTitle: selectedAddr.title ?? '',
        goingToAddressAddress: selectedAddr.address ?? '',
      );
    } else {
      state = state.copyWith(clearGoingToAddress: true);
    }
  }

  // ── Device Token ─────────────────────────────────────────────

  Future<void> _updateDeviceToken() async {
    // Wait briefly for FCM token to be available (may not be ready immediately)
    String? fcmToken = NotificationManager.instance.fcmToken;
    if (fcmToken == null) {
      await Future.delayed(const Duration(seconds: 3));
      fcmToken = NotificationManager.instance.fcmToken;
    }
    if (fcmToken == null) return;

    final request = FirebaseDeviceTokenRequest(deviceToken: fcmToken);
    await _repository.updateDeviceToken(request);
  }

  // ── Firebase Topics ────────────────────────────────────────────

  void _subscribeFirebaseTopics() {
    FirebaseTopicManager.instance.subscribeToTopics(
      cityId: _entity?.cityId,
      countryId: _entity?.countryId,
      businessType: BusinessType.taxi,
    );
  }

  void _unsubscribeFirebaseTopics() {
    FirebaseTopicManager.instance.unsubscribeFromTopics();
  }

  // ── Heat Map ───────────────────────────────────────────────────

  Future<void> toggleHeatMap() async {
    final newValue = !state.isHeatMapEnabled;
    await _sharedPref.putIsHeatMap(newValue);
    state = state.copyWith(isHeatMapEnabled: newValue);

    if (newValue) {
      await fetchHeatMap();
    }
  }

  Future<void> fetchHeatMap() async {
    final response = await _historyRepository.getHeatMap();
    if (response is Success<dynamic>) {
      // Heat map data will be consumed by the screen to render on map
      debugPrint('HomeViewModel: heat map data loaded');
    }
  }

  // ── Vehicle Pickup / Drop (Hub Drivers) ────────────────────────

  Future<bool> pickVehicle(String vehicleId) async {
    final response = await _repository.pickVehicle(
      vehicleId: vehicleId,
      request: PickVehicleRequest(),
    );

    if (response is Success) {
      state = state.copyWith(isVehiclePickedUp: true);
      await getEntityDetail();
      debugPrint('HomeViewModel: vehicle picked up');
      return true;
    }
    _showErrorSnackBar(response.message);
    return false;
  }

  Future<bool> dropVehicle(String vehicleId) async {
    final response = await _repository.dropVehicle(vehicleId: vehicleId);

    if (response is Success) {
      state = state.copyWith(isVehiclePickedUp: false);
      await getEntityDetail();
      debugPrint('HomeViewModel: vehicle dropped');
      return true;
    }
    _showErrorSnackBar(response.message);
    return false;
  }

  // ── Subscription Info ──────────────────────────────────────────

  void dismissSubscriptionInfoBottomSheet() {
    state = state.copyWith(showSubscriptionInfoBottomSheet: false);
  }

  bool _isLoadingSubscriptionInfo = false;

  Future<void> getSubscriptionInfo() async {
    if (_isLoadingSubscriptionInfo) return;
    _isLoadingSubscriptionInfo = true;
    final response = await _repository.getSubscriptionVehicleInfo();
    _isLoadingSubscriptionInfo = false;
    if (response is Success<SubscriptionVehicleInfoResponse>) {
      final vehicleSubscription = response.data?.vehicleSubscription;
      final subscription = vehicleSubscription?.subscription;
      final pkg = subscription?.subscriptionPackage;
      final usage = vehicleSubscription?.usageSubscription;

      // Build title: "PackageName (VehicleType)"
      var title = pkg?.name ?? '';
      if (title.isNotEmpty && (subscription?.vehicleTypeName?.isNotEmpty ?? false)) {
        title = '$title (${subscription!.vehicleTypeName})';
      }

      // Build price
      final price = pkg?.price != null ? _formatPrice(pkg!.price!) : null;

      // Build description list (benefits)
      final descriptionList = _buildSubscriptionDescription(pkg, usage);

      state = state.copyWith(
        subscriptionDetail: vehicleSubscription,
        showSubscriptionInfoBottomSheet: true,
        subscriptionInfoTitle: title.isNotEmpty ? title : null,
        subscriptionInfoPrice: price,
        subscriptionInfoDescription: descriptionList.isNotEmpty
            ? descriptionList.join('\n')
            : null,
        isSubscriptionOptional: _setting?.subscriptionConfig?.isOptional ?? true,
      );
    }
  }

  List<String> _buildSubscriptionDescription(
      SubscriptionPackage? pkg, SubscriptionPackage? usage) {
    final list = <String>[];

    if (pkg?.adminProfit != null && pkg!.adminProfit! > 0) {
      final usageStr = (pkg.currentAdminProfit ?? 0) > 0
          ? ' - ${pkg.currentAdminProfit}%'
          : '';
      list.add(getString(appStr.descriptionAdminProfit, 'description_admin_profit')
          .replacePlaceholders({StringConstant.value: '${pkg.adminProfit}%$usageStr'}));
    }

    if (pkg?.maxBookingsReceivedPerDay?.isActive == true) {
      final usageStr = usage?.maxBookingsReceivedPerDay?.value != null
          ? ' - ${usage!.maxBookingsReceivedPerDay!.value!.toInt()}'
          : '';
      list.add(getString(appStr.descriptionMaximumDailyBookingsReceived,
              'description_maximum_daily_bookings_received')
          .replacePlaceholders({StringConstant.value: '${pkg!.maxBookingsReceivedPerDay!.value?.toInt() ?? 0}$usageStr'}));
    }

    if (pkg?.maxCanceledBookingsAllowed?.isActive == true) {
      final usageStr = usage?.maxCanceledBookingsAllowed?.value != null
          ? ' - ${usage!.maxCanceledBookingsAllowed!.value!.toInt()}'
          : '';
      list.add(getString(appStr.descriptionMaximumCancelledBookingsAfterAccept,
              'description_maximum_cancelled_bookings_after_accept')
          .replacePlaceholders({StringConstant.value: '${pkg!.maxCanceledBookingsAllowed!.value?.toInt() ?? 0}$usageStr'}));
    }

    if (pkg?.maxScheduledRidesPerDay?.isActive == true) {
      final usageStr = usage?.maxScheduledRidesPerDay?.value != null
          ? ' - ${usage!.maxScheduledRidesPerDay!.value!.toInt()}'
          : '';
      list.add(getString(appStr.descriptionMaximumDailyScheduledRides,
              'description_maximum_daily_scheduled_rides')
          .replacePlaceholders({StringConstant.value: '${pkg!.maxScheduledRidesPerDay!.value?.toInt() ?? 0}$usageStr'}));
    }

    return list;
  }

  // ── Information Status ─────────────────────────────────────────

  Future<void> getInformationStatus() async {
    // Skip if blocked
    if (state.isBlockStatus) return;

    // Declined users — show approval screen directly without API call
    if (state.isDeclineStatus) {
      state = state.copyWith(
        showApprovalScreen: true,
        missingInfoItems: [
          MissingInfoItem(
            id: 0,
            title: getString(
              appStr.errorNotApprovedYet,
              'error_not_approved_yet',
            ),
            description: _withCheckrStatus(getString(
              appStr.descriptionYourAccountIsDeclined,
              'description_your_account_is_declined',
            )),
            isEnabled: false,
          ),
        ],
      );
      return;
    }

    final response = await _repository.getInformationStatus();
    if (response is Success<InformationStatusResponse>) {
      final data = response.data;
      if (data == null) return;

      final info = data.informationStatus;
      final creditOk = info?.creditStatus ?? true;
      final minWallet = data.cashBookingMinimumWallet;
      final formatted =
          minWallet != null ? _formatPrice(minWallet.toDouble()) : '';

      state = state.copyWith(
        isCreditStatusOk: creditOk,
        cashBookingMinimumWallet: formatted,
      );

      _processInformationStatus(info);

      // Load subscription info if needed
      if (info?.subscriptionStatus == true) {
        getSubscriptionInfo();
      }
    }
  }

  void _processInformationStatus(InformationStatus? info) {
    if (info == null) return;

    // Build actionable missing info items (Mode A)
    final actionableItems = _buildMissingInfoList(info);

    if (actionableItems.isNotEmpty) {
      // Mode A: User has actionable items to complete
      state = state.copyWith(
        missingInfoItems: actionableItems,
        showApprovalScreen: false,
      );
      return;
    }

    // No actionable items — check for approval items (Mode B)
    final approvalItems = _buildApprovalList(info);

    if (approvalItems.isNotEmpty) {
      final allNonActionable = approvalItems.every((item) => !item.isEnabled);
      if (allNonActionable) {
        // Mode B: All items are non-actionable (pending review)
        state = state.copyWith(
          missingInfoItems: approvalItems,
          showApprovalScreen: true,
        );
      } else {
        // Some items are actionable (rejected/expired) — show as Mode A
        state = state.copyWith(
          missingInfoItems: approvalItems,
          showApprovalScreen: false,
        );
      }
    } else {
      // All clear — no missing info or approval needed
      state = state.copyWith(
        missingInfoItems: [],
        showApprovalScreen: false,
      );
    }
  }

  // ── Profile Status & Missing Info ───────────────────────────────

  bool get shouldHideGoButton =>
      state.isBlockStatus ||
      state.isDeclineStatus ||
      state.missingInfoItems.isNotEmpty ||
      (state.isHubDriver && !state.isVehiclePickedUp);

  String? get entityCountryId => _entity?.countryId;

  void _checkProfileStatus() {
    final status = _entity?.status;
    switch (status) {
      case EntityStatus.decline:
        state = state.copyWith(
          isDeclineStatus: true,
          isBlockStatus: false,
          blockedUserMessage: '',
        );
        break;
      case EntityStatus.block:
        state = state.copyWith(
          isBlockStatus: true,
          blockedUserMessage: getString(
            appStr.descriptionYourAccountIsBlocked,
            'description_your_account_is_blocked',
          ),
        );
        break;
      case EntityStatus.approve:
        state = state.copyWith(
          isDeclineStatus: false,
          isBlockStatus: false,
          blockedUserMessage: '',
        );
        break;
    }
  }

  List<MissingInfoItem> _buildMissingInfoList(InformationStatus? info) {
    if (info == null) return [];

    final items = <MissingInfoItem>[];

    if (info.countryStatus == false) {
      items.add(MissingInfoItem(
        id: 4,
        title: getString(appStr.hintCountry, 'hint_country'),
        description: getString(appStr.errorPleaseUpdateCountry, 'error_please_update_country'),
      ));
    }

    if (info.cityStatus == false) {
      items.add(MissingInfoItem(
        id: 5,
        title: getString(appStr.hintCity, 'hint_city'),
        description: getString(appStr.errorPleaseUpdateCity, 'error_please_update_city'),
      ));
    }

    if (info.profileStatus == false) {
      items.add(MissingInfoItem(
        id: 6,
        title: getString(appStr.headingProfile, 'heading_profile'),
        description: getString(
          appStr.errorPleaseUpdateProfile,
          'error_please_update_profile',
        ),
      ));
    }

    if (info.documentStatus == DocumentStatus.pending.value) {
      items.add(MissingInfoItem(
        id: 1,
        title: getString(appStr.headingDocument, 'heading_document'),
        description: getString(
          appStr.errorPleaseUpdateMandatoryDocument,
          'error_please_update_mandatory_document',
        ),
      ));
    }

    if (info.vehicleStatus == false && !state.isHubDriver) {
      items.add(MissingInfoItem(
        id: 2,
        title: getString(appStr.headingVehicles, 'heading_vehicles'),
        description: getString(appStr.errorPleaseAddVehicle, 'error_please_add_vehicle'),
      ));
    }

    if (info.availableStatus == false) {
      items.add(MissingInfoItem(
        id: 7,
        title: getString(appStr.headingAvailability, 'heading_availability'),
        description: getString(appStr.errorNoAvailabilityAdded, 'error_no_availability_added'),
      ));
    }

    if (info.vehicleDocumentStatus == DocumentStatus.pending.value &&
        info.vehicleStatus == true) {
      items.add(MissingInfoItem(
        id: 3,
        title: getString(appStr.subHeadingVehicleDocument, 'sub_heading_vehicle_document'),
        description: getString(
          appStr.errorPleaseUpdateMandatoryVehicleDocument,
          'error_please_update_mandatory_vehicle_document',
        ),
      ));
    }

    // Item 11: Select Business (workflowTypes empty & driver type)
    final workflowTypes = info.workflowTypes;
    if ((workflowTypes == null || workflowTypes.isEmpty) &&
        _entity?.type == EntityType.driver) {
      items.add(MissingInfoItem(
        id: 11,
        title: getString(appStr.headingSelectBusiness, 'heading_select_business'),
        description: getString(appStr.errorPleaseSelectBusiness, 'error_please_select_business'),
      ));
    }

    // Item 8: Assessment
    final assessmentStatus = info.assessmentStatus;
    if (assessmentStatus == AssessmentStatus.pending ||
        assessmentStatus == AssessmentStatus.failed) {
      final assessment = info.assessment;
      items.add(MissingInfoItem(
        id: 8,
        title: assessment?.title ??
            getString(appStr.headingAssessment, 'heading_assessment'),
        description: assessment?.description ??
            getString(appStr.errorPleaseCompleteAssessment, 'error_please_complete_assessment'),
        data: assessment,
      ));
    }

    // Item 9: Application Form
    if (info.isApplicationFormDownloaded == false) {
      final appForm = info.applicationForm;
      items.add(MissingInfoItem(
        id: 9,
        title: appForm?.title ??
            getString(appStr.headingApplicationForm, 'heading_application_form'),
        description: appForm?.description ??
            getString(appStr.errorPleaseDownloadApplicationForm, 'error_please_download_application_form'),
        data: appForm,
      ));
    }

    // Item 10: ABN
    if (info.isAbnSubmitted == false) {
      final abnConfig = info.abnConfig;
      items.add(MissingInfoItem(
        id: 10,
        title: abnConfig?.title ?? getString(appStr.headingAbn, 'heading_abn'),
        description: abnConfig?.description ??
            getString(appStr.errorPleaseSubmitAbn, 'error_please_submit_abn'),
        data: abnConfig,
      ));
    }

    // Item 12: Police Check
    if (info.isPoliceCheckSubmitted == false) {
      final policeConfig = info.policeCheckConfig;
      items.add(MissingInfoItem(
        id: 12,
        title: policeConfig?.title ??
            getString(appStr.headingPoliceCheck, 'heading_police_check'),
        description: policeConfig?.description ??
            getString(appStr.errorPleaseSubmitPoliceCheck, 'error_please_submit_police_check'),
        data: policeConfig,
      ));
    }

    // Item 13: Additional Terms (each unaccepted term is a separate item)
    if (info.isAdditionalTermsAccepted == false) {
      final terms = info.additionalTerms;
      if (terms != null) {
        for (final term in terms) {
          if (term.isAccepted != true) {
            items.add(MissingInfoItem(
              id: 13,
              title: term.title ?? getString(appStr.headingAdditionalTerms, 'heading_additional_terms'),
              description:
                  getString(appStr.errorPleaseAcceptAdditionalTerms, 'error_please_accept_additional_terms'),
              data: term,
            ));
          }
        }
      }
    }

    if (info.isCheckrStatus == false) {
      items.add(MissingInfoItem(
        id: 103,
        title: getString(appStr.headingCheckr, 'heading_checkr'),
        description: getString(
          appStr.descriptionBackgroundVerification,
          'description_background_verification',
        ),
      ));
    }

    return items;
  }

  /// Extra line appended to the "not approved yet" / declined messages telling
  /// the driver where their background check stands. Empty when the entity has
  /// no Checkr record — mirrors native's `getCheckrStatusMessage()`.
  String _checkrStatusMessage() {
    final status = _entity?.checkrCheck?.status;
    if (status == null) return '';

    return switch (status) {
      CheckrStatus.uploaded => getString(
          appStr.descriptionCheckrInProgress, 'description_checkr_in_progress'),
      CheckrStatus.pending => getString(
          appStr.descriptionCheckrPending, 'description_checkr_pending'),
      CheckrStatus.verified => getString(
          appStr.descriptionCheckrVerified, 'description_checkr_verified'),
      CheckrStatus.reviewRequired => getString(
          appStr.descriptionCheckrReviewRequired,
          'description_checkr_review_required'),
      _ => '',
    };
  }

  /// Appends the Checkr line below [message], separated by a blank line, the
  /// way native does with `.plus("\n\n").plus(getCheckrStatusMessage())`.
  String _withCheckrStatus(String message) {
    final checkr = _checkrStatusMessage();
    return checkr.isEmpty ? message : '$message\n\n$checkr';
  }

  /// Starts a Checkr background check and returns the URL to open in a WebView.
  /// Mirrors the native `initiateCheckr()`.
  Future<String?> initiateCheckr() async {
    final entity = _sharedPref.getEntity();

    final response = await _repository.initiateCheckr(
      CheckrRequest(
        typeId: entity?.id ?? '',
        firstName: entity?.firstName ?? '',
        lastName: entity?.lastName ?? '',
        email: entity?.email ?? '',
      ),
    );

    switch (response) {
      case Success():
        final url = response.data?.continueUrl;
        debugPrint('Checkr: status=${response.data?.status} url=$url');
        if (url != null && url.isNotEmpty) return url;
        state = state.copyWith(
          snackBarMessage: response.message,
          isSnackBarError: true,
        );
        return null;
      case Error():
        state = state.copyWith(
          snackBarMessage: response.error?.message,
          isSnackBarError: true,
        );
        return null;
      case Loading():
        return null;
    }
  }

  List<MissingInfoItem> _buildApprovalList(InformationStatus? info) {
    if (info == null) return [];

    final items = <MissingInfoItem>[];
    final docStatus = info.documentStatus ?? 0;
    final vehDocStatus = info.vehicleDocumentStatus ?? 0;

    final isUploaded = docStatus == DocumentStatus.uploaded.value ||
        vehDocStatus == DocumentStatus.uploaded.value ||
        _entity?.status == EntityStatus.pending;

    if (isUploaded) {
      // Admin is reviewing — not actionable
      items.add(MissingInfoItem(
        id: 6,
        title: getString(
          appStr.errorNotApprovedYet,
          'error_not_approved_yet',
        ),
        description: _withCheckrStatus(getString(
            appStr.errorAdminReviewYourProfile, 'error_admin_review_your_profile')),
        isEnabled: false,
      ));
    } else {
      if (docStatus == DocumentStatus.rejected.value) {
        items.add(MissingInfoItem(
          id: 1,
          title: getString(
            appStr.errorNotApprovedYet,
            'error_not_approved_yet',
          ),
          description: getString(appStr.errorAdminDocRejected, 'error_admin_doc_rejected'),
        ));
        return items;
      }
      if (docStatus == DocumentStatus.expired.value) {
        items.add(MissingInfoItem(
          id: 1,
          title: getString(
            appStr.errorNotApprovedYet,
            'error_not_approved_yet',
          ),
          description: getString(appStr.errorAdminDocExpired, 'error_admin_doc_expired'),
        ));
        return items;
      }
      if (info.vehicleApprovalStatus == DocumentStatus.rejected.value) {
        items.add(MissingInfoItem(
          id: 2,
          title: getString(
            appStr.errorNotApprovedYet,
            'error_not_approved_yet',
          ),
          description: getString(appStr.errorAdminVehicleRejected, 'error_admin_vehicle_rejected'),
        ));
      }
      if (vehDocStatus == DocumentStatus.rejected.value) {
        items.add(MissingInfoItem(
          id: 3,
          title: getString(
            appStr.errorNotApprovedYet,
            'error_not_approved_yet',
          ),
          description: getString(appStr.errorAdminVehicleDocRejected, 'error_admin_vehicle_doc_rejected'),
        ));
        return items;
      }
      if (vehDocStatus == DocumentStatus.expired.value) {
        items.add(MissingInfoItem(
          id: 3,
          title: getString(
            appStr.errorNotApprovedYet,
            'error_not_approved_yet',
          ),
          description: getString(appStr.errorAdminVehicleDocExpired, 'error_admin_vehicle_doc_expired'),
        ));
        return items;
      }
    }

    return items;
  }

  // ── Snackbar ──────────────────────────────────────────────────

  void _showErrorSnackBar(String? message) {
    if (message == null || message.isEmpty) return;
    state = state.copyWith(
      snackBarMessage: message,
      isSnackBarError: true,
    );
  }

  void clearSnackBar() {
    state = state.copyWith(clearSnackBar: true);
  }

  // ── Map Helpers ────────────────────────────────────────────────

  LatLng? get currentLatLng {
    if (state.currentLatitude != null && state.currentLongitude != null) {
      return LatLng(state.currentLatitude!, state.currentLongitude!);
    }
    return null;
  }

  /// The current vehicle typeId (for hub drivers to drop vehicle)
  String? get vehicleTypeId => _entity?.typeId;

  /// Access to the history repository for heat map data
  HistoryRepository get historyRepository => _historyRepository;

  // ── Workflow / Business Type ────────────────────────────────────

  Future<bool> selectBusinessType(int businessType) async {
    final request = WorkFlowRequest(
      workflowType: businessType,
      priceModes: [PriceMode.normal, PriceMode.sharing, PriceMode.rental],
    );
    final response = await _repository.setWorkflow(request);
    if (response is Success) {
      await getEntityDetail();
      getInformationStatus();
      return true;
    }
    return false;
  }

  // ── Cleanup ────────────────────────────────────────────────────

  @override
  void dispose() {
    _isDisposed = true;
    stopMtaPolling();
    _nativeMtaLocationSubscription?.cancel();
    _filteredLocationSubscription?.cancel();
    _ackSubscription?.cancel();
    _uiLocationSubscription?.cancel();
    _driverLocationProvider.stopGps();
    _driverLocationProvider.stopAckListening();
    _socketManager.offEvent(SocketConstants.eventDriverZoneQueueNumber);
    _socketManager.offEvent(SocketConstants.eventDriverAutoOffline);
    _socketManager.offEvent(SocketConstants.eventGetNewBooking);
    _socketManager.offEvent(SocketConstants.bookingStatus);
    super.dispose();
  }
}

final homeViewModelProvider =
    StateNotifierProvider<HomeViewModel, HomeState>((ref) {
  final sharedPref = ref.watch(sharedPreferenceManagerProvider).maybeWhen(
        data: (data) => data,
        orElse: () => throw Exception('SharedPreferences not initialized'),
      );
  final repository = ref.watch(appRepositoryProvider);
  final historyRepository = ref.watch(historyRepositoryProvider);
  final socketManager = ref.watch(socketManagerProvider);
  final locationServiceManager = ref.watch(locationServiceManagerProvider);
  final driverLocProvider = ref.watch(driverLocationProvider);
  final mtaApi = ref.watch(mtaApiProvider);
  return HomeViewModel(
    repository,
    historyRepository,
    sharedPref,
    socketManager,
    locationServiceManager,
    driverLocProvider,
    mtaApi,
  );
});
