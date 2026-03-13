import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// A slim bottom banner ad (used on Expenses & Tasks pages).
class AdBannerWidget extends StatefulWidget {
  const AdBannerWidget({super.key});

  @override
  State<AdBannerWidget> createState() => _AdBannerWidgetState();
}

class _AdBannerWidgetState extends State<AdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-1174538697381859/5744335517' // Android real ad unit (bottom_ads)
      : 'ca-app-pub-3940256099942544/2934735716'; // iOS test ad unit

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('BannerAd failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const SizedBox.shrink();
    }

    return Container(
      alignment: Alignment.center,
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

/// A card-style ad for the Rooms list page using a larger BannerAd format.
class AdCardWidget extends StatefulWidget {
  const AdCardWidget({super.key});

  @override
  State<AdCardWidget> createState() => _AdCardWidgetState();
}

class _AdCardWidgetState extends State<AdCardWidget> {
  BannerAd? _cardAd;
  bool _isLoaded = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-1174538697381859/5744335517' // Android real ad unit (bottom_ads)
      : 'ca-app-pub-3940256099942544/2934735716'; // iOS test ad unit

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    _cardAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      // Standard banner is the shortest and matches the sleek look requested
      size: AdSize.banner,  
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('$ad loaded.');
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('AdCardWidget failed to load: $err');
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _cardAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalMargin = constraints.maxWidth < 360 ? 8.0 : 8.0;

        return Container(
          margin: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _cardAd!.size.width.toDouble(),
            height: _cardAd!.size.height.toDouble(),
            child: AdWidget(ad: _cardAd!),
          ),
        );
      },
    );
  }
}
