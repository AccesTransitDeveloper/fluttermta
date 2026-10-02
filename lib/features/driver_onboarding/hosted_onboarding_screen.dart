import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';

import '../../core/preferences/shared_preference_manager.dart';
import '../../core/providers/app_providers.dart';
import '../../core/router/app_navigation.dart';

/// Hosted enrollment updates independently of the native application.
class HostedOnboardingScreen extends ConsumerStatefulWidget {
  const HostedOnboardingScreen({super.key});
  @override
  ConsumerState<HostedOnboardingScreen> createState() => _HostedOnboardingState();
}

class _HostedOnboardingState extends ConsumerState<HostedOnboardingScreen>
    with WidgetsBindingObserver {
  static final _origin = Uri.parse('https://fashnmall.com');
  static final _page = _origin.resolve('/at-driver-web/onboarding');
  static final _api = _origin.resolve('/at-driver-web/onboarding/api/');
  SharedPreferenceManager? _preferences;
  InAppWebViewController? _controller;
  String? _accountId;
  String? _handoffToken;
  String? _error;
  bool _loading = true;
  bool _finishing = false;
  int _generation = 0;

  bool _trusted(Uri? url) => url?.scheme == 'https' &&
      url?.host == _origin.host && url?.port == 443 &&
      (url?.path == '/at-driver-web/onboarding' ||
       (url?.path.startsWith('/at-driver-web/onboarding/') ?? false));

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepare();
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final authorization = _preferences?.getAuthorization();
    if (authorization == null || authorization.isEmpty) {
      throw StateError('Sign in to your driver account to continue.');
    }
    final response = await http.post(
      _api.resolve(path),
      headers: {'Authorization': authorization, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 40));
    final result = jsonDecode(response.body);
    if (result is! Map<String, dynamic>) throw StateError('Registration service returned an invalid response.');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(result['error'] is String ? result['error'] : 'Registration service is unavailable.');
    }
    return result;
  }

  Future<void> _checkService() async {
    final response = await http.get(_api.resolve('health'),
      headers: {'Cache-Control': 'no-cache'},
    ).timeout(const Duration(seconds: 20));
    Map<String, dynamic>? health;
    try {
      final result = jsonDecode(response.body);
      if (result is Map<String, dynamic>) health = result;
    } catch (_) {
      // An unpublished API may return the web page rather than JSON.
    }
    if (response.statusCode != 200 || health?['ok'] != true ||
        health?['service'] != 'at-driver-onboarding' || health?['protocolVersion'] != 1) {
      throw StateError('The registration service must be published at this address. This is a server error, not a sign-in error. Contact support.');
    }
    if (health?['crmConfigured'] != true || health?['databaseConfigured'] != true) {
      throw StateError('The registration server is missing required configuration. Contact support.');
    }
  }

  Future<void> _prepare() async {
    final generation = ++_generation;
    setState(() { _loading = true; _error = null; _handoffToken = null; });
    try {
      final preferences = await ref.read(sharedPreferenceManagerProvider.future);
      _preferences = preferences;
      await _checkService();
      // Resolve identity from a server-verified account, never a generated ID.
      final status = await _post('account-status', {});
      final id = status['accountId'];
      if (id is! String || id.isEmpty) throw StateError('A registered driver account ID is required.');
      _accountId = id;
      if (status['status'] == 'submitted' && status['crmApplicationId'] is String) {
        await preferences.requireHostedOnboarding(id);
        await preferences.completeHostedOnboarding(id, status['crmApplicationId'] as String);
        if (mounted && generation == _generation) context.navigateToHome();
        return;
      }
      await preferences.requireHostedOnboarding(id);
      final handoff = await _post('handoff', {'accountId': id, 'language': preferences.getLanguage()});
      final token = handoff['handoffToken'];
      if (token is! String || token.isEmpty) throw StateError('Registration handoff could not be created.');
      if (mounted && generation == _generation) {
        setState(() { _handoffToken = token; _loading = false; });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _error = error is StateError ? error.message.toString() : 'Could not open registration. Check your connection and retry.';
        });
      }
    }
  }

  Future<void> _confirmReload() async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reload registration?'),
        content: const Text('Files not uploaded yet must be selected again. Documents already saved in CRM will remain available.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Reload')),
        ],
      ),
    );
    if (reload == true && mounted) await _prepare();
  }

  Future<Map<String, dynamic>> _complete(List<dynamic> arguments) async {
    if (_finishing || !_trusted((await _controller?.getUrl())?.uriValue)) return {'success': false};
    _finishing = true;
    try {
      final status = await _post('account-status', {});
      final claimedId = arguments.isNotEmpty && arguments.first is Map
          ? (arguments.first as Map)['crmApplicationId'] : null;
      if (status['accountId'] != _accountId || status['status'] != 'submitted' ||
          status['crmApplicationId'] is! String || status['crmApplicationId'] != claimedId) {
        throw StateError('CRM has not confirmed all registration documents.');
      }
      await _preferences!.completeHostedOnboarding(_accountId!, claimedId as String);
      if (mounted) context.navigateToHome();
      return {'success': true};
    } catch (_) {
      return {'success': false, 'error': 'Registration has not been confirmed. Check status and retry.'};
    } finally { _finishing = false; }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final hidden = state != AppLifecycleState.resumed;
    _controller?.evaluateJavascript(source: '''
      window.__atDriverNativeHidden = ${hidden ? 'true' : 'false'};
      document.dispatchEvent(new Event('visibilitychange'));
    ''');
  }

  @override
  void dispose() {
    _generation++;
    _handoffToken = null;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.evaluateJavascript(source: '''
      document.querySelectorAll('video').forEach(video =>
        video.srcObject?.getTracks().forEach(track => track.stop()));
    ''');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('AT Driver registration'), automaticallyImplyLeading: false,
        actions: [IconButton(
          tooltip: 'Reload registration',
          onPressed: _loading ? null : _confirmReload,
          icon: const Icon(Icons.refresh),
        )],
      ),
      body: SafeArea(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
              mainAxisSize: MainAxisSize.min, children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _prepare, child: const Text('Retry')),
              ])))
          : InAppWebView(
              key: ValueKey(_generation),
              initialUrlRequest: URLRequest(url: WebUri(_page.toString())),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true, useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true, thirdPartyCookiesEnabled: false,
                cacheMode: CacheMode.LOAD_NO_CACHE,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_NEVER_ALLOW,
                allowFileAccess: false, allowContentAccess: true,
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
                controller.addJavaScriptHandler(
                  handlerName: 'driverOnboardingBootstrap',
                  callback: (arguments) async {
                    if (!_trusted((await controller.getUrl())?.uriValue)) return {'error': 'Untrusted registration page.'};
                    final token = _handoffToken;
                    _handoffToken = null;
                    if (token == null) return {'error': 'Reload registration using Retry.'};
                    return {'handoffToken': token};
                  },
                );
                controller.addJavaScriptHandler(handlerName: 'driverOnboardingCompleted', callback: _complete);
              },
              shouldOverrideUrlLoading: (controller, action) async {
                return _trusted(action.request.url?.uriValue)
                    ? NavigationActionPolicy.ALLOW : NavigationActionPolicy.CANCEL;
              },
              onPermissionRequest: (controller, request) async {
                if (!_trusted((await controller.getUrl())?.uriValue) ||
                    request.origin.host != _origin.host) {
                  return PermissionResponse(resources: request.resources, action: PermissionResponseAction.DENY);
                }
                final allowed = <PermissionResourceType>[];
                for (final resource in request.resources) {
                  if (resource == PermissionResourceType.CAMERA && await Permission.camera.request().isGranted) allowed.add(resource);
                  if (resource == PermissionResourceType.MICROPHONE && await Permission.microphone.request().isGranted) allowed.add(resource);
                }
                return PermissionResponse(resources: allowed, action: allowed.isEmpty ? PermissionResponseAction.DENY : PermissionResponseAction.GRANT);
              },
              onReceivedError: (controller, request, error) {
                if (request.isForMainFrame == true && mounted) {
                  setState(() => _error = 'The registration page could not be loaded. Retry when connected.');
                }
              },
              onReceivedHttpError: (controller, request, response) {
                if (request.isForMainFrame == true && (response.statusCode ?? 200) >= 400 && mounted) {
                  setState(() => _error = 'Registration is unavailable. Please retry later.');
                }
              },
            )),
    ),
  );
}