package com.thankful.app.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

data class ApiProblem(val type: String, val title: String, val status: Int, val detail: String?, val instance: String?, val trace_id: String?)

sealed class ApiError(message: String): Exception(message) {
  class Network(message: String): ApiError(message)
  class Problem(val problem: ApiProblem): ApiError(problem.title)
}

class ApiClient(private val baseUrl: String, private var accessToken: String? = null, private var orgId: String? = null) {
  private val client = OkHttpClient()

  fun setAuth(token: String?, org: String?) { accessToken = token; orgId = org }

  fun headersForSSE(): Map<String, String> {
    val map = mutableMapOf<String, String>()
    accessToken?.let { map["Authorization"] = "Bearer $it" }
    orgId?.let { map["X-Org-ID"] = it }
    return map
  }

  suspend fun request(path: String, method: String = "GET", bodyJson: String? = null, idempotencyKey: String? = null, headers: Map<String, String>? = null): Pair<String, Int> = withContext(Dispatchers.IO) {
    val media = "application/json".toMediaType()
    val builder = Request.Builder().url("$baseUrl$path").method(method, bodyJson?.toRequestBody(media))
    accessToken?.let { builder.addHeader("Authorization", "Bearer $it") }
    orgId?.let { builder.addHeader("X-Org-ID", it) }
    idempotencyKey?.let { builder.addHeader("Idempotency-Key", it) }
    headers?.forEach { (k, v) -> builder.addHeader(k, v) }
    val resp = client.newCall(builder.build()).execute()
    val body = resp.body?.string() ?: ""
    return@withContext Pair(body, resp.code)
  }
}


