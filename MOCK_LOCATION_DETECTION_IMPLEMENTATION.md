# Mock Location Detection Implementation

## Overview
This document explains how the mock location detection system works in the Visage Attendance App to prevent fraudulent attendance marking using spoofed/mock locations.

## Implementation Layers

### Layer 1: Early Detection (Before Camera Initialization)
**Location**: `FaceVerificationScreen._checkMockLocationBeforeStart()`

When a user opens the FaceVerificationScreen to mark attendance:

1. **Initial Mock Location Check** is performed BEFORE any camera initialization
2. **Detection Methods Used**:
   - `MockLocationService.isMockLocationAppSet()` - Checks if a mock location provider app is set via AppOpsManager
   - `MockLocationService.isAnyProviderMocked()` - Checks if any location provider is currently delivering mocked coordinates

3. **If Mock Location is Detected**:
   - A dialog is shown with the warning message: "Security Alert: Mock Location Detected!"
   - User options:
     - **Exit**: Leave the app
     - **Retry**: Re-run the mock location check after disabling mock location

### Layer 2: Continuous Monitoring (Real-time Detection)
**Location**: `FaceVerificationScreen._startContinuousMockLocationCheck()`

A timer runs every 2 seconds checking if:
- Mock location status changes from NOT-MOCK to MOCK
- Mock location status changes from MOCK to NOT-MOCK

**If Status Changes to MOCK During Usage**:
- Dialog is immediately shown
- Camera stream is stopped
- UI switches to warning screen

**If Status Changes from MOCK to NOT-MOCK**:
- User is allowed to proceed with camera initialization
- Automatic retry of setup

### Layer 3: Pre-Capture Verification
**Location**: `FaceVerificationScreen._captureAndVerifyAutomatic()`

Before face capture is processed:

1. **Fresh Location Verification**:
   - Re-verify location is not mocked (second check)
   - Get fresh GPS coordinates

2. **Comprehensive Mock Detection**:
   - Perform multi-layer mock detection on the fresh coordinates
   - Check sensor patterns for suspicious accuracy values
   - Cross-validate with multiple detection methods

3. **If Mock Detected at This Stage**:
   - Face capture is blocked
   - Error message shown to user
   - User can retry after disabling mock location

### Layer 4: Pre-Submission Verification
**Location**: `FaceVerificationScreen._handleVerificationSuccess()`

After face is successfully verified by API, BEFORE marking attendance:

1. **Final Mock Location Check**
   - Verify location is STILL not mocked
   - Prevents user from enabling mock location between face verification and attendance marking

2. **If Mock Location Detected**:
   - Attendance marking is BLOCKED
   - Success screen is NOT shown
   - User must disable mock location and retry

## Native Android Implementation

### MockLocationDetector.kt

#### Method 1: isMockLocationAppSet()
```kotlin
- Checks AppOpsManager for OPSTR_MOCK_LOCATION permission
- Checks all location providers for isFromMockProvider flag
- Returns true if any provider is currently mocked
```

#### Method 2: isLocationMocked(location)
```kotlin
- Checks the Location.isFromMockProvider property
- This is set by Android system when location comes from mock provider
- Most reliable per-fix detection method
```

#### Method 3: isAnyProviderMocked()
```kotlin
- Iterates through all enabled location providers
- Checks last known location from each provider
- Detects if any provider is delivering mocked locations
```

#### Method 4: isAccuracySuspicious(location)
```kotlin
Detects patterns indicating mock locations:
- Accuracy = 0 or negative (mock apps sometimes set this)
- Sub-half-meter accuracy on non-GPS provider (unrealistic)
- Network provider with sub-2m accuracy (impossible)
- Accuracy > 10km (clearly invalid)
- Round number accuracy values (indicates mock data)
```

## User Flow

### Scenario 1: Mock Location Enabled Before Opening App
```
User Opens FaceVerificationScreen
    ↓
_checkMockLocationBeforeStart() runs
    ↓
Mock location detected via AppOpsManager
    ↓
Dialog shown: "Mock Location Detected"
    ↓
Camera NEVER initializes
    ↓
User either Exits or clicks Retry after disabling mock location
```

### Scenario 2: User Enables Mock Location During Usage
```
User in Camera screen
    ↓
Continuous check detects mock location enabled
    ↓
Dialog shown immediately
    ↓
Camera stream stopped
    ↓
Warning UI displayed
```

### Scenario 3: User Tries to Spoof Location During Face Capture
```
Face detected and captured
    ↓
_captureAndVerifyAutomatic() runs pre-capture verification
    ↓
Fresh location check detects mock
    ↓
Capture blocked, error shown
    ↓
Camera restored to idle state
```

### Scenario 4: User Enables Mock After Face Verification
```
Face verified successfully
    ↓
_handleVerificationSuccess() runs final verification
    ↓
Final mock location check detects mock
    ↓
Success screen NOT shown
    ↓
Error shown, user must disable mock and retry
```

## Security Benefits

1. **Multiple Detection Layers**: Four different detection methods means mock location apps can't bypass all checks
2. **Real-time Monitoring**: Continuous checking prevents users from enabling mock location mid-session
3. **Fresh Verification**: Location is re-checked right before submission, not just at app start
4. **Sensor Cross-Validation**: Accuracy patterns are checked for suspicious values
5. **Per-Fix Detection**: Each location fix is checked for the isFromMockProvider flag
6. **AppOpsManager Integration**: Detects mock location app installation/permission

## How Mock Location Apps Work (Context)

Mock location apps typically work by:
1. Installing with "Allow installation from unknown sources"
2. Enabling "Developer Options" in Android settings
3. Selecting the mock location app as the "Mock Location Provider" in Developer Settings
4. The OS then delivers mocked coordinates through the LocationManager

Our detection catches this at multiple points:
- AppOpsManager permission check
- Provider-level isFromMockProvider flag
- Accuracy pattern validation

## Testing the Detection

To test if mock location detection is working:

1. **Install a mock location app** (e.g., "Fake GPS")
2. **Enable it in Developer Options** → Select Mock location app
3. **Open the Visage app**
4. **Expected Result**: Should immediately see warning dialog before camera initializes

## Permissions Required

The app already has these permissions in AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.CAMERA" />
```

No additional permissions are needed for mock location detection, as AppOpsManager checks are built-in to Android system.

## Key Code Locations

- **Flutter Layer**: `lib/face_verification_screen.dart`
  - `_checkMockLocationBeforeStart()` - Initial check
  - `_startContinuousMockLocationCheck()` - Continuous monitoring
  - `_showMockLocationDialog()` - Warning dialog
  - `_retryMockLocationCheck()` - User retry logic

- **Kotlin Layer**: `android/app/src/main/kotlin/com/example/visage_app/MockLocationDetector.kt`
  - `isMockLocationAppSet()` - App-level check
  - `isLocationMocked()` - Per-fix check
  - `isAnyProviderMocked()` - Provider-level check
  - `isAccuracySuspicious()` - Pattern validation
  - `performComprehensiveCheck()` - Multi-layer check

- **Service Layer**: `lib/services/mock_location_service.dart`
  - Method channel communication with native code
  - Wrapper around Kotlin implementation
  - Result mapping to Dart classes

