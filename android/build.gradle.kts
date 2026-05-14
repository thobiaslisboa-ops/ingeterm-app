import org.gradle.api.tasks.Delete
import org.gradle.api.file.Directory

buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Gradle Plugin para Android y Google Services
        classpath("com.android.tools.build:gradle:8.2.0")
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Cambiar el directorio de build principal
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.buildDir = newBuildDir.asFile

// Cambiar buildDir para todos los subproyectos
subprojects {
    buildDir = newBuildDir.dir(project.name).asFile

    // Forzar Java 17 en todas las tareas Java de cada subproyecto
    afterEvaluate {
        tasks.withType<JavaCompile>().configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}

// Evaluar subproyectos antes que app
subprojects {
    evaluationDependsOn(":app")
}

// Tarea clean
tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
