import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "gr.scholilink.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            val storePassword = keystoreProperties.getProperty("storePassword")
            val keyPassword = keystoreProperties.getProperty("keyPassword")
            val keyAlias = keystoreProperties.getProperty("keyAlias")
            if (storeFilePath != null &&
                storePassword != null &&
                keyPassword != null &&
                keyAlias != null &&
                rootProject.file(storeFilePath).exists()
            ) {
                create("release") {
                    this.keyAlias = keyAlias
                    this.keyPassword = keyPassword
                    storeFile = rootProject.file(storeFilePath)
                    this.storePassword = storePassword
                }
            }
        }
    }

    defaultConfig {
        applicationId = "gr.scholilink.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = if (signingConfigs.findByName("release") != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    // ABI splits are handled via the Flutter CLI — do NOT add a Gradle `splits`
    // block here, as Flutter's Gradle plugin already sets `abiFilters` in
    // defaultConfig which causes a Gradle conflict.
    //
    // To build per-architecture APKs (smaller install size):
    //   flutter build apk --split-per-abi
    //
    // To build a universal APK (one file, all architectures):
    //   flutter build apk
    //
    // To build an App Bundle for the Play Store (recommended for distribution):
    //   flutter build appbundle
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
