// Top-level build.gradle.kts for Flutter project with Java 17 support

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin compatible with Java 17
        classpath("com.android.tools.build:gradle:8.1.0")
    }
}

// All projects repositories
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory (optional)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Subprojects build directory setup
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Ensure app project is evaluated first
subprojects {
    project.evaluationDependsOn(":app")
}

// Clean task
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
