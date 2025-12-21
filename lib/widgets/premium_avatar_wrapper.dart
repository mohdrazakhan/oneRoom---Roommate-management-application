import 'package:flutter/material.dart';

class PremiumAvatarWrapper extends StatefulWidget {
  final Widget child;
  final bool isPremium;
  final double size; // Total size including border
  final double borderWidth;

  const PremiumAvatarWrapper({
    super.key,
    required this.child,
    required this.isPremium,
    this.size = 50, // Default radius size (gets doubled for diameter roughly)
    this.borderWidth = 3,
  });

  @override
  State<PremiumAvatarWrapper> createState() => _PremiumAvatarWrapperState();
}

class _PremiumAvatarWrapperState extends State<PremiumAvatarWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isPremium) return widget.child;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Rotating Golden Border
        RotationTransition(
          turns: _controller,
          child: Container(
            width: widget.size * 2 + widget.borderWidth * 2,
            height: widget.size * 2 + widget.borderWidth * 2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: const [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFA500), // Orange
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFFACD), // LemonChiffon (Light Gold)
                  Color(0xFFFFD700), // Gold
                ],
                stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.amber.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        ),
        // Inner white/background padding to separate content from border
        Container(
          width: widget.size * 2,
          height: widget.size * 2,
          decoration: const BoxDecoration(
            color: Colors.white, // Or transparent if needed
            shape: BoxShape.circle,
          ),
          child: ClipOval(child: widget.child),
        ),
      ],
    );
  }
}
