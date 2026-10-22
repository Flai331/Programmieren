"""Fenster-Programm: Eingangsordner überwachen, an Leerseiten trennen."""
from __future__ import annotations

import json
import queue
import shutil
import threading
import time
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, ttk

from scan_trenner_core import Einstellungen, datei_ist_fertig, sammle_dateien, verarbeite_datei

KONFIG = Path.home() / ".scan_trenner.json"


class App(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("Scan-Trenner – Leerseiten trennen und löschen")
        self.geometry("720x560")
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

        self._aufbauen()
        self.protocol("WM_DELETE_WINDOW", self._schliessen)
        self.after(200, self._log_leeren)

    # ---------- Oberfläche ----------
    def _aufbauen(self) -> None:
        rahmen = ttk.Frame(self, padding=12)
        rahmen.pack(fill="both", expand=True)
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

        knoepfe = ttk.Frame(rahmen)
        knoepfe.grid(row=8, column=0, columnspan=3, sticky="ew", pady=10)
        self.start_btn = ttk.Button(knoepfe, text="▶ Überwachung starten", command=self._starten)
        self.start_btn.pack(side="left")
        self.stop_btn = ttk.Button(knoepfe, text="■ Stoppen", command=self._stoppen, state="disabled")
        self.stop_btn.pack(side="left", padx=6)
        ttk.Button(knoepfe, text="Dateien einmal verarbeiten…", command=self._einmal).pack(side="left")
        self.status = ttk.Label(knoepfe, text="Bereit")
        self.status.pack(side="right")

        self.logfeld = tk.Text(rahmen, height=12, state="disabled", wrap="word")
        self.logfeld.grid(row=9, column=0, columnspan=3, sticky="nsew")
        rahmen.rowconfigure(9, weight=1)

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
        daten = {"eingang": self.eingang.get(), "ausgabe": self.ausgabe.get(), "trennen": self.trennen.get(),
                 "loeschen": self.loeschen.get(), "schwelle": round(self.schwelle.get(), 3)}
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
        self.after(200, self._log_leeren)

    def _verarbeite(self, datei: Path, ausgabe: Path, e: Einstellungen, eingang: Path | None) -> None:
        erg = verarbeite_datei(datei, ausgabe, e)
        if erg.fehler:
            self.log(f"FEHLER {datei.name}: {erg.fehler}")
            return
        self.log(f"{datei.name}: {erg.seiten_gesamt} Seiten, {len(erg.leerseiten)} leer → "
                 f"{len(erg.ausgabedateien)} Dokument(e)")
        if eingang is not None:  # Original nach „erledigt“ verschieben, damit nichts doppelt läuft
            ziel = eingang / "erledigt"
            ziel.mkdir(exist_ok=True)
            name = datei.name if not (ziel / datei.name).exists() else f"{datei.stem}_{int(time.time())}{datei.suffix}"
            shutil.move(str(datei), str(ziel / name))

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
