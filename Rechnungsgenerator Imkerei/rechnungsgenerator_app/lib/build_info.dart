// Die laufende Nummer dieser Fassung. Wird bei jeder Änderung manuell
// hochgezählt.
//
// Sie steht in Fehlerberichten, in der App unter Einstellungen, und sie
// benennt das Release: Eine veröffentlichte Fassung trägt den Tag
// `build-<N>`, und daran erkennt die App, ob es etwas Neueres gibt.
//
// Beim Erhöhen auch `version: 1.0.0+N` in pubspec.yaml mitziehen — daraus
// kommt Androids versionCode. test/build_number_test.dart besteht darauf.
const int kBuildNumber = 15;
