package com.klaas.nfc_riegel

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * Farben aus `design_system/tokens.css`. Dieser Schirm läuft ohne Flutter-Engine,
 * deshalb stehen sie hier als Konstanten statt im Theme — ändert sich ein Token,
 * müssen `tokens.css`, `lib/theme.dart` und diese Datei gemeinsam nachgezogen werden.
 */
private object BlockColors {
    val BACKGROUND = Color.parseColor("#05070C")   // bg-block, tiefer als alles andere
    val SURFACE = Color.parseColor("#141A24")      // bg-elev-1
    val BORDER = Color.parseColor("#29FFFFFF")     // border-strong
    val LOCKED = Color.parseColor("#F5A65B")       // locked
    val LOCKED_BRIGHT = Color.parseColor("#FFC089")
    val LOCKED_TINT = Color.parseColor("#24F5A65B")
    val FG_1 = Color.parseColor("#EEF2F7")
    val FG_2 = Color.parseColor("#B6C0CE")
    val FG_3 = Color.parseColor("#7C8899")
    val FG_4 = Color.parseColor("#515C6B")
}

/** Vollbild-Sperrschirm. Zeigt Restzeit und nimmt den Notfall-Code entgegen. */
class BlockActivity : Activity() {

    private lateinit var controller: LockController
    private lateinit var countdown: TextView
    private lateinit var hint: TextView
    private lateinit var modeCaption: TextView
    private val handler = Handler(Looper.getMainLooper())

    private val ticker = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 1000)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        controller = LockController(this)
        setContentView(buildLayout())
    }

    override fun onResume() {
        super.onResume()
        handler.post(ticker)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(ticker)
    }

    /** Zurück-Taste darf den Sperrschirm nicht wegräumen. */
    override fun onBackPressed() {
        moveTaskToBack(true)
    }

    private fun buildLayout(): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BlockColors.BACKGROUND)
            setPadding(dp(32), dp(40), dp(32), dp(32))
        }

        val glyph = TextView(this).apply {
            text = "🔒"
            textSize = 30f
            gravity = Gravity.CENTER
            background = roundedRect(BlockColors.LOCKED_TINT, dp(24))
            layoutParams = LinearLayout.LayoutParams(dp(76), dp(76)).apply {
                bottomMargin = dp(24)
            }
        }

        val headline = TextView(this).apply {
            text = "Gesperrt"
            textSize = 30f
            setTypeface(null, Typeface.BOLD)
            setTextColor(BlockColors.FG_1)
            gravity = Gravity.CENTER
        }

        // Läuft in Mono: Proportionalziffern lassen die Zeile bei jedem
        // Sekundenwechsel zappeln. Ohne Timer bleibt die View unsichtbar —
        // ein Platzhalter sähe aus, als lade sie noch.
        countdown = TextView(this).apply {
            textSize = 42f
            typeface = Typeface.MONOSPACE
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(BlockColors.LOCKED_BRIGHT)
            gravity = Gravity.CENTER
            setPadding(0, dp(14), 0, dp(4))
        }

        hint = TextView(this).apply {
            textSize = 15f
            setTextColor(BlockColors.FG_2)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(36))
        }

        val codeField = EditText(this).apply {
            hint = "NOTFALL-CODE"
            inputType = InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            typeface = Typeface.MONOSPACE
            letterSpacing = 0.18f
            textSize = 15f
            setTextColor(BlockColors.FG_1)
            setHintTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            background = roundedRect(BlockColors.SURFACE, dp(10), BlockColors.BORDER)
            setPadding(dp(14), dp(13), dp(14), dp(13))
        }

        // Outline statt Vollfläche: der Code ist der Notausgang, nicht der Hauptweg.
        val submit = Button(this).apply {
            text = "Code einlösen"
            textSize = 14f
            isAllCaps = false
            setTextColor(BlockColors.FG_2)
            background = roundedRect(Color.TRANSPARENT, dp(10), BlockColors.BORDER)
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(10) }
            setOnClickListener { submitCode(codeField.text.toString()) }
        }

        modeCaption = TextView(this).apply {
            textSize = 12f
            setTextColor(BlockColors.FG_4)
            gravity = Gravity.CENTER
            setPadding(0, dp(14), 0, 0)
        }

        root.addView(glyph)
        root.addView(headline)
        root.addView(countdown)
        root.addView(hint)
        root.addView(codeField)
        root.addView(submit)
        root.addView(modeCaption)
        return root
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun roundedRect(fill: Int, radius: Int, stroke: Int? = null) =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius.toFloat()
            setColor(fill)
            if (stroke != null) setStroke(dp(1).coerceAtLeast(1), stroke)
        }

    private fun submitCode(code: String) {
        when (controller.submitCode(code).outcome) {
            CodeOutcome.UNLOCKED -> {
                Toast.makeText(this, "Riegel offen", Toast.LENGTH_SHORT).show()
                finish()
            }
            CodeOutcome.WRONG ->
                Toast.makeText(this, "Code falsch", Toast.LENGTH_SHORT).show()
            CodeOutcome.LOCKED_OUT ->
                Toast.makeText(this, "Zu viele Versuche — 60 Sekunden warten", Toast.LENGTH_LONG).show()
            CodeOutcome.NOT_SET ->
                Toast.makeText(this, "Kein Notfall-Code hinterlegt", Toast.LENGTH_LONG).show()
        }
    }

    private fun refresh() {
        val state = controller.engine.state()
        val lock = state.chipLock
        if (lock == null) {
            finish()
            return
        }
        val profileName = state.profileById(lock.profileId)?.name ?: "Riegel"
        val endsAt = lock.endsAt
        if (endsAt != null) {
            val remaining = ((endsAt - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
            countdown.visibility = View.VISIBLE
            countdown.text = "%02d:%02d".format(remaining / 60, remaining % 60)
            hint.text = "oder Chip scannen"
        } else {
            countdown.visibility = View.GONE
            hint.text = "Chip scannen, um freizugeben"
        }
        modeCaption.text = "Profil: $profileName"
    }
}
