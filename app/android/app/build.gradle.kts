import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties, which CI writes from
// repository secrets. It is never committed (see .gitignore).
val keystorePropertiesFile = rootProject.file("key.properties")
// Test builds (E1/E2) are release-mode but signed with the debug key. That is an
// explicit opt-in through ORG_GRADLE_PROJECT_allowDebugSigning=true, set only by
// the build_android workflow's "test" build type. Real release builds never
// fall back to debug keys.
val allowDebugSigning = (findProperty("allowDebugSigning") as String?) == "true"
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

android {
    namespace = "com.zdmgold.statussozo"
    // compileSdk 36 needs Android Gradle Plugin 8.9.1 or newer and Gradle 8.11.1
    // or newer; both are pinned in settings.gradle.kts and the wrapper.
    compileSdk = 36
    // Several plugins now require NDK 27. Flutter 3.29.2's default is older.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.zdmgold.statussozo"
        minSdk = 29
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Google's sample AdMob app ID. A live release build passes its own
        // through the admobAppId Gradle property.
        manifestPlaceholders["admobAppId"] =
            (project.findProperty("admobAppId") as String?)
                ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (!keystorePropertiesFile.exists() && allowDebugSigning) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
}

// A release build must never silently fall back to debug keys.
gradle.taskGraph.whenReady {
    val releaseRequested = allTasks.any {
        Regex("(assemble|bundle|package)Release").containsMatchIn(it.name)
    }
    if (releaseRequested && !keystorePropertiesFile.exists() && !allowDebugSigning) {
        throw GradleException(
            "Release build requested but android/key.properties is missing. " +
                "CI writes it from the signing secrets.",
        )
    }
}

flutter {
    source = "../.."
}
