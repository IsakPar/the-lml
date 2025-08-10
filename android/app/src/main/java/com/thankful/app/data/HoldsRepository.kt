package com.thankful.app.data

import com.thankful.app.core.ApiClient

class HoldsRepository(private val api: ApiClient) {
  suspend fun acquire(perfId: String, seats: List<String>, ttlSeconds: Int): Pair<String, Int> {
    val body = "{" + "\"performance_id\":\"$perfId\",\"seats\":[" + seats.joinToString(separator = ",") { "\"$it\"" } + "],\"ttl_seconds\":$ttlSeconds}"
    return api.request("/v1/holds", method = "POST", bodyJson = body, idempotencyKey = makeIdem("POST","/v1/holds", body))
  }
  suspend fun extend(perfId: String, seatId: String, addSec: Int, holdToken: String): Pair<String, Int> {
    val body = "{" + "\"performance_id\":\"$perfId\",\"seat_id\":\"$seatId\",\"additional_seconds\":$addSec,\"hold_token\":\"$holdToken\"}"
    return api.request("/v1/holds", method = "PATCH", bodyJson = body, idempotencyKey = makeIdem("PATCH","/v1/holds", body), headers = mapOf("If-Match" to holdToken))
  }
  suspend fun release(holdId: String, perfId: String, seatId: String, holdToken: String): Pair<String, Int> {
    return api.request("/v1/holds/$holdId?performance_id=$perfId&seat_id=$seatId", method = "DELETE", idempotencyKey = makeIdem("DELETE","/v1/holds/$holdId",""), headers = mapOf("If-Match" to holdToken))
  }
  private fun makeIdem(method: String, path: String, body: String): String {
    val key = (method + path + body).hashCode().toUInt().toString(16)
    return "idem-$key"
  }
}


