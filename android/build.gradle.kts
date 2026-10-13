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

// The Flutter plugins' Java compiles with JDK 21 too, the F-Droid
// buildserver's JDK (see the toolchain note in app/build.gradle.kts); their
// bytecode ends up in the APK. :app sets its own toolchain, which AGP
// finalizes, so it is skipped here.
subprojects {
    if (project.name == "app") return@subprojects
    tasks.withType<JavaCompile>().configureEach {
        javaCompiler.set(
            project.extensions.getByType<JavaToolchainService>().compilerFor {
                languageVersion.set(JavaLanguageVersion.of(21))
            }
        )
    }
}

// Flutter's integration_test plugin is a dev dependency, but assembleRelease
// still builds it (flutter/flutter#56591), and it declares dynamic versions
// (runner 1.2+, rules 1.2+, espresso-core 3.3+). A dynamic version resolves
// to whatever is newest on the day, so two builds of the same commit can
// differ, and it cannot resolve offline at all. Pinned to what they resolve
// to today; revisit when the pinned Flutter changes integration_test's
// dependencies.
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
