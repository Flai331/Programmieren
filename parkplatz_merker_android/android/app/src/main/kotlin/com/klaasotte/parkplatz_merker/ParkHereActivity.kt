package com.klaasotte.parkplatz_merker

import android.app.Activity
import android.os.Bundle
import android.widget.Toast

class ParkHereActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val source = intent?.getStringExtra("source") ?: "widget"
        TripService.start(this, TripService.ACTION_MANUAL, source)
        Toast.makeText(this, "Standort wird gemerkt …", Toast.LENGTH_SHORT).show()
        finish()
    }
}
