package com.klaas.nfc_riegel

import android.content.Intent
import android.nfc.NdefMessage
import android.nfc.NdefRecord
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build

object NfcSupport {

    const val MIME_TYPE = "application/vnd.com.klaas.nfc_riegel"

    fun toHex(bytes: ByteArray): String = bytes.joinToString("") { "%02X".format(it) }

    /** Tag aus dem Intent holen — ab API 33 mit Typ, davor über die veraltete Variante. */
    @Suppress("DEPRECATION")
    fun tagFrom(intent: Intent): Tag? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG, Tag::class.java)
        } else {
            intent.getParcelableExtra(NfcAdapter.EXTRA_TAG)
        }

    /**
     * Nachricht für den Chip: eigener MIME-Record (löst den Intent aus) plus
     * Android Application Record (startet die App, auch wenn sie geschlossen ist).
     */
    fun buildMessage(packageName: String): NdefMessage = NdefMessage(
        arrayOf(
            NdefRecord.createMime(MIME_TYPE, "riegel".toByteArray()),
            NdefRecord.createApplicationRecord(packageName),
        )
    )
}
