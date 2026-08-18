// LLM-CONTEXT:BEGIN
// FILE: android/app/build.gradle.kts
// ROLE: Owns build.gradle behavior within the platform-shell subsystem.
// DOMAIN: platform-shell
// SECURITY-INVARIANT: Keep platform permissions and generated integration boundaries minimal and reproducible.
// CHANGE-GUARD: Preserve public contracts, bounded inputs, lifecycle cleanup, and fail-closed behavior; run analysis and relevant tests after edits.
// DOCS: See /docs/llm-context-schema.md and the nearest mermaid.md architecture map.
// LLM-CONTEXT:END
import java.io.FileInputStream
import java.util.Properties
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasLocalReleaseSigning = keystorePropertiesFile.exists()
if (hasLocalReleaseSigning) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun requireSigningValues(
    source: String,
    values: Map<String, String?>,
): Map<String, String> {
    val missing = values.filterValues { it.isNullOrBlank() }.keys.sorted()
    if (missing.isNotEmpty()) {
        throw GradleException(
            "$source is incomplete; missing ${missing.joinToString(", ")}.",
        )
    }
    return values.mapValues { checkNotNull(it.value).trim() }
}

val environmentSigningValues = mapOf(
    "storeFile" to System.getenv("NAZA_ANDROID_KEYSTORE_PATH"),
    "storePassword" to System.getenv("NAZA_ANDROID_KEYSTORE_PASSWORD"),
    "keyAlias" to System.getenv("NAZA_ANDROID_KEY_ALIAS"),
    "keyPassword" to System.getenv("NAZA_ANDROID_KEY_PASSWORD"),
)
val hasEnvironmentReleaseSigning =
    environmentSigningValues.values.any { !it.isNullOrBlank() }
val releaseSigning = when {
    hasLocalReleaseSigning -> requireSigningValues(
        "android/key.properties",
        mapOf(
            "storeFile" to keystoreProperties.getProperty("storeFile"),
            "storePassword" to keystoreProperties.getProperty("storePassword"),
            "keyAlias" to keystoreProperties.getProperty("keyAlias"),
            "keyPassword" to keystoreProperties.getProperty("keyPassword"),
        ),
    )
    hasEnvironmentReleaseSigning -> requireSigningValues(
        "Android release-signing environment",
        environmentSigningValues,
    )
    else -> null
}
val releaseStoreFile = releaseSigning?.getValue("storeFile")?.let(rootProject::file)
if (releaseStoreFile != null && !releaseStoreFile.isFile) {
    throw GradleException("Android release keystore does not exist: $releaseStoreFile")
}

android {
    namespace = "com.qroadscan.lightcal"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.qroadscan.lightcal"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += "arm64-v8a"
        }
    }

    signingConfigs {
        if (releaseSigning != null) {
            create("release") {
                keyAlias = releaseSigning.getValue("keyAlias")
                keyPassword = releaseSigning.getValue("keyPassword")
                storeFile = checkNotNull(releaseStoreFile)
                storePassword = releaseSigning.getValue("storePassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            if (releaseSigning != null) {
                signingConfig = signingConfigs.getByName("release")
            }
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
