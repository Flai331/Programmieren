/*
 * Wärmefluss-Rechner
 *
 * Berechnet Wärmefluss/-strom nach dem Fourier'schen Wärmeleitungsgesetz:
 *   q = -λ * (dT/dx)          [Wärmestromdichte, W/m²]
 *   Q =  λ * A * ΔT / d       [Wärmestrom durch Wand, W]
 *
 * Unterstützt:
 *   1) Einfache Wand (homogen)
 *   2) Mehrschichtige Wand (Verbundwand)
 *   3) Vordefinierte Materialwerte
 */

#include <iostream>
#include <iomanip>
#include <vector>
#include <string>
#include <limits>
#include <cmath>

// ─── Datenstrukturen ────────────────────────────────────────────────────────

struct Material {
    std::string name;
    double lambda;   // Wärmeleitfähigkeit [W/(m·K)]
};

struct Schicht {
    Material material;
    double dicke;    // [m]
};

// ─── Materialdatenbank ───────────────────────────────────────────────────────

const std::vector<Material> MATERIALIEN = {
    {"Beton",              2.10},
    {"Ziegel",             0.80},
    {"Holz (Fichte)",      0.13},
    {"Mineralwolle",       0.04},
    {"Styropor (EPS)",     0.035},
    {"Stahl",             50.00},
    {"Aluminium",        160.00},
    {"Glas",               1.00},
    {"Luft (stehend)",     0.026},
    {"Wasser",             0.60},
};

// ─── Hilfsfunktionen ─────────────────────────────────────────────────────────

void trennlinie(char c = '-', int breite = 55) {
    std::cout << std::string(breite, c) << "\n";
}

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

void materialliste_anzeigen() {
    std::cout << "\n  Verfügbare Materialien:\n";
    for (size_t i = 0; i < MATERIALIEN.size(); ++i) {
        std::cout << "  [" << std::setw(2) << (i + 1) << "] "
                  << std::left << std::setw(22) << MATERIALIEN[i].name
                  << "λ = " << std::fixed << std::setprecision(3)
                  << MATERIALIEN[i].lambda << " W/(m·K)\n";
    }
    std::cout << "  [" << (MATERIALIEN.size() + 1) << "] Eigenen Wert eingeben\n";
}

Material material_auswaehlen() {
    materialliste_anzeigen();
    int wahl = eingabe_int("\n  Auswahl: ", 1, (int)MATERIALIEN.size() + 1);
    if (wahl <= (int)MATERIALIEN.size()) {
        return MATERIALIEN[wahl - 1];
    }
    Material m;
    std::cout << "  Materialname: ";
    std::cin.ignore();
    std::getline(std::cin, m.name);
    m.lambda = eingabe_double("  Wärmeleitfähigkeit λ [W/(m·K)]: ", 0.0);
    return m;
}

// ─── Berechnungsfunktionen ───────────────────────────────────────────────────

void einfache_wand() {
    trennlinie('=');
    std::cout << "  EINFACHE WAND\n";
    trennlinie('=');

    Material mat = material_auswaehlen();
    double d  = eingabe_double("\n  Wanddicke d [m]: ", 0.0);
    double T1 = eingabe_double("  Temperatur Seite 1 T₁ [°C]: ", -300.0);
    double T2 = eingabe_double("  Temperatur Seite 2 T₂ [°C]: ", -300.0);
    double A  = eingabe_double("  Fläche A [m²] (1.0 für Wärmestromdichte): ", 0.0);

    double dT  = T1 - T2;
    double q   = mat.lambda * dT / d;           // W/m²
    double Q   = q * A;                          // W
    double R   = d / mat.lambda;                 // m²·K/W (Wärmewiderstand pro m²)

    trennlinie();
    std::cout << std::fixed << std::setprecision(4);
    std::cout << "\n  ERGEBNISSE\n";
    trennlinie();
    std::cout << "  Material:             " << mat.name << "\n";
    std::cout << "  λ:                    " << mat.lambda << " W/(m·K)\n";
    std::cout << "  Dicke:                " << d    << " m\n";
    std::cout << "  Temperaturdifferenz:  " << dT   << " K\n";
    std::cout << "  Wärmewiderstand R':   " << R    << " m²·K/W\n";
    std::cout << "  Wärmestromdichte q:   " << q    << " W/m²\n";
    std::cout << "  Wärmestrom Q:         " << Q    << " W\n";

    if (Q > 0)
        std::cout << "  Richtung:             von T₁ nach T₂ (Wärmeverlust)\n";
    else if (Q < 0)
        std::cout << "  Richtung:             von T₂ nach T₁\n";
    else
        std::cout << "  Richtung:             kein Wärmefluss (ΔT = 0)\n";

    std::cout << "\n";
}

void mehrschichtige_wand() {
    trennlinie('=');
    std::cout << "  MEHRSCHICHTIGE WAND (VERBUNDWAND)\n";
    trennlinie('=');

    int n = eingabe_int("\n  Anzahl der Schichten: ", 1, 20);

    std::vector<Schicht> schichten(n);
    for (int i = 0; i < n; ++i) {
        std::cout << "\n  --- Schicht " << (i + 1) << " ---\n";
        schichten[i].material = material_auswaehlen();
        schichten[i].dicke    = eingabe_double("  Dicke [m]: ", 0.0);
    }

    double T1 = eingabe_double("\n  Außentemperatur T₁ [°C]: ", -300.0);
    double T2 = eingabe_double("  Innentemperatur T₂ [°C]: ", -300.0);
    double A  = eingabe_double("  Fläche A [m²]: ", 0.0);

    // Gesamtwärmewiderstand
    double R_ges = 0.0;
    for (const auto& s : schichten)
        R_ges += s.dicke / s.material.lambda;

    double dT  = T1 - T2;
    double q   = dT / R_ges;     // W/m²
    double Q   = q * A;          // W
    double U   = 1.0 / R_ges;    // W/(m²·K) — vereinfacht ohne Übergangswiderstände

    trennlinie();
    std::cout << "\n  ERGEBNISSE\n";
    trennlinie();
    std::cout << std::fixed << std::setprecision(4);
    std::cout << "  Temperaturdifferenz ΔT: " << dT   << " K\n";
    std::cout << "  Gesamtwiderstand R':    " << R_ges << " m²·K/W\n";
    std::cout << "  U-Wert (vereinfacht):   " << U    << " W/(m²·K)\n";
    std::cout << "  Wärmestromdichte q:     " << q    << " W/m²\n";
    std::cout << "  Wärmestrom Q:           " << Q    << " W\n";

    // Temperaturprofil
    std::cout << "\n  Temperaturprofil:\n";
    double T_aktuell = T1;
    std::cout << "  T₁ = " << std::setprecision(2) << T_aktuell << " °C\n";
    for (int i = 0; i < n; ++i) {
        double dT_schicht = q * schichten[i].dicke / schichten[i].material.lambda;
        T_aktuell -= dT_schicht;
        std::cout << "  nach Schicht " << (i + 1) << " (" << schichten[i].material.name
                  << "): " << T_aktuell << " °C\n";
    }
    std::cout << "\n";
}

void wärmestromdichte_gradient() {
    trennlinie('=');
    std::cout << "  WÄRMESTROMDICHTE AUS TEMPERATURGRADIENTEN\n";
    trennlinie('=');
    std::cout << "  Fourier'sches Gesetz: q = -λ · (dT/dx)\n\n";

    double lambda   = eingabe_double("  Wärmeleitfähigkeit λ [W/(m·K)]: ", 0.0);
    double gradient = eingabe_double("  Temperaturgradient dT/dx [K/m] (positiv = Erwärmung in x): ", -1e18);

    double q = -lambda * gradient;

    trennlinie();
    std::cout << "\n  ERGEBNISSE\n";
    trennlinie();
    std::cout << std::fixed << std::setprecision(4);
    std::cout << "  λ:               " << lambda   << " W/(m·K)\n";
    std::cout << "  dT/dx:           " << gradient << " K/m\n";
    std::cout << "  Wärmestromdichte q = " << q << " W/m²\n";
    std::cout << "  (negatives Vorzeichen = Fluss entgegen dem Gradienten)\n\n";
}

// ─── Hauptmenü ───────────────────────────────────────────────────────────────

int main() {
    std::cout << "\n";
    trennlinie('=', 55);
    std::cout << "        WÄRMEFLUSS-RECHNER (Fourier'sches Gesetz)\n";
    trennlinie('=', 55);

    while (true) {
        std::cout << "\n  Berechnungsmodus:\n";
        std::cout << "  [1] Einfache (homogene) Wand\n";
        std::cout << "  [2] Mehrschichtige Verbundwand\n";
        std::cout << "  [3] Wärmestromdichte aus Temperaturgradient\n";
        std::cout << "  [0] Beenden\n";

        int wahl = eingabe_int("\n  Auswahl: ", 0, 3);

        switch (wahl) {
            case 1: einfache_wand();             break;
            case 2: mehrschichtige_wand();        break;
            case 3: wärmestromdichte_gradient();  break;
            case 0:
                std::cout << "\n  Programm beendet.\n\n";
                return 0;
        }
    }
}
