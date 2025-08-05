plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // ✅ Firebase용 추가
}

android {
    namespace = "com.example.ddobaki_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973" 
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17 // ✅ JDK 17 권장
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.ddobaki_app"
        minSdk = 24 // ✅ Firebase 최소 요구 21 -> 24로 변경 flutter_sound 라이브러리는 최소 24이상 요함
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth")
}