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
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

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
  val client = remember { OkHttpClient() }
  val baseUrl = System.getenv("API_BASE_URL") ?: "http://10.0.2.2:3000"

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
              val req = Request.Builder()
                .url("$baseUrl/v1/oauth/token")
                .post(json.toRequestBody("application/json".toMediaType()))
                .build()
              client.newCall(req).execute().use { resp ->
                if (resp.isSuccessful) {
                  val body = resp.body?.string() ?: "{}"
                  val t = Regex("\"access_token\":\"([^\"]+)\"").find(body)?.groupValues?.get(1)
                  token = t
                } else {
                  message = "Login failed: ${'$'}{resp.code}"
                }
              }
            }
          }) { Text("Sign in") }
        } else {
          Button(onClick = {
            scope.launch(Dispatchers.IO) {
              val req = Request.Builder()
                .url("$baseUrl/v1/users/me")
                .addHeader("Authorization", "Bearer ${'$'}token")
                .addHeader("X-Org-ID", "00000000-0000-0000-0000-000000000001")
                .build()
              client.newCall(req).execute().use { resp ->
                message = "me: ${'$'}{resp.code}"
              }
            }
          }) { Text("Call /v1/users/me") }
          Spacer(Modifier.height(8.dp))
          Button(onClick = { token = null }) { Text("Sign out") }
        }
        Spacer(Modifier.height(16.dp))
        if (message != null) Text(message!!)
      }
    }
  }
}


