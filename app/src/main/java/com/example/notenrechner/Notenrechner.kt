package com.example.notenrechner

object Notenrechner {
    // IHK Notenschlüssel (Stand: Oktober 2014): Mapping von 0–100 Punkten auf Komma-Noten
    fun berechneIHK(punkte: Int): Double = when (punkte.coerceIn(0, 100)) {
        100 -> 1.0
        99, 98 -> 1.1
        97, 96 -> 1.2
        95, 94 -> 1.3
        93, 92 -> 1.4
        91 -> 1.5
        90 -> 1.6
        89 -> 1.7
        88 -> 1.8
        87 -> 1.9
        86, 85 -> 2.0
        84 -> 2.1
        83 -> 2.2
        82 -> 2.3
        81 -> 2.4
        80 -> 2.5
        79 -> 2.6
        78, 77 -> 2.7
        76 -> 2.8
        75, 74 -> 2.9
        73 -> 3.0
        72, 71 -> 3.1
        70 -> 3.2
        69, 68 -> 3.3
        67 -> 3.4
        66 -> 3.5
        65, 64 -> 3.6
        63, 62 -> 3.7
        61 -> 3.8
        60, 59 -> 3.9
        58, 57 -> 4.0
        56, 55 -> 4.1
        54 -> 4.2
        53, 52 -> 4.3
        51, 50 -> 4.4
        49 -> 4.5
        48, 47 -> 4.6
        46, 45 -> 4.7
        44, 43 -> 4.8
        42, 41 -> 4.9
        40, 39, 38 -> 5.0
        37, 36 -> 5.1
        35, 34 -> 5.2
        33, 32 -> 5.3
        31, 30 -> 5.4
        29 -> 5.5
        in 23..28 -> 5.6
        in 17..22 -> 5.7
        in 12..16 -> 5.8
        in 6..11 -> 5.9
        else -> 6.0 // 0..5
    }

    // IHK mit beliebigen Maximalpunkten: skaliere auf 0–100 und wende Mapping an
    fun berechneIHK(punkte: Int, maxPunkte: Int): Double {
        if (maxPunkte <= 0) return Double.NaN
        val skaliert = ((punkte.toDouble() / maxPunkte) * 100).toInt().coerceIn(0, 100)
        return berechneIHK(skaliert)
    }

    // Normaler Notenschlüssel: 1,0 = 100%, 6,0 = 0%, linear
    fun berechneNormal(punkte: Int, maxPunkte: Int): Double {
        if (maxPunkte <= 0) return Double.NaN
        val prozent = punkte * 100.0 / maxPunkte
        return ((6.0 - 1.0) * (100 - prozent) / 100) + 1.0
    }

    // Verbale Bewertung nach üblichen Grenzen
    // sehr gut (1,0–1,5), gut (1,6–2,5), befriedigend (2,6–3,5),
    // ausreichend (3,6–4,0), mangelhaft (4,1–4,9), ungenügend (5,0–6,0)
    fun verbaleBewertung(note: Double): String {
        val n = String.format(java.util.Locale.US, "%.1f", note).toDoubleOrNull() ?: note
        return when {
            n <= 1.5 -> "sehr gut"
            n <= 2.5 -> "gut"
            n <= 3.5 -> "befriedigend"
            n <= 4.0 -> "ausreichend"
            n <= 4.9 -> "mangelhaft"
            else -> "ungenügend"
        }
    }
}