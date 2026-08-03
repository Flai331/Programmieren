package com.klaas.nfc_riegel

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.nfc.NfcAdapter
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/**
 * Farben aus `design_system/tokens.css`. Wie beim Sperrschirm als Konstanten, weil
 * dieser Schirm ohne Flutter-Engine läuft — `tokens.css`, `lib/theme.dart` und diese
 * Datei gehören gemeinsam nachgezogen.
 */
private object TagWriteColors {
    val BACKGROUND = Color.parseColor("#080B12")   // bg-base
    val ACCENT_TINT = Color.parseColor("#1F62D9E8")
    val FG_1 = Color.parseColor("#EEF2F7")
    val FG_2 = Color.parseColor("#B6C0CE")
    val DANGER = Color.parseColor("#FF6B7A")
}

/**
 * Einrichtung: beschreibt den Chip mit MIME-Record und Application Record und
 * merkt sich dessen UID. Nutzt Foreground Dispatch, damit hier jeder Tag ankommt —
 * auch ein noch leerer.
 */
class TagWriteActivity : Activity() {

    private var adapter: NfcAdapter? = null
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        adapter = NfcAdapter.getDefaultAdapter(this)
        setContentView(buildLayout())
        if (adapter == null) {
            Toast.makeText(this, "Kein NFC auf diesem Gerät", Toast.LENGTH_LONG).show()
            finish()
        }
    }

    override fun onResume() {
        super.onResume()
        val intent = Intent(this, javaClass).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        val pending = PendingIntent.getActivity(
            this, 0, intent, PendingIntent.FLAG_MUTABLE
        )
        adapter?.enableForegroundDispatch(this, pending, null, null)
    }

    override fun onPause() {
        super.onPause()
        adapter?.disableForegroundDispatch(this)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        writeTag(intent)
    }

    private fun buildLayout(): LinearLayout = LinearLayout(this).apply {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(TagWriteColors.BACKGROUND)
        setPadding(dp(32), dp(32), dp(32), dp(32))

        val glyph = TextView(context).apply {
            text = "📶"
            textSize = 30f
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                cornerRadius = dp(24).toFloat()
                setColor(TagWriteColors.ACCENT_TINT)
            }
            layoutParams = LinearLayout.LayoutParams(dp(76), dp(76)).apply {
                bottomMargin = dp(24)
            }
        }

        status = TextView(context).apply {
            textSize = 18f
            setTextColor(TagWriteColors.FG_1)
            gravity = Gravity.CENTER
            text = "Chip jetzt an die Rückseite des Handys halten"
        }

        addView(glyph)
        addView(status)
    }

    private fun writeTag(intent: Intent) {
        val tag = NfcSupport.tagFrom(intent)
        if (tag == null) {
            status.setTextColor(TagWriteColors.DANGER)
            status.text = "Chip nicht lesbar — nochmal versuchen"
            return
        }

        val message = NfcSupport.buildMessage(packageName)
        val written = runCatching {
            val ndef = Ndef.get(tag)
            if (ndef != null) {
                ndef.connect()
                if (!ndef.isWritable) throw IllegalStateException("Chip ist schreibgeschützt")
                ndef.writeNdefMessage(message)
                ndef.close()
            } else {
                val formatable = NdefFormatable.get(tag)
                    ?: throw IllegalStateException("Chip nicht beschreibbar")
                formatable.connect()
                formatable.format(message)
                formatable.close()
            }
        }

        written.fold(
            onSuccess = {
                LockEngine(SharedPrefsLockStore(this)).enrollTag(NfcSupport.toHex(tag.id))
                Toast.makeText(this, "Chip angelernt", Toast.LENGTH_SHORT).show()
                setResult(RESULT_OK)
                finish()
            },
            onFailure = { error ->
                status.setTextColor(TagWriteColors.DANGER)
                status.text = "Fehlgeschlagen: ${error.message ?: "unbekannt"}"
            },
        )
    }
}
