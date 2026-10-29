import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Release signing ──────────────────────────────────────────────────────────
// The upload key's details live in android/key.properties, which is
// git-ignored (see android/key.properties.example). Never commit that file
// or the .jks keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKey = keystorePropertiesFile.exists()
if (hasReleaseKey) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.splitly.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true   // ✅ MUST ADD

    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.splitly.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        // Flutter's value = the latest Android (36 / Android 16), which
        // Google Play requires for new apps and updates.
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ── arm64-only APK ──────────────────────────────────────────────────
        // SPLITLY_ARM64_ONLY=true flutter build apk --release --target-platform android-arm64
        // `--target-platform` alone only limits Flutter's own libraries; some
        // packages (ML Kit, the QR scanner) would still add 32-bit and x86 ones,
        // so a 32-bit phone would install the APK and crash at start. This
        // keeps ONLY arm64 libraries, so such a phone refuses to install it.
        // Normal builds (universal APK, app bundle) are not affected.
    }

    if (System.getenv("SPLITLY_ARM64_ONLY") == "true") {
        logger.lifecycle("Splitly: arm64-only build (32-bit and x86 libraries left out)")
        packaging {
            jniLibs {
                excludes += listOf("lib/armeabi-v7a/**", "lib/armeabi/**", "lib/x86/**", "lib/x86_64/**")
            }
        }
    }
    dependencies {
        coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
        // ML Kit: the google_mlkit_text_recognition plugin already brings
        // the Latin text model — the only one Splitly uses.
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // No key.properties: still lets `flutter run --release`
                // work on your phone, but Google Play will REJECT this build.
                logger.warn(
                    "WARNING: android/key.properties not found — this release " +
                        "build is signed with the DEBUG key and cannot be uploaded to Google Play."
                )
                signingConfig = signingConfigs.getByName("debug")
            }
            // Our R8 rules (ML Kit's other-language classes are optional and
            // not bundled, so R8 must not fail on them).
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
