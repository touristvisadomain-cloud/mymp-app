import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "bd.mymp.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Fixed for the life of the app: Play ties the listing, the reviews and
        // the signing key to this string and it can never be changed.
        applicationId = "bd.mymp.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // The Google Maps key (owner, 2026-10-17), into the manifest's
        // com.google.android.geo.API_KEY. From MAPS_API_KEY in
        // android/local.properties (never committed) or the environment
        // variable MAPS_API_KEY (Codemagic). With neither it is empty, and
        // the app draws its own maps: MainActivity tells the Dart side
        // whether there is a key (lib/maps/google.dart).
        val localMaps = rootProject.file("local.properties").takeIf { it.exists() }
            ?.let { f -> Properties().apply { FileInputStream(f).use { load(it) } } }
            ?.getProperty("MAPS_API_KEY")
        val mapsKey = (localMaps?.takeIf { it.isNotBlank() } ?: System.getenv("MAPS_API_KEY") ?: "").trim()
        manifestPlaceholders["MAPS_API_KEY"] = mapsKey
    }

    /*
     * The upload key, from one of two places:
     *  - on Codemagic, the keystore uploaded under Code signing identities,
     *    which the build machine exposes as CM_KEYSTORE_PATH and friends;
     *  - on this PC, android/key.properties (never committed).
     * With neither, a release build falls back to the debug key so a phone test
     * still works on a fresh clone; Play refuses a debug-signed bundle, so the
     * Codemagic release workflow sets REQUIRE_UPLOAD_KEY and fails instead.
     */
    val ciKeystore = System.getenv("CM_KEYSTORE_PATH")?.takeIf { file(it).exists() }
    val localProps = rootProject.file("key.properties").takeIf { it.exists() }
        ?.let { f -> Properties().apply { FileInputStream(f).use { load(it) } } }
    val localKeystore = localProps?.getProperty("storeFile")?.let { rootProject.file(it) }?.takeIf { it.exists() }
    val hasUploadKey = ciKeystore != null || localKeystore != null

    signingConfigs {
        create("upload") {
            if (ciKeystore != null) {
                storeFile = file(ciKeystore)
                storePassword = System.getenv("CM_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            } else if (localKeystore != null && localProps != null) {
                storeFile = localKeystore
                storePassword = localProps.getProperty("storePassword")
                keyAlias = localProps.getProperty("keyAlias")
                keyPassword = localProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (!hasUploadKey && System.getenv("REQUIRE_UPLOAD_KEY") == "true") {
                throw GradleException(
                    "No upload key: add the keystore in Codemagic (Code signing identities, " +
                        "reference mymp_upload) or create android/key.properties.",
                )
            }
            signingConfig = signingConfigs.getByName(if (hasUploadKey) "upload" else "debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
