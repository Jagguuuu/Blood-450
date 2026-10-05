# Blood450 — Phase 3A: Environment Recovery & Build Diagnostics

**Mode:** Diagnose only — no project files modified  
**Date:** 2026-08-06  
**Baselines:** `BLOOD450_AUDIT_FOR_CHATGPT.md`, `BLOOD450_PHASE2_FEATURE_CONTRACT.md`

---

## Verdict (read this first)

| Question | Answer |
|----------|--------|
| Can Flutter build/launch Android **today**? | **YES** |
| Evidence | Terminal: `√ Built ...app-debug.apk` → installed on `sdk gphone16k x86 64` → Flutter VM Service up |
| Was the original failure project logic? | **NO** |
| Original root causes | **Environment:** invalid `JAVA_HOME` (`...\bin`) + **Windows Gradle transforms file lock** |
| Do project Gradle versions look broken? | **NO** — AGP 8.11.1 / Gradle 8.13 / Java 17 target / Flutter 3.38.7 are compatible |
| Still risky without cleanup? | **YES** — `JAVA_HOME` still wrong for raw `gradlew`; transforms locks can recur |

**Phase 3A conclusion:** Environment is now *capable* of building. Do **not** change project Gradle/deps for build recovery. Stabilize env vars + antivirus/cache hygiene, then move to Phase 4 (runtime).

---

## 1. Environment Summary

| Item | Detected value | Status |
|------|----------------|--------|
| OS | Windows 11 Pro 64-bit, 25H2 (10.0.26200) | OK |
| Flutter | 3.38.7 stable @ `C:\Users\Avs-Mohandas\.android\flutter` | OK |
| Dart | 3.10.7 | OK (matches `pubspec` `^3.10.7`) |
| `flutter config` android-sdk | `C:\Users\Avs-Mohandas\AppData\Local\Android\Sdk` | OK |
| `flutter config` jdk-dir | `C:\Program Files\Android\Android Studio\jbr` (JDK **21**) | OK for Flutter |
| `JAVA_HOME` (env) | `C:\Users\Avs-Mohandas\Desktop\Java jdk\jdk-17.0.13\bin` | **INVALID** (must be JDK root, not `\bin`) |
| `java` on PATH | Oracle javapath → reports **17.0.12** | Works, but not what Flutter uses |
| Alternate JDK | `C:\Program Files\Java\jdk-17` exists | Available |
| Desktop JDK root | `...\Desktop\Java jdk\jdk-17.0.13` exists (`javac.exe` present) | Valid root if JAVA_HOME fixed |
| `ANDROID_HOME` | `C:\Users\Avs-Mohandas\AppData\Local\Android\Sdk` | OK |
| `ANDROID_SDK_ROOT` | unset | OK (ANDROID_HOME set) |
| `D:\Android\Sdk` | **does not exist** | Earlier `flutter config --android-sdk "D:\Android\Sdk"` was a dead path; config now points to C: |
| Android SDK | 36.0.0 toolchain; platforms 34/35/36/36.1; build-tools 34/35/36 | OK |
| NDK | `28.2.13676358` installed | Matches Flutter default |
| Emulator | `Medium_Phone` AVD; device `emulator-5554` Android 17 (API 37) | OK / connected |
| Licenses | All accepted (`flutter doctor`) | OK |
| Visual Studio | Incomplete install | **Warning only** (Windows desktop apps, not Android) |
| Network | OK | OK |
| Project path | `D:\...\ayh_mobile` (spaces in path) | Works; can worsen file-lock quirks |
| Pub-cache vs project drive | Project **D:**, cache typically **C:** | Mitigated in `build.gradle.kts` / `kotlin.incremental=false` |

### Flutter doctor (summary)

- Flutter / Android toolchain / Chrome / Devices / Network: **pass**
- Visual Studio: **fail** (desktop only — ignore for mobile revival)
- Connected: emulator + Windows + Chrome + Edge

### Android project files (inspected, not changed)

| File | Finding |
|------|---------|
| `settings.gradle.kts` | AGP **8.11.1**, Kotlin **2.2.20** |
| `app/build.gradle.kts` | Java **17**; `compileSdk`/`minSdk`/`targetSdk` from Flutter; app id `com.example.ayh_mobile` |
| `gradle-wrapper.properties` | Gradle **8.13** |
| `gradle.properties` | 4G heap; `daemon=false`; `parallel=false`; `caching=false`; Kotlin incremental off |
| `local.properties` | SDK = C: Local Android Sdk; Flutter SDK = `.android\flutter` |
| `AndroidManifest.xml` | INTERNET + location; `usesCleartextTraffic=true` (needed for `http://10.0.2.2`) |
| Root `build.gradle.kts` | Redirects build dir; avoids cross-drive plugin build dirs |

---

## 2. Version Compatibility Matrix

| Component | Project / Flutter expects | Machine has | Compatible? |
|-----------|---------------------------|-------------|-------------|
| Flutter | ~3.38.x | 3.38.7 | Yes |
| Dart | ^3.10.7 | 3.10.7 | Yes |
| Gradle | 8.13 | Wrapper downloads 8.13 | Yes |
| AGP | 8.11.1 | (via settings) | Yes with Gradle 8.13 |
| Kotlin | 2.2.20 | (via settings) | Yes |
| compileSdk | Flutter default **36** | android-36 / 36.1 installed | Yes |
| targetSdk | **36** | OK | Yes |
| minSdk | **24** | OK | Yes |
| NDK | **28.2.13676358** | Installed | Yes |
| Java for `app` compile | **17** | Studio JBR **21** (Flutter) / PATH Java 17 | Yes (21 can compile Java 17 bytecode) |
| JAVA_HOME for raw Gradle | JDK **root** | Points to `\bin` | **No** (breaks `.\gradlew` if Flutter JDK not used) |

**No project version bump required for Phase 3A.**

---

## 3. Detected Build Errors

### A. Historical (this revival, earlier terminal) — RESOLVED for Flutter path

| Error | Classification | Status now |
|-------|----------------|------------|
| `JAVA_HOME is set to an invalid directory: ...\jdk-17.0.13\bin` | Environment / Java | **Still true in env**, but Flutter bypasses via `jdk-dir` → Studio JBR |
| `Could not move temporary workspace ...\transforms\...` | Windows File Lock / Gradle cache | **Not reproducing** on latest successful `flutter run` |
| Transforms delete: “file is being used by another process” | Windows File Lock | Historical; cache currently exists (~1736 transform entries) |

### B. Latest diagnostic run (this phase)

| Step | Result |
|------|--------|
| `flutter clean` | Success |
| `flutter pub get` | Success (`Got dependencies!`) |
| Device pick | Once quit when only desktop/web listed; later emulator available |
| `flutter run` (emulator) | **Success** — APK built (~404s), installed, app running |
| `gradlew assembleDebug` | **Not re-run** while app session active (would risk re-locking cache); Flutter already proved assembleDebug |

### C. Non-blocking noise

| Item | Impact |
|------|--------|
| `Skipped N frames` / `Davey!` on emulator | Perf warning, not build failure |
| 71 packages “newer versions available” | Pub constraint noise — **do not upgrade in Phase 3** |
| Incomplete Visual Studio | Windows desktop only |

---

## 4. Root Cause Analysis

### Original failure chain

1. **`JAVA_HOME` → `...\bin`**  
   - Raw `gradlew` fails immediately.  
   - Confidence: **High**

2. **Gradle transforms rename locked by another process** (Java/Gradle daemon, Defender, indexer)  
   - Classic Windows symptom under `~\.gradle\caches\8.14\transforms`.  
   - Confidence: **High**

3. **Not caused by** wrong AGP/Gradle/Kotlin in repo, missing SDK 36, missing NDK, Flutter/Dart mismatch, or app Dart code.  
   - Confidence: **High** (successful assemble + install proves this)

### Why it works now

- Flutter uses configured **`jdk-dir` = Android Studio JBR**, so invalid `JAVA_HOME` does not block `flutter run`.
- Emulator is up; SDK/licenses/NDK present.
- Cache lock either cleared or not contended during latest build.
- Project Gradle files already include Windows D:/C: mitigations.

### Residual root risks (not fixed)

1. `JAVA_HOME` still invalid → any script/`gradlew` outside Flutter will fail.  
2. Transforms lock can return if Defender scans `~\.gradle` or multiple Gradle/Java processes fight.  
3. `org.gradle.daemon=false` → very slow builds (404s observed); not a functional blocker.  
4. Stale mental model of `D:\Android\Sdk` — folder missing; real SDK is on C:.

---

## 5. Blocker Classification

| Blocker | Class | Severity now | Action needed? |
|---------|-------|--------------|----------------|
| Invalid `JAVA_HOME` (`...\bin`) | Environment / Java | Medium (latent) | Yes — fix env, not project |
| Transforms file lock | Windows File Lock / Gradle | Low now / High if returns | Hygiene + Defender exclusion |
| Missing `D:\Android\Sdk` | Environment / SDK | None (config corrected to C:) | Avoid re-pointing to D: |
| Incomplete Visual Studio | Environment | None for Android | Ignore for mobile |
| Project AGP/Gradle/Kotlin | Project Configuration | None | Do not change |
| Dependency versions | Dependency | None | Do not upgrade |
| Emulator | Emulator | None | Keep AVD running for Phase 4 |
| Network | Network | None | — |
| Permissions / licenses | Permissions | None | Already accepted |
| Path with spaces (`Latest Helloid (1)`) | Windows / Other | Low | Prefer later relocate; not required now |

---

## 6. Ordered Fix Plan (DO NOT APPLY IN THIS PHASE — recommendations only)

### P0 — Fix `JAVA_HOME` permanently (Environment)

- **Do:** Set User/System `JAVA_HOME` =  
  `C:\Users\Avs-Mohandas\Desktop\Java jdk\jdk-17.0.13`  
  **or** `C:\Program Files\Java\jdk-17`  
  (no `\bin`). Ensure `%JAVA_HOME%\bin` is on PATH.  
- **Reason:** Prevents `gradlew` / IDE / scripts from failing; aligns with project Java 17.  
- **Expected:** `echo %JAVA_HOME%` shows root; `.\gradlew --version` works in new terminal.  
- **Confidence:** High  

### P0 — Keep Flutter JDK explicit (Environment)

- **Do:** Leave `flutter config --jdk-dir="C:\Program Files\Android\Android Studio\jbr"` (already set) **or** point to a JDK 17 root after JAVA_HOME fix.  
- **Reason:** Flutter currently builds via Studio JBR 21 successfully.  
- **Expected:** `flutter doctor -v` continues showing a valid Java binary.  
- **Confidence:** High  

### P1 — Defend against transforms lock (Windows File Lock)

- **Do:** Add Windows Defender exclusions for:  
  - `C:\Users\Avs-Mohandas\.gradle\`  
  - `C:\Users\Avs-Mohandas\.android\flutter\`  
  - project `ayh_mobile\`  
- Before clean rebuilds: stop stray `java.exe` / close duplicate Gradle; optional delete only if lock returns: `~\.gradle\caches\8.14\transforms`  
- **Reason:** This was the hard build killer earlier.  
- **Expected:** No more “Could not move temporary workspace”.  
- **Confidence:** High  

### P1 — Confirm single Android SDK (SDK)

- **Do:** Keep SDK at `C:\Users\Avs-Mohandas\AppData\Local\Android\Sdk`. Do **not** set Flutter android-sdk to `D:\Android\Sdk` unless that folder is fully installed.  
- **Reason:** `D:\Android\Sdk` does not exist.  
- **Expected:** `local.properties` and `flutter doctor` agree on C: path.  
- **Confidence:** High  

### P2 — Optional build speed only (Gradle / Project — later, not required)

- **Do (Phase 3B only if desired):** Consider `org.gradle.daemon=true` (and maybe caching) after env is stable.  
- **Reason:** 6+ minute assemble is painful; daemon=false was likely anti-lock mitigation.  
- **Expected:** Faster incremental builds; watch for lock recurrence.  
- **Confidence:** Medium — **do not do this until P0/P1 done**  

### P3 — Project configuration changes

- **Do:** **None for build recovery.**  
- **Reason:** Successful APK proves config is fine. App id / signing / dep upgrades belong in Phase 6.  
- **Expected:** N/A  

### P3 — Visual Studio

- **Do:** Ignore unless you need `flutter run -d windows`.  
- **Reason:** Not on mobile critical path.  

---

## Diagnostic commands for Phase 3B / re-check

```powershell
# After fixing JAVA_HOME in a NEW terminal:
echo $env:JAVA_HOME
java -version
flutter doctor -v
cd "D:\Latest Helloid (1)\Latest Helloid\blood-450-main\blood-450-main\ayh_mobile"
flutter devices
flutter run -d emulator-5554
```

Only if `flutter run` fails again with transforms lock:

```powershell
flutter config --jdk-dir="C:\Program Files\Android\Android Studio\jbr"
# stop java processes, then clear transforms, then rebuild
```

---

## Phase gate

| Gate | Met? |
|------|------|
| Environment can build Android debug APK | **Yes** |
| Emulator available and app installable | **Yes** |
| Project Gradle must be edited to proceed | **No** |
| Ready for Phase 4 (runtime / API) | **Yes**, after optional P0 JAVA_HOME fix for hygiene |

**Recommendation:** Apply **P0 JAVA_HOME** + **P1 Defender exclusions** manually (env only), then start **Phase 4** with Django on `:8000` and the Phase 2 checklists. Skip package upgrades and Gradle modernization until Phase 6.
