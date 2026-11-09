import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.daike.shell_video_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.daike.shell_video_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // 只打包主流手机架构，显著减小 APK 体积
        ndk {
            // 仅保留 64 位 ARM（2020 年后手机全部支持）：
            // 去掉 x86_64（模拟器）+ armeabi-v7a（32 位），APK 约缩小 84MB
            abiFilters.clear()
            abiFilters.addAll(listOf("arm64-v8a"))
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // 不启用代码混淆/资源压缩，避免与 Flutter 插件默认配置冲突
            isMinifyEnabled = false
            isShrinkResources = false
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

// ─────────────────────────────────────────────────────────────────────────────
// 体积修复：AGP 的 stripReleaseDebugSymbols 不会处理 Flutter 引擎的 libflutter.so
// （未裁剪约 157MB/ABI，导致 release APK 变成 550MB+）。
// 在「合并原生库」之后、「strip 任务」之前，用 NDK 的 llvm-strip 兜底裁剪到 ~11MB。
// 修复后 APK 约 90~100MB。如不需要，删除本段即可。
// ─────────────────────────────────────────────────────────────────────────────
val stripFlutterEngine by tasks.registering {
    val mergedDir = layout.buildDirectory.dir(
        "intermediates/merged_native_libs/release/mergeReleaseNativeLibs/out/lib"
    )
    doLast {
        val sdkDir = System.getenv("ANDROID_HOME")
            ?: System.getenv("ANDROID_SDK_ROOT")
            ?: ""
        val ndkParent = File(sdkDir, "ndk")
        val ndkDir = ndkParent.listFiles()
            ?.filter { it.isDirectory }
            ?.sortedBy { it.name }
            ?.lastOrNull()
        if (ndkDir == null) {
            logger.warn("[stripFix] 找不到 NDK 目录: ${ndkParent.absolutePath}")
            return@doLast
        }
        val stripExe = File(
            ndkDir,
            "toolchains/llvm/prebuilt/windows-x86_64/bin/llvm-strip.exe"
        )
        if (!stripExe.exists()) {
            logger.warn("[stripFix] 找不到 llvm-strip: ${stripExe.absolutePath}")
            return@doLast
        }
        val libsDir = mergedDir.get().asFile
        libsDir.listFiles()?.forEach { abiDir ->
            val so = File(abiDir, "libflutter.so")
            if (so.exists() && so.length() > 50L * 1024 * 1024) {
                val before = so.length() / 1024 / 1024
                val code = ProcessBuilder(
                    stripExe.absolutePath, "--strip-unneeded", so.absolutePath
                ).inheritIO().start().waitFor()
                logger.lifecycle(
                    "[stripFix] ${abiDir.name}/libflutter.so $before MB -> " +
                        "${so.length() / 1024 / 1024} MB (exit $code)"
                )
            }
        }
    }
}

tasks.configureEach {
    when (name) {
        "mergeReleaseNativeLibs" -> finalizedBy(stripFlutterEngine)
        "stripReleaseDebugSymbols" -> mustRunAfter(stripFlutterEngine)
    }
}
