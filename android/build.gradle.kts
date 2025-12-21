// Top-level build file where you can add configuration options common to all sub-projects/modules.
import org.gradle.api.tasks.Delete

plugins {
    // No plugins at root
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Clean task
val clean by tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
