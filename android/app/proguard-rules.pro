# Regras pra release builds com R8/ProGuard.
# Mesmo que minifyEnabled = false (default Flutter), deixar essas
# regras prontas evita "tela preta" se ativar minificação no futuro.

# ── Flutter core ──────────────────────────────────────────────────
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.embedding.**

# ── sqflite (banco SQLite) ────────────────────────────────────────
# Plugin usa reflexão pra ponte nativa. Sem keep, R8 remove.
-keep class com.tekartik.sqflite.** { *; }
-keep class com.tekartik.sqflite_common.** { *; }
-dontwarn com.tekartik.sqflite.**

# ── permission_handler ────────────────────────────────────────────
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# ── shared_preferences ────────────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── path_provider ─────────────────────────────────────────────────
-keep class io.flutter.plugins.pathprovider.** { *; }

# ── intl (data/hora localizada) ───────────────────────────────────
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# ── Java reflection genérico (vários plugins usam) ────────────────
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ── Models do projeto — não tem reflexão direta mas é defensivo ──
-keep class com.caixapadaria.padaria_pos.** { *; }
