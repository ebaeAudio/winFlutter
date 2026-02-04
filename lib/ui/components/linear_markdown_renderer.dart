import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme.dart';
import '../spacing.dart';

/// A markdown renderer styled to match Linear's presentation.
///
/// Features:
/// - Fenced code blocks with language label, copy button, and horizontal scroll
/// - Inline code with subtle background pill
/// - Images with loading states, error handling, and tap-to-view
/// - Mobile-optimized typography (line height, paragraph spacing)
/// - Tappable links with underline
/// - Blockquotes with left border
/// - Lists with proper indentation
///
/// Maximum code block height is capped at ~40% of viewport to avoid scroll conflicts.
class LinearMarkdownRenderer extends StatelessWidget {
  const LinearMarkdownRenderer({
    super.key,
    required this.data,
    this.onLinkTap,
    this.onImageTap,
  });

  /// Markdown string to render.
  final String data;

  /// Optional custom link handler. If null, opens URLs in external browser.
  final void Function(String url)? onLinkTap;

  /// Optional callback when an image is tapped. Receives the image URL.
  final void Function(String imageUrl)? onImageTap;

  @override
  Widget build(BuildContext context) {
    final text = data.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Use standard markdown extensions for fenced code blocks, tables, etc.
    final extensionSet = md.ExtensionSet(
      md.ExtensionSet.gitHubFlavored.blockSyntaxes,
      [
        md.EmojiSyntax(),
        ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
      ],
    );

    return MarkdownBody(
      data: text,
      selectable: true,
      extensionSet: extensionSet,
      styleSheet: _buildStyleSheet(theme, scheme),
      builders: {
        'code': _InlineCodeBuilder(scheme: scheme),
        'pre': _FencedCodeBlockBuilder(scheme: scheme),
      },
      imageBuilder: (uri, title, alt) => _MarkdownImage(
        uri: uri,
        title: title,
        alt: alt,
        scheme: scheme,
        onTap: onImageTap,
      ),
      onTapLink: (text, href, title) {
        if (href == null || href.isEmpty) return;
        if (onLinkTap != null) {
          onLinkTap!(href);
        } else {
          _launchUrl(context, href);
        }
      },
    );
  }

  MarkdownStyleSheet _buildStyleSheet(ThemeData theme, ColorScheme scheme) {
    final baseText = theme.textTheme.bodyMedium?.copyWith(
      height: 1.65, // Increased line height for readability
      color: scheme.onSurface,
    );

    return MarkdownStyleSheet(
      // Body text
      p: baseText,
      pPadding: const EdgeInsets.only(bottom: AppSpace.s12),

      // Headings
      h1: theme.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: scheme.onSurface,
      ),
      h1Padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
      h2: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: scheme.onSurface,
      ),
      h2Padding: const EdgeInsets.only(top: AppSpace.s12, bottom: AppSpace.s8),
      h3: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: scheme.onSurface,
      ),
      h3Padding: const EdgeInsets.only(top: AppSpace.s12, bottom: AppSpace.s4),
      h4: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: scheme.onSurface,
      ),
      h4Padding: const EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s4),
      h5: theme.textTheme.bodyLarge?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: scheme.onSurface,
      ),
      h5Padding: const EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s4),
      h6: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: scheme.onSurfaceVariant,
      ),
      h6Padding: const EdgeInsets.only(top: AppSpace.s8, bottom: AppSpace.s4),

      // Emphasis
      strong: baseText?.copyWith(fontWeight: FontWeight.w700),
      em: baseText?.copyWith(fontStyle: FontStyle.italic),

      // Links — underlined for tappability clarity
      a: baseText?.copyWith(
        color: scheme.primary,
        decoration: TextDecoration.underline,
        decorationColor: scheme.primary.withOpacity(0.5),
      ),

      // Lists
      listBullet: baseText?.copyWith(color: scheme.onSurfaceVariant),
      listBulletPadding: const EdgeInsets.only(right: AppSpace.s8),
      listIndent: 20,

      // Blockquotes — left border accent
      blockquote: baseText?.copyWith(
        color: scheme.onSurfaceVariant,
        fontStyle: FontStyle.italic,
      ),
      blockquoteDecoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: scheme.primary.withOpacity(0.5),
            width: 3,
          ),
        ),
      ),
      blockquotePadding: const EdgeInsets.only(
        left: AppSpace.s12,
        top: AppSpace.s4,
        bottom: AppSpace.s4,
      ),

      // Code — handled by custom builders, but provide fallback
      code: TextStyle(
        fontFamily: _kMonoFontFamily,
        fontSize: (baseText?.fontSize ?? 14) * 0.9,
        color: scheme.onSurfaceVariant,
        backgroundColor: scheme.surfaceContainerHighest.withOpacity(0.5),
      ),
      codeblockDecoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(kRadiusMedium),
      ),
      codeblockPadding: const EdgeInsets.all(AppSpace.s12),

      // Horizontal rule
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
        ),
      ),

      // Tables
      tableHead: baseText?.copyWith(fontWeight: FontWeight.w600),
      tableBorder: TableBorder.all(
        color: scheme.outlineVariant.withOpacity(0.5),
        width: 1,
      ),
      tableColumnWidth: const IntrinsicColumnWidth(),
      tableCellsPadding: const EdgeInsets.all(AppSpace.s8),
    );
  }

  static Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    // Only allow http/https to prevent javascript:, file:, data: etc.
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently fail — link tap should not break the app
    }
  }
}

/// Monospace font family for code.
const String _kMonoFontFamily = 'monospace';

// ─────────────────────────────────────────────────────────────────────────────
// Inline Code Builder
// ─────────────────────────────────────────────────────────────────────────────

/// Custom builder for inline code (`code` like this).
/// Renders as a subtle pill with monospace font.
class _InlineCodeBuilder extends MarkdownElementBuilder {
  _InlineCodeBuilder({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    final code = element.textContent;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 5,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: scheme.outlineVariant.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: Text(
        code,
        style: TextStyle(
          fontFamily: _kMonoFontFamily,
          fontSize: 13,
          color: scheme.onSurface,
          height: 1.4,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fenced Code Block Builder
// ─────────────────────────────────────────────────────────────────────────────

/// Custom builder for fenced code blocks (```lang ... ```).
///
/// Features:
/// - Monospace font with preserved whitespace
/// - Distinct container with background and 1px border
/// - Language label in top row (if provided)
/// - Copy button with feedback
/// - Horizontal scroll for long lines
/// - Vertical scroll with max height cap (~40% viewport)
class _FencedCodeBlockBuilder extends MarkdownElementBuilder {
  _FencedCodeBlockBuilder({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    // Extract code and language from the element
    String code = '';
    String? language;

    // The fenced code block structure varies by markdown parser.
    // Usually the element is 'pre' containing 'code' with class 'language-xxx'.
    if (element.tag == 'pre') {
      for (final child in element.children ?? <md.Node>[]) {
        if (child is md.Element && child.tag == 'code') {
          code = child.textContent;
          // Extract language from class attribute
          final classes = child.attributes['class'] ?? '';
          final match = RegExp(r'language-(\w+)').firstMatch(classes);
          if (match != null) {
            language = match.group(1);
          }
        }
      }
      if (code.isEmpty) {
        code = element.textContent;
      }
    } else {
      code = element.textContent;
    }

    // Remove trailing newline if present
    if (code.endsWith('\n')) {
      code = code.substring(0, code.length - 1);
    }

    return _FencedCodeBlock(
      code: code,
      language: language,
      scheme: scheme,
    );
  }
}

/// The actual fenced code block widget with all the features.
class _FencedCodeBlock extends StatefulWidget {
  const _FencedCodeBlock({
    required this.code,
    required this.language,
    required this.scheme,
  });

  final String code;
  final String? language;
  final ColorScheme scheme;

  @override
  State<_FencedCodeBlock> createState() => _FencedCodeBlockState();
}

class _FencedCodeBlockState extends State<_FencedCodeBlock> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final isDark = scheme.brightness == Brightness.dark;

    // Background and border colors — subtle but distinct
    final bgColor = isDark
        ? scheme.surfaceContainerHighest.withOpacity(0.4)
        : scheme.surfaceContainerHighest.withOpacity(0.7);
    final borderColor = scheme.outlineVariant.withOpacity(isDark ? 0.3 : 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(kRadiusMedium),
          border: Border.all(color: borderColor, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top bar: language label + copy button
            _buildTopBar(scheme, borderColor),

            // Code content with scroll
            _buildCodeContent(scheme),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(ColorScheme scheme, Color borderColor) {
    final hasLanguage =
        widget.language != null && widget.language!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s8,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Language label
          if (hasLanguage)
            Text(
              widget.language!.toLowerCase(),
              style: TextStyle(
                fontFamily: _kMonoFontFamily,
                fontSize: 11,
                color: scheme.onSurfaceVariant.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          const Spacer(),

          // Copy button — minimum 44px tap target
          SizedBox(
            height: 28,
            child: TextButton.icon(
              onPressed: _copyToClipboard,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
                minimumSize: const Size(44, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: scheme.onSurfaceVariant,
              ),
              icon: Icon(
                _copied ? Icons.check : Icons.copy,
                size: 14,
              ),
              label: Text(
                _copied ? 'Copied' : 'Copy',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeContent(ColorScheme scheme) {
    // Cap height at ~40% of viewport to avoid scroll conflicts.
    // LayoutBuilder gives us the constraints.
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use MediaQuery for viewport height
        final viewportHeight = MediaQuery.of(context).size.height;
        final maxHeight = viewportHeight * 0.4;

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            // Vertical scroll for tall code blocks
            child: SingleChildScrollView(
              // Horizontal scroll for long lines
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(AppSpace.s12),
              child: SelectableText(
                widget.code,
                style: TextStyle(
                  fontFamily: _kMonoFontFamily,
                  fontSize: 13,
                  height: 1.5,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: widget.code));
    if (!mounted) return;
    setState(() => _copied = true);

    // Reset after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Markdown Image Builder
// ─────────────────────────────────────────────────────────────────────────────

/// Custom image widget for markdown images.
///
/// Features:
/// - Loading indicator while image loads
/// - Error state with retry option
/// - Rounded corners matching design system
/// - Constrained width for mobile readability
/// - Optional tap-to-view callback
class _MarkdownImage extends StatelessWidget {
  const _MarkdownImage({
    required this.uri,
    required this.title,
    required this.alt,
    required this.scheme,
    this.onTap,
  });

  final Uri uri;
  final String? title;
  final String? alt;
  final ColorScheme scheme;
  final void Function(String imageUrl)? onTap;

  @override
  Widget build(BuildContext context) {
    final imageUrl = uri.toString();

    // Skip rendering for invalid URLs
    if (imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: GestureDetector(
        onTap: onTap != null ? () => onTap!(imageUrl) : () => _showFullImage(context, imageUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(kRadiusMedium),
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: double.infinity,
              minHeight: 100,
            ),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(kRadiusMedium),
              border: Border.all(
                color: scheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildLoadingState(loadingProgress);
              },
              errorBuilder: (context, error, stackTrace) {
                return _buildErrorState(context, imageUrl);
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(ImageChunkEvent loadingProgress) {
    final progress = loadingProgress.expectedTotalBytes != null
        ? loadingProgress.cumulativeBytesLoaded /
            loadingProgress.expectedTotalBytes!
        : null;

    return Container(
      constraints: const BoxConstraints(minHeight: 100),
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress,
              color: scheme.primary,
            ),
          ),
          if (progress != null) ...[
            Gap.h8,
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String imageUrl) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 28,
            color: scheme.onSurfaceVariant.withOpacity(0.5),
          ),
          Gap.h8,
          Text(
            'Image failed to load',
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          Gap.h8,
          TextButton(
            onPressed: () => _openInBrowser(imageUrl),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s8),
              minimumSize: const Size(44, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Open in browser', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => _FullImageDialog(
        imageUrl: imageUrl,
        scheme: scheme,
        alt: alt,
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently fail
    }
  }
}

/// Full-screen image dialog for viewing images.
class _FullImageDialog extends StatelessWidget {
  const _FullImageDialog({
    required this.imageUrl,
    required this.scheme,
    this.alt,
  });

  final String imageUrl;
  final ColorScheme scheme;
  final String? alt;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black.withOpacity(0.9),
      insetPadding: EdgeInsets.zero,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image with interactive viewer for zoom/pan
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  final progress = loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null;
                  return Center(
                    child: CircularProgressIndicator(
                      value: progress,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: Colors.white54,
                      ),
                      Gap.h12,
                      Text(
                        'Failed to load image',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpace.s8,
            right: AppSpace.s8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                minimumSize: const Size(44, 44),
              ),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),

          // Actions bar at bottom
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + AppSpace.s16,
            left: AppSpace.s16,
            right: AppSpace.s16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Open in browser
                FilledButton.icon(
                  onPressed: () => _openInBrowser(imageUrl),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Open in browser'),
                ),
              ],
            ),
          ),

          // Alt text at bottom if available
          if (alt != null && alt!.trim().isNotEmpty)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + AppSpace.s16 + 56,
              left: AppSpace.s16,
              right: AppSpace.s16,
              child: Text(
                alt!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openInBrowser(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Silently fail
    }
  }
}
