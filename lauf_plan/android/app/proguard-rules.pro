# Plugin-Klassen nicht von R8 entfernen/umbenennen lassen.
# Ohne diese Regel fehlt in der Release-APK
# SharedPreferencesApiRegistrar.getAll -> NoSuchMethodError beim Start,
# die App bleibt schwarz (im Emulator-Starttest nachgewiesen).
-keep class io.flutter.plugins.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }
