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

    /** Adresse suchen: bis zu 5 Treffer (lat, lng, label). Asynchron, done wird genau einmal aufgerufen. */
    fun forward(ctx: Context, query: String, done: (List<Map<String, Any?>>) -> Unit) {
        if (!Geocoder.isPresent() || query.isBlank()) {
            done(emptyList())
            return
        }
        val geocoder = Geocoder(ctx, Locale.GERMANY)
        fun toMaps(list: List<Address>?): List<Map<String, Any?>> =
            (list ?: emptyList()).filter { it.hasLatitude() && it.hasLongitude() }.map {
                mapOf(
                    "lat" to it.latitude,
                    "lng" to it.longitude,
                    "label" to (addressText(it) ?: query),
                )
            }
        if (Build.VERSION.SDK_INT >= 33) {
            geocoder.getFromLocationName(query, 5, object : Geocoder.GeocodeListener {
                override fun onGeocode(addresses: MutableList<Address>) {
                    done(toMaps(addresses))
                }

                override fun onError(errorMessage: String?) {
                    done(emptyList())
                }
            })
        } else {
            Thread {
                val found = try {
                    @Suppress("DEPRECATION")
                    toMaps(geocoder.getFromLocationName(query, 5))
                } catch (e: Exception) {
                    emptyList()
                }
                done(found)
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
