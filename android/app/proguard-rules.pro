-keep class com.hiroshima.pos.mobile.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# Keep all plugins and reflection
-keep class sk.fourq.otaupdate.** { *; }
-dontwarn sk.fourq.otaupdate.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class com.baseflow.permissionhandler.** { *; }
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-keep class app.web.groons.print_bluetooth_thermal.** { *; }
-keep class io.flutter.plugins.sharedpreferences.** { *; }
