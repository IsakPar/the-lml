package com.thankful.app.features.availability

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.thankful.app.core.ApiClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@Composable
fun AvailabilityScreen(api: ApiClient, perfId: String, seatmapId: String) {
  var held by remember { mutableStateOf(0) }
  var available by remember { mutableStateOf(0) }
  var error by remember { mutableStateOf<String?>(null) }
  val scope = rememberCoroutineScope()

  LaunchedEffect(perfId, seatmapId) {
    scope.launch(Dispatchers.IO) {
      try {
        val (body, code) = api.request("/v1/performances/$perfId/availability?seatmap_id=$seatmapId")
        if (code == 200) {
          val heldCount = Regex("\"status\":\"held\"").findAll(body).count()
          val availCount = Regex("\"status\":\"available\"").findAll(body).count()
          held = heldCount
          available = availCount
        } else error = "Error $code"
      } catch (e: Exception) { error = e.message }
    }
  }

  Column(Modifier.fillMaxSize().padding(12.dp)) {
    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
    Text("Held: $held")
    Text("Available: $available")
  }
}


