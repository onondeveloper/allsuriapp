# Flutter and Dart
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Kotlin coroutines
-dontwarn kotlinx.coroutines.**
-keepclassmembers class kotlinx.coroutines.** { *; }

# OkHttp/Okio (if used transitively)
-dontwarn okhttp3.**
-dontwarn okio.**

# Gson / Moshi (if used)
-dontwarn com.google.gson.**
-dontwarn com.squareup.moshi.**

# Google Play Services / Firebase
-dontwarn com.google.android.gms.**
-dontwarn com.google.firebase.**

# WebView
-dontwarn android.webkit.**

# Keep models used by reflection (Supabase/Postgrest JSON mapping is runtime-based)
-keep class com.ononcompany.allsuri.** { *; }
