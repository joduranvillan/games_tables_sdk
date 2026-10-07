plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    compileSdk = 34
    namespace = "org.opentable.network.nearby"

    defaultConfig {
        minSdk = 21
        @Suppress("DEPRECATION")
        targetSdk = 34
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

tasks.whenTaskAdded {
    if (name == "assembleRelease") {
        doLast {
            val aarDir = layout.buildDirectory.dir("outputs/aar").get().asFile
            val srcAar = aarDir.resolve("${project.name}-release.aar")
            val destAar = aarDir.resolve("OpenTableNearby-release.aar")
            if (srcAar.exists() && srcAar != destAar) {
                srcAar.copyTo(destAar, overwrite = true)
            }
        }
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.2.2.stable")
    implementation("com.google.android.gms:play-services-nearby:19.3.0")
    implementation("org.jetbrains.kotlin:kotlin-stdlib:1.9.22")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.11.0")
    testImplementation("org.mockito.kotlin:mockito-kotlin:5.2.1")
}
