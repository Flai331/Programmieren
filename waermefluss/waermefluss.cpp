/*
 * ============================================================================
 *  WÄRMEFLUSS-RECHNER
 * ============================================================================
 *
 *  Vollständiger Konsolen-Rechner für stationäre Wärmeleitung, Wärmeübergang
 *  und Heizkosten. Grundlage ist das Fourier'sche Wärmeleitungsgesetz sowie
 *  die Wärmeübergangsberechnung nach DIN EN ISO 6946.
 *
 *  Berechnungsmodi:
 *    1) Einfache (homogene) Wand            q = λ·ΔT/d ,  Q = q·A
 *    2) Mehrschichtige Verbundwand          R' = Σ d_i/λ_i  + Temperaturprofil
 *    3) Wärmestromdichte aus Gradient       q = -λ·(dT/dx)
 *    4) Wand mit Wärmeübergang (U-Wert)     U = 1/(Rsi + Σd/λ + Rse), DIN 6946
 *                                           inkl. Oberflächen­temperaturen und
 *                                           Tauwasser-Check (Magnus-Formel)
 *    5) Rohr / Zylinder (radial)            Q = 2π·λ·L·ΔT / ln(ra/ri)
 *    6) Energie & Heizkosten über Zeit      E = Q·t ,  Kosten = E·Preis
 *    7) Materialdatenbank anzeigen
 *    8) Protokoll als Datei exportieren
 *
 *  Jede Berechnung wird automatisch in einem Protokoll gesammelt, das als
 *  Textdatei exportiert werden kann.
 *
 *  Kompilieren:  g++ -std=c++17 -O2 -o waermefluss waermefluss.cpp
 * ============================================================================
 */

#include <iostream>
#include <iomanip>
#include <vector>
#include <string>
#include <limits>
#include <cmath>
#include <sstream>
#include <fstream>
#include <ctime>

// Unter Windows: Konsole auf UTF-8 stellen, damit Umlaute und Sonderzeichen
// (λ, °C, ₁₂ …) korrekt angezeigt werden. Unter Linux wird dieser Block
// vom Präprozessor übersprungen.
#ifdef _WIN32
#include <windows.h>
#endif

// ─── Datenstrukturen ─────────────────────────────────────────────────────────

struct Material {
    std::string name;
    double      lambda;     // Wärmeleitfähigkeit [W/(m·K)]
    std::string kategorie;
};

struct Schicht {
    Material material;
    double   dicke;         // [m]
};

// Kreiszahl π (portabel; PI ist keine Standard-C++-Konstante und fehlt z. B.
// bei MinGW/Windows ohne zusätzliche Defines).
constexpr double PI = 3.14159265358979323846;

// ─── Materialdatenbank ───────────────────────────────────────────────────────
// Richtwerte für λ in W/(m·K) (Bemessungswerte, gerundet).

const std::vector<Material> MATERIALIEN = {
    {"Stahlbeton",        2.30, "Massivbaustoffe"},
    {"Beton",             2.10, "Massivbaustoffe"},
    {"Kalksandstein",     1.00, "Massivbaustoffe"},
    {"Vollziegel",        0.80, "Massivbaustoffe"},
    {"Hochlochziegel",    0.40, "Massivbaustoffe"},
    {"Porenbeton",        0.14, "Massivbaustoffe"},
    {"Klinker",           0.96, "Massivbaustoffe"},
    {"Kalkzementputz",    1.00, "Putze & Platten"},
    {"Gipskartonplatte",  0.25, "Putze & Platten"},
    {"Holz (Fichte)",     0.13, "Holz"},
    {"Holz (Eiche)",      0.20, "Holz"},
    {"Holzfaserplatte",   0.045,"Dämmstoffe"},
    {"Mineralwolle",      0.040,"Dämmstoffe"},
    {"Glaswolle",         0.035,"Dämmstoffe"},
    {"Steinwolle",        0.040,"Dämmstoffe"},
    {"EPS (Styropor)",    0.035,"Dämmstoffe"},
    {"XPS",               0.032,"Dämmstoffe"},
    {"PUR-Hartschaum",    0.025,"Dämmstoffe"},
    {"Stahl",            50.00, "Metalle"},
    {"Edelstahl",        15.00, "Metalle"},
    {"Aluminium",       160.00, "Metalle"},
    {"Kupfer",          380.00, "Metalle"},
    {"Fensterglas",       1.00, "Sonstige"},
    {"Luft (ruhend)",     0.026,"Sonstige"},
    {"Wasser",            0.60, "Sonstige"},
    {"Erdreich (feucht)", 1.50, "Sonstige"},
};

// ─── Globaler Zustand: Protokoll & letzter Wärmestrom ────────────────────────

std::ostringstream gProtokoll;     // gesammelte Ergebnisse aller Berechnungen
int                gAnzahl     = 0;
double             gLetzterQ   = 0.0;   // zuletzt berechneter Wärmestrom [W]
bool               gHabeQ      = false;

// ─── Allgemeine Hilfsfunktionen ──────────────────────────────────────────────

void trennlinie(char c = '-', int breite = 60) {
    std::cout << std::string(breite, c) << "\n";
}

// Liest eine Gleitkommazahl; akzeptiert nur Werte echt größer als min_val.
double eingabe_double(const std::string& prompt, double min_val = -1e18) {
    double wert;
    while (true) {
        std::cout << prompt;
        if (std::cin >> wert && wert > min_val) return wert;
        std::cout << "  Ungültige Eingabe. Bitte erneut versuchen.\n";
        std::cin.clear();
        std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    }
}

// Liest eine Ganzzahl im Bereich [min_val, max_val].
int eingabe_int(const std::string& prompt, int min_val = 1, int max_val = 999) {
    int wert;
    while (true) {
        std::cout << prompt;
        if (std::cin >> wert && wert >= min_val && wert <= max_val) return wert;
        std::cout << "  Ungültige Eingabe. Bitte Zahl zwischen " << min_val
                  << " und " << max_val << " eingeben.\n";
        std::cin.clear();
        std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    }
}

// Einfache Ja/Nein-Abfrage (Vorgabe bei leerer Eingabe konfigurierbar).
bool eingabe_janein(const std::string& prompt, bool vorgabe = true) {
    std::cout << prompt;
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::string s;
    std::getline(std::cin, s);
    if (s.empty()) return vorgabe;
    char c = (char)std::tolower((unsigned char)s[0]);
    return (c == 'j' || c == 'y');
}

// Liest eine ganze Zeile (z. B. Dateiname). Vorheriger Aufruf nutzte >>,
// daher wird der verbliebene Zeilenumbruch zuvor verworfen.
std::string eingabe_zeile(const std::string& prompt, const std::string& vorgabe = "") {
    std::cout << prompt;
    std::cin.ignore(std::numeric_limits<std::streamsize>::max(), '\n');
    std::string s;
    std::getline(std::cin, s);
    if (s.empty()) return vorgabe;
    return s;
}

std::string zeitstempel() {
    std::time_t t = std::time(nullptr);
    char buf[64];
    std::strftime(buf, sizeof(buf), "%d.%m.%Y %H:%M:%S", std::localtime(&t));
    return std::string(buf);
}

// ─── Protokoll-Verwaltung ────────────────────────────────────────────────────

// Gibt einen Ergebnisblock auf der Konsole aus UND hängt ihn ans Protokoll an.
void ausgeben(const std::string& titel, const std::string& block) {
    std::cout << block;
    gAnzahl++;
    gProtokoll << "===== Berechnung " << gAnzahl << ": " << titel
               << "  (" << zeitstempel() << ") =====\n";
    gProtokoll << block << "\n";
}

void protokoll_exportieren() {
    trennlinie('=');
    std::cout << "  PROTOKOLL EXPORTIEREN\n";
    trennlinie('=');

    if (gAnzahl == 0) {
        std::cout << "\n  Noch keine Berechnungen vorhanden – nichts zu exportieren.\n\n";
        return;
    }

    std::string name = eingabe_zeile(
        "\n  Dateiname [waermefluss_protokoll.txt]: ", "waermefluss_protokoll.txt");

    std::ofstream f(name);
    if (!f) {
        std::cout << "  Fehler: Datei \"" << name << "\" konnte nicht geschrieben werden.\n\n";
        return;
    }

    f << "============================================================\n";
    f << " WÄRMEFLUSS-RECHNER – Ergebnisprotokoll\n";
    f << " Erstellt: " << zeitstempel() << "\n";
    f << " Anzahl Berechnungen: " << gAnzahl << "\n";
    f << "============================================================\n\n";
    f << gProtokoll.str();
    f.close();

    std::cout << "\n  " << gAnzahl << " Berechnung(en) gespeichert in: " << name << "\n\n";
}

// ─── Materialauswahl ─────────────────────────────────────────────────────────

void materialliste_anzeigen() {
    std::cout << "\n  Verfügbare Materialien:\n";
    for (size_t i = 0; i < MATERIALIEN.size(); ++i) {
        std::cout << "  [" << std::setw(2) << (i + 1) << "] "
                  << std::left << std::setw(20) << MATERIALIEN[i].name
                  << "λ = " << std::right << std::setw(7) << std::fixed
                  << std::setprecision(3) << MATERIALIEN[i].lambda << " W/(m·K)\n";
    }
    std::cout << "  [" << (MATERIALIEN.size() + 1) << "] Eigenen λ-Wert eingeben\n";
}

Material material_auswaehlen() {
    materialliste_anzeigen();
    int wahl = eingabe_int("\n  Material-Auswahl: ", 1, (int)MATERIALIEN.size() + 1);
    if (wahl <= (int)MATERIALIEN.size())
        return MATERIALIEN[wahl - 1];

    Material m;
    m.name      = eingabe_zeile("  Materialname: ", "Eigenes Material");
    m.lambda    = eingabe_double("  Wärmeleitfähigkeit λ [W/(m·K)]: ", 0.0);
    m.kategorie = "Benutzerdefiniert";
    return m;
}

// Liest n Schichten (Material + Dicke in Metern) ein.
std::vector<Schicht> schichten_einlesen() {
    int n = eingabe_int("\n  Anzahl der Schichten: ", 1, 30);
    std::vector<Schicht> schichten(n);
    for (int i = 0; i < n; ++i) {
        std::cout << "\n  --- Schicht " << (i + 1) << " von " << n << " ---\n";
        schichten[i].material = material_auswaehlen();
        schichten[i].dicke    = eingabe_double("  Dicke d [m]: ", 0.0);
    }
    return schichten;
}

// Taupunkttemperatur nach Magnus-Formel [°C].
double taupunkt(double T, double rel_feuchte_prozent) {
    const double a = 17.62, b = 243.12;
    double rh = rel_feuchte_prozent / 100.0;
    double gamma = std::log(rh) + (a * T) / (b + T);
    return (b * gamma) / (a - gamma);
}

// ─── Modus 1: Einfache Wand ──────────────────────────────────────────────────

void einfache_wand() {
    trennlinie('=');
    std::cout << "  EINFACHE (HOMOGENE) WAND\n";
    trennlinie('=');

    Material mat = material_auswaehlen();
    double d  = eingabe_double("\n  Wanddicke d [m]: ", 0.0);
    double T1 = eingabe_double("  Temperatur Seite 1  T₁ [°C]: ", -1e18);
    double T2 = eingabe_double("  Temperatur Seite 2  T₂ [°C]: ", -1e18);
    double A  = eingabe_double("  Fläche A [m²] (1.0 = nur Stromdichte): ", 0.0);

    double dT = T1 - T2;
    double R  = d / mat.lambda;          // m²·K/W
    double q  = mat.lambda * dT / d;     // W/m²
    double Q  = q * A;                   // W
    double U  = 1.0 / R;                 // W/(m²·K)

    std::ostringstream o;
    o << std::fixed;
    o << "\n  ERGEBNISSE\n";
    o << "  --------------------------------------------------\n";
    o << std::setprecision(3);
    o << "  Material:                " << mat.name << " (λ = " << mat.lambda << " W/(m·K))\n";
    o << "  Dicke d:                 " << d  << " m\n";
    o << std::setprecision(2);
    o << "  Temperaturdifferenz ΔT:  " << dT << " K\n";
    o << std::setprecision(4);
    o << "  Wärmewiderstand R':      " << R  << " m²·K/W\n";
    o << "  U-Wert:                  " << U  << " W/(m²·K)\n";
    o << std::setprecision(2);
    o << "  Wärmestromdichte q:      " << q  << " W/m²\n";
    o << "  Wärmestrom Q:            " << Q  << " W   (A = " << A << " m²)\n";
    if (dT > 0)      o << "  Richtung:                T₁ → T₂ (Wärmeverlust)\n";
    else if (dT < 0) o << "  Richtung:                T₂ → T₁\n";
    else             o << "  Richtung:                kein Fluss (ΔT = 0)\n";
    o << "\n";

    ausgeben("Einfache Wand", o.str());
    gLetzterQ = Q; gHabeQ = true;
}

// ─── Modus 2: Mehrschichtige Verbundwand ─────────────────────────────────────

void mehrschichtige_wand() {
    trennlinie('=');
    std::cout << "  MEHRSCHICHTIGE VERBUNDWAND\n";
    trennlinie('=');

    std::vector<Schicht> schichten = schichten_einlesen();

    double T1 = eingabe_double("\n  Temperatur warme Seite  T₁ [°C]: ", -1e18);
    double T2 = eingabe_double("  Temperatur kalte Seite  T₂ [°C]: ", -1e18);
    double A  = eingabe_double("  Fläche A [m²]: ", 0.0);

    double R_ges = 0.0;
    for (const auto& s : schichten)
        R_ges += s.dicke / s.material.lambda;

    double dT = T1 - T2;
    double q  = dT / R_ges;     // W/m²
    double Q  = q * A;          // W
    double U  = 1.0 / R_ges;    // W/(m²·K) — ohne Übergangswiderstände

    std::ostringstream o;
    o << std::fixed;
    o << "\n  SCHICHTAUFBAU\n";
    o << "  --------------------------------------------------\n";
    for (size_t i = 0; i < schichten.size(); ++i) {
        double Ri = schichten[i].dicke / schichten[i].material.lambda;
        o << "  " << (i + 1) << ". " << std::left << std::setw(18)
          << schichten[i].material.name << std::right
          << " d = " << std::setprecision(3) << std::setw(6) << schichten[i].dicke << " m"
          << "  R = " << std::setprecision(4) << std::setw(7) << Ri << " m²·K/W\n";
    }
    o << "\n  ERGEBNISSE\n";
    o << "  --------------------------------------------------\n";
    o << std::setprecision(2);
    o << "  Temperaturdifferenz ΔT:  " << dT    << " K\n";
    o << std::setprecision(4);
    o << "  Gesamtwiderstand R':     " << R_ges << " m²·K/W\n";
    o << "  U-Wert (ohne Übergang):  " << U     << " W/(m²·K)\n";
    o << std::setprecision(2);
    o << "  Wärmestromdichte q:      " << q     << " W/m²\n";
    o << "  Wärmestrom Q:            " << Q     << " W   (A = " << A << " m²)\n";

    o << "\n  Temperaturprofil:\n";
    double T = T1;
    o << "    Oberfläche warm:        " << std::setprecision(2) << std::setw(7) << T << " °C\n";
    for (size_t i = 0; i < schichten.size(); ++i) {
        T -= q * schichten[i].dicke / schichten[i].material.lambda;
        o << "    nach " << std::left << std::setw(18) << schichten[i].material.name
          << std::right << std::setw(7) << T << " °C\n";
    }
    o << "\n";

    ausgeben("Mehrschichtige Wand", o.str());
    gLetzterQ = Q; gHabeQ = true;
}

// ─── Modus 3: Wärmestromdichte aus Gradient ──────────────────────────────────

void gradient_modus() {
    trennlinie('=');
    std::cout << "  WÄRMESTROMDICHTE AUS TEMPERATURGRADIENT\n";
    trennlinie('=');
    std::cout << "  Fourier:  q = -λ · (dT/dx)\n\n";

    double lambda   = eingabe_double("  Wärmeleitfähigkeit λ [W/(m·K)]: ", 0.0);
    double gradient = eingabe_double("  Temperaturgradient dT/dx [K/m]: ", -1e18);

    double q = -lambda * gradient;

    std::ostringstream o;
    o << std::fixed << std::setprecision(3);
    o << "\n  ERGEBNISSE\n";
    o << "  --------------------------------------------------\n";
    o << "  λ:                       " << lambda   << " W/(m·K)\n";
    o << "  dT/dx:                   " << gradient << " K/m\n";
    o << "  Wärmestromdichte q:      " << q        << " W/m²\n";
    o << "  (negatives Vorzeichen = Fluss entgegen dem Gradienten)\n\n";

    ausgeben("Gradient", o.str());
}

// ─── Modus 4: Wand mit Wärmeübergang (U-Wert nach DIN EN ISO 6946) ───────────

void uwert_modus() {
    trennlinie('=');
    std::cout << "  WAND MIT WÄRMEÜBERGANG (U-WERT, DIN EN ISO 6946)\n";
    trennlinie('=');

    std::vector<Schicht> schichten = schichten_einlesen();

    std::cout << "\n  Wärmeübergangswiderstände (Rsi innen / Rse außen):\n";
    std::cout << "  [1] Wand   – horizontaler Strom (0.13 / 0.04)\n";
    std::cout << "  [2] Dach   – Strom aufwärts     (0.10 / 0.04)\n";
    std::cout << "  [3] Boden  – Strom abwärts      (0.17 / 0.04)\n";
    std::cout << "  [4] Eigene Werte\n";
    int wahl = eingabe_int("\n  Auswahl: ", 1, 4);

    double Rsi = 0.13, Rse = 0.04;
    switch (wahl) {
        case 1: Rsi = 0.13; Rse = 0.04; break;
        case 2: Rsi = 0.10; Rse = 0.04; break;
        case 3: Rsi = 0.17; Rse = 0.04; break;
        case 4:
            Rsi = eingabe_double("  Rsi (innen) [m²·K/W]: ", 0.0);
            Rse = eingabe_double("  Rse (außen) [m²·K/W]: ", 0.0);
            break;
    }

    double Ti = eingabe_double("\n  Innentemperatur  Tᵢ [°C]: ", -1e18);
    double Te = eingabe_double("  Außentemperatur  Tₑ [°C]: ", -1e18);
    double A  = eingabe_double("  Fläche A [m²]: ", 0.0);

    double R_cond = 0.0;
    for (const auto& s : schichten)
        R_cond += s.dicke / s.material.lambda;

    double R_ges = Rsi + R_cond + Rse;
    double U     = 1.0 / R_ges;
    double dT    = Ti - Te;
    double q     = U * dT;       // W/m²  (Luft zu Luft)
    double Q     = q * A;        // W

    double T_si = Ti - q * Rsi;  // innere Oberflächentemperatur
    double T_se = Te + q * Rse;  // äußere Oberflächentemperatur

    std::ostringstream o;
    o << std::fixed;
    o << "\n  ERGEBNISSE\n";
    o << "  --------------------------------------------------\n";
    o << std::setprecision(4);
    o << "  Rsi / Rse:               " << Rsi << " / " << Rse << " m²·K/W\n";
    o << "  R Schichten (Σd/λ):      " << R_cond << " m²·K/W\n";
    o << "  Gesamtwiderstand R_T:    " << R_ges  << " m²·K/W\n";
    o << "  U-Wert:                  " << U      << " W/(m²·K)\n";
    o << std::setprecision(2);
    o << "  Temperaturdifferenz ΔT:  " << dT << " K\n";
    o << "  Wärmestromdichte q:      " << q  << " W/m²\n";
    o << "  Wärmestrom Q:            " << Q  << " W   (A = " << A << " m²)\n";
    o << "  Oberfläche innen  T_si:  " << T_si << " °C\n";
    o << "  Oberfläche außen  T_se:  " << T_se << " °C\n";

    // Temperaturprofil inkl. Übergänge
    o << "\n  Temperaturprofil:\n";
    o << "    Raumluft innen:         " << std::setw(7) << Ti  << " °C\n";
    double T = T_si;
    o << "    Oberfläche innen:       " << std::setw(7) << T   << " °C\n";
    for (size_t i = 0; i < schichten.size(); ++i) {
        T -= q * schichten[i].dicke / schichten[i].material.lambda;
        o << "    nach " << std::left << std::setw(18) << schichten[i].material.name
          << std::right << std::setw(7) << T << " °C\n";
    }
    o << "    Außenluft:              " << std::setw(7) << Te << " °C\n";

    ausgeben("U-Wert mit Wärmeübergang", o.str());
    gLetzterQ = Q; gHabeQ = true;

    // Optionaler Tauwasser-Check anhand der relativen Raumluftfeuchte
    if (eingabe_janein("\n  Tauwasser-Check durchführen? (j/N): ", false)) {
        double rh = eingabe_double("  Relative Luftfeuchte innen [%] (z.B. 50): ", 0.0);
        double Td = taupunkt(Ti, rh);
        std::ostringstream t;
        t << std::fixed << std::setprecision(2);
        t << "\n  TAUWASSER-CHECK\n";
        t << "  --------------------------------------------------\n";
        t << "  Taupunkttemperatur:      " << Td   << " °C\n";
        t << "  Oberfläche innen T_si:   " << T_si << " °C\n";
        if (T_si <= Td)
            t << "  ⚠ ACHTUNG: T_si ≤ Taupunkt → Tauwasser/Schimmelgefahr!\n\n";
        else
            t << "  ✓ T_si > Taupunkt → keine Kondensation an der Oberfläche.\n\n";
        ausgeben("Tauwasser-Check", t.str());
    }
}

// ─── Modus 5: Rohr / Zylinder (radiale Wärmeleitung) ─────────────────────────

void rohr_modus() {
    trennlinie('=');
    std::cout << "  ROHR / ZYLINDER – RADIALE WÄRMELEITUNG\n";
    trennlinie('=');
    std::cout << "  Q = 2π·L·ΔT / Σ( ln(rₐ/rᵢ) / λ )\n";

    double ri_mm = eingabe_double("\n  Innenradius rᵢ [mm]: ", 0.0);
    double ri    = ri_mm / 1000.0;

    int n = eingabe_int("  Anzahl der (Rohr-/Dämm-)Schichten: ", 1, 20);

    std::vector<Material> mats(n);
    std::vector<double>   r_aussen(n);   // Außenradius jeder Schicht [m]
    double r = ri;
    for (int i = 0; i < n; ++i) {
        std::cout << "\n  --- Schicht " << (i + 1) << " von " << n << " ---\n";
        mats[i] = material_auswaehlen();
        double dicke_mm = eingabe_double("  Dicke [mm]: ", 0.0);
        r += dicke_mm / 1000.0;
        r_aussen[i] = r;
    }
    double ra = r;   // äußerster Radius

    double Ti = eingabe_double("\n  Temperatur innen  Tᵢ [°C]: ", -1e18);
    double Te = eingabe_double("  Temperatur außen  Tₑ [°C]: ", -1e18);
    double L  = eingabe_double("  Rohrlänge L [m]: ", 0.0);

    // Wärmewiderstand pro Meter Länge (Leitung)
    double R_perL = 0.0;
    double r_inner = ri;
    for (int i = 0; i < n; ++i) {
        R_perL += std::log(r_aussen[i] / r_inner) / (2.0 * PI * mats[i].lambda);
        r_inner = r_aussen[i];
    }

    // Optionale Konvektion innen/außen
    bool konv = eingabe_janein("\n  Konvektion (Wärmeübergang) berücksichtigen? (j/N): ", false);
    double hi = 0.0, ha = 0.0;
    if (konv) {
        hi = eingabe_double("  α innen  [W/(m²·K)] (z.B. 8): ", 0.0);
        ha = eingabe_double("  α außen  [W/(m²·K)] (z.B. 23): ", 0.0);
        R_perL += 1.0 / (2.0 * PI * ri * hi);
        R_perL += 1.0 / (2.0 * PI * ra * ha);
    }

    double dT     = Ti - Te;
    double Q_perL = dT / R_perL;     // W/m
    double Q      = Q_perL * L;      // W

    std::ostringstream o;
    o << std::fixed;
    o << "\n  ERGEBNISSE\n";
    o << "  --------------------------------------------------\n";
    o << std::setprecision(1);
    o << "  Innenradius rᵢ:          " << ri * 1000.0 << " mm\n";
    o << "  Außenradius rₐ:          " << ra * 1000.0 << " mm\n";
    o << std::setprecision(2);
    o << "  Temperaturdifferenz ΔT:  " << dT << " K\n";
    o << std::setprecision(4);
    o << "  Wärmewiderst. pro Meter: " << R_perL << " m·K/W\n";
    if (konv)
        o << "  (inkl. Konvektion αᵢ=" << std::setprecision(1) << hi
          << ", αₐ=" << ha << " W/(m²·K))\n";
    o << std::setprecision(2);
    o << "  Wärmestrom pro Meter:    " << Q_perL << " W/m\n";
    o << "  Wärmestrom gesamt Q:     " << Q      << " W   (L = " << L << " m)\n\n";

    ausgeben("Rohr / Zylinder", o.str());
    gLetzterQ = Q; gHabeQ = true;
}

// ─── Modus 6: Energie & Heizkosten über Zeit ─────────────────────────────────

void energie_modus() {
    trennlinie('=');
    std::cout << "  ENERGIE & HEIZKOSTEN ÜBER ZEIT\n";
    trennlinie('=');

    double Q;
    if (gHabeQ) {
        std::cout << "\n  Letzter berechneter Wärmestrom: " << std::fixed
                  << std::setprecision(2) << gLetzterQ << " W\n";
        if (eingabe_janein("  Diesen Wert verwenden? (J/n): ", true))
            Q = gLetzterQ;
        else
            Q = eingabe_double("  Wärmestrom Q [W]: ", -1e18);
    } else {
        Q = eingabe_double("\n  Wärmestrom Q [W]: ", -1e18);
    }

    std::cout << "\n  Zeitraum-Einheit:\n";
    std::cout << "  [1] Stunden\n  [2] Tage\n  [3] Jahre\n";
    int einheit = eingabe_int("  Auswahl: ", 1, 3);
    double wert = eingabe_double("  Dauer: ", 0.0);

    double stunden = wert;
    if (einheit == 2) stunden = wert * 24.0;
    if (einheit == 3) stunden = wert * 24.0 * 365.0;

    double preis = eingabe_double("  Energiepreis [€/kWh] (z.B. 0.30): ", 0.0);

    double kWh    = std::fabs(Q) * stunden / 1000.0;
    double kosten = kWh * preis;

    // Hochrechnungen
    double kWh_tag  = std::fabs(Q) * 24.0 / 1000.0;
    double kWh_jahr = std::fabs(Q) * 24.0 * 365.0 / 1000.0;

    std::ostringstream o;
    o << std::fixed;
    o << "\n  ERGEBNISSE\n";
    o << "  --------------------------------------------------\n";
    o << std::setprecision(2);
    o << "  Wärmestrom Q:            " << std::fabs(Q) << " W\n";
    o << "  Zeitraum:                " << stunden << " h\n";
    o << "  Energiemenge:            " << kWh << " kWh\n";
    o << "  Kosten:                  " << kosten << " €   (bei " << preis << " €/kWh)\n";
    o << "  --------------------------------------------------\n";
    o << "  Hochrechnung pro Tag:    " << kWh_tag  << " kWh  =  "
      << kWh_tag * preis  << " €\n";
    o << "  Hochrechnung pro Jahr:   " << kWh_jahr << " kWh  =  "
      << kWh_jahr * preis << " €\n\n";

    ausgeben("Energie & Heizkosten", o.str());
}

// ─── Modus 7: Materialdatenbank anzeigen ─────────────────────────────────────

void datenbank_anzeigen() {
    trennlinie('=');
    std::cout << "  MATERIALDATENBANK (" << MATERIALIEN.size() << " Einträge)\n";
    trennlinie('=');

    std::string aktuelle_kat;
    for (const auto& m : MATERIALIEN) {
        if (m.kategorie != aktuelle_kat) {
            aktuelle_kat = m.kategorie;
            std::cout << "\n  " << aktuelle_kat << ":\n";
        }
        std::cout << "    " << std::left << std::setw(20) << m.name
                  << "λ = " << std::right << std::setw(7) << std::fixed
                  << std::setprecision(3) << m.lambda << " W/(m·K)\n";
    }
    std::cout << "\n  Hinweis: Niedriges λ = gute Dämmwirkung.\n\n";
}

// ─── Hauptmenü ───────────────────────────────────────────────────────────────

int main() {
#ifdef _WIN32
    // UTF-8-Ausgabe/-Eingabe auf der Windows-Konsole aktivieren.
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif

    std::cout << "\n";
    trennlinie('=');
    std::cout << "            WÄRMEFLUSS-RECHNER\n";
    std::cout << "   Wärmeleitung · Wärmeübergang · Heizkosten\n";
    trennlinie('=');

    while (true) {
        std::cout << "\n  Berechnungsmodus:\n";
        std::cout << "  [1] Einfache (homogene) Wand\n";
        std::cout << "  [2] Mehrschichtige Verbundwand\n";
        std::cout << "  [3] Wärmestromdichte aus Temperaturgradient\n";
        std::cout << "  [4] Wand mit Wärmeübergang (U-Wert, DIN EN ISO 6946)\n";
        std::cout << "  [5] Rohr / Zylinder (radiale Wärmeleitung)\n";
        std::cout << "  [6] Energie & Heizkosten über Zeit\n";
        std::cout << "  [7] Materialdatenbank anzeigen\n";
        std::cout << "  [8] Protokoll als Datei exportieren";
        if (gAnzahl > 0) std::cout << "  (" << gAnzahl << " Berechnung(en))";
        std::cout << "\n";
        std::cout << "  [0] Beenden\n";

        int wahl = eingabe_int("\n  Auswahl: ", 0, 8);

        switch (wahl) {
            case 1: einfache_wand();        break;
            case 2: mehrschichtige_wand();  break;
            case 3: gradient_modus();       break;
            case 4: uwert_modus();          break;
            case 5: rohr_modus();           break;
            case 6: energie_modus();        break;
            case 7: datenbank_anzeigen();   break;
            case 8: protokoll_exportieren(); break;
            case 0:
                if (gAnzahl > 0 &&
                    eingabe_janein("\n  Protokoll vor dem Beenden speichern? (j/N): ", false)) {
                    protokoll_exportieren();
                }
                std::cout << "\n  Programm beendet.\n\n";
                return 0;
        }
    }
}
