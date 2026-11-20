#!/bin/sh
# Baut Hundekeks.apk ohne Gradle direkt mit den Android-Build-Tools.
# Aufruf: ANDROID_SDK=/pfad/zum/sdk ./build_apk.sh [versionCode]
# Benötigt: platforms;android-34 und build-tools;35.0.0, JDK 17+.
set -e
cd "$(dirname "$0")"
SDK=${ANDROID_SDK:?ANDROID_SDK setzen}
BT=$SDK/build-tools/35.0.0
JAR=$SDK/platforms/android-34/android.jar
VC=${1:-1}
OUT=build
rm -rf $OUT && mkdir -p $OUT/assets $OUT/classes

# Web-App aktualisieren und mit lokalen Bibliotheken (offline) in die Assets legen
../build.sh
sed -e 's#https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js#three.min.js#' \
    -e 's#https://cdn.jsdelivr.net/npm/three@0.128.0/examples/js/controls/OrbitControls.js#OrbitControls.js#' \
    ../../docs/hundekeks/index.html > $OUT/assets/index.html
cp vendor/three.min.js vendor/OrbitControls.js $OUT/assets/

$BT/aapt2 compile --dir res -o $OUT/res.zip
$BT/aapt2 link -o $OUT/base.apk -I $JAR --manifest AndroidManifest.xml -A $OUT/assets $OUT/res.zip \
  --min-sdk-version 24 --target-sdk-version 34 --version-code "$VC" --version-name "1.$VC"
javac -nowarn -source 8 -target 8 -bootclasspath $JAR -d $OUT/classes $(find src -name '*.java') 2>&1 | grep -v -e warning -e JAVA_ -e '^Note' || true
$BT/d8 --lib $JAR --min-api 24 --release --output $OUT $(find $OUT/classes -name '*.class')
(cd $OUT && zip -q base.apk classes.dex)
$BT/zipalign -f -p 4 $OUT/base.apk $OUT/aligned.apk
# Schlüssel liegt bewusst im Repo (Hobby-App, Sideload): nur so lassen sich spätere Versionen als Update installieren.
$BT/apksigner sign --ks hundekeks.p12 --ks-pass pass:hundekeks --key-pass pass:hundekeks --out Hundekeks.apk $OUT/aligned.apk
$BT/apksigner verify Hundekeks.apk && echo "Fertig: $(pwd)/Hundekeks.apk"
