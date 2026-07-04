# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep model classes
-keep class com.composia.app.** { *; }

# OkHttp (used by http package)
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

# Gson / JSON
-keepattributes Signature
-keepattributes *Annotation*

# Play Core split-install classes (Flutter deferred components, unused here)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
