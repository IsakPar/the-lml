package com.thankful.app.data

import kotlinx.coroutines.delay

class OrderPollingService(private val orders: OrdersRepository) {
  suspend fun waitUntilPaid(orderId: String, timeoutSec: Int = 30): Boolean {
    val start = System.currentTimeMillis()
    while (System.currentTimeMillis() - start < timeoutSec * 1000) {
      try {
        val (body, code) = orders.getOrder(orderId)
        if (code == 200 && body.contains("\"status\":\"paid\"")) return true
      } catch (_: Exception) {}
      delay(1000)
    }
    return false
  }
}


