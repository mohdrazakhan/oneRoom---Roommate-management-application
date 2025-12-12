// android/app/build.gradle.kts
import java.io.FileInputStream
import java.util.Properties

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

fun registerFlutterApkCopyTask(variant: String) {
    val capitalized = variant.replaceFirstChar { it.uppercaseChar() }
    tasks.matching { it.name == "package$capitalized" }.configureEach {
        doLast {
            val flutterProjectDir = project.projectDir.parentFile?.parentFile
                ?: error("Unable to locate Flutter project directory")
            val targetDir = flutterProjectDir.resolve("build/app/outputs/flutter-apk")
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }

            val sourceApk = project.layout.buildDirectory
                .dir("outputs/apk/$variant")
                .map { it.file("app-$variant.apk").asFile }
                .get()

            if (sourceApk.exists()) {
                val targetFile = targetDir.resolve("app-$variant.apk")
                sourceApk.copyTo(targetFile, overwrite = true)
            }
        }
    }
}

registerFlutterApkCopyTask("debug")
registerFlutterApkCopyTask("release")

fun registerFlutterBundleCopyTask(variant: String) {
    val capitalized = variant.replaceFirstChar { it.uppercaseChar() }
    tasks.matching { it.name == "bundle$capitalized" }.configureEach {
        doLast {
            val flutterProjectDir = project.projectDir.parentFile?.parentFile
                ?: error("Unable to locate Flutter project directory")
            val targetDir = flutterProjectDir.resolve("build/app/outputs/bundle/$variant")
            if (!targetDir.exists()) {
                targetDir.mkdirs()
            }

            val sourceBundle = project.layout.buildDirectory
                .dir("outputs/bundle/$variant")
                .map { it.file("app-$variant.aab").asFile }
                .get()

            if (sourceBundle.exists()) {
                val targetFile = targetDir.resolve("app-$variant.aab")
                sourceBundle.copyTo(targetFile, overwrite = true)
            }
        }
    }
}

registerFlutterBundleCopyTask("release")

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
