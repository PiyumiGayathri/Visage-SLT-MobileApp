# Mock Location Detection - Testing Guide

## Complete Testing Procedures

### Environment Setup

#### Required Tools
- Android Studio 4.2+
- Android SDK 21+ 
- Flutter 3.0+
- ADB (Android Debug Bridge)
- Real Android device or emulator

#### Device Setup
```bash
# Enable Developer Options
Settings → About Phone → Tap "Build Number" 7 times

# Enable USB Debugging
Settings → Developer Options → USB Debugging

# Connect device
adb devices
```

---

## Test Case 1: Genuine Location (Control Test)

### Objective
Verify that app allows attendance with genuine GPS location.

### Prerequisites
- Device without mock location app
- GPS enabled
- Location permission granted to app

### Steps
```
1. Disconnect any mock location services
   - Go to Settings → Location
   - Verify "Use precise location" is enabled
   - Check no mock location apps are active

2. Connect device to computer
   adb devices

3. Run the app
   flutter run

4. Allow location permission when prompted

5. Wait for "Location acquired" message

6. Position face in frame

7. Wait for face detection (blue frame)

8. App captures face automatically

9. Observe response
```

### Expected Outcome
```
✓ Location verified successfully
✓ No security alerts shown
✓ Camera initializes
✓ Face detection works
✓ Face capture succeeds
✓ App shows green success frame
✓ Attendance marked (navigate to success screen)
✓ No [SECURITY] warnings in logcat
```

### Logcat Output (Expected)
```
[SECURITY] Verifying location is not mocked...
[SECURITY] ✓ Location verification passed
[SECURITY] Starting comprehensive mock location detection...
[SECURITY] Mock location check completed:
[SECURITY]   - Is Mocked: false
[SECURITY]   - Details: [AppOpsManager check: false, ...]
```

### Pass/Fail Criteria
- ✅ PASS: Attendance marked successfully
- ❌ FAIL: Attendance blocked or error shown

---

## Test Case 2: Mock Location App (Google Maps)

### Objective
Verify app blocks attendance when mock location app is active.

### Prerequisites
- Device with Google Maps or similar location sharing app
- Mock location app installed and active

### Steps
```
1. Install Google Maps (if not present)
   Play Store → Search "Google Maps" → Install

2. Enable location sharing in Google Maps
   Google Maps → Settings → Location Sharing → Enable

3. Connect device
   adb devices

4. Run the app
   flutter run

5. Observe response at initialization
```

### Expected Outcome
```
✗ Security alert shown during location check
✗ Message: "Security Alert: Mock location detected..."
✗ Camera does NOT initialize
✗ App returns to main screen
✓ No API call made
```

### Logcat Output (Expected)
```
[SECURITY] Verifying location is not mocked...
[SECURITY] ⚠️  Mock location app is set - blocking
```

### Pass/Fail Criteria
- ✅ PASS: Blocked before camera initialization
- ❌ FAIL: App proceeds or crashes

---

## Test Case 3: Fake GPS Location App

### Objective
Verify app blocks attendance when Fake GPS location app is active.

### Prerequisites
- "Fake GPS Location" app installed (or similar)
- Mock location enabled in app settings
- Different GPS coordinates selected

### Steps
```
1. Install "Fake GPS Location" from Play Store
   Play Store → Search "Fake GPS" → Install first result

2. Grant location permission to Fake GPS app
   Settings → Apps → Fake GPS Location → Permissions

3. Open Fake GPS app
   - Select a different city/location
   - Enable "Start" or "Simulate" button

4. Connect device
   adb devices

5. Run attendance app
   flutter run

6. Observe response

7. Try to capture face and mark attendance
```

### Expected Outcome (At Initialization)
```
Option A - Detected at startup:
  ✗ Security alert shown
  ✗ Camera does not initialize
  ✓ Blocked before face detection

Option B - Detected at submission:
  ✓ Camera initializes (more sophisticated mock)
  ✓ Face detection works
  ✗ Blocked BEFORE API call
  ✗ Error message shown
```

### Logcat Output (Expected - Option B)
```
[SECURITY] Starting comprehensive mock location detection...
[SECURITY] Mock location check completed:
[SECURITY]   - Is Mocked: true
[SECURITY]   - Details: [Per-fix location check: true, ...]
[SECURITY] ⚠️  MOCK LOCATION DETECTED - BLOCKING ATTENDANCE
```

### Pass/Fail Criteria
- ✅ PASS: Blocked (either at init or submission)
- ❌ FAIL: Attendance marked or API called

---

## Test Case 4: Android Studio Location Emulation

### Objective
Verify app blocks attendance when using Android Studio's location emulator.

### Prerequisites
- Android emulator running
- Android Studio with Extended Controls available

### Steps
```
1. Start Android emulator (if not already running)
   Android Studio → AVD Manager → Launch

2. Open Extended Controls
   Emulator window → ... (three dots) → Extended Controls

3. Navigate to Location tab

4. Set coordinates to spoofed location
   - Latitude: 1.3521 (Singapore)
   - Longitude: 103.8198
   - Click "Send"

5. Run app on emulator
   flutter run -d emulator-5554

6. Allow permissions

7. Try to mark attendance
```

### Expected Outcome
```
✗ Either blocked at initialization or submission
✗ Security alert shown
✗ Attendance NOT marked
✓ No API call made with spoofed location
```

### Logcat Output (Expected)
```
[SECURITY] Starting comprehensive mock location detection...
[SECURITY] Mock location check completed:
[SECURITY]   - Is Mocked: true
```

### Pass/Fail Criteria
- ✅ PASS: Blocked as expected
- ❌ FAIL: Attendance allowed

---

## Test Case 5: Suspicious Accuracy Pattern

### Objective
Verify app blocks attendance when location has suspicious accuracy patterns.

### Prerequisites
- Root access (on device) or use mock app to set accuracy
- Understanding of how mock apps can set accuracy values

### Steps
```
1. Use Fake GPS app to set location with 0 accuracy
   Fake GPS → Select location → Advanced → Set accuracy to 0

2. Enable mock location

3. Run app
   flutter run

4. Try to mark attendance
```

### Expected Outcome
```
✗ Blocked during comprehensive check
✗ Accuracy validation layer detects suspicious pattern
✗ Error message shown
```

### Logcat Output (Expected)
```
[SECURITY] Starting comprehensive mock location detection...
[SECURITY] Mock location check completed:
[SECURITY]   - Is Mocked: true
[SECURITY]   - Details: [..., Suspicious accuracy patterns: true]
```

### Pass/Fail Criteria
- ✅ PASS: Blocked due to accuracy
- ❌ FAIL: Attendance marked

---

## Test Case 6: Multiple Detection Layers

### Objective
Verify all detection layers work independently.

### Prerequisites
- Multiple mock location apps
- Ability to run multiple checks

### Steps
```
1. Test Layer 1 (AppOpsManager)
   - Enable Google Maps location sharing
   - Expected: Blocked at init

2. Test Layer 2 (Per-fix check)
   - Disable Layer 1, enable Fake GPS
   - Expected: Blocked at submission

3. Test Layer 3 (Accuracy)
   - Disable Layer 1 & 2, set 0 accuracy
   - Expected: Blocked by accuracy
```

### Expected Outcome
```
All three layers should independently detect and block mock locations
No layer should depend on others
```

---

## Performance Testing

### Test Case 7: Location Check Performance

### Objective
Verify location checks don't cause noticeable delays.

### Prerequisites
- Device with GPS enabled
- App ready to run

### Steps
```
1. Run app with performance monitoring
   flutter run --profile

2. Measure location check time
   - Note time from "Getting location" to "Location acquired"
   - Should be <200ms

3. Observe logcat timestamps
   adb logcat -v threadtime | grep SECURITY
```

### Expected Performance
```
Initial Location Check:   <100ms
Comprehensive Check:      <150ms
Total User Delay:         <250ms (perceived as instant)
```

### Pass/Fail Criteria
- ✅ PASS: <200ms for location check
- ❌ FAIL: >300ms (noticeable delay)

---

## Error Handling Testing

### Test Case 8: Network Error Recovery

### Objective
Verify app handles network errors gracefully.

### Prerequisites
- Device with toggleable network
- Network issue simulation

### Steps
```
1. Run app
   flutter run

2. At location acquisition stage
   - Turn off WiFi and Mobile data
   - Observe error handling

3. Re-enable network

4. Try again
```

### Expected Outcome
```
✓ Graceful error message shown
✓ User can retry
✓ No crash or exception
```

---

## Regression Testing

### Test Case 9: Existing Features Not Broken

### Objective
Verify mock location detection doesn't break existing functionality.

### Prerequisites
- Genuine location available
- Valid API endpoint
- Test user account

### Steps
```
1. Run full attendance workflow
   - Open app
   - Allow permissions
   - Capture face
   - Submit attendance
   - Verify success screen

2. Check all existing features still work
   - Face detection
   - Camera feed
   - API communication
   - Data persistence
```

### Expected Outcome
```
✓ All existing features work
✓ No performance degradation
✓ No memory leaks
```

---

## Manual Logcat Analysis

### Monitor Security Checks
```bash
# Start logcat filtering
adb logcat | grep SECURITY

# Start logcat with timestamps
adb logcat -v threadtime | grep SECURITY

# Save to file
adb logcat | grep SECURITY > security_log.txt

# Example output analysis
[SECURITY] Starting comprehensive mock location detection...
          # ↑ Indicates user attempted to submit attendance

[SECURITY] Mock location check completed:
          # ↑ All checks completed

[SECURITY]   - Is Mocked: false
          # ↑ Result of comprehensive check

[SECURITY]   - Details: [...]
          # ↑ Individual layer results

[SECURITY] ✓ Location verification passed
          # ↑ GREEN check = allowed to proceed
          
[SECURITY] ⚠️  MOCK LOCATION DETECTED - BLOCKING ATTENDANCE
          # ↑ RED alert = attendance blocked
```

---

## Test Summary Template

```
TEST EXECUTION REPORT
=====================

Date: _______________
Device: _____________
Android Version: _____
App Version: ________

Test Case 1: Genuine Location
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 2: Mock Location App
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 3: Fake GPS App
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 4: Location Emulator
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 5: Suspicious Accuracy
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 6: Multiple Layers
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 7: Performance
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 8: Error Handling
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

Test Case 9: Regression
  Result: PASS / FAIL / INCONCLUSIVE
  Notes: _______________________

OVERALL RESULT: _______________

Issues Found:
1. ___________________________
2. ___________________________
3. ___________________________

Recommendations:
1. ___________________________
2. ___________________________
3. ___________________________

Signed: _____________ Date: _____
```

---

## Troubleshooting Common Issues

### Issue 1: "Method not found" error
```
Error: MissingPluginException: No implementation found for method...

Solution:
  1. Clean build: flutter clean
  2. Get dependencies: flutter pub get
  3. Rebuild: flutter run
  4. Check MockLocationDetector.kt is in correct path
```

### Issue 2: Permission denied when checking mock location
```
Error: AppOpsManager.noteOpNoThrow returns RESULT_DENIED

Solution:
  1. Check device has Android 4.3+
  2. Verify app has location permission
  3. Grant permission: Settings → Apps → Permissions
```

### Issue 3: isFromMockProvider not available
```
Error: Location.isFromMockProvider throws exception

Solution:
  1. Check device is Android 4.2+
  2. Use try-catch to handle exception
  3. Fall back to accuracy layer
```

### Issue 4: False positives with genuine locations
```
Symptoms: Legitimate users blocked

Solution:
  1. Check accuracy thresholds (currently 10000m max)
  2. Review suspicious patterns (0 or negative accuracy)
  3. Adjust thresholds based on real data
  4. Add device-specific exceptions if needed
```

---

## Continuous Testing

### Automated Testing (Future)
```
1. Unit Tests
   - Test MockLocationDetector methods
   - Test MockLocationService methods
   - Test error handling

2. Integration Tests
   - Test method channel communication
   - Test full detection flow
   - Test with different mock apps

3. E2E Tests
   - Test complete attendance workflow
   - Test with various mock location scenarios
   - Test performance under load
```

### Manual Testing Schedule
```
Before Each Release:
  - Run all 9 test cases
  - Test on 3 device models (Samsung, Google, OnePlus)
  - Test on 2 Android versions
  - Review all [SECURITY] logs
  - Check for regressions

Monthly:
  - Update with new mock location techniques
  - Review false positive rate
  - Monitor user reports
  - Adjust detection thresholds
```

---

## Success Criteria

### All Tests Must Pass
- ✅ Test 1: Genuine location allowed
- ✅ Test 2: Mock app blocked
- ✅ Test 3: Fake GPS blocked
- ✅ Test 4: Emulator blocked
- ✅ Test 5: Suspicious accuracy blocked
- ✅ Test 6: All layers working
- ✅ Test 7: Performance acceptable
- ✅ Test 8: Error handling graceful
- ✅ Test 9: No regressions

### Success Metrics
```
Detection Rate:        >95% (catch mock locations)
False Positive Rate:   <2% (don't block genuine users)
Performance Impact:    <200ms added delay
User Satisfaction:     >90% (positive feedback)
System Stability:      100% (no crashes)
```

---

## Deployment Approval Checklist

Before deploying to production:

- [ ] All 9 test cases passed
- [ ] No [SECURITY] errors in logcat
- [ ] Performance testing completed
- [ ] Tested on 3+ device models
- [ ] Tested on Android 4.2+ versions
- [ ] Team code review completed
- [ ] Security audit passed
- [ ] Documentation reviewed
- [ ] User communication prepared
- [ ] Rollback plan ready

**Release Date**: _______________
**Approved By**: ________________
**Tested By**: __________________

---

**Document Version**: 1.0  
**Created**: April 24, 2026  
**Purpose**: Complete testing procedures for mock location detection

