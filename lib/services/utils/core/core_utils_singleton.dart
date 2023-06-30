import 'package:walletconnect_modal_flutter/services/utils/core/core_utils.dart';
import 'package:walletconnect_modal_flutter/services/utils/core/i_core_utils.dart';

class CoreUtilsSingleton {
  ICoreUtils instance;

  CoreUtilsSingleton() : instance = CoreUtils();
}

final coreUtils = CoreUtilsSingleton();
