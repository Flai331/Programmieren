"""Fenster-Programm: Eingangsordner überwachen, an Leerseiten trennen."""
from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
import tkinter as tk
from datetime import date
from pathlib import Path
from tkinter import filedialog, messagebox, simpledialog, ttk

import rechnungen as rg
from scan_trenner_core import Einstellungen, datei_ist_fertig, sammle_dateien, verarbeite_datei

KONFIG = Path.home() / ".scan_trenner.json"


class App(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Scan-Trenner – Leerseiten trennen, Rechnungen im Blick")
        self.geometry("820x640")
        self.minsize(620, 480)
        self.log_queue: queue.Queue[str] = queue.Queue()
        self.stop_event = threading.Event()
        self.worker: threading.Thread | None = None

        k = self._lade()
        self.eingang = tk.StringVar(value=k.get("eingang", str(Path.home() / "Scans" / "Eingang")))
        self.ausgabe = tk.StringVar(value=k.get("ausgabe", str(Path.home() / "Scans" / "Fertig")))
        self.trennen = tk.BooleanVar(value=k.get("trennen", True))
        self.loeschen = tk.BooleanVar(value=k.get("loeschen", True))
        self.schwelle = tk.DoubleVar(value=k.get("schwelle", 0.3))
        self.rechnungen_an = tk.BooleanVar(value=k.get("rechnungen", True))
        self.vorlauf = tk.IntVar(value=k.get("vorlauf_tage", 3))
        self.nachfassen = tk.IntVar(value=k.get("nachfassen_wochen", 6))
        gewaehlt = set(k.get("stellen", ["Krankenkasse"]))
        self.stellen = {s: tk.BooleanVar(value=s in gewaehlt) for s in rg.ERSTATTUNGSSTELLEN}
        # Schützt rechnungen.json vor gleichzeitigem Schreiben (Überwachung + Knöpfe).
        self.buch_lock = threading.Lock()
        self.buch_geaendert = threading.Event()

        self._aufbauen()
        self.protocol("WM_DELETE_WINDOW", self._schliessen)
        self.after(200, self._log_leeren)
        self.after(1500, self._erinnerungen_pruefen)

    # ---------- Oberfläche ----------
    def _aufbauen(self) -> None:
        self.notebook = ttk.Notebook(self)
        self.notebook.pack(fill="both", expand=True)
        rahmen = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(rahmen, text="Scannen")
        rechnungen = ttk.Frame(self.notebook, padding=12)
        self.notebook.add(rechnungen, text="Rechnungen")
        self._rechnungen_aufbauen(rechnungen)
        rahmen.columnconfigure(1, weight=1)

        ttk.Label(rahmen, text="Eingangsordner (hier legt der Scanner ab):").grid(row=0, column=0, columnspan=3, sticky="w")
        ttk.Entry(rahmen, textvariable=self.eingang).grid(row=1, column=0, columnspan=2, sticky="ew", pady=(2, 8))
        ttk.Button(rahmen, text="Wählen…", command=lambda: self._waehlen(self.eingang)).grid(row=1, column=2, padx=(6, 0), pady=(2, 8))

        ttk.Label(rahmen, text="Ausgabeordner (fertige Dokumente):").grid(row=2, column=0, columnspan=3, sticky="w")
        ttk.Entry(rahmen, textvariable=self.ausgabe).grid(row=3, column=0, columnspan=2, sticky="ew", pady=(2, 8))
        ttk.Button(rahmen, text="Wählen…", command=lambda: self._waehlen(self.ausgabe)).grid(row=3, column=2, padx=(6, 0), pady=(2, 8))

        ttk.Checkbutton(rahmen, text="Bei Leerseiten in einzelne Dokumente trennen", variable=self.trennen).grid(row=4, column=0, columnspan=3, sticky="w")
        ttk.Checkbutton(rahmen, text="Leerseiten löschen", variable=self.loeschen).grid(row=5, column=0, columnspan=3, sticky="w")

        ttk.Label(rahmen, text="Empfindlichkeit:").grid(row=6, column=0, sticky="w", pady=(8, 0))
        skala = ttk.Scale(rahmen, from_=0.05, to=2.0, variable=self.schwelle, command=lambda _v: self._schwelle_text())
        skala.grid(row=6, column=1, sticky="ew", padx=6, pady=(8, 0))
        self.schwelle_label = ttk.Label(rahmen, width=18)
        self.schwelle_label.grid(row=6, column=2, sticky="w", pady=(8, 0))
        self._schwelle_text()
        ttk.Label(rahmen, foreground="#666",
                  text="Niedriger = nur ganz weiße Seiten gelten als leer. Höher = auch Seiten mit Flecken/Rauschen.").grid(
            row=7, column=0, columnspan=3, sticky="w")
        ttk.Checkbutton(rahmen, text="Rechnungen erkennen (Betrag, Fälligkeit, bezahlt/zu bezahlen) "
                        "und Erinnerungen anlegen", variable=self.rechnungen_an).grid(
            row=8, column=0, columnspan=3, sticky="w", pady=(8, 0))

        knoepfe = ttk.Frame(rahmen)
        knoepfe.grid(row=9, column=0, columnspan=3, sticky="ew", pady=10)
        self.start_btn = ttk.Button(knoepfe, text="▶ Überwachung starten", command=self._starten)
        self.start_btn.pack(side="left")
        self.stop_btn = ttk.Button(knoepfe, text="■ Stoppen", command=self._stoppen, state="disabled")
        self.stop_btn.pack(side="left", padx=6)
        ttk.Button(knoepfe, text="Dateien einmal verarbeiten…", command=self._einmal).pack(side="left")
        self.status = ttk.Label(knoepfe, text="Bereit")
        self.status.pack(side="right")

        self.logfeld = tk.Text(rahmen, height=12, state="disabled", wrap="word")
        self.logfeld.grid(row=10, column=0, columnspan=3, sticky="nsew")
        rahmen.rowconfigure(10, weight=1)

    def _rechnungen_aufbauen(self, rahmen: ttk.Frame) -> None:
        rahmen.columnconfigure(0, weight=1)

        einst = ttk.LabelFrame(rahmen, text="Einstellungen", padding=8)
        einst.grid(row=0, column=0, sticky="ew")
        ttk.Label(einst, text="Arztrechnungen einreichen bei:").grid(row=0, column=0, columnspan=3, sticky="w")
        for i, (stelle, var) in enumerate(self.stellen.items()):
            ttk.Checkbutton(einst, text=stelle, variable=var, command=self._speichere).grid(
                row=1 + i // 3, column=i % 3, sticky="w", padx=(0, 12))
        zeile = ttk.Frame(einst)
        zeile.grid(row=5, column=0, columnspan=3, sticky="w", pady=(6, 0))
        ttk.Label(zeile, text="Erinnern").pack(side="left")
        ttk.Spinbox(zeile, from_=0, to=30, width=4, textvariable=self.vorlauf, command=self._speichere).pack(side="left", padx=4)
        ttk.Label(zeile, text="Tage vor Fälligkeit · Erstattung nachfassen nach").pack(side="left")
        ttk.Spinbox(zeile, from_=1, to=26, width=4, textvariable=self.nachfassen, command=self._speichere).pack(side="left", padx=4)
        ttk.Label(zeile, text="Wochen").pack(side="left")

        self.zahl_info = ttk.Label(rahmen, font=("TkDefaultFont", 10, "bold"))
        self.zahl_info.grid(row=1, column=0, sticky="w", pady=(10, 2))
        self.zahl_liste = self._tabelle(rahmen, 2, [("faellig", "Fällig", 90), ("betrag", "Betrag", 90),
                                                     ("status", "Status", 110), ("titel", "Datei", 360)])
        self.zahl_liste.tag_configure("ueberfaellig", foreground="#c62828")
        knoepfe = ttk.Frame(rahmen)
        knoepfe.grid(row=3, column=0, sticky="w", pady=4)
        ttk.Button(knoepfe, text="✓ Bezahlt", command=self._bezahlt).pack(side="left")
        ttk.Button(knoepfe, text="Öffnen", command=lambda: self._oeffnen(self.zahl_liste)).pack(side="left", padx=6)
        ttk.Button(knoepfe, text="Kalendereintrag", command=self._kalender).pack(side="left")
        ttk.Button(knoepfe, text="Datei als Rechnung aufnehmen…", command=self._datei_aufnehmen).pack(side="left", padx=6)

        self.erst_info = ttk.Label(rahmen, font=("TkDefaultFont", 10, "bold"))
        self.erst_info.grid(row=4, column=0, sticky="w", pady=(10, 2))
        self.erst_liste = self._tabelle(rahmen, 5, [("stelle", "Stelle", 150), ("status", "Status", 100),
                                                     ("betrag", "Betrag", 90), ("eingereicht", "Eingereicht", 90),
                                                     ("titel", "Datei", 260)])
        knoepfe2 = ttk.Frame(rahmen)
        knoepfe2.grid(row=6, column=0, sticky="w", pady=4)
        ttk.Button(knoepfe2, text="Eingereicht", command=lambda: self._erstattung(rg.EINGEREICHT)).pack(side="left")
        ttk.Button(knoepfe2, text="Erstattet…", command=lambda: self._erstattung(rg.ERSTATTET)).pack(side="left", padx=6)
        ttk.Button(knoepfe2, text="Abgelehnt", command=lambda: self._erstattung(rg.ABGELEHNT)).pack(side="left")
        ttk.Button(knoepfe2, text="Öffnen", command=lambda: self._oeffnen(self.erst_liste)).pack(side="left", padx=6)
        rahmen.rowconfigure(2, weight=1)
        rahmen.rowconfigure(5, weight=1)
        self.after(300, self._rechnungen_anzeigen)

    def _tabelle(self, rahmen: ttk.Frame, zeile: int, spalten: list[tuple[str, str, int]]) -> ttk.Treeview:
        baum = ttk.Treeview(rahmen, columns=[s[0] for s in spalten], show="headings", height=6, selectmode="browse")
        for sid, titel, breite in spalten:
            baum.heading(sid, text=titel)
            baum.column(sid, width=breite, stretch=sid == "titel")
        baum.grid(row=zeile, column=0, sticky="nsew")
        return baum

    # ---------- Rechnungen ----------
    def _buch(self) -> rg.Rechnungsbuch:
        return rg.Rechnungsbuch.im_ordner(Path(self.ausgabe.get()))

    def _rechnungs_einstellungen(self) -> rg.Rechnungseinstellungen:
        return rg.Rechnungseinstellungen(vorlauf_tage=self._int(self.vorlauf, 3),
                                         nachfassen_wochen=self._int(self.nachfassen, 6),
                                         stellen=[s for s, v in self.stellen.items() if v.get()])

    @staticmethod
    def _int(var: tk.IntVar, standard: int) -> int:
        try:
            return int(var.get())
        except (tk.TclError, ValueError):
            return standard

    def _rechnungen_anzeigen(self) -> None:
        with self.buch_lock:
            buch = self._buch()
        heute = date.today()
        self.zahl_liste.delete(*self.zahl_liste.get_children())
        offen = buch.offene()
        for r in offen:
            self.zahl_liste.insert("", "end", iid=r.id, values=(
                rg._de(r.faellig) or "—", rg.euro(r.betrag_cent), r.status, Path(r.datei).name),
                tags=("ueberfaellig",) if r.ueberfaellig(heute) else ())
        ueber = sum(1 for r in offen if r.ueberfaellig(heute))
        summe = rg.euro(sum(r.betrag_cent or 0 for r in offen)) or "0,00 €"
        self.zahl_info.config(text=f"Zu bezahlen: {len(offen)} Rechnung(en) · {summe}"
                              + (f" · {ueber} überfällig!" if ueber else ""))
        self.erst_liste.delete(*self.erst_liste.get_children())
        erst = buch.offene_erstattungen()
        for r, x in erst:
            self.erst_liste.insert("", "end", iid=f"{r.id}|{x.stelle}", values=(
                x.stelle, x.status, rg.euro(r.betrag_cent), rg._de(x.eingereicht_am) or "—", Path(r.datei).name))
        ausstehend = sum(r.betrag_cent or 0 for r, x in erst if x.status == rg.EINGEREICHT)
        self.erst_info.config(text=f"Erstattungen: {sum(1 for _, x in erst if x.status == rg.EINZUREICHEN)} "
                              f"einzureichen · {rg.euro(ausstehend) or '0,00 €'} ausstehend")
        self.notebook.tab(1, text=f"Rechnungen ({len(offen) + len(erst)})" if offen or erst else "Rechnungen")

    def _auswahl(self, baum: ttk.Treeview) -> str | None:
        sel = baum.selection()
        if not sel:
            messagebox.showinfo("Nichts gewählt", "Bitte zuerst eine Zeile auswählen.")
            return None
        return sel[0]

    def _bezahlt(self) -> None:
        rid = self._auswahl(self.zahl_liste)
        if rid:
            with self.buch_lock:
                self._buch().als_bezahlt(rid)
            self._rechnungen_anzeigen()

    def _erstattung(self, status: str) -> None:
        iid = self._auswahl(self.erst_liste)
        if not iid:
            return
        rid, stelle = iid.split("|", 1)
        cent = None
        if status == rg.ERSTATTET:
            eingabe = simpledialog.askstring("Erstattet", f"Erstatteter Betrag von {stelle} (leer = voll):",
                                             parent=self)
            if eingabe is None:
                return
            cent = rg.euro_lesen(eingabe) if eingabe.strip() else None
            with self.buch_lock:
                r = self._buch().finden(rid)
            if cent is not None and r and r.betrag_cent and cent < r.betrag_cent:
                status = rg.TEILWEISE
        with self.buch_lock:
            self._buch().erstattung_setzen(rid, stelle, status, self._rechnungs_einstellungen().nachfassen_wochen,
                                           erstattet_cent=cent)
        self._rechnungen_anzeigen()

    def _oeffnen(self, baum: ttk.Treeview) -> None:
        iid = self._auswahl(baum)
        if not iid:
            return
        with self.buch_lock:
            r = self._buch().finden(iid.split("|", 1)[0])
        if r:
            self._datei_oeffnen(Path(r.datei))

    @staticmethod
    def _datei_oeffnen(pfad: Path) -> None:
        if sys.platform.startswith("win"):
            os.startfile(str(pfad))  # type: ignore[attr-defined]
        else:
            subprocess.Popen(["open" if sys.platform == "darwin" else "xdg-open", str(pfad)])

    def _kalender(self) -> None:
        rid = self._auswahl(self.zahl_liste)
        if not rid:
            return
        with self.buch_lock:
            r = self._buch().finden(rid)
        if r is None:
            return
        ziel = rg.ics_schreiben(r, Path(self.ausgabe.get()) / "Erinnerungen")
        if ziel is None:
            messagebox.showinfo("Kein Datum", "Für diese Rechnung ist keine Fälligkeit bekannt.")
            return
        self._datei_oeffnen(ziel)  # öffnet Outlook/Kalender zum Übernehmen

    def _datei_aufnehmen(self) -> None:
        datei = filedialog.askopenfilename(title="Rechnung wählen", filetypes=[("PDF", "*.pdf")])
        if not datei:
            return
        e = self._rechnungs_einstellungen()
        with self.buch_lock:
            buch = self._buch()
            r, hinweis = rg.erfasse(Path(datei), buch, e, Path(self.ausgabe.get()) / "Erinnerungen")
            if r is None and messagebox.askyesno(
                    "Nicht erkannt", (hinweis + "\n\n" if hinweis else "")
                    + "Die Datei wurde nicht als Rechnung erkannt. Trotzdem als „zu bezahlen“ aufnehmen?"):
                r = rg.Rechnung(datei=datei, titel=Path(datei).stem, status=rg.ZU_BEZAHLEN)
                buch.hinzufuegen(r)
        if r:
            self.log(f"Rechnung {Path(datei).name}: {rg.kurzbericht(r)}")
        self._rechnungen_anzeigen()

    def _erinnerungen_pruefen(self) -> None:
        try:
            with self.buch_lock:
                texte = self._buch().faellige_erinnerungen()
        except OSError:
            texte = []
        if texte:
            self._rechnungen_anzeigen()
            self.bell()
            self.deiconify()
            self.lift()
            messagebox.showwarning("Erinnerung", "\n\n".join(texte), parent=self)
        self.after(60_000, self._erinnerungen_pruefen)

    def _schwelle_text(self) -> None:
        self.schwelle_label.config(text=f"{self.schwelle.get():.2f} % Tinte")

    def _waehlen(self, var: tk.StringVar) -> None:
        pfad = filedialog.askdirectory(initialdir=var.get() or str(Path.home()))
        if pfad:
            var.set(pfad)

    # ---------- Einstellungen ----------
    def _lade(self) -> dict:
        try:
            return json.loads(KONFIG.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            return {}

    def _speichere(self) -> None:
        re_e = self._rechnungs_einstellungen()
        daten = {"eingang": self.eingang.get(), "ausgabe": self.ausgabe.get(), "trennen": self.trennen.get(),
                 "loeschen": self.loeschen.get(), "schwelle": round(self.schwelle.get(), 3),
                 "rechnungen": self.rechnungen_an.get(), "vorlauf_tage": re_e.vorlauf_tage,
                 "nachfassen_wochen": re_e.nachfassen_wochen, "stellen": re_e.stellen}
        try:
            KONFIG.write_text(json.dumps(daten, indent=2), encoding="utf-8")
        except OSError:
            pass

    def _einstellungen(self) -> Einstellungen:
        return Einstellungen(tinten_schwelle=self.schwelle.get() / 100,
                             trennen=self.trennen.get(), leerseiten_loeschen=self.loeschen.get())

    # ---------- Ablauf ----------
    def log(self, text: str) -> None:
        self.log_queue.put(f"[{time.strftime('%H:%M:%S')}] {text}\n")

    def _log_leeren(self) -> None:
        try:
            while True:
                zeile = self.log_queue.get_nowait()
                self.logfeld.config(state="normal")
                self.logfeld.insert("end", zeile)
                self.logfeld.see("end")
                self.logfeld.config(state="disabled")
        except queue.Empty:
            pass
        if self.buch_geaendert.is_set():
            self.buch_geaendert.clear()
            self._rechnungen_anzeigen()
        self.after(200, self._log_leeren)

    def _verarbeite(self, datei: Path, ausgabe: Path, e: Einstellungen, eingang: Path | None) -> None:
        erg = verarbeite_datei(datei, ausgabe, e)
        if erg.fehler:
            self.log(f"FEHLER {datei.name}: {erg.fehler}")
            return
        self.log(f"{datei.name}: {erg.seiten_gesamt} Seiten, {len(erg.leerseiten)} leer → "
                 f"{len(erg.ausgabedateien)} Dokument(e)")
        if self.rechnungen_an.get():
            self._rechnungen_erfassen(erg.ausgabedateien, ausgabe)
        if eingang is not None:  # Original nach „erledigt“ verschieben, damit nichts doppelt läuft
            ziel = eingang / "erledigt"
            ziel.mkdir(exist_ok=True)
            name = datei.name if not (ziel / datei.name).exists() else f"{datei.stem}_{int(time.time())}{datei.suffix}"
            shutil.move(str(datei), str(ziel / name))

    def _rechnungen_erfassen(self, dateien: list[Path], ausgabe: Path) -> None:
        e = self._rechnungs_einstellungen()
        for pdf in dateien:
            try:
                with self.buch_lock:
                    r, hinweis = rg.erfasse(pdf, rg.Rechnungsbuch.im_ordner(ausgabe), e, ausgabe / "Erinnerungen")
            except Exception as exc:  # Rechnungserkennung darf das Trennen nie stoppen
                self.log(f"Rechnungserkennung {pdf.name} fehlgeschlagen: {exc}")
                continue
            if hinweis:
                self.log(f"Hinweis: {hinweis}")
            if r:
                self.log(f"  → Rechnung {pdf.name}: {rg.kurzbericht(r)}")
                self.buch_geaendert.set()

    def _ueberwachen(self, eingang: Path, ausgabe: Path, e: Einstellungen) -> None:
        gesehen: dict[Path, tuple[int, float]] = {}
        self.log(f"Überwache {eingang}")
        while not self.stop_event.is_set():
            try:
                for f in sammle_dateien(eingang):
                    fertig, gesehen[f] = datei_ist_fertig(f, gesehen.get(f))
                    if fertig:
                        self._verarbeite(f, ausgabe, e, eingang)
                        gesehen.pop(f, None)
            except OSError as exc:
                self.log(f"Ordnerfehler: {exc}")
            self.stop_event.wait(2)
        self.log("Überwachung gestoppt.")

    def _starten(self) -> None:
        eingang, ausgabe = Path(self.eingang.get()), Path(self.ausgabe.get())
        if not eingang.name or not ausgabe.name:
            messagebox.showwarning("Ordner fehlt", "Bitte Eingangs- und Ausgabeordner wählen.")
            return
        if eingang.resolve() == ausgabe.resolve():
            messagebox.showwarning("Ordner gleich", "Eingang und Ausgabe müssen verschiedene Ordner sein.")
            return
        eingang.mkdir(parents=True, exist_ok=True)
        ausgabe.mkdir(parents=True, exist_ok=True)
        self._speichere()
        self.stop_event.clear()
        self.worker = threading.Thread(target=self._ueberwachen, args=(eingang, ausgabe, self._einstellungen()), daemon=True)
        self.worker.start()
        self.start_btn.config(state="disabled")
        self.stop_btn.config(state="normal")
        self.status.config(text="Überwache Ordner …")

    def _stoppen(self) -> None:
        self.stop_event.set()
        self.start_btn.config(state="normal")
        self.stop_btn.config(state="disabled")
        self.status.config(text="Bereit")

    def _einmal(self) -> None:
        dateien = filedialog.askopenfilenames(title="Scans wählen",
                                              filetypes=[("PDF und Bilder", "*.pdf *.jpg *.jpeg *.png *.tif *.tiff *.bmp")])
        if not dateien:
            return
        ausgabe, e = Path(self.ausgabe.get()), self._einstellungen()
        self._speichere()

        def lauf() -> None:
            for d in dateien:
                self._verarbeite(Path(d), ausgabe, e, None)
            self.log("Fertig.")
        threading.Thread(target=lauf, daemon=True).start()

    def _schliessen(self) -> None:
        self.stop_event.set()
        self._speichere()
        self.destroy()


if __name__ == "__main__":
    App().mainloop()
