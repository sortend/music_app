package app.musicplayer;

import io.flutter.embedding.android.FlutterActivity;

/**
 * Deliberately Java rather than Kotlin: no Kotlin Gradle plugin is applied in
 * app/build.gradle.kts, so a .kt source here would only compile on AGP
 * versions that enable built-in Kotlin support. Java always compiles.
 *
 * <p>To switch back to Kotlin, first add {@code id("org.jetbrains.kotlin.android")}
 * to app/build.gradle.kts (with a version declared in settings.gradle.kts).
 */
public class MainActivity extends FlutterActivity {
}
