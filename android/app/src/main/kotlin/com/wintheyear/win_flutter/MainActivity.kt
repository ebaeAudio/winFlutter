package com.wintheyear.win_flutter

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity: FlutterActivity() {
  private val channelName = "win_flutter/restriction_engine"
  private val prefsName = "focus_engine_prefs"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)

    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
      .setMethodCallHandler { call, result ->
        when (call.method) {
          "getPermissions" -> {
            val enabled = isAccessibilityServiceEnabled()
            result.success(
              mapOf(
                "isSupported" to true,
                "isAuthorized" to enabled,
                "needsOnboarding" to !enabled,
                "platformDetails" to "Accessibility enabled: $enabled"
              )
            )
          }

          "requestPermissions" -> {
            // Opens Accessibility settings so the user can enable the service.
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            result.success(null)
          }

          "configureApps" -> {
            // iOS-only concept. Android policies are configured in Flutter.
            result.success(null)
          }

          "startSession" -> {
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            val endsAtMillis = (args["endsAtMillis"] as? Number)?.toLong() ?: 0L
            val allowedApps = args["allowedApps"] as? List<*> ?: emptyList<Any>()
            val friction = args["friction"] as? Map<*, *> ?: emptyMap<Any, Any>()

            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            prefs.edit()
              .putBoolean("active", true)
              .putLong("endsAtMillis", endsAtMillis)
              .putString("allowedAppsJson", JSONArray(allowedApps).toString())
              .putString("frictionJson", JSONObject(friction).toString())
              .apply()
            result.success(null)
          }

          "endSession" -> {
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            prefs.edit()
              .putBoolean("active", false)
              .remove("endsAtMillis")
              .remove("allowedAppsJson")
              .remove("frictionJson")
              .remove("emergencyUntilMillis")
              .apply()
            result.success(null)
          }

          "startEmergencyException" -> {
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            val durationMillis = (args["durationMillis"] as? Number)?.toLong() ?: 0L
            val until = System.currentTimeMillis() + durationMillis
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            prefs.edit().putLong("emergencyUntilMillis", until).apply()
            result.success(null)
          }

          "setCardRequired" -> {
            val args = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            val required = (args["required"] as? Boolean) ?: false
            val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
            val e = prefs.edit().putBoolean("cardRequired", required)
            if (required) {
              // No bypass: when cardRequired is enabled, clear any active emergency window.
              e.remove("emergencyUntilMillis")
            }
            e.apply()
            result.success(null)
          }

          else -> result.notImplemented()
        }
      }
  }

  private fun isAccessibilityServiceEnabled(): Boolean {
    // Lightweight heuristic: check enabled services string contains our package name.
    val enabled = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: ""
    return enabled.contains(packageName)
  }
}
