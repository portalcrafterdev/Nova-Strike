# Nova Strike - R8 / ProGuard rules
#
# Flutter's Gradle plugin picks this file up automatically when it exists
# (FlutterPlugin.kt appends "${project.projectDir}/proguard-rules.pro" to the
# release build type), so build.gradle.kts does not reference it.
#
# Applied before this file, in order:
#   1. proguard-android-optimize.txt   AGP defaults
#   2. flutter_proguard_rules.pro      keeps FlutterPlugin implementations
#   3. each dependency's own consumer rules, unpacked from its AAR
#
# Many rules below overlap that third set. They are written out per package
# anyway so the protection is visible here rather than depending on what a
# dependency happens to ship, and so a library bump that drops a consumer rule
# cannot quietly break a release build.
#
# What is deliberately NOT here: "-keep class ** { *; }". That switches
# shrinking off across the board and hands back everything minification buys.
# Every rule below is scoped to a package or to a reflective surface.

# ===========================================================================
# Global attributes
# ===========================================================================
# SourceFile and LineNumberTable make Play Console crash reports resolvable
# against mapping.txt. Without them a stack trace has no line numbers, and
# uploading mapping.txt cannot invent what was stripped. Renaming every source
# file to the literal "SourceFile" keeps real file names out of the binary.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Reflection, generics and annotation processing all read these back at runtime.
-keepattributes Signature
-keepattributes Exceptions
-keepattributes InnerClasses,EnclosingMethod
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
-keepattributes AnnotationDefault

# ===========================================================================
# Cross-cutting reflective surfaces
# ===========================================================================
# Anything explicitly annotated to survive.
-keep @androidx.annotation.Keep class * { *; }
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

# JNI: a native method is resolved by name from C, so the name has to survive.
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# Enums: values() and valueOf() are called reflectively by the framework and by
# Kotlin's when-mapping tables.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable CREATOR fields are looked up by name by the platform.
-keepclassmembers class * implements android.os.Parcelable {
    public static final ** CREATOR;
}

# Serializable plumbing, read by name if anything ever serialises.
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# View subclasses inflated from XML by name, and their setters.
-keepclassmembers class * extends android.view.View {
    void set*(***);
    *** get*();
}

# ===========================================================================
# The game's own code
# ===========================================================================
# MainActivity is named as a string in AndroidManifest.xml. The rest of the
# package is small and keeping it removes any doubt about the entry points.
-keep class com.portalcrafter.novastrike.** { *; }

# ===========================================================================
# Flutter engine and embedding
# ===========================================================================
# The embedding is reached from native code and from the generated plugin
# registrant. flutter_proguard_rules.pro already keeps FlutterPlugin
# implementations; this widens it to the embedding and plugin surfaces.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# ===========================================================================
# google_mobile_ads / Google Mobile Ads SDK / UMP
# ===========================================================================
# The ads SDK resolves ClientApi and every mediation adapter by name. Its own
# consumer rules cover this; restated so a future mediation network works
# without a debugging session.
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.ump.** { *; }
-keep class io.flutter.plugins.googlemobileads.** { *; }
-keep class * extends com.google.android.gms.ads.mediation.MediationAdapter { *; }
-keep class * implements com.google.android.gms.ads.mediation.MediationAdapter { *; }
-keep class * implements com.google.android.gms.ads.mediation.customevent.CustomEvent { *; }
-dontwarn com.google.android.gms.ads.**

# ===========================================================================
# games_services / Play Games Services
# ===========================================================================
# The plugin passes its model classes to Gson().toJson(), and Dart reads the
# result back by key name (json["playerID"], json["displayName"]). Gson takes
# those keys from the field names, so renamed fields would produce
# {"a":..,"b":..} and every value would decode to null, in release only, with
# no build warning. The plugin ships this rule; it is restated because the
# failure is silent and a library bump must not be able to remove it.
-keep class com.abedalkareem.games_services.** { *; }
-keep class com.abedalkareem.games_services.models.** { <fields>; }
-keep class com.google.android.gms.games.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.**

# ===========================================================================
# Gson
# ===========================================================================
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
# TypeToken carries its type argument in the generic signature only.
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
-dontwarn com.google.gson.**

# ===========================================================================
# androidx.work + Room + startup + datastore
# ===========================================================================
# Not obvious from pubspec.yaml: google_mobile_ads pulls play-services-ads-api,
# which pulls androidx.work:work-runtime, which is built on Room.
#
# Room never constructs its database directly. It builds the name and loads it:
#
#     Class.forName("androidx.work.impl.WorkDatabase" + "_Impl")
#          .getDeclaredConstructor().newInstance()
#
# Nothing in the bytecode references WorkDatabase_Impl, so R8 in full mode,
# the AGP 8 default, removes it. androidx.startup then initialises WorkManager
# at process start, that fails, and the app dies before the first frame with:
#
#     Unable to get provider androidx.startup.InitializationProvider:
#     Failed to create an instance of androidx.work.impl.WorkDatabase
#
# work-runtime 2.7.0 ships Room 2.2.5, whose consumer rules predate full mode
# and do not cover this. This was a real crash on every launch, not a
# precaution.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.RoomDatabase { *; }
-keep class * extends androidx.startup.Initializer { *; }
-keep class androidx.startup.** { *; }
-keep class androidx.work.** { *; }
-keep class androidx.datastore.** { *; }
-dontwarn androidx.room.paging.**

# ===========================================================================
# Kotlin and coroutines
# ===========================================================================
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlin.**
-dontwarn kotlinx.coroutines.**

# ===========================================================================
# audioplayers / flame_audio
# ===========================================================================
-keep class xyz.luan.audioplayers.** { *; }

# ===========================================================================
# shared_preferences
# ===========================================================================
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ===========================================================================
# webview_flutter, pulled in transitively by google_mobile_ads
# ===========================================================================
-keep class io.flutter.plugins.webviewflutter.** { *; }

# ===========================================================================
# Not needed today, kept as a note
# ===========================================================================
# Deferred components / Play Feature Delivery. The Flutter embedding touches
# com.google.android.play.core.* only when split install is used. This build
# does not, and R8 reports no missing classes, so these stay commented out.
# -dontwarn com.google.android.play.core.**
# -keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
