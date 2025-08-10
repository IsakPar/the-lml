package com.thankful.app.features.venues

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.thankful.app.core.ApiClient
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

data class Venue(val id: String, val name: String)

@Composable
fun VenuesScreen(api: ApiClient) {
  var venues by remember { mutableStateOf(listOf<Venue>()) }
  var error by remember { mutableStateOf<String?>(null) }
  var loading by remember { mutableStateOf(false) }
  val scope = rememberCoroutineScope()

  LaunchedEffect(Unit) { fetch(scope, api) { v, e, l -> venues = v; error = e; loading = l } }

  Column(Modifier.fillMaxSize().padding(12.dp)) {
    if (loading) LinearProgressIndicator(modifier = Modifier.fillMaxWidth())
    error?.let { Text(it, color = MaterialTheme.colorScheme.error) }
    LazyColumn(Modifier.fillMaxSize()) {
      items(venues) { v -> Text(v.name, modifier = Modifier.padding(8.dp)) }
    }
  }
}

private fun fetch(scope: androidx.compose.runtime.Composer, api: ApiClient, update: (List<Venue>, String?, Boolean) -> Unit) {}

private fun fetch(scope: androidx.compose.runtime.CoroutineScope, api: ApiClient, update: (List<Venue>, String?, Boolean) -> Unit) {
  update(emptyList(), null, true)
  scope.launch(Dispatchers.IO) {
    try {
      val (body, code) = api.request("/v1/venues")
      if (code == 200) {
        val names = Regex("\"name\":\"([^\"]+)\"")
        val ids = Regex("\"_id\":\"?([^,\"]+)\"?")
        val items = names.findAll(body).zip(ids.findAll(body)).map { match ->
          val name = match.first.groupValues[1]
          val id = match.second.groupValues[1]
          Venue(id, name)
        }.toList()
        update(items, null, false)
      } else {
        update(emptyList(), "Error $code", false)
      }
    } catch (e: Exception) {
      update(emptyList(), e.message, false)
    }
  }
}


