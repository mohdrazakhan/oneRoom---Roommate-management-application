// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")   // Firebase (google-services.json)
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// -------------------------
// Load keystore properties
// -------------------------
val keystorePropertiesFile = file("../../key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

android {
    namespace = "com.oneroom.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.oneroom.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // -------------------------
    // Signing configs (release)
    // -------------------------
    signingConfigs {
        create("release") {
            // key properties loaded from key.properties file
            keyAlias = keystoreProperties["keyAlias"] as String? ?: "release"
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    // -------------------------
    // Build types
    // -------------------------
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")

            // Recommended: enable shrinking and minification for production
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )

            // Optional: disable debug logs or set other release flags here
        }

        getByName("debug") {
            // debug default configuration
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring for Java 8+ APIs
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // Multidex support (safe for older devices)
    implementation("androidx.multidex:multidex:2.0.1")

    // Play Billing (for in-app purchases / remove ads)
    implementation("com.android.billingclient:billing:7.0.0")

    // Google Mobile Ads (AdMob)
    implementation("com.google.android.gms:play-services-ads:22.2.0")

    // Firebase handled by google-services plugin; add firebase libs in pubspec and dart code
}
