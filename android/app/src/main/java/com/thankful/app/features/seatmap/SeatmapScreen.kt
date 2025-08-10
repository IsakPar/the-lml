package com.thankful.app.features.seatmap

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.thankful.app.core.ApiClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

@Composable
fun SeatmapScreen(api: ApiClient, seatmapId: String) {
  var title by remember { mutableStateOf<String?>(null) }
  var error by remember { mutableStateOf<String?>(null) }
  var etag by remember { mutableStateOf<String?>(null) }
  val scope = rememberCoroutineScope()

  LaunchedEffect(seatmapId) {
    scope.launch(Dispatchers.IO) {
      try {
        val (body, code) = api.request("/v1/seatmaps/$seatmapId")
        if (code == 200) {
          title = Regex("\"name\":\"([^\"]+)\"").find(body)?.groupValues?.get(1)
        } else {
          error = "Error $code"
        }
      } catch (e: Exception) { error = e.message }
    }
  }

  Column(Modifier.fillMaxSize().padding(12.dp)) {
    if (error != null) Text(error!!, color = MaterialTheme.colorScheme.error)
    Text(title ?: "Seatmap", style = MaterialTheme.typography.titleMedium)
  }
}


