plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    // Note: AGP 9.0+ has built-in Kotlin support, so the separate
    // 'kotlin-android' plugin is no longer needed here.
    id("dev.flutter.flutter-gradle-plugin")
    // Add the Google services Gradle plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "app.musicplayer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        // This must match the package_name in google-services.json
        applicationId = "app.musicplayer"
        minSdk = 23 // just_audio_background / media session support needs 23+
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Signed with the debug key so `flutter build apk` works out of
            // the box. Replace with your own release signing config before
            // publishing to the Play Store.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Import the Firebase BoM so all Firebase library versions stay compatible
    implementation(platform("com.google.firebase:firebase-bom:34.18.0"))
    implementation("com.google.android.gms:play-services-base:18.5.0")
}
