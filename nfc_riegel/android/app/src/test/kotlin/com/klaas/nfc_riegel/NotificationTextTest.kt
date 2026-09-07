package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Was in der Benachrichtigung steht — die Rechnung dahinter, ohne Android. */
class NotificationTextTest {

    private val now = 1_000_000L
    private val minute = 60_000L

    private val arbeit = Profile(
        id = "p1",
        name = "Arbeit",
        blockedPackages = setOf("com.instagram.android"),
        defaultMode = LockMode.OPEN,
    )
    private val nacht = Profile(
        id = "p2",
        name = "Nacht",
        blockedPackages = setOf("com.zhiliaoapp.musically"),
        defaultMode = LockMode.TIMER,
    )

    private fun zustand(
        chipLock: ChipLock? = null,
        release: Release? = null,
        timeLocks: List<TimeLock> = emptyList(),
    ) = LockState(
        profiles = listOf(arbeit, nacht),
        chipLock = chipLock,
        release = release,
        timeLocks = timeLocks,
    )

    @Test
    fun `ohne Sperre gibt es nichts anzuzeigen`() {
        assertNull(NotificationText.content(zustand(), now))
    }

    @Test
    fun `Chipsperre nennt den Weg zurueck`() {
        val inhalt = NotificationText.content(zustand(chipLock = ChipLock("p1")), now)!!

        assertEquals("Riegel aktiv — Arbeit, 1 App gesperrt", inhalt.title)
        assertEquals("Chip scannen, um freizugeben", inhalt.text)
    }

    @Test
    fun `Zeitsperre nennt ihr Ende`() {
        val ende = now + 30 * minute

        val inhalt = NotificationText.content(
            zustand(timeLocks = listOf(TimeLock("p2", LockMode.TIMER, ende))),
            now,
        )!!

        assertEquals(
            "Frei ab ${NotificationText.uhrzeit(ende)} — vorher nur mit dem Notfall-Code",
            inhalt.text,
        )
    }

    @Test
    fun `laufende Freigabe nennt nur ihr eigenes Profil`() {
        val ende = now + 10 * minute

        val inhalt = NotificationText.content(
            zustand(chipLock = ChipLock("p1"), release = Release("p1", ende)),
            now,
        )!!

        assertEquals("Freigabe läuft — Arbeit", inhalt.title)
        assertEquals("Frei bis ${NotificationText.uhrzeit(ende)} — danach wieder zu", inhalt.text)
    }

    @Test
    fun `neben der Freigabe genannte Sperren bleiben genannt`() {
        // Der Fall, der vorher falsch war: die Zeitsperre der Nacht landete unter
        // „Freigabe läuft", als waere auch sie offen.
        val ende = now + 10 * minute

        val inhalt = NotificationText.content(
            zustand(
                chipLock = ChipLock("p1"),
                release = Release("p1", ende),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, now + 30 * minute)),
            ),
            now,
        )!!

        assertEquals("Freigabe läuft — Arbeit", inhalt.title)
        assertTrue(inhalt.text, inhalt.text.endsWith(", Nacht bleibt gesperrt"))
    }

    @Test
    fun `abgelaufene Freigabe zaehlt nicht mehr`() {
        val inhalt = NotificationText.content(
            zustand(chipLock = ChipLock("p1"), release = Release("p1", now - 1)),
            now,
        )!!

        assertEquals("Riegel aktiv — Arbeit, 1 App gesperrt", inhalt.title)
        assertEquals("Chip scannen, um freizugeben", inhalt.text)
    }

    @Test
    fun `Chipsperre und Zeitsperre nennen beide Wege`() {
        val ende = now + 30 * minute

        val inhalt = NotificationText.content(
            zustand(
                chipLock = ChipLock("p1"),
                timeLocks = listOf(TimeLock("p2", LockMode.TIMER, ende)),
            ),
            now,
        )!!

        assertEquals(
            "Frei ab ${NotificationText.uhrzeit(ende)}, der Rest nach erneutem Scan",
            inhalt.text,
        )
    }
}
