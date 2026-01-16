import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Defines all app-specific intents for keyboard shortcuts.
///
/// Intents are "what" the user wants to do. Actions define "how" it's done.
/// This separation allows the same shortcut to have different implementations
/// in different contexts.

// ─────────────────────────────────────────────────────────────────────────────
// Navigation Intents
// ─────────────────────────────────────────────────────────────────────────────

/// Navigate to Today screen.
class GoToTodayIntent extends Intent {
  const GoToTodayIntent();
}

/// Navigate to Focus screen.
class GoToFocusIntent extends Intent {
  const GoToFocusIntent();
}

/// Navigate to Projects screen.
class GoToProjectsIntent extends Intent {
  const GoToProjectsIntent();
}

/// Navigate to Tasks screen.
class GoToTasksIntent extends Intent {
  const GoToTasksIntent();
}

/// Navigate to Settings screen.
class GoToSettingsIntent extends Intent {
  const GoToSettingsIntent();
}

/// Navigate to Rollups screen.
class GoToRollupsIntent extends Intent {
  const GoToRollupsIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// Command Palette Intent
// ─────────────────────────────────────────────────────────────────────────────

/// Open the command palette (⌘K / Ctrl+K).
class OpenCommandPaletteIntent extends Intent {
  const OpenCommandPaletteIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// Task Intents
// ─────────────────────────────────────────────────────────────────────────────

/// Create a new task.
class NewTaskIntent extends Intent {
  const NewTaskIntent();
}

/// Create a new Must-Win task.
class NewMustWinIntent extends Intent {
  const NewMustWinIntent();
}

/// Toggle focus task completion.
class ToggleFocusTaskIntent extends Intent {
  const ToggleFocusTaskIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// Date Navigation Intents
// ─────────────────────────────────────────────────────────────────────────────

/// Go to previous day.
class PreviousDayIntent extends Intent {
  const PreviousDayIntent();
}

/// Go to next day.
class NextDayIntent extends Intent {
  const NextDayIntent();
}

/// Jump to today's date.
class JumpToTodayIntent extends Intent {
  const JumpToTodayIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// Focus Mode Intents
// ─────────────────────────────────────────────────────────────────────────────

/// Toggle focus mode on/off.
class ToggleFocusModeIntent extends Intent {
  const ToggleFocusModeIntent();
}

/// Open "I'm stuck" menu.
class ImStuckIntent extends Intent {
  const ImStuckIntent();
}

/// Start focus timer.
class StartFocusTimerIntent extends Intent {
  const StartFocusTimerIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// Search Intent
// ─────────────────────────────────────────────────────────────────────────────

/// Focus on search field.
class FocusSearchIntent extends Intent {
  const FocusSearchIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Capture Intent
// ─────────────────────────────────────────────────────────────────────────────

/// Open quick capture window (⌥Space global hotkey equivalent).
class OpenQuickCaptureIntent extends Intent {
  const OpenQuickCaptureIntent();
}

// ─────────────────────────────────────────────────────────────────────────────
// Shortcut Definitions
// ─────────────────────────────────────────────────────────────────────────────

/// All keyboard shortcuts for the app.
///
/// On macOS, meta = ⌘ (Command). On Windows/Linux, meta = Win/Super key.
/// We use meta for macOS-like shortcuts and control for Windows/Linux parity.
class AppShortcuts {
  AppShortcuts._();

  /// Returns the app's keyboard shortcut mappings.
  ///
  /// Uses ⌘ (meta) on macOS, Ctrl on other platforms.
  static Map<ShortcutActivator, Intent> get shortcuts => {
        // ─────────────────────────────────────────────────────────────────────
        // Command Palette (⌘K / Ctrl+K)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true):
            const OpenCommandPaletteIntent(),
        const SingleActivator(LogicalKeyboardKey.keyK, control: true):
            const OpenCommandPaletteIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // Navigation (⌘1-5 / Ctrl+1-5)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.digit1, meta: true):
            const GoToTodayIntent(),
        const SingleActivator(LogicalKeyboardKey.digit1, control: true):
            const GoToTodayIntent(),

        const SingleActivator(LogicalKeyboardKey.digit2, meta: true):
            const GoToFocusIntent(),
        const SingleActivator(LogicalKeyboardKey.digit2, control: true):
            const GoToFocusIntent(),

        const SingleActivator(LogicalKeyboardKey.digit3, meta: true):
            const GoToRollupsIntent(),
        const SingleActivator(LogicalKeyboardKey.digit3, control: true):
            const GoToRollupsIntent(),

        const SingleActivator(LogicalKeyboardKey.digit4, meta: true):
            const GoToProjectsIntent(),
        const SingleActivator(LogicalKeyboardKey.digit4, control: true):
            const GoToProjectsIntent(),

        const SingleActivator(LogicalKeyboardKey.digit5, meta: true):
            const GoToSettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.digit5, control: true):
            const GoToSettingsIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // Task Creation (⌘N / Ctrl+N, ⌘⇧N / Ctrl+Shift+N)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true):
            const NewTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const NewTaskIntent(),

        const SingleActivator(LogicalKeyboardKey.keyN, meta: true, shift: true):
            const NewMustWinIntent(),
        const SingleActivator(
            LogicalKeyboardKey.keyN, control: true, shift: true):
            const NewMustWinIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // Date Navigation (⌘←/→ / Ctrl+←/→, ⌘T / Ctrl+T)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.arrowLeft, meta: true):
            const PreviousDayIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true):
            const PreviousDayIntent(),

        const SingleActivator(LogicalKeyboardKey.arrowRight, meta: true):
            const NextDayIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, control: true):
            const NextDayIntent(),

        const SingleActivator(LogicalKeyboardKey.keyT, meta: true):
            const JumpToTodayIntent(),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
            const JumpToTodayIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // Focus Mode (⌘⏎ / Ctrl+Enter, Space when in focus view)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            const ToggleFocusTaskIntent(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            const ToggleFocusTaskIntent(),

        const SingleActivator(LogicalKeyboardKey.keyF, meta: true, shift: true):
            const ToggleFocusModeIntent(),
        const SingleActivator(
            LogicalKeyboardKey.keyF, control: true, shift: true):
            const ToggleFocusModeIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // "I'm Stuck" (⌘⇧S / Ctrl+Shift+S)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
            const ImStuckIntent(),
        const SingleActivator(
            LogicalKeyboardKey.keyS, control: true, shift: true):
            const ImStuckIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // Search (⌘F / Ctrl+F)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            const FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const FocusSearchIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // Settings (⌘, / Ctrl+,)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.comma, meta: true):
            const GoToSettingsIntent(),
        const SingleActivator(LogicalKeyboardKey.comma, control: true):
            const GoToSettingsIntent(),

        // ─────────────────────────────────────────────────────────────────────
        // Quick Capture (⌥N / Alt+N)
        // ─────────────────────────────────────────────────────────────────────
        const SingleActivator(LogicalKeyboardKey.keyN, alt: true):
            const OpenQuickCaptureIntent(),
      };

  /// Returns a human-readable label for a shortcut.
  static String labelFor(ShortcutActivator activator) {
    if (activator is SingleActivator) {
      final parts = <String>[];
      if (activator.control) parts.add('Ctrl');
      if (activator.meta) parts.add('⌘');
      if (activator.alt) parts.add('⌥');
      if (activator.shift) parts.add('⇧');
      parts.add(_keyLabel(activator.trigger));
      return parts.join('+');
    }
    return activator.toString();
  }

  static String _keyLabel(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowLeft) return '←';
    if (key == LogicalKeyboardKey.arrowRight) return '→';
    if (key == LogicalKeyboardKey.arrowUp) return '↑';
    if (key == LogicalKeyboardKey.arrowDown) return '↓';
    if (key == LogicalKeyboardKey.enter) return '⏎';
    if (key == LogicalKeyboardKey.space) return 'Space';
    if (key == LogicalKeyboardKey.escape) return 'Esc';
    if (key == LogicalKeyboardKey.comma) return ',';

    // Handle digit keys
    if (key == LogicalKeyboardKey.digit1) return '1';
    if (key == LogicalKeyboardKey.digit2) return '2';
    if (key == LogicalKeyboardKey.digit3) return '3';
    if (key == LogicalKeyboardKey.digit4) return '4';
    if (key == LogicalKeyboardKey.digit5) return '5';
    if (key == LogicalKeyboardKey.digit6) return '6';
    if (key == LogicalKeyboardKey.digit7) return '7';
    if (key == LogicalKeyboardKey.digit8) return '8';
    if (key == LogicalKeyboardKey.digit9) return '9';
    if (key == LogicalKeyboardKey.digit0) return '0';

    // Handle letter keys
    final keyLabel = key.keyLabel;
    if (keyLabel.length == 1) return keyLabel.toUpperCase();

    return keyLabel;
  }
}
