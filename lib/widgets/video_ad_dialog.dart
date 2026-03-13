import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Shows an Interstitial Ad (often containing video).
/// [onComplete] is called when the user closes the ad or if the ad fails to load.
Future<void> showVideoAd(BuildContext context,
    {required VoidCallback onComplete}) async {
  
  // Show a brief loading indicator while the ad loads
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(
      child: CircularProgressIndicator(color: Color(0xFF667EEA)),
    ),
  );

  final String adUnitId = Platform.isAndroid
      ? 'ca-app-pub-1174538697381859/9299009439' // Android Real Interstitial ID (Download)
      : 'ca-app-pub-3940256099942544/4411468910'; // iOS Interstitial Test ID

  InterstitialAd.load(
    adUnitId: adUnitId,
    request: const AdRequest(),
    adLoadCallback: InterstitialAdLoadCallback(
      onAdLoaded: (InterstitialAd ad) {
        // Dismiss the loading dialog
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }

        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (InterstitialAd ad) {
            ad.dispose();
            onComplete();
          },
          onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
            ad.dispose();
            onComplete();
          },
        );
        ad.show();
      },
      onAdFailedToLoad: (LoadAdError error) {
        debugPrint('InterstitialAd failed to load: $error');
        // Dismiss the loading dialog
        if (context.mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
        // Proceed with the action anyway if the ad fails
        onComplete();
      },
    ),
  );
}
