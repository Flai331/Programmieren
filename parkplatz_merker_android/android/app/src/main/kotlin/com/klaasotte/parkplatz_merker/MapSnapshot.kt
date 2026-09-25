package com.klaasotte.parkplatz_merker

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.BitmapFactory
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.tan

object MapSnapshot {
    /**
     * Zeichnet eine 256×256 px Karte (Zoom 16) mit Auto-Punkt in der Mitte.
     * NUR im Hintergrund-Thread aufrufen! Gibt null zurück bei Fehler oder Netzwerkproblem.
     */
    fun render(lat: Double, lng: Double): Bitmap? {
        return try {
            val z = 16
            val n = 1 shl z
            val px = (lng + 180.0) / 360.0 * n * 256
            val latRad = Math.toRadians(lat)
            val py = (1 - ln(tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * n * 256

            val left = px - 128
            val top = py - 128
            val tx0 = floor(left / 256).toInt()
            val ty0 = floor(top / 256).toInt()

            val bitmap = Bitmap.createBitmap(256, 256, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            for (tx in tx0..(tx0 + 1)) {
                for (ty in ty0..(ty0 + 1)) {
                    val tile = download("https://tile.openstreetmap.org/$z/$tx/$ty.png") ?: return null
                    canvas.drawBitmap(
                        tile,
                        (tx * 256 - left).toFloat(),
                        (ty * 256 - top).toFloat(),
                        null
                    )
                }
            }

            // Mittelpunkt: weißer Kreis r=14, darin Indigo r=11
            val paint = Paint().apply { isAntiAlias = true }
            paint.color = 0xFFFFFFFF.toInt() // weiß
            canvas.drawCircle(128f, 128f, 14f, paint)
            paint.color = 0xFF3F51B5.toInt() // Indigo
            canvas.drawCircle(128f, 128f, 11f, paint)

            bitmap
        } catch (e: Exception) {
            null
        }
    }

    private fun download(url: String): Bitmap? {
        return try {
            val conn = URL(url).openConnection() as HttpURLConnection
            conn.connectTimeout = 8000
            conn.readTimeout = 8000
            conn.setRequestProperty("User-Agent", "ParkplatzMerker/1.0 (Android; com.klaasotte.parkplatz_merker)")
            try {
                BitmapFactory.decodeStream(conn.inputStream)
            } finally {
                conn.disconnect()
            }
        } catch (e: Exception) {
            null
        }
    }
}
