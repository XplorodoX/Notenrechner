package com.example.notenrechner

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import com.example.notenrechner.ui.theme.NotenrechnerTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContent {
            NotenrechnerTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
                    NotenrechnerScreen(Modifier.padding(innerPadding))
                }
            }
        }
    }
}

@Composable
fun NotenrechnerScreen(modifier: Modifier = Modifier) {
    var punkte by remember { mutableStateOf("") }
    var maxPunkte by remember { mutableStateOf("") }
    var modus by remember { mutableStateOf(0) } // 0 = IHK, 1 = Normal
    var note by remember { mutableStateOf("") }
    var verbal by remember { mutableStateOf("") }
    val history = remember { mutableStateListOf<HistoryEntry>() }

    Column(
        modifier = modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text("Notenrechner", style = MaterialTheme.typography.headlineMedium)
        Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
            Text("Modus:")
            Spacer(Modifier.width(8.dp))
            SegmentedButton(selectedIndex = modus, onIndexSelected = {
                modus = it
                // Reset der Ausgabe und ggf. Felder beim Wechseln
                note = ""
                verbal = ""
                if (modus == 0) maxPunkte = "" // im IHK-Modus wird max nicht verwendet
            })
        }
        OutlinedTextField(
            value = punkte,
            onValueChange = { punkte = it.filter { c -> c.isDigit() } },
            label = { Text("Erreichte Punkte") },
            singleLine = true,
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
        )
        if (modus == 1) {
            OutlinedTextField(
                value = maxPunkte,
                onValueChange = { maxPunkte = it.filter { c -> c.isDigit() } },
                label = { Text("Maximale Punkte") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
            )
        }
        Button(onClick = {
            val p = punkte.toIntOrNull()
            val m = maxPunkte.toIntOrNull()
            note = when (modus) {
                0 -> {
                    if (p == null) {
                        "Bitte Punkte (0–100) eingeben."
                    } else if (p < 0 || p > 100) {
                        "IHK: Punkte müssen zwischen 0 und 100 liegen."
                    } else {
                        val n = com.example.notenrechner.Notenrechner.berechneIHK(p)
                        verbal = com.example.notenrechner.Notenrechner.verbaleBewertung(n)
                        // Verlauf hinzufügen (max 50 Einträge)
                        if (history.size >= 50) history.removeAt(0)
                        history.add(HistoryEntry(Modus.IHK, p, 100, n, verbal))
                        String.format(java.util.Locale.GERMANY, "%.1f", n)
                    }
                }
                else -> {
                    if (p == null || m == null || m <= 0) {
                        "Bitte gültige Werte eingeben (Punkte und maximale Punkte > 0)."
                    } else if (p < 0 || p > m) {
                        "Punkte müssen zwischen 0 und $m liegen."
                    } else {
                        val n = com.example.notenrechner.Notenrechner.berechneNormal(p, m)
                        verbal = com.example.notenrechner.Notenrechner.verbaleBewertung(n)
                        // Verlauf hinzufügen (max 50 Einträge)
                        if (history.size >= 50) history.removeAt(0)
                        history.add(HistoryEntry(Modus.NORMAL, p, m, n, verbal))
                        String.format(java.util.Locale.GERMANY, "%.1f", n)
                    }
                }
            }
        }) {
            Text("Berechnen")
        }
        if (note.isNotEmpty()) {
            Card(modifier = Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Ergebnis", style = MaterialTheme.typography.titleLarge)
                    val modusText = if (modus == 0) "IHK" else "Normal"
                    Text("Modus: $modusText", style = MaterialTheme.typography.bodyMedium)
                    Text("Note: $note", style = MaterialTheme.typography.headlineMedium)
                    if (verbal.isNotEmpty()) {
                        Text("Bewertung: ${verbal.replaceFirstChar { if (it.isLowerCase()) it.titlecase(java.util.Locale.getDefault()) else it.toString() }}",
                            style = MaterialTheme.typography.titleMedium)
                    }
                }
            }
        }

        // Verlauf
        if (history.isNotEmpty()) {
            Spacer(Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("Verlauf", style = MaterialTheme.typography.titleLarge)
                TextButton(onClick = { history.clear() }) { Text("Löschen") }
            }
            Card(modifier = Modifier.fillMaxWidth()) {
                LazyColumn(modifier = Modifier
                    .fillMaxWidth()
                    .padding(8.dp)) {
                    items(history.reversed()) { entry ->
                        HistoryRow(entry)
                        Divider()
                    }
                }
            }
        }
    }
}

@Composable
fun HistoryRow(entry: HistoryEntry) {
    val modusText = if (entry.modus == Modus.IHK) "IHK" else "Normal"
    val noteText = String.format(java.util.Locale.GERMANY, "%.1f", entry.note)
    val dateText = java.text.SimpleDateFormat("dd.MM.yyyy HH:mm", java.util.Locale.GERMANY)
        .format(java.util.Date(entry.timestamp))
    Column(Modifier.padding(8.dp)) {
        Text("$modusText • Note $noteText — ${entry.verbal.replaceFirstChar { if (it.isLowerCase()) it.titlecase(java.util.Locale.getDefault()) else it.toString() }}",
            style = MaterialTheme.typography.titleMedium)
        val punkteText = if (entry.maxPunkte != null) "${entry.punkte}/${entry.maxPunkte}" else entry.punkte.toString()
        Text("Punkte: $punkteText • $dateText", style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
fun SegmentedButton(selectedIndex: Int, onIndexSelected: (Int) -> Unit) {
    Row {
        Button(
            onClick = { onIndexSelected(0) },
            colors = if (selectedIndex == 0) ButtonDefaults.buttonColors() else ButtonDefaults.outlinedButtonColors(),
            modifier = Modifier.padding(end = 4.dp)
        ) { Text("IHK") }
        Button(
            onClick = { onIndexSelected(1) },
            colors = if (selectedIndex == 1) ButtonDefaults.buttonColors() else ButtonDefaults.outlinedButtonColors()
        ) { Text("Normal") }
    }
}

@Preview(showBackground = true)
@Composable
fun NotenrechnerPreview() {
    NotenrechnerTheme {
        NotenrechnerScreen()
    }
}