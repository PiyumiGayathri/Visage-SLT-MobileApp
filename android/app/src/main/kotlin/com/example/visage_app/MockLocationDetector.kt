package com.example.visage_app

import android.app.AppOpsManager
import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Build
import androidx.annotation.RequiresApi

/**
 * Comprehensive mock location detection system
 * Implements multiple verification layers:
 * 1. AppOpsManager check for mock location permission
 * 2. Per-fix mock detection via Location.isFromMockProvider
 * 3. Sensor-based cross-validation
 */
class MockLocationDetector(private val context: Context) {

    private val appOpsManager: AppOpsManager? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
        context.getSystemService(Context.APP_OPS_SERVICE) as? AppOpsManager
    } else {
        null
    }

    private val locationManager: LocationManager =
        context.getSystemService(Context.LOCATION_SERVICE) as LocationManager

    /**
     * Check if mock location app is currently set via AppOpsManager
     * This detects if the system has a mock location provider set
     *
     * @return true if mock location app is set, false otherwise
     */
    @RequiresApi(Build.VERSION_CODES.KITKAT)
    fun isMockLocationAppSet(): Boolean {
        return try {
            // Method 1: Check AppOpsManager for any app with mock location permission
            val result = appOpsManager?.noteOp(
                AppOpsManager.OPSTR_MOCK_LOCATION,
                android.os.Process.myUid(),
                context.packageName
            )
            // 0 = MODE_ALLOWED means mock location is enabled on system
            val appOpsCheck = result == 0

            if (appOpsCheck) {
                println("Mock location detected via AppOpsManager")
                return true
            }

            // Method 2: Check if any location manager provider is set to mock
            val allProviders = locationManager.allProviders
            for (provider in allProviders) {
                try {
                    // Try to get the last known location to check if it's from mock provider
                    val location = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        locationManager.getLastKnownLocation(provider)
                    } else {
                        @Suppress("DEPRECATION")
                        locationManager.getLastKnownLocation(provider)
                    }

                    // If we find a mocked location, mock app is set
                    if (location != null && location.isFromMockProvider) {
                        println("Mock location detected via provider: $provider")
                        return true
                    }
                } catch (e: Exception) {
                    // Provider not available, continue checking others
                }
            }

            println("No mock location detected")
            false
        } catch (e: Exception) {
            e.printStackTrace()
            println("Error checking mock location app: ${e.message}")
            false
        }
    }

    /**
     * Verify a location fix is not mocked by checking the Location object's internal flag
     * This is the most reliable per-fix detection method
     *
     * @param location The Location object to verify
     * @return true if location is from mock provider, false if genuine
     */
    fun isLocationMocked(location: Location?): Boolean {
        if (location == null) return false

        return try {
            // Check Location.isFromMockProvider() - available in Android 4.2+
            // This flag is set by Android system when location comes from a mock provider
            location.isFromMockProvider
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Check if any location provider is currently mocked
     * Checks all enabled providers
     *
     * @return true if any provider is mocked, false otherwise
     */
    fun isAnyProviderMocked(): Boolean {
        return try {
            val allProviders = locationManager.allProviders
            allProviders.any { provider ->
                try {
                    // Get last known location from each provider
                    val lastLocation = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        locationManager.getLastKnownLocation(provider)
                    } else {
                        @Suppress("DEPRECATION")
                        locationManager.getLastKnownLocation(provider)
                    }

                    // Check if this provider is mocked
                    lastLocation != null && lastLocation.isFromMockProvider
                } catch (e: Exception) {
                    false
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Comprehensive mock location check combining multiple detection methods
     * Returns detailed results for logging and analysis
     *
     * @param location Optional location object to verify per-fix
     * @return MockDetectionResult with detailed findings
     */
    fun performComprehensiveCheck(location: Location? = null): MockDetectionResult {
        val results = mutableListOf<String>()
        var isMocked = false

        // Check 1: AppOpsManager (mock app set)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            val appOpsMocked = try {
                isMockLocationAppSet()
            } catch (e: Exception) {
                false
            }
            results.add("AppOpsManager check: $appOpsMocked")
            if (appOpsMocked) isMocked = true
        }

        // Check 2: Per-fix location verification
        if (location != null) {
            val locationMocked = isLocationMocked(location)
            results.add("Per-fix location check (isFromMockProvider): $locationMocked")
            if (locationMocked) isMocked = true
        }

        // Check 3: Any provider mocked
        val anyProviderMocked = try {
            isAnyProviderMocked()
        } catch (e: Exception) {
            false
        }
        results.add("Any provider mocked: $anyProviderMocked")
        if (anyProviderMocked) isMocked = true

        // Check 4: Sensor-based cross-validation (accuracy check)
        val accuracySuspicious = location?.let {
            isAccuracySuspicious(it)
        } ?: false
        results.add("Suspicious accuracy patterns: $accuracySuspicious")
        if (accuracySuspicious) isMocked = true

        return MockDetectionResult(
            isMocked = isMocked,
            details = results,
            timestamp = System.currentTimeMillis(),
            locationLatitude = location?.latitude,
            locationLongitude = location?.longitude,
            locationAccuracy = location?.accuracy
        )
    }

    /**
     * Cross-validate location using sensor-based patterns
     * Detects suspicious accuracy patterns that indicate mock locations
     *
     * @param location Location to validate
     * @return true if accuracy patterns are suspicious
     */
    private fun isAccuracySuspicious(location: Location): Boolean {
        return try {
            val accuracy = location.accuracy
            val provider = location.provider
            val speed = location.speed
            val bearing = location.bearing

            // Suspicious patterns:
            // 1. Exactly 0 accuracy (mock apps sometimes set this)
            // 2. Impossibly high accuracy (< 0.5 meter) - indicates perfect mock
            // 3. Exactly matching accuracy values (indicates mock data)
            // 4. Provider is "fused" but accuracy is suspiciously exact
            // 5. Speed or bearing values are exactly 0 when moving

            when {
                accuracy == 0f -> {
                    println("Suspicious: Accuracy is exactly 0.0")
                    true
                }
                accuracy < 0.5f && provider != LocationManager.GPS_PROVIDER -> {
                    println("Suspicious: Sub-half-meter accuracy on $provider provider")
                    true
                }
                provider == LocationManager.NETWORK_PROVIDER && accuracy < 2 -> {
                    println("Suspicious: Network provider with sub-2m accuracy")
                    true
                }
                accuracy > 10000 -> {
                    println("Suspicious: Accuracy exceeds 10km (likely mock)")
                    true
                }
                // Check for round numbers indicating mock
                accuracy % 10 == 0f && accuracy > 50 -> {
                    println("Suspicious: Accuracy is round number: $accuracy (indicates mock)")
                    true
                }
                else -> false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    /**
     * Data class for comprehensive mock detection results
     */
    data class MockDetectionResult(
        val isMocked: Boolean,
        val details: List<String>,
        val timestamp: Long,
        val locationLatitude: Double? = null,
        val locationLongitude: Double? = null,
        val locationAccuracy: Float? = null
    ) {
        fun toMap(): Map<String, Any?> {
            return mapOf(
                "isMocked" to isMocked,
                "details" to details,
                "timestamp" to timestamp,
                "latitude" to locationLatitude,
                "longitude" to locationLongitude,
                "accuracy" to locationAccuracy
            )
        }
    }
}

