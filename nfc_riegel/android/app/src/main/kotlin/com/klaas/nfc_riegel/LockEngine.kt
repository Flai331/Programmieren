package com.klaas.nfc_riegel

enum class ScanOutcome {
    LOCKED,
    UNLOCKED,
    /** Freigabe lief, der Scan hat sie beendet — es ist wieder zu. */
    RELOCKED,

    /** Chipsperre ließe sich öffnen, das Profil will aber vorher nach der Dauer gefragt werden. */
    ASK_RELEASE,

    /** Anderer Chip hat übernommen: alte Sperre beendet, neue gestartet. */
    SWITCHED,
    /** Zeitsperre lief bereits, ihr Ende wurde nach hinten geschoben. */
    EXTENDED,
    /** Zeitsperre läuft — nur der Notfall-Code öffnet sie vorzeitig. */
    TIME_LOCK_RUNNING,
    UNKNOWN_TAG,
    NO_TAG_ENROLLED,
    /** Chip zeigt auf ein Profil, das es nicht mehr gibt. */
    NO_PROFILE,
    /** UNTIL-Zeitpunkt liegt in der Vergangenheit. */
    UNTIL_IN_PAST,
}

data class ScanResult(val state: LockState, val outcome: ScanOutcome)

enum class CodeOutcome { UNLOCKED, WRONG, LOCKED_OUT, NOT_SET }

data class CodeResult(val state: LockState, val outcome: CodeOutcome)

enum class StartOutcome {
    STARTED,
    /** Lief bereits, das neue Ende liegt später. */
    EXTENDED,
    /** Lief bereits, das neue Ende liegt nicht später — Zustand unverändert. */
    ALREADY_RUNNING,
    UNTIL_IN_PAST,
    NO_PROFILE,
}

data class StartResult(val state: LockState, val outcome: StartOutcome)

enum class ReleaseOutcome {
    RELEASED,

    /** Keine Chipsperre dieses Profils läuft — es gibt nichts freizugeben. */
    NO_LOCK,
}

data class ReleaseResult(val state: LockState, val outcome: ReleaseOutcome)

/**
 * Alle Zustandsübergänge des Riegels. Kennt nur [LockStore] — keine Android-Klassen,
 * keine Nebenwirkungen. Alarm und Benachrichtigung setzt [LockController] anhand des
 * zurückgegebenen Zustands.
 */
class LockEngine(private val store: LockStore) {

    fun state(): LockState = store.load()

    /**
     * Chip gescannt. Der Modus des Profils entscheidet, welche Spur entsteht:
     * `OPEN` ergibt eine Chipsperre, `TIMER` und `UNTIL` eine Zeitsperre. Alle
     * Chips sind gleich: jeder beendet nur seine eigene Chipsperre. An eine
     * Zeitsperre kommt einzig der Notfall-Code.
     */
    fun onTagScanned(uid: String, now: Long): ScanResult {
        val s = store.load()
        if (s.tags.isEmpty()) return ScanResult(s, ScanOutcome.NO_TAG_ENROLLED)
        val tag = s.tagByUid(uid) ?: return ScanResult(s, ScanOutcome.UNKNOWN_TAG)

        val profile = s.profileById(tag.profileId)
            ?: return ScanResult(s, ScanOutcome.NO_PROFILE)

        if (profile.defaultMode != LockMode.OPEN) {
            val result = startLock(profile.id, now, allowExtend = false)
            return ScanResult(result.state, result.outcome.asScanOutcome())
        }

        val active = activeChipLock(s, now)
        if (active != null && active.profileId == profile.id) {
            // Reihenfolge zählt: erst die laufende Freigabe beenden, dann erst
            // fragen. Andersherum käme mitten in der Freigabe wieder der Dialog,
            // statt dass der Riegel zugeht.
            if (activeRelease(s, now)?.profileId == profile.id) {
                val next = s.copy(release = null)
                store.save(next)
                return ScanResult(next, ScanOutcome.RELOCKED)
            }
            if (profile.timedRelease) return ScanResult(s, ScanOutcome.ASK_RELEASE)
            return ScanResult(clearChipLock(s), ScanOutcome.UNLOCKED)
        }

        val next = assignChipLock(s, profile.id)
        return ScanResult(
            next,
            if (active != null) ScanOutcome.SWITCHED else ScanOutcome.LOCKED,
        )
    }

    private fun StartOutcome.asScanOutcome(): ScanOutcome = when (this) {
        StartOutcome.STARTED -> ScanOutcome.LOCKED
        StartOutcome.EXTENDED -> ScanOutcome.EXTENDED
        StartOutcome.ALREADY_RUNNING -> ScanOutcome.TIME_LOCK_RUNNING
        StartOutcome.UNTIL_IN_PAST -> ScanOutcome.UNTIL_IN_PAST
        StartOutcome.NO_PROFILE -> ScanOutcome.NO_PROFILE
    }

    /**
     * Startet die Sperre, für die das Profil eingerichtet ist — aus der
     * Oberfläche oder durch einen Scan. Der Modus entscheidet die Spur:
     * `OPEN` ergibt eine Chipsperre, `TIMER` und `UNTIL` eine Zeitsperre.
     *
     * Zumachen geht immer ohne Chip. Aufmachen nicht: eine so gestartete
     * Chipsperre endet erst durch einen Scan oder den Notfall-Code. Genau darin liegt der Sinn — der Griff zum Riegel soll
     * leicht sein, der Weg zurück nicht.
     *
     * Bei den Zeitsperren gilt: strenger stellen ist immer erlaubt, verkürzen
     * nie. Ein späteres Ende überschreibt, ein früheres lässt die laufende
     * Sperre in Ruhe.
     *
     * [allowExtend] steht nur der Schaltfläche zu. Beim Scan ist es `false`, damit
     * ein versehentlich vorbeigeführter Chip eine Sperre nicht verdoppelt.
     */
    fun startLock(profileId: String, now: Long, allowExtend: Boolean = true): StartResult {
        val s = store.load()
        val profile = s.profileById(profileId)
            ?: return StartResult(s, StartOutcome.NO_PROFILE)

        val endsAt = when (profile.defaultMode) {
            LockMode.OPEN -> return startChipLock(s, profileId)
            LockMode.TIMER -> now + profile.durationMinutes * 60_000L
            LockMode.UNTIL -> {
                val until = profile.untilAt
                if (until == null || until <= now) {
                    return StartResult(s, StartOutcome.UNTIL_IN_PAST)
                }
                until
            }
        }

        val laufend = s.timeLocks.firstOrNull { it.profileId == profileId && now < it.endsAt }
        if (laufend != null && (!allowExtend || endsAt <= laufend.endsAt)) {
            return StartResult(s, StartOutcome.ALREADY_RUNNING)
        }

        val andere = s.timeLocks.filter { it.profileId != profileId }
        val next = s.copy(
            timeLocks = andere + TimeLock(profileId, profile.defaultMode, endsAt),
        )
        store.save(next)
        return StartResult(next, if (laufend != null) StartOutcome.EXTENDED else StartOutcome.STARTED)
    }

    /**
     * Chipsperre ohne Chip. Läuft schon eine für dasselbe Profil, ändert sich
     * nichts; eine Chipsperre eines anderen Profils wird abgelöst — mehr als
     * eine gibt es nicht.
     */
    private fun startChipLock(s: LockState, profileId: String): StartResult {
        // Ausnahme von „laeuft schon": laeuft fuer dieses Profil eine Freigabe,
        // ist der Riegel gerade offen. Dann ist „Sperren" ein echter Auftrag und
        // beendet sie, statt zu antworten, es laufe ja schon etwas.
        val freigegeben = s.release?.profileId == profileId
        if (s.chipLock?.profileId == profileId && !freigegeben) {
            return StartResult(s, StartOutcome.ALREADY_RUNNING)
        }
        return StartResult(assignChipLock(s, profileId), StartOutcome.STARTED)
    }

    /**
     * Setzt die Chipsperre und räumt dabei jede Freigabe weg. Beides gehört
     * zusammen: eine neue Sperre fängt ohne Freigabe an, sonst hebt eine alte
     * sie sofort wieder auf — die App bestätigte dann eine Sperre, die nicht
     * wirkt. Einziger Weg, eine Chipsperre zu setzen.
     */
    private fun assignChipLock(s: LockState, profileId: String): LockState {
        val next = s.copy(chipLock = ChipLock(profileId), release = null)
        store.save(next)
        return next
    }

    /**
     * Freigabe auf Zeit. Legt die laufende Chipsperre bis [minutes] Minuten in
     * der Zukunft schlafen. Gelöscht wird sie nicht — deshalb sperrt sie danach
     * ohne weiteres Zutun wieder.
     */
    fun startRelease(profileId: String, minutes: Int, now: Long): ReleaseResult {
        val s = store.load()
        if (s.chipLock?.profileId != profileId) {
            return ReleaseResult(s, ReleaseOutcome.NO_LOCK)
        }
        val geklemmt = minutes.coerceIn(MIN_RELEASE_MINUTES, MAX_RELEASE_MINUTES)
        val next = s.copy(release = Release(profileId, now + geklemmt * 60_000L))
        store.save(next)
        return ReleaseResult(next, ReleaseOutcome.RELEASED)
    }

    /** Die Chipsperre. Sie läuft nicht ab — nur ein Scan oder der Code beendet sie. */
    private fun activeChipLock(s: LockState, now: Long): ChipLock? = s.chipLock

    /** Zeitsperren, die jetzt noch gelten. Abgelaufene zählen nicht. */
    private fun activeTimeLocks(s: LockState, now: Long): List<TimeLock> =
        s.timeLocks.filter { now < it.endsAt }

    /** Die laufende Freigabe, oder null. Eine abgelaufene zählt nicht. */
    private fun activeRelease(s: LockState, now: Long): Release? =
        s.release?.takeIf { now < it.endsAt }

    /**
     * Profile, die gerade sperren — über die Chipsperre, eine Zeitsperre oder ein
     * laufendes Terminfenster. Grundlage der Blockliste und aller Wächter.
     *
     * Hier und nur hier wirkt die Freigabe: die Chipsperre bleibt stehen, zählt
     * aber nicht, solange eine Freigabe für ihr Profil läuft.
     */
    private fun lockedProfileIds(s: LockState, now: Long): Set<String> = buildSet {
        val freigabe = activeRelease(s, now)
        activeChipLock(s, now)
            ?.takeIf { it.profileId != freigabe?.profileId }
            ?.let { add(it.profileId) }
        activeTimeLocks(s, now).forEach { add(it.profileId) }
        addAll(CalendarPlanner.lockedProfileIds(s.calendar, now))
    }

    /** Sperrt gerade irgendetwas? Grundlage aller Einstellungswächter. */
    fun hasActiveLock(now: Long): Boolean = lockedProfileIds(store.load(), now).isNotEmpty()

    /**
     * Beendet alles: Chipsperre und sämtliche Zeitsperren. Allein der
     * Notfall-Code kommt hier hin.
     */
    private fun clearAll(s: LockState, now: Long): LockState {
        // Ohne Unterdrückung griffe die Kalendersperre sofort wieder — sie wird ja
        // aus dem Kalender gerechnet, und der Termin läuft noch. Unterdrückt wird
        // bis zum Ende des spätesten laufenden Fensters; das nächste ist unberührt.
        val laufendeFenster = CalendarPlanner.activeWindows(s.calendar, now)
        val bisWann = laufendeFenster.maxOfOrNull { fenster ->
            s.calendar.pinnedEnds[fenster.eventId] ?: fenster.endsAt
        }

        val next = s.copy(
            chipLock = null,
            timeLocks = emptyList(),
            release = null,
            failedAttempts = 0,
            codeLockedUntil = null,
            calendar = if (bisWann == null) s.calendar
            else s.calendar.copy(suppressedUntil = bisWann),
        )
        store.save(next)
        return next
    }

    /**
     * Beendet nur die Chipsperre. Eine Freigabe fällt mit weg — sie war die
     * Aussetzung genau dieser Sperre. Zeitsperren bleiben stehen; ein normaler
     * Chip kommt an sie nicht heran.
     */
    private fun clearChipLock(s: LockState): LockState {
        val next = s.copy(chipLock = null, release = null)
        store.save(next)
        return next
    }

    /**
     * Vom Alarm gerufen. Räumt jede abgelaufene Zeitsperre ab — auch mehrere
     * zugleich — und dazu eine abgelaufene Freigabe. Die Uhrzeit entscheidet,
     * nicht das Feuern des Alarms.
     */
    fun onTimerElapsed(now: Long): LockState {
        val s = store.load()
        val verbleibend = s.timeLocks.filter { now < it.endsAt }
        val freigabe = activeRelease(s, now)

        // Zwei Fragen, die nichts miteinander zu tun haben: ist eine Zeitsperre
        // abgelaufen, und ist die Freigabe abgelaufen? Nur wenn beide Antworten
        // nein lauten, gibt es nichts zu schreiben. Ohne Freigabe steht auf
        // beiden Seiten null, das ist ebenfalls „unveraendert".
        val zeitsperrenUnveraendert = verbleibend.size == s.timeLocks.size
        val freigabeUnveraendert = freigabe == s.release
        if (zeitsperrenUnveraendert && freigabeUnveraendert) return s

        val next = s.copy(timeLocks = verbleibend, release = freigabe)
        store.save(next)
        return next
    }

    /**
     * Nach dem Neustart. OPEN bleibt gesperrt; bei TIMER und UNTIL entscheidet
     * das gespeicherte Ende.
     */
    fun restoreAfterBoot(now: Long): LockState = onTimerElapsed(now)

    /** Notfall-Code aus dem Sperrschirm. Drei Fehlversuche sperren die Eingabe 60 s. */
    fun submitCode(input: String, now: Long): CodeResult {
        val s = store.load()
        val hash = s.codeHash ?: return CodeResult(s, CodeOutcome.NOT_SET)

        val lockedUntil = s.codeLockedUntil
        if (lockedUntil != null && now < lockedUntil) {
            return CodeResult(s, CodeOutcome.LOCKED_OUT)
        }

        val normalized = input.trim().uppercase()
        if (Hashing.sha256(normalized) == hash) {
            return CodeResult(clearAll(s, now), CodeOutcome.UNLOCKED)
        }

        val attempts = s.failedAttempts + 1
        return if (attempts >= MAX_ATTEMPTS) {
            val next = s.copy(failedAttempts = 0, codeLockedUntil = now + LOCKOUT_MILLIS)
            store.save(next)
            CodeResult(next, CodeOutcome.LOCKED_OUT)
        } else {
            val next = s.copy(failedAttempts = attempts, codeLockedUntil = null)
            store.save(next)
            CodeResult(next, CodeOutcome.WRONG)
        }
    }

    /** Vom AccessibilityService bei jedem Fensterwechsel gefragt. */
    fun isBlocked(packageName: String, now: Long): Boolean =
        packageName in blockedPackages(now)

    /**
     * Vereinigung aller aktiven Sperren: Chipsperre und Zeitsperren. Ein Paket ist
     * gesperrt, sobald irgendeine davon es enthält.
     */
    fun blockedPackages(now: Long): Set<String> {
        val s = store.load()
        return lockedProfileIds(s, now)
            .flatMapTo(mutableSetOf()) { s.profileById(it)?.blockedPackages ?: emptySet() }
    }

    /** Legt ein Profil an und gibt es zurück. Immer erlaubt. */
    fun addProfile(name: String): Profile {
        val s = store.load()
        val profile = Profile(id = newId(), name = name)
        store.save(s.copy(profiles = s.profiles + profile))
        return profile
    }

    /**
     * Speichert ein geändertes Profil. Abgelehnt, solange genau dieses Profil
     * sperrt — gleich ob über die Chipsperre oder eine Zeitsperre. Andere Profile
     * bleiben bearbeitbar.
     */
    fun updateProfile(profile: Profile, now: Long): Boolean {
        val s = store.load()
        if (profile.id in lockedProfileIds(s, now)) return false
        if (s.profileById(profile.id) == null) return false
        store.save(s.copy(profiles = s.profiles.map { if (it.id == profile.id) profile else it }))
        return true
    }

    /**
     * Löscht ein Profil. Das letzte bleibt bestehen, ein sperrendes ebenfalls.
     * Zugeordnete Chips ziehen auf das erste verbleibende Profil.
     */
    fun deleteProfile(id: String, now: Long): Boolean {
        val s = store.load()
        if (s.profiles.size <= 1) return false
        if (id in lockedProfileIds(s, now)) return false
        val remaining = s.profiles.filterNot { it.id == id }
        val fallback = remaining.first().id
        store.save(
            s.copy(
                profiles = remaining,
                tags = s.tags.map { if (it.profileId == id) it.copy(profileId = fallback) else it },
            )
        )
        return true
    }

    /**
     * Chip anlernen oder einen bekannten aktualisieren. Während jeder Sperre
     * abgelehnt — sonst läge man sich mitten in der Sperre einen neuen Schlüssel an.
     */
    fun enrollTag(
        uid: String,
        label: String,
        profileId: String,
        now: Long,
    ): Boolean {
        val s = store.load()
        if (lockedProfileIds(s, now).isNotEmpty()) return false
        val binding = TagBinding(uid, label, profileId)
        val existing = s.tagByUid(uid)
        val tags = if (existing == null) s.tags + binding
        else s.tags.map { if (it.uid.equals(uid, ignoreCase = true)) binding else it }
        store.save(s.copy(tags = tags))
        return true
    }

    fun deleteTag(uid: String, now: Long): Boolean {
        val s = store.load()
        if (lockedProfileIds(s, now).isNotEmpty()) return false
        store.save(s.copy(tags = s.tags.filterNot { it.uid.equals(uid, ignoreCase = true) }))
        return true
    }

    /**
     * Erzeugt den Notfall-Code, speichert nur dessen Hash und gibt ihn einmalig
     * zurück. Während jeder Sperre abgelehnt — sonst wäre der Notausgang jederzeit
     * neu ausstellbar.
     */
    fun generateCode(now: Long): String? {
        val s = store.load()
        if (lockedProfileIds(s, now).isNotEmpty()) return null
        val code = (1..8).map { CODE_ALPHABET.random() }.joinToString("")
        store.save(s.copy(codeHash = Hashing.sha256(code)))
        return code
    }

    private fun newId(): String =
        System.currentTimeMillis().toString(36) + (0..999).random().toString(36)

    /**
     * Legt frisch eingelesene Terminfenster ab. Nagelt dabei die Enden der
     * Fenster fest, deren Profil [Profile.pinCalendarEnd] gesetzt hat, und räumt
     * vergangene Nägel weg.
     */
    fun updateWindows(windows: List<CalendarWindow>, now: Long): LockState {
        val s = store.load()
        val genagelt = CalendarPlanner.prunePins(s.calendar, now)

        // Ein festgenageltes Fenster bleibt im Zwischenspeicher, auch wenn sein
        // Termin aus dem Kalender verschwunden ist. Ohne das verlöre es sein
        // Profil und sperrte nichts mehr — also genau das, wogegen das
        // Festnageln gedacht ist.
        val frisch = windows.map { it.eventId }.toSet()
        val ueberlebende = s.calendar.cachedWindows.filter {
            it.eventId in genagelt && it.eventId !in frisch
        }

        val mitFenstern = s.calendar.copy(
            cachedWindows = windows + ueberlebende,
            windowsFetchedAt = now,
            pinnedEnds = genagelt,
        )
        val neueNaegel = CalendarPlanner.pinsToAdd(mitFenstern, s.profiles, now)
        val next = s.copy(
            calendar = mitFenstern.copy(pinnedEnds = mitFenstern.pinnedEnds + neueNaegel),
        )
        store.save(next)
        return next
    }

    /**
     * Speichert Hauptschalter und Stichwort — das, was für alle Profile gilt.
     * Welche Kalender sperren, steht an den Profilen. Der Zwischenspeicher
     * bleibt stehen, er wird gleich darauf ohnehin neu eingelesen.
     */
    fun updateCalendarSettings(enabled: Boolean, keywordMarker: String): LockState {
        val s = store.load()
        val next = s.copy(
            calendar = s.calendar.copy(enabled = enabled, keywordMarker = keywordMarker),
        )
        store.save(next)
        return next
    }

    /** Laufende Terminfenster, für Anzeige und Diagnose. */
    fun activeCalendarWindows(now: Long): List<CalendarWindow> =
        CalendarPlanner.activeWindows(store.load().calendar, now)

    companion object {
        const val MAX_ATTEMPTS = 3
        const val LOCKOUT_MILLIS = 60_000L
        /** Ohne 0/O und 1/I — der Code wird abgeschrieben. */
        const val CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        /** Kürzer als eine Minute ist keine Freigabe, länger als vier Stunden keine kurze. */
        const val MIN_RELEASE_MINUTES = 1
        const val MAX_RELEASE_MINUTES = 240
    }
}
