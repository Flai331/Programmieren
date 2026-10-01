package com.klaas.nfc_riegel

import org.junit.Assert.assertEquals
import org.junit.Test

class VolumePlannerTest {

    private fun profil(id: String, vararg laut: Pair<VolumeStream, Int>) =
        Profile(id, id, volumes = laut.toMap())

    @Test
    fun `ein sperrendes Profil gibt seine Lautstaerken vor`() {
        val profile = listOf(profil("p1", VolumeStream.MEDIEN to 20, VolumeStream.WECKER to 80))

        assertEquals(
            mapOf(VolumeStream.MEDIEN to 20, VolumeStream.WECKER to 80),
            VolumePlanner.targets(profile, setOf("p1")),
        )
    }

    @Test
    fun `ohne Sperre bleibt alles unveraendert`() {
        val profile = listOf(profil("p1", VolumeStream.MEDIEN to 20))

        assertEquals(emptyMap<VolumeStream, Int>(), VolumePlanner.targets(profile, emptySet()))
    }

    @Test
    fun `bei mehreren Sperren gewinnt je Strom die leiseste`() {
        val profile = listOf(
            profil("p1", VolumeStream.MEDIEN to 40, VolumeStream.KLINGELTON to 10),
            profil("p2", VolumeStream.MEDIEN to 0, VolumeStream.WECKER to 60),
            profil("p3", VolumeStream.MEDIEN to 100),
        )

        assertEquals(
            mapOf(
                VolumeStream.MEDIEN to 0,
                VolumeStream.KLINGELTON to 10,
                VolumeStream.WECKER to 60,
            ),
            VolumePlanner.targets(profile, setOf("p1", "p2")),
        )
    }

    @Test
    fun `Prozent werden auf Stufen gerundet und begrenzt`() {
        assertEquals(8, VolumePlanner.stufe(50, max = 15))
        assertEquals(0, VolumePlanner.stufe(0, max = 15))
        assertEquals(15, VolumePlanner.stufe(100, max = 15))
        // Der Wecker hat ab Android 9 eine Untergrenze über null.
        assertEquals(1, VolumePlanner.stufe(0, max = 7, min = 1))
        assertEquals(7, VolumePlanner.stufe(250, max = 7))
    }
}
