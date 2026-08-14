package com.klaas.nfc_riegel

import android.app.Activity
import android.content.Intent
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
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Vollbild-Sperrschirm. Zeigt Restzeit und nimmt den Notfall-Code entgegen. */
class BlockActivity : Activity() {

    private lateinit var controller: LockController
    private lateinit var countdown: TextView
    private lateinit var hint: TextView
    private lateinit var modeCaption: TextView
    private lateinit var screenTime: TextView
    private var blockiertesPaket: String? = null
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
        blockiertesPaket = intent?.getStringExtra(EXTRA_PACKAGE)
        setContentView(buildLayout())
    }

    /** Wird mit `CLEAR_TOP` erneut gestartet, wenn eine andere gesperrte App drankommt. */
    override fun onNewIntent(intent: Intent?) {
        super.onNewIntent(intent)
        setIntent(intent)
        blockiertesPaket = intent?.getStringExtra(EXTRA_PACKAGE)
        aktualisiereScreenzeit()
    }

    override fun onResume() {
        super.onResume()
        handler.post(ticker)
        aktualisiereScreenzeit()
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
            // TYPE_CLASS_TEXT muss mit: das Flag allein lässt die Klassenbits auf
            // 0 stehen, das ist TYPE_NULL — „nicht editierbar". Die Tastatur geht
            // dann nicht auf und der Notausgang bliebe zu.
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_FLAG_CAP_CHARACTERS
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

        screenTime = TextView(this).apply {
            textSize = 12f
            setTextColor(BlockColors.FG_3)
            gravity = Gravity.CENTER
            setPadding(0, dp(6), 0, 0)
            visibility = View.GONE
        }

        root.addView(glyph)
        root.addView(headline)
        root.addView(countdown)
        root.addView(hint)
        root.addView(codeField)
        root.addView(submit)
        root.addView(modeCaption)
        root.addView(screenTime)
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
        val now = System.currentTimeMillis()
        val laufende = state.timeLocks.filter { now < it.endsAt }
        val termine = CalendarPlanner.activeWindows(state.calendar, now)
        val gesperrteProfile = buildSet {
            state.chipLock?.let { add(it.profileId) }
            laufende.forEach { add(it.profileId) }
            termine.forEach { if (it.profileId.isNotEmpty()) add(it.profileId) }
        }
        if (gesperrteProfile.isEmpty()) {
            finish()
            return
        }

        val profileName = gesperrteProfile
            .mapNotNull { state.profileById(it)?.name }
            .joinToString(", ")
            .ifEmpty { "Riegel" }

        // Die am spätesten endende Sperre zählt: eine frühere sagt nichts,
        // solange eine spätere noch greift. Termine zählen mit — ein
        // festgenageltes Ende schlägt dabei das Ende aus dem Kalender.
        val terminEnden = termine.map { state.calendar.pinnedEnds[it.eventId] ?: it.endsAt }
        val spaetestesEnde = (laufende.map { it.endsAt } + terminEnden).maxOrNull()
        if (spaetestesEnde != null) {
            val remaining = ((spaetestesEnde - now) / 1000).coerceAtLeast(0)
            countdown.visibility = View.VISIBLE
            // Eine UNTIL-Sperre läuft über Nacht. „720:00" wäre keine Auskunft,
            // deshalb ab einer Stunde mit Stundenfeld.
            countdown.text = if (remaining >= 3600) {
                "%d:%02d:%02d".format(remaining / 3600, (remaining % 3600) / 60, remaining % 60)
            } else {
                "%02d:%02d".format(remaining / 60, remaining % 60)
            }
            hint.text = when {
                termine.isNotEmpty() -> "Bis der Termin vorbei ist, öffnet nur ein Generalschlüssel"
                state.chipLock != null -> "Chip scannen oder warten"
                else -> "Vorher öffnet nur ein Generalschlüssel"
            }
        } else {
            countdown.visibility = View.GONE
            hint.text = "Chip scannen, um freizugeben"
        }

        // Der Termin nennt den Grund der Sperre — das sagt mehr als der
        // Profilname, den man ohnehin selbst vergeben hat.
        modeCaption.text = if (termine.isEmpty()) {
            "Profil: $profileName"
        } else {
            val ende = SimpleDateFormat("HH:mm", Locale.GERMANY).format(Date(terminEnden.first()))
            "${termine.first().title} — frei ab $ende"
        }
    }

    /**
     * Bewusst nicht im Sekundentakt: der Ticker fragt jede Sekunde den
     * Sperrzustand ab, aber die Nutzungsereignisse des ganzen Tages dafür
     * durchzugehen wäre Verschwendung. Die Zahl ändert sich ohnehin nicht,
     * solange dieser Schirm oben liegt — die App dahinter läuft ja nicht.
     */
    private fun aktualisiereScreenzeit() {
        val paket = blockiertesPaket
        if (paket == null) {
            screenTime.visibility = View.GONE
            return
        }

        val quelle = AndroidUsageSource(this)
        // Ohne Berechtigung bleibt die Zeile weg. Der Sperrschirm ist der
        // falsche Ort, um etwas einzufordern — dort ist man ohnehin gebremst.
        if (!quelle.granted()) {
            screenTime.visibility = View.GONE
            return
        }

        val jetzt = System.currentTimeMillis()
        val beginn = ScreenTimeCalculator.startOfDay(jetzt)
        val millis = ScreenTimeCalculator
            .totals(quelle.events(beginn, jetzt), beginn, jetzt)[paket] ?: 0L

        screenTime.visibility = View.VISIBLE
        screenTime.text = when {
            millis == 0L -> "Heute noch nicht benutzt"
            millis < 60_000L -> "Heute: unter 1 min"
            else -> "Heute: ${formatiereDauer(millis)}"
        }
    }

    /** Wie `formatUsage` in `lib/screen_time.dart` — hier ohne Flutter. */
    private fun formatiereDauer(millis: Long): String {
        val minuten = millis / 60_000L
        return if (minuten < 60) "$minuten min" else "${minuten / 60} h ${minuten % 60} min"
    }

    companion object {
        const val EXTRA_PACKAGE = "paket"
    }
}
