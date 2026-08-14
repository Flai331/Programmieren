package com.klaas.nfc_riegel

import android.graphics.Color

/**
 * Farben aus `design_system/tokens.css`. Sperr- und Pausenschirm laufen ohne
 * Flutter-Engine, deshalb stehen sie hier als Konstanten statt im Theme —
 * ändert sich ein Token, müssen `tokens.css`, `lib/theme.dart` und diese Datei
 * gemeinsam nachgezogen werden.
 */
object BlockColors {
    val BACKGROUND = Color.parseColor("#05070C")   // bg-block, tiefer als alles andere
    val SURFACE = Color.parseColor("#141A24")      // bg-elev-1
    val BORDER = Color.parseColor("#29FFFFFF")     // border-strong
    val LOCKED = Color.parseColor("#F5A65B")       // locked
    val LOCKED_BRIGHT = Color.parseColor("#FFC089")
    val LOCKED_TINT = Color.parseColor("#24F5A65B")
    val ACCENT = Color.parseColor("#62D9E8")       // accent, für die Pause
    val FG_1 = Color.parseColor("#EEF2F7")
    val FG_2 = Color.parseColor("#B6C0CE")
    val FG_3 = Color.parseColor("#7C8899")
    val FG_4 = Color.parseColor("#515C6B")
}
