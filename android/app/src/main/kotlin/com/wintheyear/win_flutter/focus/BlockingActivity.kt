package com.wintheyear.win_flutter.focus

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

class BlockingActivity : Activity() {
  private val prefsName = "focus_engine_prefs"

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)

    val blocked = intent.getStringExtra("blockedPackage") ?: "this app"
    val prefs = getSharedPreferences(prefsName, Context.MODE_PRIVATE)
    val frictionRaw = prefs.getString("frictionJson", "{}") ?: "{}"
    val friction = parseFriction(frictionRaw)

    val root = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER
      setPadding(48, 48, 48, 48)
      layoutParams = ViewGroup.LayoutParams(
        ViewGroup.LayoutParams.MATCH_PARENT,
        ViewGroup.LayoutParams.MATCH_PARENT
      )
    }

    val title = TextView(this).apply {
      text = "Blocked during Focus Session"
      textSize = 22f
      gravity = Gravity.CENTER
    }

    val subtitle = TextView(this).apply {
      text = blocked
      textSize = 14f
      gravity = Gravity.CENTER
    }

    val hint = TextView(this).apply {
      text = "Hold to unlock (early exit)"
      gravity = Gravity.CENTER
    }

    val holdBtn = Button(this).apply {
      text = "Hold ${friction.holdToUnlockSeconds}s"
    }

    holdBtn.setOnLongClickListener {
      holdBtn.isEnabled = false
      hint.text = "Waiting ${friction.unlockDelaySeconds}s…"
      Handler(Looper.getMainLooper()).postDelayed({
        // NOTE: For scaffold, we simply end the session on Android by disabling active flag.
        // A real implementation could do "temporary exception" instead of ending session.
        prefs.edit().putBoolean("active", false).apply()
        finish()
      }, (friction.unlockDelaySeconds * 1000).toLong())
      true
    }

    val emergencyBtn = Button(this).apply {
      text = "Emergency unlock (${friction.emergencyUnlockMinutes} min)"
    }

    emergencyBtn.setOnClickListener {
      val until = System.currentTimeMillis() + (friction.emergencyUnlockMinutes * 60_000L)
      prefs.edit().putLong("emergencyUntilMillis", until).apply()
      finish()
    }

    root.addView(title)
    root.addView(subtitle)
    root.addView(hint)
    root.addView(holdBtn)
    root.addView(emergencyBtn)

    setContentView(root)
  }

  private data class Friction(
    val holdToUnlockSeconds: Int,
    val unlockDelaySeconds: Int,
    val emergencyUnlockMinutes: Int
  )

  private fun parseFriction(raw: String): Friction {
    return try {
      val obj = JSONObject(raw)
      Friction(
        holdToUnlockSeconds = obj.optInt("holdToUnlockSeconds", 3),
        unlockDelaySeconds = obj.optInt("unlockDelaySeconds", 10),
        emergencyUnlockMinutes = obj.optInt("emergencyUnlockMinutes", 3),
      )
    } catch (_: Throwable) {
      Friction(3, 10, 3)
    }
  }
}


