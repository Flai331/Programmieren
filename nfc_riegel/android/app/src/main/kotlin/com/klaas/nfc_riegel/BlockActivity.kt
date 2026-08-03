package com.klaas.nfc_riegel

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/** Vollbild-Sperrschirm. Zeigt Restzeit und nimmt den Notfall-Code entgegen. */
class BlockActivity : Activity() {

    private lateinit var controller: LockController
    private lateinit var title: TextView
    private lateinit var subtitle: TextView
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
            setBackgroundColor(Color.parseColor("#101317"))
            setPadding(48, 48, 48, 48)
        }

        title = TextView(this).apply {
            textSize = 28f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            text = "Gesperrt"
        }

        subtitle = TextView(this).apply {
            textSize = 16f
            setTextColor(Color.parseColor("#B0B8C1"))
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 48)
        }

        val codeField = EditText(this).apply {
            hint = "Notfall-Code"
            inputType = InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
            setTextColor(Color.WHITE)
            setHintTextColor(Color.parseColor("#6B7480"))
            gravity = Gravity.CENTER
        }

        val submit = Button(this).apply {
            text = "Code einlösen"
            setOnClickListener { submitCode(codeField.text.toString()) }
        }

        root.addView(title)
        root.addView(subtitle)
        root.addView(codeField)
        root.addView(submit)
        return root
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
        if (!state.locked) {
            finish()
            return
        }
        val endsAt = state.endsAt
        subtitle.text = if (state.mode == LockMode.TIMER && endsAt != null) {
            val remaining = ((endsAt - System.currentTimeMillis()) / 1000).coerceAtLeast(0)
            "Noch %02d:%02d — oder Chip scannen".format(remaining / 60, remaining % 60)
        } else {
            "Chip scannen, um freizugeben"
        }
    }
}
