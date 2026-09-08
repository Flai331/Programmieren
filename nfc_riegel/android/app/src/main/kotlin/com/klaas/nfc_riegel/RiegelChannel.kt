package com.klaas.nfc_riegel

import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/** Einzige Schnittstelle zwischen Flutter und der nativen Sperrmechanik. */
class RiegelChannel(private val activity: Activity) {

    private val controller = LockController(activity)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getState" -> result.success(stateMap())

                "addProfile" -> {
                    val name = call.argument<String>("name") ?: "Neues Profil"
                    result.success(controller.engine.addProfile(name).id)
                }

                "updateProfile" -> {
                    val profile = Profile(
                        id = call.argument<String>("id") ?: "",
                        name = call.argument<String>("name") ?: "",
                        blockedPackages = call.argument<List<String>>("blockedPackages")
                            ?.toSet() ?: emptySet(),
                        defaultMode = runCatching {
                            LockMode.valueOf(call.argument<String>("defaultMode") ?: "TIMER")
                        }.getOrDefault(LockMode.TIMER),
                        durationMinutes = call.argument<Int>("durationMinutes") ?: 60,
                        untilAt = call.argument<Long>("untilAt"),
                        pinCalendarEnd = call.argument<Boolean>("pinCalendarEnd") ?: false,
                        timedRelease = call.argument<Boolean>("timedRelease") ?: false,
                        pause = PauseSettings(
                            enabled = call.argument<Boolean>("pauseEnabled") ?: false,
                            stepMinutes = call.argument<Int>("pauseStepMinutes") ?: 15,
                            baseSeconds = call.argument<Int>("pauseBaseSeconds") ?: 5,
                            resetMinutes = call.argument<Int>("pauseResetMinutes") ?: 15,
                        ),
                        quiet = QuietSettings(
                            enabled = call.argument<Boolean>("quietEnabled") ?: false,
                            scope = runCatching {
                                QuietScope.valueOf(call.argument<String>("quietScope") ?: "ALLE")
                            }.getOrDefault(QuietScope.ALLE),
                            // Normalisiert wird hier, damit im Speicher nur
                            // Ziffern landen — die Oberfläche darf schicken, was
                            // in den Kontakten steht.
                            numbers = call.argument<List<String>>("quietNumbers")
                                ?.map { PhoneNumbers.normalize(it) }
                                ?.filter { it.isNotEmpty() }
                                ?.toSet()
                                ?: emptySet(),
                            afterEventMinutes = call.argument<Int>("quietAfterEventMinutes") ?: 0,
                            whileLocked = call.argument<Boolean>("quietWhileLocked") ?: true,
                            schedules = wochenplaene(call.argument("quietSchedules")),
                            ringer = runCatching {
                                RingerMode.valueOf(
                                    call.argument<String>("quietRinger") ?: "UNVERAENDERT",
                                )
                            }.getOrDefault(RingerMode.UNVERAENDERT),
                        ),
                    )
                    result.success(
                        controller.updateProfile(profile, System.currentTimeMillis())
                    )
                }

                "deleteProfile" ->
                    result.success(
                        controller.deleteProfile(
                            call.argument<String>("id") ?: "",
                            System.currentTimeMillis(),
                        )
                    )

                "deleteTag" ->
                    result.success(
                        controller.engine.deleteTag(
                            call.argument<String>("uid") ?: "",
                            System.currentTimeMillis(),
                        )
                    )

                "generateCode" ->
                    result.success(controller.engine.generateCode(System.currentTimeMillis()))

                "startTagEnrollment" -> {
                    val intent = Intent(activity, TagWriteActivity::class.java)
                        .putExtra(TagWriteActivity.EXTRA_LABEL, call.argument<String>("label"))
                        .putExtra(TagWriteActivity.EXTRA_PROFILE_ID, call.argument<String>("profileId"))
                    activity.startActivity(intent)
                    result.success(true)
                }

                "isAccessibilityEnabled" -> result.success(isAccessibilityEnabled())

                "openAccessibilitySettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(true)
                }

                /**
                 * Gibt das Administratorrecht zurueck, damit sich die App
                 * normal deinstallieren laesst. Waehrend einer Sperre
                 * verweigert - sonst waere der Umgehungsschutz eine Attrappe,
                 * die man im Sperrmoment einfach abstellt.
                 */
                "releaseAdmin" -> {
                    if (controller.engine.hasActiveLock(System.currentTimeMillis())) {
                        result.success(false)
                    } else {
                        devicePolicyManager().removeActiveAdmin(adminComponent())
                        result.success(true)
                    }
                }

                "isAdminActive" -> result.success(devicePolicyManager().isAdminActive(adminComponent()))

                "requestAdmin" -> {
                    val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN)
                        .putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
                        .putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "Verhindert, dass der Riegel während einer Sperre deinstalliert wird.",
                        )
                    activity.startActivity(intent)
                    result.success(true)
                }

                "contacts" -> result.success(
                    ContactSource(activity).contacts().map {
                        mapOf("name" to it.name, "number" to it.number)
                    }
                )

                "contactsGranted" -> result.success(ContactPermission.granted(activity))

                "requestContacts" -> {
                    if (ContactPermission.granted(activity)) {
                        result.success(true)
                    } else {
                        ContactPermission.request(activity)
                        // Wie beim Kalender: die Antwort kommt asynchron ins
                        // System zurück, die Oberfläche fragt danach neu.
                        result.success(false)
                    }
                }

                "callScreeningAvailable" -> result.success(CallScreening.available(activity))

                "callScreeningHeld" -> result.success(CallScreening.held(activity))

                "requestCallScreening" -> result.success(CallScreening.request(activity))

                "dndGranted" -> result.success(QuietDnd(activity).granted())

                "openDndSettings" -> {
                    QuietDnd(activity).openSettings()
                    result.success(true)
                }

                "getDiagnostics" -> {
                    val map = Diagnostics.summarize(
                        controller.engine.state(),
                        System.currentTimeMillis(),
                    ).toMutableMap()
                    map["Bedienungshilfe"] = if (isAccessibilityEnabled()) "an" else "AUS"
                    map["Geräteadministrator"] =
                        if (devicePolicyManager().isAdminActive(adminComponent())) "an" else "aus"
                    map["Benachrichtigungen"] = notificationPermissionState()
                    map["Anruffilter"] = if (CallScreening.held(activity)) "an" else "aus"
                    map["Bitte nicht stören"] =
                        if (QuietDnd(activity).granted()) "erlaubt" else "VERWEIGERT"
                    map["Ruhe"] = if (
                        QuietPlanner.isQuiet(controller.engine.state(), System.currentTimeMillis())
                    ) {
                        "aktiv"
                    } else {
                        "aus"
                    }
                    map["Nutzungsdaten"] =
                        if (AndroidUsageSource(activity).granted()) "erlaubt" else "VERWEIGERT"
                    map["Android"] = "SDK ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})"
                    result.success(map)
                }

                "startLock" -> {
                    val outcome = controller.startLock(
                        call.argument<String>("profileId") ?: "",
                    )
                    result.success(outcome.name)
                }

                "usageAccessGranted" ->
                    result.success(AndroidUsageSource(activity).granted())

                "openUsageAccessSettings" -> {
                    activity.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(true)
                }

                "screenTimeToday" -> result.success(screenTimeToday())

                "launchableApps" -> result.success(launchableApps())

                "deviceCalendars" ->
                    result.success(
                        ContentCalendarSource(activity).calendars().map {
                            mapOf("id" to it.id, "name" to it.name, "account" to it.account)
                        }
                    )

                "requestCalendarPermission" -> {
                    if (CalendarPermission.granted(activity)) {
                        result.success(true)
                    } else {
                        CalendarPermission.request(activity)
                        // Die Antwort kommt asynchron ins System zurück; die
                        // Oberfläche fragt den Zustand nach dem Dialog neu ab.
                        result.success(false)
                    }
                }

                "setCalendarSettings" -> {
                    val roh = call.argument<Map<String, Map<String, String>>>("calendarRules")
                        ?: emptyMap()
                    val regeln = roh.mapValues { (_, eintrag) ->
                        CalendarRule(
                            profileId = eintrag["profileId"] ?: "",
                            match = runCatching {
                                CalendarMatch.valueOf(eintrag["match"] ?: "ALL")
                            }.getOrDefault(CalendarMatch.ALL),
                        )
                    }.filterValues { it.profileId.isNotEmpty() }

                    controller.engine.updateCalendarSettings(
                        enabled = call.argument<Boolean>("enabled") ?: false,
                        calendarRules = regeln,
                        keywordMarker = call.argument<String>("keywordMarker") ?: "[Riegel]",
                        keywordProfileId = call.argument<String>("keywordProfileId"),
                        keywordCalendarIds =
                            call.argument<List<String>>("keywordCalendarIds")?.toSet()
                                ?: emptySet(),
                    )
                    controller.refreshCalendar()
                    result.success(true)
                }

                "refreshCalendar" -> {
                    controller.refreshCalendar()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    /**
     * Wochenpläne aus Flutter. Je Plan `days` mit Zahlen nach
     * `Calendar.DAY_OF_WEEK` (Sonntag = 1), dazu Beginn und Ende als Minuten
     * seit Mitternacht. Unvollständige Einträge fallen weg, statt den ganzen
     * Aufruf scheitern zu lassen.
     */
    private fun wochenplaene(roh: List<Map<String, Any?>>?): List<QuietSchedule> =
        roh.orEmpty().mapNotNull { eintrag ->
            val tage = (eintrag["days"] as? List<*>)
                ?.mapNotNull { (it as? Number)?.toInt() }
                ?.toSet()
                ?: return@mapNotNull null
            if (tage.isEmpty()) return@mapNotNull null
            QuietSchedule(
                days = tage,
                startMinute = (eintrag["startMinute"] as? Number)?.toInt()
                    ?: return@mapNotNull null,
                endMinute = (eintrag["endMinute"] as? Number)?.toInt()
                    ?: return@mapNotNull null,
            )
        }

    private fun stateMap(): Map<String, Any?> {
        val s = controller.engine.state()
        val now = System.currentTimeMillis()
        return mapOf(
            "profiles" to s.profiles.map { p ->
                mapOf(
                    "id" to p.id,
                    "name" to p.name,
                    "blockedPackages" to p.blockedPackages.toList(),
                    "defaultMode" to p.defaultMode.name,
                    "durationMinutes" to p.durationMinutes,
                    "untilAt" to p.untilAt,
                    "pinCalendarEnd" to p.pinCalendarEnd,
                    "timedRelease" to p.timedRelease,
                    "pauseEnabled" to p.pause.enabled,
                    "pauseStepMinutes" to p.pause.stepMinutes,
                    "pauseBaseSeconds" to p.pause.baseSeconds,
                    "pauseResetMinutes" to p.pause.resetMinutes,
                    "quietEnabled" to p.quiet.enabled,
                    "quietScope" to p.quiet.scope.name,
                    "quietNumbers" to p.quiet.numbers.toList(),
                    "quietAfterEventMinutes" to p.quiet.afterEventMinutes,
                    "quietWhileLocked" to p.quiet.whileLocked,
                    "quietSchedules" to p.quiet.schedules.map { plan ->
                        mapOf(
                            "days" to plan.days.toList(),
                            "startMinute" to plan.startMinute,
                            "endMinute" to plan.endMinute,
                        )
                    },
                    "quietRinger" to p.quiet.ringer.name,
                )
            },
            "tags" to s.tags.map { t ->
                mapOf(
                    "uid" to t.uid,
                    "label" to t.label,
                    "profileId" to t.profileId,
                )
            },
            "chipLock" to s.chipLock?.let { mapOf("profileId" to it.profileId) },
            // Abgelaufene Freigaben gehen gar nicht erst raus — die Oberfläche
            // soll die Uhrzeitrechnung nicht ein zweites Mal machen.
            "release" to s.release?.takeIf { now < it.endsAt }?.let {
                mapOf("profileId" to it.profileId, "endsAt" to it.endsAt)
            },
            // Damit die Oberfläche zeigen kann, dass gerade still gestellt ist,
            // ohne die Fensterrechnung noch einmal in Dart nachzubauen.
            "quietNow" to QuietPlanner.isQuiet(s, now),
            "timeLocks" to s.timeLocks.filter { now < it.endsAt }.map { l ->
                mapOf(
                    "profileId" to l.profileId,
                    "mode" to l.mode.name,
                    "endsAt" to l.endsAt,
                )
            },
            "calendar" to mapOf(
                "enabled" to s.calendar.enabled,
                // Als Karte von Kalender-ID auf eine kleine Karte — der
                // MethodChannel überträgt keine eigenen Typen.
                "calendarRules" to s.calendar.calendarRules.mapValues { (_, regel) ->
                    mapOf(
                        "profileId" to regel.profileId,
                        "match" to regel.match.name,
                    )
                },
                "keywordMarker" to s.calendar.keywordMarker,
                "keywordProfileId" to s.calendar.keywordProfileId,
                "keywordCalendarIds" to s.calendar.keywordCalendarIds.toList(),
                "permissionGranted" to CalendarPermission.granted(activity),
                "windows" to s.calendar.cachedWindows
                    .sortedBy { it.startsAt }
                    .take(3)
                    .map { windowMap(it) },
                "activeWindows" to controller.engine.activeCalendarWindows(now)
                    .map { windowMap(it) },
            ),
            "hasCode" to (s.codeHash != null),
        )
    }

    private fun windowMap(fenster: CalendarWindow): Map<String, Any?> = mapOf(
        "eventId" to fenster.eventId,
        "title" to fenster.title,
        "startsAt" to fenster.startsAt,
        "endsAt" to fenster.endsAt,
        "profileId" to fenster.profileId,
    )

    /**
     * Tagesnutzung ab lokaler Mitternacht, absteigend sortiert.
     *
     * Die Namen kommen aus [launchableApps] — das filtert zugleich zweierlei
     * heraus: Hintergrunddienste ohne Startsymbol, die keine „benutzte App"
     * sind, und Riegel selbst. Wer die Screenzeit ansieht, erzeugt dabei
     * Screenzeit; diese Zahl anzuzeigen wäre Rauschen.
     */
    private fun screenTimeToday(): List<Map<String, Any>> {
        val quelle = AndroidUsageSource(activity)
        if (!quelle.granted()) return emptyList()

        val jetzt = System.currentTimeMillis()
        val beginn = ScreenTimeCalculator.startOfDay(jetzt)
        val summen = ScreenTimeCalculator.totals(quelle.events(beginn, jetzt), beginn, jetzt)
        val namen = launchableApps().associate {
            it.getValue("packageName") to it.getValue("name")
        }

        return summen.mapNotNull { (paket, millis) ->
            val name = namen[paket] ?: return@mapNotNull null
            mapOf<String, Any>("packageName" to paket, "name" to name, "millis" to millis)
        }.sortedByDescending { it["millis"] as Long }
    }

    /**
     * Apps, die im Starter auftauchen. Bewusst **nicht** „alles außer
     * Systemapps": Chrome, YouTube und Gmail sind auf Pixel und Samsung
     * vorinstalliert und damit Systemapps — und genau die will man sperren.
     * Umgekehrt hat kein Hintergrunddienst ein Startsymbol, die Liste bleibt
     * also kurz.
     *
     * Riegel selbst fehlt: wer ihn sperrt, kommt an keine Einstellung mehr.
     */
    private fun launchableApps(): List<Map<String, String>> {
        val pm = activity.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val treffer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.queryIntentActivities(intent, PackageManager.ResolveInfoFlags.of(0L))
        } else {
            @Suppress("DEPRECATION")
            pm.queryIntentActivities(intent, 0)
        }
        return treffer
            .map { it.activityInfo.applicationInfo }
            .filter { it.packageName != activity.packageName }
            .distinctBy { it.packageName }
            .map {
                mapOf(
                    "name" to pm.getApplicationLabel(it).toString(),
                    "packageName" to it.packageName,
                )
            }
            .sortedBy { it.getValue("name").lowercase() }
    }

    private fun devicePolicyManager() =
        activity.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun adminComponent() = ComponentName(activity, UninstallAdmin::class.java)

    private fun isAccessibilityEnabled(): Boolean {
        val service = ComponentName(activity, BlockerService::class.java)
        val enabled = Settings.Secure.getString(
            activity.contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES,
        ) ?: ""
        return enabled.split(':').any {
            it.equals(service.flattenToString(), ignoreCase = true) ||
                it.equals(service.flattenToShortString(), ignoreCase = true)
        }
    }

    /**
     * Seit Android 13 ist POST_NOTIFICATIONS eine Laufzeit-Berechtigung. Fehlt sie,
     * verschwindet die Sperr-Benachrichtigung lautlos — im Bericht muss das stehen.
     */
    private fun notificationPermissionState(): String =
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            "nicht nötig"
        } else if (
            activity.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            "erlaubt"
        } else {
            "VERWEIGERT"
        }

    companion object {
        const val CHANNEL = "com.klaas.nfc_riegel/riegel"
    }
}
