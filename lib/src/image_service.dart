part of '../main.dart';

class AppImageService {
  AppImageService._();

  static const bucket = 'app-images';

  static String normalizePath(String source) {
    final normalized = source.trim().replaceAll('\\', '/');
    if (normalized.startsWith('assets/')) {
      return normalized.substring('assets/'.length);
    }
    return normalized.startsWith('/') ? normalized.substring(1) : normalized;
  }

  static String publicUrl(String source) {
    if (source.startsWith('https://') || source.startsWith('http://')) {
      return source;
    }
    final path = normalizePath(source);
    if (path.isEmpty || SupabaseConfig.url.isEmpty) return '';
    final encoded = path.split('/').map(Uri.encodeComponent).join('/');
    final baseUrl = SupabaseConfig.url.replaceFirst(RegExp(r'/+$'), '');
    return '$baseUrl/storage/v1/object/public/$bucket/$encoded';
  }

  static Future<Uint8List> loadBytes(String source) async {
    final url = publicUrl(source);
    if (url.isEmpty) throw StateError('Image URL is unavailable');
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw StateError('Image returned ${response.statusCode}');
    }
    return response.bodyBytes;
  }
}

class _AppImage extends StatelessWidget {
  const _AppImage({
    required this.source,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.semanticLabel,
    this.placeholder,
  });

  final String source;
  final double? width;
  final double? height;
  final BoxFit fit;
  final String? semanticLabel;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final url = AppImageService.publicUrl(source);
    final fallback =
        placeholder ??
        const ColoredBox(
          color: Color(0xFFEAF0F7),
          child: Center(
            child: Icon(Icons.image_outlined, color: Color(0xFF8A98AA)),
          ),
        );
    if (url.isEmpty) {
      return SizedBox(width: width, height: height, child: fallback);
    }
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final cacheWidth = width?.isFinite == true
        ? max(1, (width! * pixelRatio).round())
        : null;
    final cacheHeight = height?.isFinite == true
        ? max(1, (height! * pixelRatio).round())
        : null;
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      semanticLabel: semanticLabel,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, synchronouslyLoaded) =>
          synchronouslyLoaded || frame != null ? child : fallback,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
