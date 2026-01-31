/// # Win the Year Design System
///
/// This file documents the design constraints enforced across the app.
/// All UI code should follow these rules to maintain a human-crafted,
/// product-driven, and intentionally restrained aesthetic.
///
/// ## Design Philosophy
/// - **Hierarchy first**: One clear primary action per screen
/// - **Restraint + consistency**: Avoid component soup; use plain layout + dividers
/// - **No AI aesthetics**: No glassmorphism, neon gradients, glow effects, or blur
/// - **Reduce clutter**: Max one persistent floating element per screen
/// - **Product realism**: Handle loading, empty, error, offline states
/// - **Accessibility**: 44px tap targets, readable contrast, dynamic text
library;

import 'package:flutter/material.dart';

// =============================================================================
// SPACING SCALE
// =============================================================================
/// Strict spacing scale: 4 / 8 / 12 / 16 / 24 only.
///
/// Usage:
/// - `s4`: Inline spacing (icon-to-text, tight groups)
/// - `s8`: Default compact spacing (list item padding, between related items)
/// - `s12`: Medium spacing (section content padding, form field gaps)
/// - `s16`: Standard spacing (screen padding, card padding, section gaps)
/// - `s24`: Large spacing (between major sections)
///
/// DO NOT invent new values. If tempted to use 20, 32, 48, etc., reconsider
/// whether the hierarchy is correct — usually one of the scale values fits.
abstract final class DesignSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;

  /// Screen edge padding (horizontal and vertical).
  static const double screenPadding = s16;

  /// Maximum content width for readability on large screens.
  static const double maxContentWidth = 720;
}

// =============================================================================
// CORNER RADII
// =============================================================================
/// Two radius levels only.
///
/// - `small`: For pills, tags, buttons, chips (8px)
/// - `medium`: For cards, containers, modals, inputs (12px)
///
/// DO NOT use 16px or higher radii — they feel "AI-generated".
abstract final class DesignRadius {
  /// Tight radius for pills, tags, small interactive elements.
  static const double small = 8;

  /// Standard radius for cards, containers, modals.
  static const double medium = 12;

  static BorderRadius get smallBorder => BorderRadius.circular(small);
  static BorderRadius get mediumBorder => BorderRadius.circular(medium);
}

// =============================================================================
// ELEVATION
// =============================================================================
/// Two elevation levels only.
///
/// - `none` (0): Default — most surfaces are flat
/// - `raised` (2): Cards that need to float (modals, popovers, FABs)
///
/// Prefer flat design. Reserve elevation for truly floating elements.
abstract final class DesignElevation {
  static const double none = 0;
  static const double raised = 2;
}

// =============================================================================
// TYPOGRAPHY ROLES
// =============================================================================
/// Typography hierarchy guide (use Material 3 TextTheme):
///
/// - `titleLarge`: Screen titles, modal headers
/// - `titleMedium`: Section headers, card titles
/// - `titleSmall`: Sub-section headers, form group labels
/// - `bodyLarge`: Primary content text, list item titles
/// - `bodyMedium`: Secondary content, descriptions
/// - `bodySmall`: Metadata, timestamps, hints
/// - `labelLarge`: Button text, prominent labels
/// - `labelMedium`: Tags, pills, chips
/// - `labelSmall`: Captions, subtle metadata
///
/// Always use theme.textTheme.* — never create ad-hoc TextStyle.
abstract final class DesignTypography {
  // No constants needed; use Theme.of(context).textTheme directly.
  // This class exists for documentation.
}

// =============================================================================
// ACCESSIBILITY
// =============================================================================
/// Minimum tap target sizes and contrast requirements.
abstract final class DesignAccessibility {
  /// Minimum tap target size per WCAG / Apple HIG.
  static const double minTapTarget = 44;

  /// Minimum size for interactive elements (buttons, list items, etc.).
  static const Size minTapTargetSize = Size(minTapTarget, minTapTarget);
}

// =============================================================================
// LAYOUT PATTERNS
// =============================================================================
/// Guidelines for common layout decisions:
///
/// ### Cards vs Plain Layout
/// - **Use cards** for: Truly grouped content (form sections, actionable items)
/// - **Use plain layout** for: Lists of homogeneous items, settings rows
/// - **Use dividers** between list items instead of wrapping each in a card
///
/// ### Floating Elements
/// - Maximum ONE persistent floating element per screen
/// - Contextual actions appear only when relevant (e.g., editing mode)
///
/// ### Empty/Loading/Error States
/// - Always implement all three states for async content
/// - Errors must be user-actionable: retry, open settings, learn more
/// - Empty states should guide users to take action
///
/// ### Icons
/// - Add icons only when they improve scanning or disambiguate meaning
/// - Avoid decorative icons that don't add information
///
/// ### Motion
/// - Subtle and functional only (state changes, navigation)
/// - No decorative animations or "delightful" micro-interactions
abstract final class DesignLayout {
  // No constants needed; this class exists for documentation.
}
