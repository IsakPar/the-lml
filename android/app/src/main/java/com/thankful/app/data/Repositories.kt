package com.thankful.app.data

import com.thankful.app.core.ApiClient

class OrdersRepository(private val api: ApiClient) {
  suspend fun createOrder(totalMinor: Int, currency: String): String {
    val body = "{" + "\"total_minor\":$totalMinor,\"currency\":\"$currency\"}"
    val (resp, code) = api.request("/v1/orders", method = "POST", bodyJson = body, idempotencyKey = null)
    if (code != 200 && code != 201) throw Exception("HTTP $code")
    val id = Regex("\"order_id\":\"([^\"]+)\"").find(resp)?.groupValues?.get(1)
    return id ?: ""
  }
  suspend fun getOrder(id: String): Pair<String, Int> = api.request("/v1/orders/$id")
}

class PaymentsRepository(private val api: ApiClient) {
  suspend fun createPaymentIntent(orderId: String, amountMinor: Int, currency: String): Pair<String, Int> {
    val body = "{" + "\"order_id\":\"$orderId\",\"amount_minor\":$amountMinor,\"currency\":\"$currency\"}"
    return api.request("/v1/payments/intents", method = "POST", bodyJson = body)
  }
}


