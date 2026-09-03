package com.klaas.nfc_riegel

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.provider.ContactsContract

/** Ein Kontakt mit einer Rufnummer, für die Auswahlliste. */
data class DeviceContact(val name: String, val number: String)

/** Fragt [Manifest.permission.READ_CONTACTS] an — erst beim Öffnen der Auswahl. */
object ContactPermission {

    const val REQUEST_CODE = 1003

    fun granted(activity: Activity): Boolean =
        activity.checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    fun request(activity: Activity) {
        activity.requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), REQUEST_CODE)
    }
}

/**
 * Liest Namen und Rufnummern für die Auswahl. Gespeichert wird davon nur die
 * normalisierte Nummer: Riegel muss beim Anruf entscheiden können, und dafür
 * ist der Name unnötig. Wer die Kontaktberechtigung später entzieht, behält
 * damit eine funktionierende Auswahl — nur die Namen fehlen dann.
 */
class ContactSource(private val context: Context) {

    private fun darfLesen(): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CONTACTS) ==
            PackageManager.PERMISSION_GRANTED

    fun contacts(): List<DeviceContact> {
        if (!darfLesen()) return emptyList()

        val spalten = arrayOf(
            ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
            ContactsContract.CommonDataKinds.Phone.NUMBER,
        )
        // Je normalisierter Nummer nur ein Eintrag: dieselbe Nummer steht oft
        // mehrfach in den Kontakten, einmal mit und einmal ohne Landesvorwahl.
        val gefunden = LinkedHashMap<String, DeviceContact>()

        context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            spalten,
            null,
            null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} COLLATE LOCALIZED ASC",
        )?.use { zeiger ->
            while (zeiger.moveToNext()) {
                val name = zeiger.getString(0) ?: continue
                val nummer = PhoneNumbers.normalize(zeiger.getString(1))
                if (nummer.isEmpty() || gefunden.containsKey(nummer)) continue
                gefunden[nummer] = DeviceContact(name, nummer)
            }
        }
        return gefunden.values.toList()
    }
}
