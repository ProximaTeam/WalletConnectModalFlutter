// ignore: depend_on_referenced_packages
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:universal_io/io.dart';
import 'package:walletconnect_flutter_v2/walletconnect_flutter_v2.dart';
import 'dart:convert';

import 'package:walletconnect_modal_flutter/models/listings.dart';
import 'package:walletconnect_modal_flutter/services/explorer/i_explorer_service.dart';
import 'package:walletconnect_modal_flutter/services/utils/core/core_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/platform/i_platform_utils.dart';
import 'package:walletconnect_modal_flutter/services/utils/platform/platform_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/url/url_utils_singleton.dart';
import 'package:walletconnect_modal_flutter/services/utils/logger/logger_util.dart';
import 'package:walletconnect_modal_flutter/widgets/grid_list/grid_list_item_model.dart';

class ExplorerService implements IExplorerService {
  @override
  final String explorerUriRoot;

  @override
  final String projectId;

  @override
  Set<String>? recommendedWalletIds;

  @override
  ExcludedWalletState excludedWalletState;

  @override
  Set<String>? excludedWalletIds;

  List<Listing> _listings = [];
  List<GridListItemModel<WalletData>> _walletList = [];
  @override
  ValueNotifier<List<GridListItemModel<WalletData>>> itemList =
      ValueNotifier([]);

  @override
  ValueNotifier<bool> initialized = ValueNotifier(false);

  final http.Client client;

  final String referer;

  ExplorerService({
    required this.projectId,
    required this.referer,
    this.explorerUriRoot = 'https://explorer-api.walletconnect.com',
    this.recommendedWalletIds,
    this.excludedWalletState = ExcludedWalletState.list,
    this.excludedWalletIds,
    http.Client? client,
  }) : client = client ?? http.Client();

  @override
  Future<void> init() async {
    if (initialized.value) {
      return;
    }

    String? platform;
    switch (platformUtils.instance.getPlatformType()) {
      case PlatformType.desktop:
        platform = 'Desktop';
        break;
      case PlatformType.mobile:
        if (Platform.isIOS) {
          platform = 'iOS';
        } else if (Platform.isAndroid) {
          platform = 'Android';
        } else {
          platform = 'Mobile';
        }
        break;
      case PlatformType.web:
        platform = 'Injected';
        break;
      default:
        platform = null;
    }

    LoggerUtil.logger.i('Fetching wallet listings. Platform: $platform');
    _listings = await fetchListings(
      endpoint: '/w3m/v1/get${platform}Listings',
      referer: referer,
      // params: params,
    );

    if (excludedWalletState == ExcludedWalletState.list) {
      // If we are excluding all wallets, take out the excluded listings, if they exist
      if (excludedWalletIds != null) {
        _listings = filterExcludedListings(
          listings: _listings,
        );
      }
    } else if (excludedWalletState == ExcludedWalletState.all &&
        recommendedWalletIds != null) {
      // Filter down to only the included
      _listings = _listings
          .where(
            (listing) => recommendedWalletIds!.contains(
              listing.id,
            ),
          )
          .toList();
    } else {
      // If we are excluding all wallets and have no recommended wallets,
      // return an empty list
      _walletList = [];
      itemList.value = [];
      return;
    }
    _walletList.clear();

    for (Listing item in _listings) {
      bool installed = await urlUtils.instance.isInstalled(item.mobile.native);
      if (installed) {
        LoggerUtil.logger.i('Wallet ${item.name} installed: $installed');
      }
      _walletList.add(
        GridListItemModel<WalletData>(
          title: item.name,
          id: item.id,
          description: installed ? 'Installed' : null,
          image: getWalletImageUrl(
            imageId: item.imageId,
          ),
          data: WalletData(
            listing: item,
            installed: installed,
          ),
        ),
      );
    }

    // Sort the installed wallets to the top
    if (recommendedWalletIds != null) {
      _walletList.sort((a, b) {
        if ((a.data.installed && !b.data.installed) ||
            recommendedWalletIds!.contains(a.id)) {
          LoggerUtil.logger.i('Sorting ${a.title} to the top. ID: ${a.id}');
          return -1;
        } else if ((recommendedWalletIds!.contains(a.id) &&
                recommendedWalletIds!.contains(b.id)) ||
            (a.data.installed == b.data.installed)) {
          return 0;
        } else {
          return 1;
        }
      });
    } else {
      _walletList.sort((a, b) {
        if (a.data.installed && !b.data.installed) {
          LoggerUtil.logger.v('Sorting ${a.title} to the top. ID: ${a.id}');
          return -1;
        } else if (a.data.installed == b.data.installed) {
          return 0;
        } else {
          return 1;
        }
      });
    }

    itemList.value = _walletList;
    initialized.value = true;
  }

  @override
  void filterList({
    String? query,
  }) {
    if (query == null || query.isEmpty) {
      itemList.value = _walletList;
      return;
    }

    final List<GridListItemModel<WalletData>> filtered = _walletList
        .where(
          (wallet) => wallet.title.toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .toList();
    itemList.value = filtered;
  }

  @override
  String getWalletImageUrl({
    required String imageId,
  }) {
    return '$explorerUriRoot/w3m/v1/getWalletImage/$imageId?projectId=$projectId';
  }

  @override
  String getAssetImageUrl({
    required String imageId,
  }) {
    return '$explorerUriRoot/w3m/v1/getAssetImage/$imageId?projectId=$projectId';
  }

  @override
  Redirect? getRedirect({required String name}) {
    try {
      LoggerUtil.logger.i('Getting redirect for $name');
      final Listing listing = _listings.firstWhere(
        (listing) => listing.name.contains(name) || name.contains(listing.name),
      );

      return listing.mobile;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Listing>> fetchListings({
    required String endpoint,
    required String referer,
    ListingParams? params,
  }) async {
    LoggerUtil.logger.i('Fetching wallet listings. Endpoint: $endpoint');
    final Map<String, String> headers = {
      'user-agent': coreUtils.instance.getUserAgent(),
      'referer': referer,
    };
    LoggerUtil.logger.i('Fetching wallet listings. Headers: $headers');
    final Uri uri = Uri.parse(explorerUriRoot + endpoint);
    final Map<String, dynamic> queryParameters = {
      'projectId': projectId,
      ...params == null ? {} : params.toJson(),
    };
    final http.Response response = await client.get(
      uri.replace(
        queryParameters: queryParameters,
      ),
      headers: headers,
    );
    // print(json.decode(response.body)['listings'].entries.first);
    ListingResponse res = ListingResponse.fromJson(json.decode(response.body));
    return res.listings.values.toList();
  }

  List<Listing> filterExcludedListings({
    required List<Listing> listings,
  }) {
    return listings.where((listing) {
      if (excludedWalletIds!.contains(
        listing.id,
      )) {
        LoggerUtil.logger.i('Excluding wallet from list: $listing');
        return false;
      }

      return true;
    }).toList();
  }
}
