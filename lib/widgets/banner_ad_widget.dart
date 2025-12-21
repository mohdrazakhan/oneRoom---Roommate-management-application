import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../services/subscription_service.dart';

class MyBannerAd extends StatefulWidget {
  const MyBannerAd({super.key});

  @override
  State<MyBannerAd> createState() => _MyBannerAdState();
}

class _MyBannerAdState extends State<MyBannerAd> {
  late BannerAd _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();

    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: 'ca-app-pub-3940256099942544/6300978111', // TEST BANNER ID
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint("Ad failed to load: $error");
        },
      ),
      request: const AdRequest(),
    );

    _bannerAd.load();
  }

  @override
  Widget build(BuildContext context) {
    // Check Premium Status
    final subService = context.watch<SubscriptionService>();
    // Only hide if user has isAdFree (Premium Plus)
    if (subService.isAdFree) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Remove Ads Button
        Container(
          width: double.infinity,
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, '/subscription');
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.block, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Remove Ads',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[800],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        // The Ad
        SizedBox(
          width: _bannerAd.size.width.toDouble(),
          height: _bannerAd.size.height.toDouble(),
          child: AdWidget(ad: _bannerAd),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _bannerAd.dispose();
    super.dispose();
  }
}
