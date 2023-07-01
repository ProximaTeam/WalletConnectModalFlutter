// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:w_common/disposable.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'package:walletconnect_modal_flutter/services/explorer/explorer_service.dart';
import 'package:walletconnect_modal_flutter/services/explorer/i_explorer_service.dart';
import 'package:walletconnect_modal_flutter/services/toast/toast_message.dart';
import 'package:walletconnect_modal_flutter/services/toast/toast_service.dart';
import 'package:walletconnect_modal_flutter/services/utils/platform/i_platform_utils.dart';
import 'package:walletconnect_modal_flutter/services/utils/platform/platform_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/url/url_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/walletconnect_modal/i_walletconnect_modal_service.dart';
import 'package:walletconnect_modal_flutter/services/utils/logger/logger_util.dart';
import 'package:walletconnect_modal_flutter/utils/namespaces.dart';
import 'package:walletconnect_modal_flutter/widgets/walletconnect_modal.dart';

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

  @override
  late IExplorerService explorerService;

  Map<String, RequiredNamespace> _requiredNamespaces =
      NamespaceConstants.ethereum;
  @override
  Map<String, RequiredNamespace> get requiredNamespaces => _requiredNamespaces;

  ConnectResponse? connectResponse;
  BuildContext? context;
  final ToastService _toastService = ToastService();

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
    IExplorerService? explorerService,
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

    this.explorerService = explorerService ??
        ExplorerService(
          projectId: _projectId,
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

    await _web3App!.init();
    await explorerService.init(
      referer: _web3App!.metadata.name.replaceAll(' ', ''),
    );

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
  }) async {
    _checkInitialized();

    if (_isOpen) {
      return;
    }

    // If we aren't connected, connect!
    if (!_isConnected) {
      LoggerUtil.logger.i(
        'Connecting to WalletConnect, required namespaces: $_requiredNamespaces',
      );
      connectResponse = await web3App!.connect(
        requiredNamespaces: _requiredNamespaces,
      );
      _awaitConnectResponse();
    }

    // Reset the explorer
    explorerService.filterList(
      query: '',
    );

    this.context = context;

    final bool bottomSheet =
        platformUtils.instance.getPlatformType() == PlatformType.mobile ||
            platformUtils.instance.isMobileWidth(
              MediaQuery.of(context).size.width,
            );

    _isOpen = true;

    notifyListeners();

    if (bottomSheet) {
      await showModalBottomSheet(
        // enableDrag: false,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        isScrollControlled: true,
        context: context,
        builder: (context) {
          return WalletConnectModal(
            service: this,
            toastService: _toastService,
            // startState: startState,
          );
        },
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) {
          return WalletConnectModal(
            service: this,
            toastService: _toastService,
            // startState: startState,
          );
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
      reason: WalletConnectError(
        code: 0,
        message: 'User disconnected',
      ),
    );
  }

  @override
  void launchCurrentWallet() {
    _checkInitialized();

    if (_session == null) {
      return;
    }

    final Redirect? redirect = _constructRedirect();

    LoggerUtil.logger.i(
      'Launching wallet: $redirect, ${_session?.peer.metadata}',
    );

    if (redirect == null) {
      urlUtils.instance.launchUrl(
        Uri.parse(
          _session!.peer.metadata.url,
        ),
      );
    } else {
      urlUtils.instance.launchRedirect(
        nativeUri: Uri.parse(redirect.native ?? ''),
        universalUri: Uri.parse(redirect.universal ?? ''),
      );
    }
  }

  // @override
  // void setDefaultChain({
  //   required Map<String, RequiredNamespace> requiredNamespaces,
  // }) {
  //   _checkInitialized();

  //   _requiredNamespaces = requiredNamespaces;

  //   notifyListeners();
  // }

  @override
  void setRequiredNamespaces(Map<String, RequiredNamespace> namespaces) {
    _checkInitialized();
    LoggerUtil.logger.i('Setting Required namespaces: $namespaces');

    _requiredNamespaces = namespaces;

    notifyListeners();
  }

  @override
  String getReferer() {
    _checkInitialized();

    return _web3App!.metadata.name.replaceAll(' ', '');
  }

  ////// Private methods //////

  Redirect? _constructRedirect() {
    if (session == null) {
      return null;
    }

    final Redirect? sessionRedirect = session?.peer.metadata.redirect;
    final Redirect? explorerRedirect = explorerService.getRedirect(
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
  }

  void _unregisterListeners() {
    // web3App!.onSessionConnect.unsubscribe(
    //   _onSessionConnect,
    // );
    web3App!.onSessionDelete.unsubscribe(
      _onSessionDelete,
    );
  }

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
    } catch (e) {
      LoggerUtil.logger.e('Error connecting to wallet: $e');
      await _toastService.show(
        ToastMessage(
          type: ToastType.error,
          text: 'Error Connecting to Wallet',
        ),
      );
    } finally {
      connectResponse = null;
    }

    if (_isOpen) {
      close();
    } else {
      notifyListeners();
    }
  }

  void _onSessionDelete(SessionDelete? args) {
    _isConnected = false;
    _address = '';

    notifyListeners();
  }

  void _checkInitialized() {
    if (!isInitialized) {
      throw StateError(
        'Web3ModalService must be initialized before calling this method.',
      );
    }
  }
}
