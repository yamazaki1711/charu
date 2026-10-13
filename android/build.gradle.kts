allprojects {
    repositories {
        maven { url = uri("file:///Users/oleg/flutter-maven-local") }
        // Зеркала aliyun первыми — прямые google()/mavenCentral() из этой сети
        // качаются часами. Убрать зеркала можно без последствий для сборки.
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
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

// Форс compileSdk 36 для всех android-подпроектов (плагинов): требует
// flutter_plugin_android_lifecycle 2.0.33+. Убрать после обновления плагинов.
// Блок обязан идти ДО subprojects { evaluationDependsOn(":app") }.
subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            androidExt.javaClass.methods
                .firstOrNull { it.name == "setCompileSdk" }
                ?.invoke(androidExt, 36)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
