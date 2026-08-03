package com.klaas.nfc_riegel

import android.app.Activity
import android.app.PendingIntent
import android.content.Intent
import android.graphics.Color
import android.nfc.NfcAdapter
import android.nfc.tech.Ndef
import android.nfc.tech.NdefFormatable
import android.os.Bundle
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

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
        orientation = LinearLayout.VERTICAL
        gravity = Gravity.CENTER
        setBackgroundColor(Color.parseColor("#101317"))
        setPadding(48, 48, 48, 48)
        status = TextView(context).apply {
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            text = "Chip jetzt an die Rückseite des Handys halten"
        }
        addView(status)
    }

    private fun writeTag(intent: Intent) {
        val tag = NfcSupport.tagFrom(intent)
        if (tag == null) {
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
                status.text = "Fehlgeschlagen: ${error.message ?: "unbekannt"}"
            },
        )
    }
}
