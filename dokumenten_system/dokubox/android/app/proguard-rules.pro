# google_mlkit_text_recognition referenziert optionale Sprachmodelle
# (Chinesisch, Devanagari, Japanisch, Koreanisch), die wir nicht einbinden —
# DokuBox nutzt nur das Latin-Modell. R8 darf diese Verweise ignorieren.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
