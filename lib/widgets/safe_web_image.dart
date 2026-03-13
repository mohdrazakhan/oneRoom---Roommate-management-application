// import 'dart:io'; // Removed for web support
import 'package:flutter/material.dart';

class SafeWebImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;

  const SafeWebImage(
    this.url, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.errorBuilder,
    this.loadingBuilder,
  });

  @override
  State<SafeWebImage> createState() => _SafeWebImageState();
}

class _SafeWebImageState extends State<SafeWebImage> {
  bool _hasError = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    // On web, checking URL existence via HEAD request is tricky due to CORS.
    // We will rely on Image.network's built-in error handling.
    _checked = true;
  }

  @override
  void didUpdateWidget(SafeWebImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _hasError = false;
        // _checked = false;
      });
    }
  }

  // Removed _checkUrl that used dart:io HttpClient

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(context, Exception('404 Not Found'), null);
      }
      return const SizedBox.shrink();
    }

    if (!_checked) {
      // Show loading or transparent while checking
      if (widget.loadingBuilder != null) {
        return widget.loadingBuilder!(context, const SizedBox.shrink(), null);
      }
      return const SizedBox.shrink();
    }

    // URL is verified, safe to use Image.network
    return Image.network(
      widget.url,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      errorBuilder: widget.errorBuilder,
      loadingBuilder: widget.loadingBuilder,
    );
  }
}
