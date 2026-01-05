package com.wintheyear.win_flutter.focus

import android.accessibilityservice.AccessibilityService
import android.content.Context
import android.content.Intent
import android.view.accessibility.AccessibilityEvent
import org.json.JSONArray

class FocusAccessibilityService : AccessibilityService() {
  private val prefsName = "focus_engine_prefs"

  override fun onAccessibilityEvent(event: AccessibilityEvent?) {
    if (event == null) return
    if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return

    val pkg = event.packageName?.toString() ?: return
    if (pkg == applicationContext.packageName) return

    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
    val active = prefs.getBoolean("active", false)
    if (!active) return

    val endsAt = prefs.getLong("endsAtMillis", 0L)
    if (endsAt > 0 && System.currentTimeMillis() >= endsAt) {
      prefs.edit().putBoolean("active", false).apply()
      return
    }

    val emergencyUntil = prefs.getLong("emergencyUntilMillis", 0L)
    if (emergencyUntil > System.currentTimeMillis()) {
      // Temporary exception window.
      return
    }

    val allowedRaw = prefs.getString("allowedAppsJson", "[]") ?: "[]"
    val allowed = parseAllowedPackages(allowedRaw)
    val isAllowed = allowed.contains(pkg)
    if (isAllowed) return

    val i = Intent(this, BlockingActivity::class.java).apply {
      addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      putExtra("blockedPackage", pkg)
    }
    startActivity(i)
  }

  override fun onInterrupt() {
    // No-op
  }

  private fun parseAllowedPackages(raw: String): Set<String> {
    return try {
      val arr = JSONArray(raw)
      val out = mutableSetOf<String>()
      for (i in 0 until arr.length()) {
        val obj = arr.optJSONObject(i) ?: continue
        // Dart AppIdentifier.toJson: {platform, id, displayName?}
        val platform = obj.optString("platform")
        if (platform != "android") continue
        val id = obj.optString("id")
        if (id.isNotBlank()) out.add(id)
      }
      out
    } catch (_: Throwable) {
      emptySet()
    }
  }
}


