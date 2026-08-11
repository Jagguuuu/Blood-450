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
    // Avoid redirecting plugin build dirs across Windows drive roots
    // (project on D:, pub-cache on C:) which breaks Gradle file collections.
    val projectDrive = project.projectDir.absolutePath.take(1)
    val buildDrive = newBuildDir.asFile.absolutePath.take(1)
    if (projectDrive.equals(buildDrive, ignoreCase = true)) {
        val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
        project.layout.buildDirectory.value(newSubprojectBuildDir)
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
