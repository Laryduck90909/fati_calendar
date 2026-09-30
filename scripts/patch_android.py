#!/usr/bin/env python3
"""
يعدّل مشروع أندرويد الذي ينشئه `flutter create` (Flutter 3.24، Groovy).

السبب: قالب Flutter 3.24.0 قديم (AGP 7.3.0 / Gradle 7.6.3 / Kotlin 1.7.10)،
والإضافات الحديثة تحتاج أحدث منه:
  - shared_preferences_android 2.4.x يحتاج Kotlin >= 1.9   (وإلا: "incompatible version of Kotlin")
  - desugar_jdk_libs 2.0.4 يحتاج AGP >= 8.x               (وإلا: "This is not a JSON Array")
  - flutter_local_notifications يحتاج core library desugaring + multiDex

السكربت آمن للتشغيل أكثر من مرة، ويفشل بوضوح إذا تغيّرت بنية الملفات.
"""
import re
import sys
from pathlib import Path

AGP_VERSION = "8.3.0"
KOTLIN_VERSION = "1.9.24"
GRADLE_VERSION = "8.4"   # AGP 8.3 يتطلب Gradle 8.4 على الأقل


def die(msg: str):
    sys.exit("ERROR: " + msg)


def read(p: Path) -> str:
    if not p.exists():
        die(f"{p} غير موجود — شغّل flutter create أولاً")
    return p.read_text(encoding="utf-8")


# 1) settings.gradle : نسخ AGP و Kotlin
settings = Path("android/settings.gradle")
s = read(settings)
s2, n1 = re.subn(r'(id\s+"com\.android\.application"\s+version\s+")[^"]+(")', rf"\g<1>{AGP_VERSION}\2", s)
s2, n2 = re.subn(r'(id\s+"org\.jetbrains\.kotlin\.android"\s+version\s+")[^"]+(")', rf"\g<1>{KOTLIN_VERSION}\2", s2)
if n1 != 1 or n2 != 1:
    die("لم أجد أسطر إصدار AGP/Kotlin في android/settings.gradle")
if s2 != s:
    settings.write_text(s2, encoding="utf-8")
    print(f"settings.gradle: AGP {AGP_VERSION}, Kotlin {KOTLIN_VERSION}")

# 2) gradle-wrapper.properties : نسخة Gradle
wrapper = Path("android/gradle/wrapper/gradle-wrapper.properties")
w = read(wrapper)
w2, n = re.subn(r"gradle-[0-9.]+-(all|bin)\.zip", rf"gradle-{GRADLE_VERSION}-\1.zip", w)
if n != 1:
    die("لم أجد distributionUrl في gradle-wrapper.properties")
if w2 != w:
    wrapper.write_text(w2, encoding="utf-8")
    print(f"gradle-wrapper: Gradle {GRADLE_VERSION}")

# 3) app/build.gradle : desugaring + multiDex
path = Path("android/app/build.gradle")
src = read(path)
out = src

if "coreLibraryDesugaringEnabled" not in out:
    out, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled = true", out, count=1)
    if n != 1:
        die("لم أجد كتلة compileOptions")

if "multiDexEnabled" not in out:
    out, n = re.subn(r"(defaultConfig\s*\{)", r"\1\n        multiDexEnabled = true", out, count=1)
    if n != 1:
        die("لم أجد كتلة defaultConfig")

if "desugar_jdk_libs" not in out:
    out = out.rstrip() + '\n\ndependencies {\n    coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.0.4"\n}\n'

if out != src:
    path.write_text(out, encoding="utf-8")
    print("app/build.gradle: desugaring + multiDex")

print("android patch OK")
