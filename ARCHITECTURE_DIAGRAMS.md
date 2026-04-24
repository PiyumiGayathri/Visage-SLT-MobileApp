# Mock Location Detection - Architecture & Diagrams

## System Architecture Overview

### High-Level Architecture Diagram

```
┌──────────────────────────────────────────────────────────────────┐
│                         FLUTTER UI LAYER                         │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │           FaceVerificationScreen Widget                     │ │
│  │                                                             │ │
│  │  • Camera preview with face detection                      │ │
│  │  • Real-time frame state (idle/scanning/success/error)    │ │
│  │  • Location status display                                │ │
│  │  • User instructions & feedback                           │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                        │
│                         ▼                                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │          MockLocationService (lib/services/)               │ │
│  │                                                             │ │
│  │  • isMockLocationEnabled() ← SafeDevice plugin             │ │
│  │  • isMockLocationAppSet() ← Native Layer 1                 │ │
│  │  • isLocationMocked() ← Native Layer 2                     │ │
│  │  • isAnyProviderMocked() ← Native Layer 2+                 │ │
│  │  • performComprehensiveCheck() ← All layers               │ │
│  │  • MockDetectionResult class                              │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                        │
└─────────────────────────┼────────────────────────────────────────┘
                          │
                          │ MethodChannel
                          │ "com.example.visage_app/mockLocation"
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│                  ANDROID NATIVE LAYER (Kotlin)                   │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │                    MainActivity.kt                          │ │
│  │                                                             │ │
│  │  MethodCallHandler Routes:                                │ │
│  │  ├─ isMockLocationAppSet()                                │ │
│  │  ├─ isLocationMocked()                                    │ │
│  │  ├─ isAnyProviderMocked()                                 │ │
│  │  └─ performComprehensiveCheck()                           │ │
│  │                                                             │ │
│  │  Each route delegates to MockLocationDetector              │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │              MockLocationDetector.kt                        │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────┐   │ │
│  │  │  Layer 1: AppOpsManager Detection                  │   │ │
│  │  │  isMockLocationAppSet()                             │   │ │
│  │  │  └─ Checks if mock location app is set as provider │   │ │
│  │  └─────────────────────────────────────────────────────┘   │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────┐   │ │
│  │  │  Layer 2: Per-Fix Location Verification            │   │ │
│  │  │  isLocationMocked()                                 │   │ │
│  │  │  └─ Checks Location.isFromMockProvider flag         │   │ │
│  │  │                                                     │   │ │
│  │  │  isAnyProviderMocked()                              │   │ │
│  │  │  └─ Checks all location providers                  │   │ │
│  │  └─────────────────────────────────────────────────────┘   │ │
│  │                                                             │ │
│  │  ┌─────────────────────────────────────────────────────┐   │ │
│  │  │  Layer 3: Accuracy Pattern Validation              │   │ │
│  │  │  isAccuracySuspicious()                             │   │ │
│  │  │  └─ Detects suspicious accuracy patterns           │   │ │
│  │  │     • Zero or negative accuracy                    │   │ │
│  │  │     • Network provider sub-meter accuracy          │   │ │
│  │  │     • Accuracy > 10km                              │   │ │
│  │  └─────────────────────────────────────────────────────┘   │ │
│  │                                                             │ │
│  │  MockDetectionResult                                       │ │
│  │  ├─ isMocked: Boolean                                      │ │
│  │  ├─ details: List<String>                                  │ │
│  │  ├─ timestamp: Long                                        │ │
│  │  └─ location data (lat/lng/accuracy)                       │ │
│  └──────────────────────┬──────────────────────────────────────┘ │
│                         │                                        │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │         MockDetectionLocationListener.kt                    │ │
│  │                                                             │ │
│  │  • Implements LocationListener interface                  │ │
│  │  • Real-time per-fix detection                            │ │
│  │  • Callback: onLocationReceived(location, isMocked)       │ │
│  │  • For integration with LocationManager                   │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                         │                                        │
└─────────────────────────┼────────────────────────────────────────┘
                          │
                          │ System APIs
                          ▼
┌──────────────────────────────────────────────────────────────────┐
│              ANDROID SYSTEM SERVICES & APIs                      │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │            AppOpsManager                                    │ │
│  │  • OPSTR_MOCK_LOCATION check                               │ │
│  │  • Returns: RESULT_ALLOWED (0) if mock app set             │ │
│  │  • API Level: Android 4.3+ (KITKAT)                        │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │            LocationManager                                  │ │
│  │  • Gets location from providers                            │ │
│  │  • Provides: GPS, NETWORK, FUSED, PASSIVE                  │ │
│  │  • Returns: Location objects with metadata                 │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────────┐ │
│  │            Location Objects                                 │ │
│  │  • isFromMockProvider: Boolean flag                         │ │
│  │  • Set by Android when location from mock provider          │ │
│  │  • API Level: Android 4.2+                                 │ │
│  │  • accuracy: Float (meters)                                │ │
│  │  • provider: String (GPS/NETWORK/etc)                      │ │
│  └─────────────────────────────────────────────────────────────┘ │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Sequence Diagrams

### Sequence 1: App Initialization with Mock Detection

```
User                  Flutter App              MockLocationService      Android Native
 │                        │                           │                      │
 ├─ Opens App             │                           │                      │
 │                        │                           │                      │
 │                   InitialCheckScreen              │                      │
 │                   _initializeApp()                 │                      │
 │                        │                           │                      │
 │                   _getCurrentLocation()            │                      │
 │                        │                           │                      │
 │                        ├──── _verifyLocationNotMocked() ──────────────►   │
 │                        │                           │                      │
 │                        │                     isMockLocationAppSet()       │
 │                        │                           │        AppOpsManager │
 │                        │                           ├─────────────────────►│
 │                        │                           │◄─ result ────────────┤
 │                        │                           │                      │
 │                        │ ◄───── detection result ──┤                      │
 │                        │                           │                      │
 │    Mock Detected?      │                           │                      │
 │    ├─ YES ────────────►│                           │                      │
 │    │                   │ Show Error: "Mock         │                      │
 │    │                   │ location detected"        │                      │
 │    │                   │ Return (don't proceed)    │                      │
 │    │                   │                           │                      │
 │    └─ NO              │                           │                      │
 │                        │ Request GPS location      │                      │
 │                        │ (Normal flow)             │                      │
 │                        │                           │                      │
 ├─ Location Acquired    │                           │                      │
 │                        │ Initialize Camera         │                      │
 │                        │                           │                      │
 ├─ Camera Ready         │ Show: "Position face"     │                      │
 │                        │                           │                      │
```

### Sequence 2: Face Capture & Comprehensive Check

```
User                  Flutter App              MockLocationService      Android Native
 │                        │                           │                      │
 ├─ Face Detected        │                           │                      │
 │                        │                           │                      │
 │                   _captureAndVerifyAutomatic()    │                      │
 │                        │                           │                      │
 │                        ├─ Take Picture             │                      │
 │                        │                           │                      │
 ├─ Picture Captured      │                           │                      │
 │                        │                           │                      │
 │                        ├─── performComprehensiveCheck() ─────────────►    │
 │                        │                           │                      │
 │                        │                     executeMethodCall:           │
 │                        │                     "performComprehensiveCheck"  │
 │                        │                           │                      │
 │                        │                           ├─ Layer 1 Check       │
 │                        │                           │ isMockLocationAppSet()
 │                        │                           │       ┌─────────────►│
 │                        │                           │◄──────┘ result       │
 │                        │                           │                      │
 │                        │                           ├─ Layer 2 Check       │
 │                        │                           │ isLocationMocked()    │
 │                        │                           │       ┌─────────────►│
 │                        │                           │◄──────┘ flag         │
 │                        │                           │                      │
 │                        │                           ├─ Layer 3 Check       │
 │                        │                           │ isAccuracySuspicious()
 │                        │                           │       ┌─────────────►│
 │                        │                           │◄──────┘ result       │
 │                        │                           │                      │
 │                        │◄── MockDetectionResult ──┤                      │
 │                        │ (isMocked, details, ...)  │                      │
 │                        │                           │                      │
 │    Mock Detected?      │                           │                      │
 │    ├─ YES ────────────►│                           │                      │
 │    │                   │ Set frameState: 'error'   │                      │
 │    │                   │ Show: "Security Alert:    │                      │
 │    │                   │ Mock location detected"   │                      │
 │    │                   │ Wait 4 seconds            │                      │
 │    │                   │ Return (don't call API)   │                      │
 │    │                   │                           │                      │
 │    └─ NO              │                           │                      │
 │                        │ Call Verification API     │                      │
 │                        │ (Submit attendance)       │                      │
 │                        │                           │                      │
 ├─ API Response         │ Show Success or Error      │                      │
 │                        │                           │                      │
```

---

## Detection Logic Flowchart

```
                    ┌─────────────────────┐
                    │  Location Acquired  │
                    └──────────┬──────────┘
                               │
                               ▼
                    ┌─────────────────────┐
                    │ Comprehensive Check │
                    │   3-Layer Test      │
                    └──────────┬──────────┘
                               │
                ┌──────────────┼──────────────┐
                │              │              │
                ▼              ▼              ▼
        ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
        │   LAYER 1    │ │   LAYER 2    │ │   LAYER 3    │
        │ AppOpsManager│ │ Per-Fix &    │ │ Accuracy     │
        │              │ │ All Providers│ │ Validation   │
        └──────┬───────┘ └──────┬───────┘ └──────┬───────┘
               │                │                │
        ┌──────▼────┐    ┌──────▼────┐    ┌──────▼────┐
        │Check Mock  │    │Check Loca-│    │Check Acc- │
        │App Set?    │    │tion Flags │    │uracy      │
        │ (AppOps    │    │(isFromMock│    │Patterns   │
        │Manager)    │    │Provider)  │    │(0, huge,  │
        └──────┬─────┘    └──────┬────┘    │network+...)
               │                │         └──────┬────┘
        ┌──────▼─────────────────▼────────────────▼──────┐
        │         ANY CHECK RETURNS TRUE?                │
        │         (Mock Location Detected)               │
        └──────┬──────────────────────────────────────────┘
               │
        ┌──────▼────────┬──────────────┐
        │               │              │
        ▼               ▼              ▼
    ┌─────────┐   ┌──────────┐   ┌───────────┐
    │ YES     │   │   NO     │   │  ERROR    │
    │(BLOCK)  │   │ (ALLOW)  │   │(BLOCK)    │
    └────┬────┘   └────┬─────┘   └─────┬─────┘
         │             │               │
         ▼             ▼               ▼
    ┌─────────┐   ┌──────────┐   ┌───────────┐
    │Show     │   │Proceed   │   │Show       │
    │Security │   │with API  │   │Error      │
    │Alert    │   │Call      │   │Message    │
    │Return   │   │Submit    │   │Return     │
    │         │   │Attendance│   │           │
    └─────────┘   └──────────┘   └───────────┘
```

---

## Component Interaction Diagram

```
┌────────────────────────────────────────────────────────────────────┐
│                    FaceVerificationScreen                          │
│                                                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ State Variables:                                             │  │
│  │ • _currentLatitude, _currentLongitude                        │  │
│  │ • _frameState (idle/scanning/success/error)                 │  │
│  │ • _isProcessing                                             │  │
│  │ • _statusMessage                                            │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                         │                                          │
│                         │ Uses                                     │
│                         ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ MockLocationService                                          │  │
│  │                                                              │  │
│  │ Static Methods (no instance needed):                         │  │
│  │ • isMockLocationEnabled()      ← SafeDevice plugin           │  │
│  │ • isMockLocationAppSet()       ← Layer 1                     │  │
│  │ • isLocationMocked()           ← Layer 2                     │  │
│  │ • isAnyProviderMocked()        ← Layer 2+                    │  │
│  │ • performComprehensiveCheck()  ← All layers                  │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                         │                                          │
│                         │ MethodChannel                            │
│                         ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Native Method Channel Handler                                │  │
│  │ (MainActivity.kt)                                            │  │
│  │                                                              │  │
│  │ Routes method calls to MockLocationDetector                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                         │                                          │
│                         │ Delegates                                │
│                         ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ MockLocationDetector                                         │  │
│  │                                                              │  │
│  │ Private Methods:                                             │  │
│  │ • isMockLocationAppSet()   (Layer 1)                         │  │
│  │ • isLocationMocked()       (Layer 2)                         │  │
│  │ • isAnyProviderMocked()    (Layer 2+)                        │  │
│  │ • isAccuracySuspicious()   (Layer 3)                         │  │
│  │ • performComprehensiveCheck() (orchestrator)                 │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                         │                                          │
│                         │ Accesses                                 │
│                         ▼                                          │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ Android System Services                                      │  │
│  │ • AppOpsManager (mock app detection)                         │  │
│  │ • LocationManager (provider info)                            │  │
│  │ • Location objects (metadata)                                │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

---

## Call Stack During Attendance Submission

```
User clicks "Submit Attendance"
    │
    ├─ FaceVerificationScreen._captureAndVerifyAutomatic()
    │  │
    │  ├─ Take picture
    │  │
    │  └─ [NEW] Check: Is location mock?
    │     │
    │     └─ MockLocationService.performComprehensiveCheck()
    │        │
    │        ├─ MethodChannel.invokeMethod("performComprehensiveCheck")
    │        │  │
    │        │  └─ MainActivity (Kotlin)
    │        │     │
    │        │     └─ performComprehensiveCheck(location)
    │        │        │
    │        │        └─ MockLocationDetector.performComprehensiveCheck()
    │        │           │
    │        │           ├─ isMockLocationAppSet()
    │        │           │  └─ AppOpsManager.noteOpNoThrow()
    │        │           │
    │        │           ├─ isLocationMocked(location)
    │        │           │  └─ location.isFromMockProvider
    │        │           │
    │        │           ├─ isAnyProviderMocked()
    │        │           │  └─ LocationManager.getLastKnownLocation()
    │        │           │
    │        │           └─ isAccuracySuspicious(location)
    │        │              └─ Check accuracy patterns
    │        │
    │        └─ Return MockDetectionResult to Flutter
    │
    ├─ Is location mocked?
    │  │
    │  ├─ YES: Return (don't call API)
    │  │   └─ Show error
    │  │
    │  └─ NO: Continue
    │
    ├─ Call Verification API
    │  │
    │  ├─ POST to https://visage.sltdigitallab.lk/api/verify_face
    │  │
    │  └─ With face image & location
    │
    └─ Return result to user
```

---

## State Transitions for Frame Display

```
                        ┌────────┐
                        │  IDLE  │ (white frame)
                        │"Position│
                        │ face"   │
                        └────┬───┘
                             │
                    Face detected?
                             │
                    ┌────────▼────────┐
                    │                 │
                    ▼                 ▼
            ┌──────────────┐    ┌──────────────┐
            │   SCANNING   │    │ Return to    │
            │   (blue)     │    │ IDLE         │
            │"Scanning..." │    │              │
            └────┬─────────┘    └──────────────┘
                 │
          Image captured?
                 │
    ┌────────────▼────────────┐
    │                         │
    ▼                         ▼
MOCK CHECK                  [wait for next]
    │
  Mocked?
    │
┌───┴────────────┬──────────────┐
│                │              │
▼                ▼              ▼
YES            NO            ERROR
│              │              │
├─ ERROR      └─ API CALL    ├─ ERROR
│ (red)          │           │ (red)
│ "Security    Mock CHECK    │
│  Alert"       │           │
│               Passed?    [Reset after
│               │          4 seconds]
│            ┌──┴──┐
│            │     │
│           YES   NO
│            │     │
│            │    └─ ERROR
│            │      │
│            ▼      ▼
│          SUCCESS  ERROR
│          (green)  (red)
│          "Face    "Failed"
│           verified"
│
└─ Reset after
   4 seconds
   to IDLE
```

---

## Memory & Performance Model

```
MEMORY USAGE

App Instance:
  FaceVerificationScreen:         ~500KB
  └─ State variables
  └─ Camera controller
  └─ Face detector

MockLocationService:              ~10KB
  └─ Static methods only
  └─ No persistent state

MockLocationDetector (native):    ~1MB
  └─ Context reference
  └─ AppOpsManager instance
  └─ LocationManager reference

Total Memory Overhead:            ~1.5MB

PERFORMANCE TIMELINE

User Action              Component           Duration    CPU%
────────────────────────────────────────────────────────────
App Launch              InitialCheck        ~100ms      10%
                        AppOpsManager       ~30ms       5%
Location Acquisition    Geolocator          ~2000ms     8%
Camera Init             Camera API          ~800ms      25%
Face Detection (per frame) MLKit           ~100ms      20%
Mock Check (init)       All 3 layers        ~100ms      10%
Mock Check (submission) All 3 layers        ~150ms      15%
API Call                Network             ~1000ms     5%
────────────────────────────────────────────────────────────
Total User Journey      (genuine user)      ~4150ms
```

---

## Error Handling Tree

```
performComprehensiveCheck()
    │
    ├─ Try Block
    │  │
    │  ├─ Layer 1: isMockLocationAppSet()
    │  │  │
    │  │  ├─ Success → result
    │  │  │
    │  │  └─ Exception
    │  │     └─ Log & continue
    │  │
    │  ├─ Layer 2a: isLocationMocked()
    │  │  │
    │  │  ├─ Success → result
    │  │  │
    │  │  └─ Exception
    │  │     └─ Log & continue
    │  │
    │  ├─ Layer 2b: isAnyProviderMocked()
    │  │  │
    │  │  ├─ Success → result
    │  │  │
    │  │  └─ Exception
    │  │     └─ Log & continue
    │  │
    │  └─ Layer 3: isAccuracySuspicious()
    │     │
    │     ├─ Success → result
    │     │
    │     └─ Exception
    │        └─ Log & continue
    │
    └─ Catch Block
       │
       ├─ Print stack trace
       │
       └─ Return "BLOCK" (safe default)
          └─ isMocked = true
          └─ details = ["Error during check"]
```

---

## Deployment Architecture

```
                   ┌─────────────┐
                   │   GitHub    │
                   │ Repository  │
                   └──────┬──────┘
                          │
                    Push to main
                          │
                   ┌──────▼──────┐
                   │   CI/CD     │
                   │  Pipeline   │
                   └──────┬──────┘
                          │
                   ┌──────▼──────┐
                   │Build & Test │
                   └──────┬──────┘
                          │
                   ┌──────▼──────┐
                   │ APK/Bundle  │
                   │  Generated  │
                   └──────┬──────┘
                          │
                   ┌──────▼──────┐
                   │ Play Store  │
                   │Release      │
                   └──────┬──────┘
                          │
                   ┌──────▼──────┐
                   │User Devices │
                   │(Automated   │
                   │Updates)     │
                   └─────────────┘
```

---

**Document Version**: 1.0  
**Last Updated**: April 24, 2026  
**Purpose**: Visual architecture and data flow documentation

