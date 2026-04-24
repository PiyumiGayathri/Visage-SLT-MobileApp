package com.example.visage_app

import android.app.ActivityManager
import android.content.Context
import android.location.Location
import android.os.Build
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.visage_app/kiosk"
    private val MOCK_LOCATION_CHANNEL = "com.example.visage_app/mockLocation"

    private var mockLocationDetector: MockLocationDetector? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Kiosk mode channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKioskMode" -> {
                    val success = startKioskMode()
                    result.success(success)
                }
                "stopKioskMode" -> {
                    val success = stopKioskMode()
                    result.success(success)
                }
                "isInKioskMode" -> {
                    val isInKiosk = isInKioskMode()
                    result.success(isInKiosk)
                }
                "enableImmersiveMode" -> {
                    enableImmersiveMode()
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Mock location detection channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MOCK_LOCATION_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isMockLocationAppSet" -> {
                    val isMocked = isMockLocationAppSet()
                    result.success(isMocked)
                }
                "isLocationMocked" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val accuracy = call.argument<Double>("accuracy")
                    val provider = call.argument<String>("provider") ?: "fused"

                    if (latitude != null && longitude != null) {
                        val location = Location(provider).apply {
                            this.latitude = latitude
                            this.longitude = longitude
                            if (accuracy != null) this.accuracy = accuracy.toFloat()
                        }
                        val isMocked = isLocationMocked(location)
                        result.success(isMocked)
                    } else {
                        result.error("INVALID_ARGS", "Missing latitude or longitude", null)
                    }
                }
                "isAnyProviderMocked" -> {
                    val isMocked = isAnyProviderMocked()
                    result.success(isMocked)
                }
                "performComprehensiveCheck" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val accuracy = call.argument<Double>("accuracy")
                    val provider = call.argument<String>("provider")

                    val location = if (latitude != null && longitude != null) {
                        Location(provider ?: "fused").apply {
                            this.latitude = latitude
                            this.longitude = longitude
                            if (accuracy != null) this.accuracy = accuracy.toFloat()
                        }
                    } else {
                        null
                    }

                    val detectionResult = performComprehensiveCheck(location)
                    result.success(detectionResult)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Check if mock location app is currently set via AppOpsManager
     */
    private fun isMockLocationAppSet(): Boolean {
        return try {
            if (mockLocationDetector == null) {
                mockLocationDetector = MockLocationDetector(this)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                mockLocationDetector!!.isMockLocationAppSet()
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Verify if a specific location is mocked
     */
    private fun isLocationMocked(location: Location): Boolean {
        return try {
            if (mockLocationDetector == null) {
                mockLocationDetector = MockLocationDetector(this)
            }
            mockLocationDetector!!.isLocationMocked(location)
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Check if any location provider is currently mocked
     */
    private fun isAnyProviderMocked(): Boolean {
        return try {
            if (mockLocationDetector == null) {
                mockLocationDetector = MockLocationDetector(this)
            }
            mockLocationDetector!!.isAnyProviderMocked()
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Perform comprehensive mock location check
     */
    private fun performComprehensiveCheck(location: Location?): Map<String, Any?> {
        return try {
            if (mockLocationDetector == null) {
                mockLocationDetector = MockLocationDetector(this)
            }
            val result = mockLocationDetector!!.performComprehensiveCheck(location)
            result.toMap()
        } catch (e: Exception) {
            e.printStackTrace()
            mapOf(
                "isMocked" to true,
                "details" to listOf("Error during check: ${e.message}"),
                "timestamp" to System.currentTimeMillis(),
                "latitude" to location?.latitude,
                "longitude" to location?.longitude,
                "accuracy" to location?.accuracy
            )
        }
    }

    private fun startKioskMode(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                startLockTask()
                enableImmersiveMode()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun stopKioskMode(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                stopLockTask()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isInKioskMode(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            try {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                val method = ActivityManager::class.java.getMethod("isInLockTaskMode")
                method.invoke(activityManager) as Boolean
            } catch (e: Exception) {
                false
            }
        } else {
            false
        }
    }

    private fun enableImmersiveMode() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior = WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        } else {
            @Suppress("DEPRECATION")
            window.decorView.systemUiVisibility = (
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
                or View.SYSTEM_UI_FLAG_FULLSCREEN
                or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
                or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
            )
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && isInKioskMode()) {
            enableImmersiveMode()
        }
    }

    override fun onBackPressed() {
        // If not in kiosk mode, allow normal back press behavior
        if (!isInKioskMode()) {
            super.onBackPressed()
        }
        // If in kiosk mode, do nothing (Flutter will handle it with WillPopScope)
    }
}
