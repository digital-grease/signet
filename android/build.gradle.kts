allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Flutter's integration_test plugin is a dev dependency, but assembleRelease
// still builds it (flutter/flutter#56591), and it declares dynamic versions
// (runner 1.2+, rules 1.2+, espresso-core 3.3+). A dynamic version needs a
// live version listing, so it fails the offline pass of
// scripts/reproducible-build.sh (even with Gradle --offline), and it can
// drift between builds. Pinned to what they resolve to today; revisit when
// the pinned Flutter changes integration_test's dependencies.
subprojects {
    if (project.name == "integration_test") {
        configurations.configureEach {
            resolutionStrategy.force(
                "androidx.test:runner:1.3.0",
                "androidx.test:rules:1.2.0",
                "androidx.test.espresso:espresso-core:3.3.0",
            )
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
