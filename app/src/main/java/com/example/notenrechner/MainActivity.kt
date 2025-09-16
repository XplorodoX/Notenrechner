package com.example.notenrechner

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
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