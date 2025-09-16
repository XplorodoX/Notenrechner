package com.example.notenrechner

enum class Modus { IHK, NORMAL }

data class HistoryEntry(
    val modus: Modus,
    val punkte: Int,
    val maxPunkte: Int?, // bei IHK immer 100, bei NORMAL gesetzt
    val note: Double,
    val verbal: String,
    val timestamp: Long = System.currentTimeMillis()
)