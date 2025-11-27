plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.khpt.mcp"
    compileSdk = 36 // ✅ Recommended stable version
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.khpt.mcp"
        minSdk = flutter.minSdkVersion       // ✅ Required for Firebase + STT
        targetSdk = 34    // ✅ Must match compileSdk = 34
        versionCode = flutter.versionCode?.toInt() ?: 1
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    packaging {
        resources {
            excludes += "META-INF/LICENSE"
            excludes += "META-INF/LICENSE.txt"
            excludes += "META-INF/NOTICE"
            excludes += "META-INF/NOTICE.txt"
            excludes += "META-INF/DEPENDENCIES"
        }
    }
}

dependencies {
    // Latest Firebase compatible with FlutterFire
    implementation(platform("com.google.firebase:firebase-bom:33.4.0"))
    implementation("com.google.firebase:firebase-analytics")

    // Required for large apps
    implementation("androidx.multidex:multidex:2.0.1")

    // (Optional) Avoid STT crash on Android 14
    implementation("androidx.core:core-ktx:1.13.1")
}

flutter {
    source = "../.."
}
