# =============================================================================
# Flutter framework
# =============================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# =============================================================================
# Kotlin & coroutines
# =============================================================================
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-dontwarn kotlin.**
-dontwarn kotlinx.**

# Keep coroutine internals used via reflection
-keepclassmembers class kotlinx.coroutines.internal.MainDispatcherFactory { *; }
-keepclassmembers class kotlinx.coroutines.CoroutineExceptionHandler { *; }

# =============================================================================
# Firebase & Google Play Services
# =============================================================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Firestore — model fields accessed via reflection / PropertyName
-keepclassmembers class * {
    @com.google.firebase.database.PropertyName <methods>;
}
# Firestore Kotlin extension classes
-keep class com.google.firebase.firestore.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }

# =============================================================================
# JSON / Gson (used internally by Firebase)
# =============================================================================
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# =============================================================================
# audioplayers  (xyz.luan.audioplayers)
# =============================================================================
-keep class xyz.luan.audioplayers.** { *; }
-keep class com.ryanheise.** { *; }

# =============================================================================
# record  (com.llfbandit.record)
# =============================================================================
-keep class com.llfbandit.record.** { *; }

# =============================================================================
# image_picker / image_cropper
# =============================================================================
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**
-keep class androidx.camera.** { *; }

# =============================================================================
# permission_handler
# =============================================================================
-keep class com.baseflow.permissionhandler.** { *; }

# =============================================================================
# flutter_secure_storage
# =============================================================================
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# =============================================================================
# device_calendar
# =============================================================================
-keep class com.builttoroam.devicecalendar.** { *; }

# =============================================================================
# gal (gallery save)
# =============================================================================
-keep class com.nkduy.gal.** { *; }

# =============================================================================
# share_plus
# =============================================================================
-keep class dev.fluttercommunity.plus.share.** { *; }

# =============================================================================
# url_launcher
# =============================================================================
-keep class io.flutter.plugins.urllauncher.** { *; }

# =============================================================================
# app_links (deep linking)
# =============================================================================
-keep class com.llfbandit.app_links.** { *; }

# =============================================================================
# path_provider
# =============================================================================
-keep class io.flutter.plugins.pathprovider.** { *; }

# =============================================================================
# Native method bridges (JNI)
# =============================================================================
-keepclasseswithmembernames class * {
    native <methods>;
}

# =============================================================================
# Suppress common warnings from third-party libraries
# =============================================================================
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
-dontwarn javax.annotation.**
-dontwarn com.google.errorprone.annotations.**
