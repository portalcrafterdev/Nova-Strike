# Nova Strike - R8 rules
#
# Flutter's Gradle plugin picks this file up automatically when it exists
# (FlutterPlugin.kt adds "${project.projectDir}/proguard-rules.pro" to the
# release build type), so nothing in build.gradle.kts has to reference it.
#
# Three rule sets are already applied before this one:
#
#   1. proguard-android-optimize.txt   AGP's defaults, added by Flutter
#   2. flutter_proguard_rules.pro      keeps every FlutterPlugin implementation
#                                      and silences io.flutter.plugin / android.*
#   3. every dependency's own consumer rules, pulled out of its AAR
#
# That third set is why this file is short. The libraries this game uses ship
# the rules they need, and duplicating them here would only add noise. What is
# already covered, verified by reading the merged configuration.txt that R8
# writes to build/app/outputs/mapping/release/:
#
#   google_mobile_ads / play-services-ads
#       keeps ClientApi and every MediationAdapter, CustomEvent and
#       MediationAdNetworkAdapter implementation, so mediation adapters loaded
#       by reflection survive.
#   games_services
#       keeps the fields of AchievementItemData, LeaderboardScoreData,
#       PlayerData and SavedGame. This one matters more than it looks: the
#       plugin hands those data classes to Gson().toJson(), and the Dart side
#       reads the result back by key name (json["playerID"], json["displayName"]
#       and so on). Gson takes its keys from the field names, so renamed fields
#       would produce {"a":..,"b":..} and every value would decode to null, in
#       release only, with no build warning. The plugin author already guards
#       against it; the note is here so nobody "cleans up" that rule later.
#   kotlin coroutines, gson, room, work-runtime, datastore, lifecycle,
#   androidx.*
#       all ship their own.
#   audioplayers / flame_audio
#       talks to MediaPlayer and AudioTrack directly, no reflection, nothing
#       needed.
#   shared_preferences
#       uses SharedPreferences and DataStore directly, nothing needed.
#
# A blanket "-keep class ** { *; }" would make all of that moot by switching
# shrinking off, which is the opposite of why minification is on. Rules go here
# only when something is genuinely reached by reflection, JNI, or a name.

# ---------------------------------------------------------------------------
# Readable crash reports
# ---------------------------------------------------------------------------
# Nothing in the merged configuration asks for these, so add them here. Without
# SourceFile and LineNumberTable, a Play Console stack trace has no line numbers
# to restore, and uploading mapping.txt cannot invent them. Renaming every
# source file to the single literal "SourceFile" keeps the original file names
# out of the shipped binary while leaving mapping.txt able to put them back.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ---------------------------------------------------------------------------
# Room, reached through WorkManager, reached through the ads SDK
# ---------------------------------------------------------------------------
# Not obvious from pubspec.yaml: google_mobile_ads pulls in
# play-services-ads-api, which pulls androidx.work:work-runtime, which is built
# on Room. Room does not construct its database directly. It builds the class
# name and loads it, roughly:
#
#     Class.forName("androidx.work.impl.WorkDatabase" + "_Impl")
#          .getDeclaredConstructor().newInstance()
#
# Nothing in the bytecode references WorkDatabase_Impl, so R8 in full mode,
# which is the AGP 8 default, strips it. WorkManager is then initialised by
# androidx.startup at process start, fails, and the app dies before the first
# frame with:
#
#     Unable to get provider androidx.startup.InitializationProvider:
#     Failed to create an instance of androidx.work.impl.WorkDatabase
#
# work-runtime 2.7.0 ships Room 2.2.5, whose consumer rules predate R8 full
# mode and do not cover this. Keeping every RoomDatabase subclass and its
# no-argument constructor is the documented fix and costs a handful of classes.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-dontwarn androidx.room.paging.**

# ---------------------------------------------------------------------------
# The game's own Android entry point
# ---------------------------------------------------------------------------
# MainActivity is named in AndroidManifest.xml and instantiated by the system
# from that string. AGP normally infers this from the manifest; keeping it
# explicitly costs one class and removes the doubt.
-keep class com.portalcrafter.novastrike.MainActivity { *; }

# ---------------------------------------------------------------------------
# Not needed today, kept as a note
# ---------------------------------------------------------------------------
# Deferred components / Play Feature Delivery. The Flutter embedding references
# com.google.android.play.core.* only when split install is used. This build
# does not use it and R8 reports no missing classes, so the rule stays
# commented out. Uncomment if a build ever warns about those classes.
# -dontwarn com.google.android.play.core.**
# -keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
#
# AdMob mediation. Adding a mediation network later brings an adapter that is
# loaded by name. The AdMob consumer rules already keep anything implementing
# the adapter interfaces, so a new network should need nothing here, but this
# is where it would go.
