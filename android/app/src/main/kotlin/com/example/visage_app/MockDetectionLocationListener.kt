package com.example.visage_app

import android.content.Context
import android.location.Location
import android.location.LocationListener
import android.os.Build
import android.os.Bundle

/**
 * Custom LocationListener for real-time per-fix mock detection
 * Checks each location update as it's received from the system
 */
class MockDetectionLocationListener(
    context: Context,
    private val onLocationReceived: (Location, Boolean) -> Unit,
    private val onError: (String) -> Unit = {}
) : LocationListener {

    private val mockDetector = MockLocationDetector(context)

    override fun onLocationChanged(location: Location) {
        try {
            val result = mockDetector.performComprehensiveCheck(location)

            println("[MockDetectionLocationListener] Location received:")
            println("  Provider: ${location.provider}")
            println("  Lat/Lng: ${location.latitude}, ${location.longitude}")
            println("  Accuracy: ${location.accuracy}m")
            println("  Is From Mock Provider: ${location.isFromMockProvider}")
            println("  Comprehensive check - isMocked: ${result.isMocked}")
            result.details.forEach { println("    $it") }

            onLocationReceived(location, result.isMocked)
        } catch (e: Exception) {
            val errorMsg = "Error checking mock status: ${e.message}"
            println("[MockDetectionLocationListener] $errorMsg")
            onError(errorMsg)
        }
    }

    override fun onProviderEnabled(provider: String) {
        println("[MockDetectionLocationListener] Provider enabled: $provider")
    }

    override fun onProviderDisabled(provider: String) {
        println("[MockDetectionLocationListener] Provider disabled: $provider")
    }

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            @Suppress("DEPRECATION")
            println("[MockDetectionLocationListener] Status changed - Provider: $provider, Status: $status")
        }
    }
}