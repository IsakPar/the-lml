package com.thankful.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import com.thankful.app.core.ApiClient
import com.thankful.app.features.venues.VenuesScreen

class MainActivity : ComponentActivity() {
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    setContent { ThankfulApp() }
  }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ThankfulApp() {
  var token by remember { mutableStateOf<String?>(null) }
  var message by remember { mutableStateOf<String?>(null) }
  val scope = rememberCoroutineScope()
  val baseUrl = System.getenv("API_BASE_URL") ?: "http://10.0.2.2:3000"
  val api = remember { ApiClient(baseUrl) }

  MaterialTheme {
    Surface(modifier = Modifier.fillMaxSize()) {
      Column(Modifier.padding(16.dp)) {
        if (token == null) {
          var user by remember { mutableStateOf("") }
          var pass by remember { mutableStateOf("") }
          OutlinedTextField(value = user, onValueChange = { user = it }, label = { Text("Email") })
          Spacer(Modifier.height(8.dp))
          OutlinedTextField(value = pass, onValueChange = { pass = it }, label = { Text("Password") })
          Spacer(Modifier.height(8.dp))
          Button(onClick = {
            scope.launch(Dispatchers.IO) {
              val json = "{" + "\"grant_type\":\"password\",\"username\":\"$user\",\"password\":\"$pass\"}"
              val (body, code) = api.request("/v1/oauth/token", method = "POST", bodyJson = json)
              if (code == 200) {
                val t = Regex("\"access_token\":\"([^\"]+)\"").find(body)?.groupValues?.get(1)
                token = t
                api.setAuth(t, "00000000-0000-0000-0000-000000000001")
              } else {
                message = "Login failed: ${'$'}code"
              }
            }
          }) { Text("Sign in") }
        } else {
          Button(onClick = {
            scope.launch(Dispatchers.IO) {
              val (_, code) = api.request("/v1/users/me")
              message = "me: ${'$'}code"
            }
          }) { Text("Call /v1/users/me") }
          Spacer(Modifier.height(8.dp))
          Button(onClick = { token = null }) { Text("Sign out") }
          Spacer(Modifier.height(16.dp))
          Text("Venues", style = MaterialTheme.typography.titleMedium)
          VenuesScreen(api)
        }
        Spacer(Modifier.height(16.dp))
        if (message != null) Text(message!!)
      }
    }
  }
}


