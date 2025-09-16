package com.example.notenrechner

object Notenrechner {
    // IHK Notenschlüssel: 100-92=1, 91-81=2, 80-67=3, 66-50=4, <50=5
    fun berechneIHK(punkte: Int, maxPunkte: Int): Int {
        val prozent = punkte * 100.0 / maxPunkte
        return when {
            prozent >= 92 -> 1
            prozent >= 81 -> 2
            prozent >= 67 -> 3
            prozent >= 50 -> 4
            else -> 5
        }
    }

    // IHK-Überladung: Maximalpunkte immer 100
    fun berechneIHK(punkte: Int): Int = berechneIHK(punkte, 100)

    // Normaler Notenschlüssel: 1,0 = 100%, 6,0 = 0%, linear
    fun berechneNormal(punkte: Int, maxPunkte: Int): Double {
        val prozent = punkte * 100.0 / maxPunkte
        return ((6.0 - 1.0) * (100 - prozent) / 100) + 1.0
    }
}