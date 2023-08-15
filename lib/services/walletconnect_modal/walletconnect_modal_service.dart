// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:w_common/disposable.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_modal_flutter/models/launch_url_exception.dart';
import 'package:walletconnect_modal_flutter/models/listings.dart';
import 'package:walletconnect_modal_flutter/services/explorer/explorer_service.dart';
import 'package:walletconnect_modal_flutter/services/explorer/explorer_service_singleton.dart';
import 'package:walletconnect_modal_flutter/services/explorer/i_explorer_service.dart';
import 'package:walletconnect_modal_flutter/services/utils/core/core_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/toast/toast_message.dart';
import 'package:walletconnect_modal_flutter/services/utils/platform/platform_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/toast/toast_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/url/url_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/widget_stack/widget_stack_singleton.dart';
import 'package:walletconnect_modal_flutter/walletconnect_modal_flutter.dart';
import 'package:walletconnect_modal_flutter/widgets/walletconnect_modal.dart';
import 'package:walletconnect_modal_flutter/widgets/walletconnect_modal_provider.dart';

class WalletConnectModalService extends ChangeNotifier
    with Disposable
    implements IWalletConnectModalService {
  bool _isInitialized = false;
  @override
  bool get isInitialized => _isInitialized;

  String _projectId = '';
  @override
  String get projectId => _projectId;

  IWeb3App? _web3App;
  @override
  IWeb3App? get web3App => _web3App;

  dynamic _initError;
  @override
  dynamic get initError => _initError;

  bool _isOpen = false;
  @override
  bool get isOpen => _isOpen;

  bool _isConnected = false;
  @override
  bool get isConnected => _isConnected;

  SessionData? _session;
  @override
  SessionData? get session => _session;

  String? _address;
  @override
  String? get address => _address;

  @override
  String? get wcUri => connectResponse?.uri.toString();

  Map<String, RequiredNamespace> _requiredNamespaces =
      NamespaceConstants.ethereum;
  @override
  Map<String, RequiredNamespace> get requiredNamespaces => _requiredNamespaces;

  ConnectResponse? connectResponse;
  Future<SessionData>? get sessionFuture => connectResponse?.session.future;
  BuildContext? context;

  // WalletConnectModalThemeData? _themeData;

  /// Creates a new instance of [WalletConnectModalService].
  /// [web3App] is optional and can be used to pass in an already created [Web3App].
  /// [projectId] and [metadata] are optional and can be used to create a new [Web3App].
  /// You must provide either a [projectId] and [metadata] or an already created [web3App], or this will throw an [ArgumentError].
  /// [requiredNamespaces] is optional and can be used to pass in a custom set of required namespaces.
  /// [explorerService] is optional and can be used to pass in a custom [IExplorerService].
  /// [recommendedWalletIds] is optional and can be used to pass in a custom set of recommended wallet IDs.
  /// [excludedWalletState] is optional and can be used to pass in a custom [ExcludedWalletState].
  /// [excludedWalletIds] is optional and can be used to pass in a custom set of excluded wallet IDs.
  WalletConnectModalService({
    IWeb3App? web3App,
    String? projectId,
    PairingMetadata? metadata,
    Map<String, RequiredNamespace>? requiredNamespaces,
    Set<String>? recommendedWalletIds,
    ExcludedWalletState excludedWalletState = ExcludedWalletState.list,
    Set<String>? excludedWalletIds,
  }) {
    if (web3App == null && projectId == null && metadata == null) {
      throw ArgumentError(
        'Either a projectId and metadata must be provided or an already created web3App.',
      );
    }
    _web3App = web3App ??
        Web3App(
          core: Core(
            projectId: projectId!,
          ),
          metadata: metadata!,
        );
    _projectId = projectId ?? _web3App!.core.projectId;

    if (requiredNamespaces != null) {
      _requiredNamespaces = requiredNamespaces;
    }

    explorerService.instance = ExplorerService(
      projectId: _projectId,
      referer: _web3App!.metadata.name.replaceAll(' ', ''),
      recommendedWalletIds: recommendedWalletIds,
      excludedWalletState: excludedWalletState,
      excludedWalletIds: excludedWalletIds,
    );
  }

  @override
  Future<void> init() async {
    if (_isInitialized) {
      return;
    }

    _initError = null;
    try {
      await _web3App!.init();
      await WalletConnectModalServices.init();
    } catch (_) {}

    _registerListeners();

    if (_web3App!.sessions.getAll().isNotEmpty) {
      _isConnected = true;
      _session = _web3App!.sessions.getAll().first;
      _address = NamespaceUtils.getAccount(
        _session!.namespaces.values.first.accounts.first,
      );
    }

    _isInitialized = true;

    notifyListeners();
  }

  @override
  // ignore: prefer_void_to_null
  Future<Null> onDispose() async {
    if (_isInitialized) {
      _unregisterListeners();
    }
  }

  @override
  Future<void> open({
    required BuildContext context,
    Widget? startWidget,
  }) async {
    _checkInitialized();

    if (_isOpen) {
      return;
    }

    _isOpen = true;

    rebuildConnectionUri();

    // Reset the explorer
    explorerService.instance!.filterList(
      query: '',
    );
    widgetStack.instance.clear();

    this.context = context;

    final bool bottomSheet = platformUtils.instance.isBottomSheet();

    notifyListeners();

    final WalletConnectModalTheme? theme =
        WalletConnectModalTheme.maybeOf(context);
    final Widget w = theme == null
        ? WalletConnectModalTheme(
            data: WalletConnectModalThemeData.lightMode,
            child: WalletConnectModal(
              startWidget: startWidget,
            ),
          )
        : WalletConnectModal(
            startWidget: startWidget,
          );
    final Widget root = WalletConnectModalProvider(
      service: this,
      child: w,
    );

    if (bottomSheet) {
      await showModalBottomSheet(
        // enableDrag: false,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        isScrollControlled: true,
        enableDrag: false,
        constraints: BoxConstraints(
          minWidth: MediaQuery.of(context).size.width,
        ),
        useSafeArea: true,
        context: context,
        builder: (context) {
          return root;
        },
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) {
          return root;
        },
      );
    }

    _isOpen = false;

    notifyListeners();
  }

  @override
  void close() {
    if (!_isOpen) {
      return;
    }
    // _isOpen = false;

    toastUtils.instance.clear();
    if (context != null) {
      Navigator.pop(context!);
    }

    // notifyListeners();
  }

  @override
  Future<void> disconnect() async {
    _checkInitialized();

    if (_session == null) {
      return;
    }

    await web3App!.disconnectSession(
      topic: session!.topic,
      // ignore: prefer_const_constructors
      reason: WalletConnectError(
        code: 0,
        message: 'User disconnected',
      ),
    );
  }

  @override
  Future<void> launchCurrentWallet() async {
    _checkInitialized();

    if (_session == null) {
      return;
    }

    final Redirect? redirect = _constructRedirect();

    LoggerUtil.logger.i(
      'Launching wallet: $redirect, ${_session?.peer.metadata}',
    );

    if (redirect == null) {
      await urlUtils.instance.launchUrl(
        Uri.parse(
          _session!.peer.metadata.url,
        ),
      );
    } else {
      // Get the native and universal URLs and add the 'wc' to the end
      // in the redirect.
      final String nativeUrl =
          coreUtils.instance.createSafeUrl(redirect.native ?? '');
      final String universalUrl =
          coreUtils.instance.createPlainUrl(redirect.universal ?? '');

      await urlUtils.instance.launchRedirect(
        nativeUri: Uri.parse(
          '${nativeUrl}wc?sessionTopic=${_session!.topic}',
        ),
        universalUri: Uri.parse(
          '${universalUrl}wc?sessionTopic=${_session!.topic}',
        ),
      );
    }
  }

  bool _connectingWallet = false;

  @override
  Future<void> connectWallet({
    required WalletData walletData,
  }) async {
    _checkInitialized();

    if (_connectingWallet) {
      return;
    }
    _connectingWallet = true;

    try {
      await rebuildConnectionUri();
      await urlUtils.instance.navigateDeepLink(
        nativeLink: walletData.listing.mobile.native,
        universalLink: walletData.listing.mobile.universal,
        wcURI: wcUri!,
      );
    } on LaunchUrlException catch (e) {
      toastUtils.instance.show(
        ToastMessage(
          type: ToastType.error,
          text: e.message,
        ),
      );
    }

    _connectingWallet = false;
  }

  @override
  void setDefaultChain({
    required Map<String, RequiredNamespace> requiredNamespaces,
  }) {
    _checkInitialized();

    LoggerUtil.logger.i('Setting default chain: $requiredNamespaces');

    _requiredNamespaces = requiredNamespaces;

    notifyListeners();
  }

  @override
  String getReferer() {
    _checkInitialized();

    return _web3App!.metadata.name.replaceAll(' ', '');
  }

  @override
  Future<void> rebuildConnectionUri() async {
    // If we aren't connected, connect!
    if (!_isConnected) {
      LoggerUtil.logger.i(
        'Connecting to WalletConnect, required namespaces: $_requiredNamespaces',
      );

      if (connectResponse != null) {
        try {
          sessionFuture!.timeout(Duration.zero);
        } on TimeoutException {
          // Ignore this error, just wanted to cancel the previous future.
        }
      }

      connectResponse = await web3App!.connect(
        requiredNamespaces: _requiredNamespaces,
      );

      notifyListeners();

      _awaitConnectResponse();
    }
  }

  ////// Private methods //////

  Redirect? _constructRedirect() {
    if (session == null) {
      return null;
    }

    final Redirect? sessionRedirect = session?.peer.metadata.redirect;
    final Redirect? explorerRedirect = explorerService.instance?.getRedirect(
      name: session!.peer.metadata.name,
    );

    if (sessionRedirect == null && explorerRedirect == null) {
      return null;
    }

    // Combine the redirect data from the session and the explorer API.
    // The explorer API is the source of truth.
    return Redirect(
      native: explorerRedirect?.native ?? sessionRedirect?.native,
      universal: explorerRedirect?.universal ?? sessionRedirect?.universal,
    );
  }

  void _registerListeners() {
    // web3App!.onSessionConnect.subscribe(
    //   _onSessionConnect,
    // );
    web3App!.onSessionDelete.subscribe(
      _onSessionDelete,
    );
    web3App!.core.relayClient.onRelayClientError.subscribe(
      _onRelayClientError,
    );
  }

  void _unregisterListeners() {
    // web3App!.onSessionConnect.unsubscribe(
    //   _onSessionConnect,
    // );
    web3App!.onSessionDelete.unsubscribe(
      _onSessionDelete,
    );
    web3App!.core.relayClient.onRelayClientError.unsubscribe(
      _onRelayClientError,
    );
  }

  void _onSessionDelete(SessionDelete? args) {
    _isConnected = false;
    _address = '';
    _session = null;

    notifyListeners();
  }

  void _onRelayClientError(ErrorEvent? args) {
    LoggerUtil.logger.e('Relay client error: $args');
    _initError = args!.error;

    notifyListeners();
  }

  /// Waits for the session to connect, and then sets the session and address.
  /// If the session fails to connect, it will show an error toast.
  /// If the session connects, it will close the modal.
  /// If the modal is already closed, it will notify listeners.
  /// If there is no connect response, it will do nothing.
  /// The completion of this method is triggered when the dApp
  /// connects to a wallet.
  Future<void> _awaitConnectResponse() async {
    if (connectResponse == null) {
      return;
    }

    try {
      final SessionData session = await connectResponse!.session.future;
      _isConnected = true;
      _session = session;
      _address = NamespaceUtils.getAccount(
        _session!.namespaces.values.first.accounts.first,
      );
      // await _toastService.show(
      //   ToastMessage(
      //     type: ToastType.info,
      //     text: 'Connected to Wallet',
      //   ),
      // );
    } on TimeoutException {
      LoggerUtil.logger.i('Rebuilding session, ending future');
      return;
    } catch (e) {
      LoggerUtil.logger.e('Error connecting to wallet: $e');
      await toastUtils.instance.show(
        ToastMessage(
          type: ToastType.error,
          text: 'Error Connecting to Wallet',
        ),
      );
      return;
    }

    if (_isOpen) {
      close();
    } else {
      notifyListeners();
    }
  }

  void _checkInitialized() {
    if (!isInitialized) {
      throw StateError(
        'Web3ModalService must be initialized before calling this method.',
      );
    }
  }
}
