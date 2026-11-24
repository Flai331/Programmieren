# Regeln für R8, den Verkleinerer im Release-Bau.
#
# Flutter zieht diese Datei automatisch dazu, wenn sie hier liegt (siehe
# packages/flutter_tools/gradle/.../FlutterPlugin.kt).

# ML Kit Texterkennung: die ungenutzten Schriften.
#
# google_mlkit_text_recognition kann Chinesisch, Devanagari, Japanisch und
# Koreanisch — bindet die zugehörigen Modelle aber nur `compileOnly` ein.
# Die Klassen stehen also im Quelltext des Pakets, liegen dem APK aber nicht
# bei. R8 sieht die Verweise, findet die Klassen nicht und bricht ab:
#
#   ERROR: Missing class
#   com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
#
# Das ist hier kein verschwiegenes Problem, sondern wirklich toter Code:
# BeeBrain erkennt ausschließlich lateinische Schrift
# (BucketScanService benutzt fest TextRecognitionScript.latin), und nur
# dieses Modell liegt bei. Die vier Zeilen nehmen genau die Schriften aus,
# die nie aufgerufen werden — an das lateinische Modell fassen sie nicht.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
