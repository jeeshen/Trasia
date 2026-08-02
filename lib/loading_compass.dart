import 'package:flutter/material.dart';

/// The shared Trasia loading animation used throughout the app.
class TrasiaLoadingCompass extends StatelessWidget {
  const TrasiaLoadingCompass({
    super.key,
    this.size = 64,
    this.semanticLabel = 'Loading',
  });

  final double size;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/branding/logo_loading.gif',
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
