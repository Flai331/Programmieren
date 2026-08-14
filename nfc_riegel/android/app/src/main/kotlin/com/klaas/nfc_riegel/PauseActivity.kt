package com.klaas.nfc_riegel

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Die Atempause. Ein Countdown, der sich nicht überspringen lässt, danach zwei
 * Wege. Bewusst kein Sperrschirm: hier wird nichts verwehrt, nur aufgehalten.
 */
class PauseActivity : Activity() {

    private lateinit var countdown: TextView
    private lateinit var weiter: Button
    private lateinit var schliessen: Button
    private var verbleibend = 5
    private val handler = Handler(Looper.getMainLooper())

    private val ticker = object : Runnable {
        override fun run() {
            verbleibend -= 1
            if (verbleibend > 0) {
                countdown.text = verbleibend.toString()
                handler.postDelayed(this, 1000)
            } else {
                countdown.text = "0"
                zeigeKnoepfe()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        verbleibend = intent?.getIntExtra(EXTRA_SECONDS, 5) ?: 5
        setContentView(buildLayout())
    }

    override fun onResume() {
        super.onResume()
        if (verbleibend > 0) handler.postDelayed(ticker, 1000)
    }

    override fun onPause() {
        super.onPause()
        handler.removeCallbacks(ticker)
    }

    /** Während des Countdowns führt die Zurück-Taste nicht heraus. */
    override fun onBackPressed() {
        if (verbleibend > 0) return
        super.onBackPressed()
    }

    private fun buildLayout(): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BlockColors.BACKGROUND)
            setPadding(dp(32), dp(40), dp(32), dp(32))
        }

        val app = TextView(this).apply {
            text = intent?.getStringExtra(EXTRA_APP_NAME) ?: "Diese App"
            textSize = 24f
            setTypeface(null, Typeface.BOLD)
            setTextColor(BlockColors.FG_1)
            gravity = Gravity.CENTER
        }

        val heute = TextView(this).apply {
            val minuten = intent?.getIntExtra(EXTRA_USED_MINUTES, 0) ?: 0
            text = "Heute $minuten Minuten"
            textSize = 15f
            setTextColor(BlockColors.FG_2)
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, dp(28))
        }

        countdown = TextView(this).apply {
            text = verbleibend.toString()
            textSize = 56f
            typeface = Typeface.MONOSPACE
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(BlockColors.ACCENT)
            gravity = Gravity.CENTER
        }

        val frage = TextView(this).apply {
            text = "Willst du weitermachen?"
            textSize = 15f
            setTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            setPadding(0, dp(10), 0, dp(32))
        }

        weiter = Button(this).apply {
            text = "Weiter"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.FG_2)
            background = roundedRect(Color.TRANSPARENT, dp(10), BlockColors.BORDER)
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
            visibility = View.INVISIBLE
            setOnClickListener { finish() }
        }

        schliessen = Button(this).apply {
            text = "Schließen"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.BACKGROUND)
            background = roundedRect(BlockColors.ACCENT, dp(10))
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(10) }
            visibility = View.INVISIBLE
            setOnClickListener {
                startActivity(
                    Intent(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_HOME)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
                finish()
            }
        }

        root.addView(app)
        root.addView(heute)
        root.addView(countdown)
        root.addView(frage)
        root.addView(weiter)
        root.addView(schliessen)
        return root
    }

    private fun zeigeKnoepfe() {
        weiter.visibility = View.VISIBLE
        schliessen.visibility = View.VISIBLE
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    private fun roundedRect(fill: Int, radius: Int, stroke: Int? = null) =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = radius.toFloat()
            setColor(fill)
            if (stroke != null) setStroke(dp(1).coerceAtLeast(1), stroke)
        }

    companion object {
        const val EXTRA_SECONDS = "sekunden"
        const val EXTRA_APP_NAME = "appName"
        const val EXTRA_USED_MINUTES = "genutzteMinuten"
    }
}
