import 'package:walletconnect_modal_flutter/services/utils/platform/i_platform_utils.dart';
import 'package:walletconnect_modal_flutter/services/utils/platform/platform_utils.dart';

class PlatformUtilsSingleton {
  IPlatformUtils instance;

  PlatformUtilsSingleton() : instance = PlatformUtils();
}

final platformUtils = PlatformUtilsSingleton();
