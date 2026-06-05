package de.waermefluss;

import android.app.Activity;
import android.os.Bundle;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;
import java.util.Locale;

public class MainActivity extends Activity {

    private EditText editLambda, editDicke, editT1, editT2, editFlaeche;
    private LinearLayout cardErgebnis;
    private TextView txtErgebnis;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        editLambda  = (EditText) findViewById(R.id.editLambda);
        editDicke   = (EditText) findViewById(R.id.editDicke);
        editT1      = (EditText) findViewById(R.id.editT1);
        editT2      = (EditText) findViewById(R.id.editT2);
        editFlaeche = (EditText) findViewById(R.id.editFlaeche);
        cardErgebnis = (LinearLayout) findViewById(R.id.cardErgebnis);
        txtErgebnis  = (TextView) findViewById(R.id.txtErgebnis);

        Button btnBerechnen = (Button) findViewById(R.id.btnBerechnen);
        Button btnReset     = (Button) findViewById(R.id.btnReset);

        btnBerechnen.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                berechnen();
            }
        });

        btnReset.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View v) {
                zuruecksetzen();
            }
        });
    }

    private void berechnen() {
        String sLambda  = editLambda.getText().toString().trim().replace(',', '.');
        String sDicke   = editDicke.getText().toString().trim().replace(',', '.');
        String sT1      = editT1.getText().toString().trim().replace(',', '.');
        String sT2      = editT2.getText().toString().trim().replace(',', '.');
        String sFlaeche = editFlaeche.getText().toString().trim().replace(',', '.');

        if (sLambda.isEmpty() || sDicke.isEmpty() || sT1.isEmpty()
                || sT2.isEmpty() || sFlaeche.isEmpty()) {
            Toast.makeText(this, "Bitte alle Felder ausfüllen", Toast.LENGTH_SHORT).show();
            return;
        }

        double lambda, d, T1, T2, A;
        try {
            lambda = Double.parseDouble(sLambda);
            d      = Double.parseDouble(sDicke);
            T1     = Double.parseDouble(sT1);
            T2     = Double.parseDouble(sT2);
            A      = Double.parseDouble(sFlaeche);
        } catch (NumberFormatException e) {
            Toast.makeText(this, "Ungültige Eingabe", Toast.LENGTH_SHORT).show();
            return;
        }

        if (lambda <= 0 || d <= 0 || A <= 0) {
            Toast.makeText(this, "λ, d und A müssen größer als 0 sein", Toast.LENGTH_SHORT).show();
            return;
        }

        double dT  = T1 - T2;
        double R   = d / lambda;
        double q   = lambda * dT / d;
        double Q   = q * A;
        double U   = lambda / d;

        String richtung;
        if (dT > 0)       richtung = "→  Wärmeverlust (T₁ nach T₂)";
        else if (dT < 0)  richtung = "←  Rückfluss (T₂ nach T₁)";
        else               richtung = "–  kein Wärmefluss (ΔT = 0)";

        String ergebnis = String.format(Locale.GERMANY,
                "Temperaturdifferenz ΔT:   %.2f K\n" +
                "Wärmewiderstand R':        %.4f m²·K/W\n" +
                "U-Wert (vereinfacht):      %.4f W/(m²·K)\n\n" +
                "Wärmestromdichte  q:       %.2f W/m²\n" +
                "Wärmestrom         Q:       %.2f W\n\n" +
                "Richtung:  %s",
                dT, R, U, q, Q, richtung);

        txtErgebnis.setText(ergebnis);
        cardErgebnis.setVisibility(View.VISIBLE);
    }

    private void zuruecksetzen() {
        editLambda.setText("");
        editDicke.setText("");
        editT1.setText("");
        editT2.setText("");
        editFlaeche.setText("");
        cardErgebnis.setVisibility(View.GONE);
        txtErgebnis.setText("");
    }
}
