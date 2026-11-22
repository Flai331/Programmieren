package de.flai.dokubox

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.app.Notification
import java.io.File

/// Installiert ein Update über eine PackageInstaller-Sitzung. Ab Android 12
/// ohne Rückfrage, sobald DokuBox sich einmal selbst aktualisiert hat (dann
/// ist es „Installationsquelle“ seiner selbst – wie der Play Store).
object UpdateInstaller {
    const val CHANNEL = "dokubox_update"

    fun install(ctx: Context, apk: File, silent: Boolean): String {
        if (Build.VERSION.SDK_INT >= 26 && !ctx.packageManager.canRequestPackageInstalls()) {
            if (silent) return "permission"
            ctx.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:${ctx.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            return "permission"
        }
        val installer = ctx.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(ctx.packageName)
        if (Build.VERSION.SDK_INT >= 31) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_NOT_REQUIRED)
        }
        if (Build.VERSION.SDK_INT >= 34) params.setRequestUpdateOwnership(true)
        val id = installer.createSession(params)
        installer.openSession(id).use { session ->
            apk.inputStream().use { input ->
                session.openWrite("base.apk", 0, apk.length()).use { out ->
                    input.copyTo(out)
                    session.fsync(out)
                }
            }
            val status = Intent(ctx, UpdateReceiver::class.java).putExtra("silent", silent)
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0)
            session.commit(PendingIntent.getBroadcast(ctx, id, status, flags).intentSender)
        }
        return "ok"
    }

    fun notify(ctx: Context, id: Int, text: String, intent: Intent?) {
        val nm = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26 && nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Updates", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = PendingIntent.getActivity(ctx, id,
            intent ?: Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else Notification.Builder(ctx)
        nm.notify(id, b.setContentTitle("DokuBox").setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher).setContentIntent(open).setAutoCancel(true).build())
    }
}

/// Rückmeldung der Installation; nach erfolgreichem Update („Paket
/// ersetzt“) eine kurze Benachrichtigung.
class UpdateReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            UpdateInstaller.notify(ctx, 4721, "DokuBox wurde aktualisiert", null)
            return
        }
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, -999)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirm = (if (Build.VERSION.SDK_INT >= 33)
                    intent.getParcelableExtra(Intent.EXTRA_INTENT, Intent::class.java)
                else intent.getParcelableExtra(Intent.EXTRA_INTENT)) ?: return
                confirm.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (intent.getBooleanExtra("silent", false)) {
                    // Im Hintergrund: einmalig bestätigen (danach automatisch).
                    UpdateInstaller.notify(ctx, 4722, "Update bereit – tippen zum Installieren", confirm)
                } else {
                    try { ctx.startActivity(confirm) } catch (_: Exception) {
                        UpdateInstaller.notify(ctx, 4722, "Update bereit – tippen zum Installieren", confirm)
                    }
                }
            }
            PackageInstaller.STATUS_SUCCESS -> {}
            else -> {
                val msg = intent.getStringExtra(PackageInstaller.EXTRA_STATUS_MESSAGE) ?: "unbekannt"
                UpdateInstaller.notify(ctx, 4723, "Update fehlgeschlagen: $msg", null)
            }
        }
    }
}
