package com.klaas.nfc_riegel

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * Fragt beim Aufsperren, wie lange offen bleiben soll. Vier Stufen und ein Feld
 * für eigene Zahlen; Abbrechen lässt die Sperre stehen.
 *
 * Kotlin-Views wie [PauseActivity] und [BlockActivity]: der Scanweg startet ohne
 * Flutter-Engine, und daran soll ein Dialog nichts ändern.
 */
class ReleaseActivity : Activity() {

    private lateinit var eingabe: EditText

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(buildLayout())
    }

    private fun oeffne(minuten: Int) {
        val profileId = intent?.getStringExtra(EXTRA_PROFILE_ID) ?: ""
        val meldung = when (LockController(this).startRelease(profileId, minuten)) {
            ReleaseOutcome.RELEASED -> "Frei für $minuten Minuten"
            ReleaseOutcome.NO_LOCK -> "Keine Sperre dieses Profils"
        }
        Toast.makeText(this, meldung, Toast.LENGTH_SHORT).show()
        finish()
    }

    private fun buildLayout(): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(BlockColors.BACKGROUND)
            setPadding(dp(32), dp(40), dp(32), dp(32))
        }

        val headline = TextView(this).apply {
            text = "Wie lange offen?"
            textSize = 24f
            setTypeface(null, Typeface.BOLD)
            setTextColor(BlockColors.FG_1)
            gravity = Gravity.CENTER
        }

        val profilname = TextView(this).apply {
            text = intent?.getStringExtra(EXTRA_PROFILE_NAME) ?: "Riegel"
            textSize = 15f
            setTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, dp(28))
        }

        val stufenReihe = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }
        STUFEN.forEachIndexed { index, minuten ->
            val knopf = Button(this).apply {
                text = minuten.toString()
                textSize = 15f
                isAllCaps = false
                setTextColor(BlockColors.FG_1)
                background = roundedRect(BlockColors.SURFACE, dp(10), BlockColors.BORDER)
                setPadding(dp(8), dp(13), dp(8), dp(13))
                layoutParams = LinearLayout.LayoutParams(
                    0,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    1f,
                ).apply { if (index > 0) marginStart = dp(8) }
                setOnClickListener { oeffne(minuten) }
            }
            stufenReihe.addView(knopf)
        }

        val erklaerung = TextView(this).apply {
            text = "Minuten"
            textSize = 12f
            setTextColor(BlockColors.FG_4)
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(28))
        }

        eingabe = EditText(this).apply {
            hint = "eigene Minuten"
            inputType = InputType.TYPE_CLASS_NUMBER
            textSize = 15f
            setTextColor(BlockColors.FG_1)
            setHintTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            background = roundedRect(BlockColors.SURFACE, dp(10), BlockColors.BORDER)
            setPadding(dp(14), dp(13), dp(14), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            )
        }

        val oeffnen = Button(this).apply {
            text = "Öffnen"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.BACKGROUND)
            background = roundedRect(BlockColors.ACCENT, dp(10))
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(16) }
            setOnClickListener {
                val zahl = eingabe.text.toString().toIntOrNull()
                if (zahl == null) {
                    Toast.makeText(this@ReleaseActivity, "Zahl eingeben", Toast.LENGTH_SHORT).show()
                } else {
                    oeffne(zahl)
                }
            }
        }

        val abbrechen = Button(this).apply {
            text = "Abbrechen"
            textSize = 15f
            isAllCaps = false
            setTextColor(BlockColors.FG_2)
            background = roundedRect(Color.TRANSPARENT, dp(10), BlockColors.BORDER)
            setPadding(dp(16), dp(13), dp(16), dp(13))
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(10) }
            // Abbruch heißt Abbruch: die Sperre bleibt genau so stehen, wie sie
            // vor dem Scan war — kein startRelease, kein sonstiger Eingriff.
            setOnClickListener { finish() }
        }

        root.addView(headline)
        root.addView(profilname)
        root.addView(stufenReihe)
        root.addView(erklaerung)
        root.addView(eingabe)
        root.addView(oeffnen)
        root.addView(abbrechen)
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

    companion object {
        const val EXTRA_PROFILE_ID = "profilId"
        const val EXTRA_PROFILE_NAME = "profilName"

        /** Kurze Stufen — eine Freigabe ist eine Unterbrechung, kein halber Tag. */
        val STUFEN = listOf(5, 10, 15, 30)
    }
}
