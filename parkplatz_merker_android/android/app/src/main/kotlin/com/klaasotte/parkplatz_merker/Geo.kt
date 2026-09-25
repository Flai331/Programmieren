package com.klaasotte.parkplatz_merker

import android.content.Context
import android.location.Address
import android.location.Geocoder
import android.os.Build
import java.util.Locale

object Geo {
    /** Reverse-Geocoding: ermittelt Adresse aus Koordinaten. Asynchron, done wird genau einmal aufgerufen. */
    fun reverse(ctx: Context, lat: Double, lng: Double, done: (String?) -> Unit) {
        if (!Geocoder.isPresent()) {
            done(null)
            return
        }
        val geocoder = Geocoder(ctx, Locale.GERMANY)
        if (Build.VERSION.SDK_INT >= 33) {
            geocoder.getFromLocation(lat, lng, 1, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    done(addresses.firstOrNull()?.let { addressText(it) })
                }

                override fun onError(errorMessage: String?) {
                    done(null)
                }
            })
        } else {
            Thread {
                val text = try {
                    @Suppress("DEPRECATION")
                    geocoder.getFromLocation(lat, lng, 1)?.firstOrNull()?.let { addressText(it) }
                } catch (e: Exception) {
                    null
                }
                done(text)
            }.start()
        }
    }

    private fun addressText(address: Address): String? {
        val line = address.getAddressLine(0)
        if (!line.isNullOrBlank()) return line
        val street = listOfNotNull(address.thoroughfare, address.subThoroughfare).joinToString(" ")
        val town = listOfNotNull(address.postalCode, address.locality).joinToString(" ")
        return listOf(street, town).filter { it.isNotBlank() }.joinToString(", ").ifBlank { null }
    }
}
