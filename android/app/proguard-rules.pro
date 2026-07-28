# Reglas ProGuard/R8 para el release build. Sin estas, R8 strippea clases
# de ML Kit y Google Play Services que `mobile_scanner` carga en runtime
# vía reflexión, produciendo NPEs con símbolos ofuscados (d5.d, z4.b, etc.)
# al primer escaneo. Los rules están tomados del README y la wiki de
# mobile_scanner + guías oficiales de ML Kit.

# --- Flutter ---
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# --- ML Kit Barcode (usado por mobile_scanner) ---
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.odml.** { *; }
-keep class com.google.mlkit.vision.barcode.internal.** { *; }
-keep class com.google.mlkit.vision.barcode.common.** { *; }
-keep class com.google.mlkit.vision.common.** { *; }

# ML Kit resuelve dependencias opcionales por reflection; si R8 detecta
# esas clases como "no usadas" y las elimina, la carga falla en runtime.
-dontwarn com.google.mlkit.**
-dontwarn com.google.android.gms.**

# --- mobile_scanner plugin ---
-keep class dev.steenbakker.mobile_scanner.** { *; }
-dontwarn dev.steenbakker.mobile_scanner.**

# --- print_bluetooth_thermal plugin (por defensa; no reportó problemas) ---
-keep class ir.mahozad.multiplatform.** { *; }

# --- Kotlin coroutines / reflection genérica que algunos plugins usan ---
-keepattributes *Annotation*, InnerClasses, Signature, Exceptions
-keep class kotlin.coroutines.Continuation
