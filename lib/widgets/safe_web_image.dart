import 'dart:io';
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
    _checkUrl();
  }

  @override
  void didUpdateWidget(SafeWebImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _hasError = false;
        _checked = false;
      });
      _checkUrl();
    }
  }

  Future<void> _checkUrl() async {
    if (widget.url.isEmpty) {
      if (mounted) setState(() => _hasError = true);
      return;
    }

    try {
      // Use HttpClient to check if the resource exists without downloading body
      // This prevents NetworkImage from throwing 404 exception which pauses debugger
      final client = HttpClient();
      final request = await client.headUrl(Uri.parse(widget.url));
      final response = await request.close();

      if (mounted) {
        setState(() {
          _hasError = response.statusCode != HttpStatus.ok;
          _checked = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _checked = true;
        });
      }
    }
  }

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
