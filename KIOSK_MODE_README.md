# Android Kiosk Mode Implementation

## 🎯 Overview

This Flutter app now implements **Android Kiosk Mode (Lock Task Mode)** to prevent users from navigating away from the app. Users are locked inside the app and cannot access:

- ❌ Home screen
- ❌ Recent apps
- ❌ Back button navigation
- ❌ Notification panel
- ❌ System gestures

## 🔐 Security Features

1. **Password-Protected Exit**: Users must enter a password (default: `1234`) to exit kiosk mode
2. **Immersive Mode**: Hides status bar and navigation bar for full-screen experience
3. **Back Button Intercepted**: Back button shows password dialog instead of exiting
4. **Floating Exit Button**: Top-right corner exit button for authorized users

## 📁 Files Created/Modified

### New Files:
1. **`lib/services/kiosk_mode_service.dart`** - Flutter service to communicate with Android native code
2. **`lib/widgets/exit_kiosk_dialog.dart`** - Password dialog for exiting kiosk mode

### Modified Files:
1. **`lib/main.dart`** - Added kiosk mode initialization and UI elements
2. **`android/app/src/main/kotlin/com/example/visage_app/MainActivity.kt`** - Native Android implementation

## 🚀 How It Works

### 1. App Launch
- When the app starts, Android shows **"App is pinned"** dialog
  - **"Got it"** → Kiosk mode activates, app continues normally
  - **"No thanks"** → App closes immediately
- If user accepts, Lock Task Mode is enabled
- The screen shows a "Kiosk Mode" indicator (green badge, top-left)
- Immersive mode hides system UI bars

### 2. User Interaction
- Users can interact with the app normally
- Pressing back button triggers the password dialog
- The floating exit button (red, top-right) also triggers the password dialog

### 3. Exit Process
- User clicks exit button or presses back
- Password dialog appears
- User enters password (default: `1234`)
- If correct: Lock Task Mode is disabled, user can exit
- If incorrect: Error message shown, kiosk mode remains active

## 🔧 Configuration

### Change the Exit Password

Edit `lib/widgets/exit_kiosk_dialog.dart`:

```dart
// Line 15: Change this to your desired password
static const String _correctPassword = '1234';  // Change '1234' to your password
```

### Disable Exit Button (Optional)

If you want to hide the floating exit button, edit `lib/main.dart` and comment out or remove the "Floating exit button" Positioned widget (around line 100).

## 📱 Testing Instructions

### Testing on Android Device:

1. **Build and Install**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

2. **Verify Kiosk Mode**:
   - App should show green "Kiosk Mode" badge
   - Try pressing Home button → Should stay in app
   - Try pressing Back button → Should show password dialog
   - Try Recent Apps button → Should stay in app

3. **Test Exit**:
   - Click red exit button (top-right)
   - Enter password: `1234`
   - Click "Exit"
   - Kiosk mode should disable
   - Now you can press Home/Back to exit normally

### Important Notes:

⚠️ **Android Version Requirements**:
- Kiosk Mode works on Android 5.0 (Lollipop) and above
- On Android 4.x, the app will run normally without kiosk mode

⚠️ **Limitations**:
- This uses `startLockTask()` which is less restrictive than Device Owner mode
- On some devices, users might be able to exit by:
  - Force stopping from Settings (requires going through security)
  - Rebooting the device
  
⚠️ **For Production Use**:
- Consider implementing Device Owner mode for stronger security
- Requires factory reset to set up device owner
- Provides complete lockdown capabilities

## 🎨 UI Elements

### Kiosk Mode Indicator (Green Badge)
- **Location**: Top-left corner
- **Appearance**: Green background with lock icon
- **Purpose**: Shows user that kiosk mode is active

### Exit Button (Red FAB)
- **Location**: Top-right corner
- **Appearance**: Small red floating action button with exit icon
- **Purpose**: Allows authorized users to exit via password

## 🐛 Troubleshooting

### Kiosk Mode Not Starting?
- Check Android version (must be 5.0+)
- Look for errors in Flutter console
- Verify MainActivity.kt compiled successfully

### Password Dialog Not Showing?
- Check that WillPopScope is properly wrapping the Scaffold
- Verify exit button's onPressed handler is connected

### Can't Exit Even with Correct Password?
- Try force stopping the app from Android Settings
- Reboot the device if necessary
- Check for errors in the console when stopKioskMode() is called

### Stuck in Kiosk Mode During Development?
- Use `adb shell` to force stop: `adb shell am force-stop com.example.visage_app`
- Or reboot your device
- Or enable USB debugging and use Android Studio to stop the app

## 🔐 Security Recommendations

1. **Change Default Password**: The default password `1234` is for testing only
2. **Use Strong Password**: Use a complex password for production
3. **Hide Exit Button**: Consider hiding the exit button for end users
4. **Log Exit Attempts**: Add logging for failed password attempts
5. **Time-based Access**: Consider adding time-based unlock (e.g., only allow exit during certain hours)

## 📞 Emergency Exit Methods

If you get stuck in kiosk mode:

1. **ADB Command** (if USB debugging enabled):
   ```bash
   adb shell am force-stop com.example.visage_app
   ```

2. **Safe Mode Boot**:
   - Reboot device into safe mode
   - Force stop the app from Settings

3. **Factory Reset** (last resort):
   - Only if app is set to auto-start on boot and you're completely locked out

## 🎓 Next Steps (Optional Enhancements)

1. **Admin Panel**: Create a hidden admin panel for configuration
2. **Remote Control**: Add ability to remotely disable kiosk mode
3. **Time Restrictions**: Only enable kiosk mode during work hours
4. **Usage Analytics**: Track how long users stay in the app
5. **Device Owner Mode**: Implement full device owner for maximum security

---

**Password**: `1234` (default - please change this!)

**Developer**: SLT Flutter Team
**Last Updated**: November 9, 2025

