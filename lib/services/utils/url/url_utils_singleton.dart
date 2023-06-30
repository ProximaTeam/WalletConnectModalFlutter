import 'package:walletconnect_modal_flutter/services/utils/url/i_url_utils.dart';
import 'package:walletconnect_modal_flutter/services/utils/url/url_utils.dart';

class UrlUtilsSingleton {
  IUrlUtils instance;

  UrlUtilsSingleton() : instance = UrlUtils();
}

final urlUtils = UrlUtilsSingleton();
