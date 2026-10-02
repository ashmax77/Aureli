# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep method channels for Window Security 
# (Since there is a custom MethodChannel 'com.manager.mobile/window_sec' in security_service.dart)
-keep class com.manager.mobile.** { *; }

# Firebase rules (often required so Firebase features don't crash in release mode)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn com.google.android.play.core.**

# Additional robust Android guidelines
-dontwarn android.support.**
-dontwarn androidx.**
-keep class androidx.** { *; }
-keep class * extends androidx.core.app.ComponentActivity { *; }
-keep class * extends androidx.fragment.app.Fragment { *; }
