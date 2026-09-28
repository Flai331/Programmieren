package com.klaasotte.parkplatz_merker

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import java.net.HttpURLConnection
import java.net.URL
import kotlin.math.floor
import kotlin.math.ln
import kotlin.math.tan

object MapSnapshot {
    /**
     * Zeichnet eine [size]×[size] px Karte (Zoom [zoom]) mit Auto-Punkt in der Mitte.
     * Standard: 512 px bei Zoom 17 – gleicher Ausschnitt wie früher 256 px bei Zoom 16,
     * aber doppelt so scharf (für das große Widget).
     * NUR im Hintergrund-Thread aufrufen! Gibt null zurück bei Fehler oder Netzwerkproblem.
     */
    fun render(lat: Double, lng: Double, size: Int = 512, zoom: Int = 17): Bitmap? {
        return try {
            val n = 1 shl zoom
            val px = (lng + 180.0) / 360.0 * n * 256
            val latRad = Math.toRadians(lat)
            val py = (1 - ln(tan(latRad) + 1 / Math.cos(latRad)) / Math.PI) / 2 * n * 256

            val half = size / 2.0
            val left = px - half
            val top = py - half
            val tx0 = floor(left / 256).toInt()
            val ty0 = floor(top / 256).toInt()
            val tx1 = floor((left + size - 1) / 256).toInt()
            val ty1 = floor((top + size - 1) / 256).toInt()

            val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)

            for (tx in tx0..tx1) {
                for (ty in ty0..ty1) {
                    val tile = download("https://tile.openstreetmap.org/$zoom/$tx/$ty.png") ?: return null
                    canvas.drawBitmap(
                        tile,
                        (tx * 256 - left).toFloat(),
                        (ty * 256 - top).toFloat(),
                        null
                    )
                }
            }

            // Mittelpunkt: weißer Kreis, darin Indigo (mit der Bildgröße skaliert)
            val scale = size / 256f
            val c = size / 2f
            val paint = Paint().apply { isAntiAlias = true }
            paint.color = 0xFFFFFFFF.toInt()
            canvas.drawCircle(c, c, 14f * scale, paint)
            paint.color = 0xFF3F51B5.toInt()
            canvas.drawCircle(c, c, 11f * scale, paint)

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
