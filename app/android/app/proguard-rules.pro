# Proguard rules for GiGly

# Keep Firebase classes
-keep class com.google.firebase.** { *; }

# Keep Flutter plugin classes
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep telephony and permission handler classes
-keep class com.shoutsy.telephony.** { *; }
-keep class com.baseflow.permissionhandler.** { *; }

# Don't warn for missing Play Store SplitInstall / deferred components classes in Flutter SDK
-dontwarn com.google.android.play.core.**
