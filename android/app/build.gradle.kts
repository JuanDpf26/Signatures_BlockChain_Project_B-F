import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de publicación: se lee de variables de entorno (GitHub Actions) o de
// android/key.properties en tu PC. Si no hay llave, se usa la de depuración.
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
fun signingValue(env: String, prop: String): String? =
    System.getenv(env)?.takeIf { it.isNotBlank() } ?: keyProps.getProperty(prop)
val releaseStoreFile = signingValue("ANDROID_KEYSTORE_PATH", "storeFile")
val releasePassword = signingValue("ANDROID_KEY_PASSWORD", "password")

android {
    namespace = "com.example.frontend"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Identificador de la app en Android (debe coincidir con el cliente OAuth de Google)
        applicationId = "co.docblocksign.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseStoreFile != null && releasePassword != null) {
            create("release") {
                storeFile = file(releaseStoreFile)
                storePassword = releasePassword
                keyAlias = signingValue("ANDROID_KEY_ALIAS", "keyAlias") ?: "docblocksign"
                keyPassword = releasePassword
            }
        }
    }

    buildTypes {
        release {
            // Llave fija: la huella SHA-1 no cambia entre versiones (necesario para
            // el inicio de sesión con Google y para actualizar la app sin desinstalar)
            signingConfig = if (releaseStoreFile != null && releasePassword != null)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

