package com.thankful.app.util

import kotlinx.coroutines.delay
import kotlin.random.Random

suspend fun <T> retryWithBackoff(maxAttempts: Int = 5, initialDelayMs: Long = 100, factor: Double = 2.0, jitterMs: Long = 50, block: suspend () -> T): T {
  var delayMs = initialDelayMs
  var attempts = 0
  while (true) {
    try { return block() } catch (e: Exception) {
      attempts += 1
      if (attempts >= maxAttempts) throw e
      val jitter = Random.nextLong(-jitterMs, jitterMs)
      delay(delayMs + jitter)
      delayMs = (delayMs * factor).toLong()
    }
  }
}


