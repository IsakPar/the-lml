package com.thankful.app.core

import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.SharedFlow
import okhttp3.Headers
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.sse.EventSource
import okhttp3.sse.EventSourceListener
import okhttp3.sse.EventSources

class SSEClient(private val client: OkHttpClient = OkHttpClient()) {
  private var source: EventSource? = null
  private val _events = MutableSharedFlow<Pair<String, String>>(replay = 0, extraBufferCapacity = 64, onBufferOverflow = BufferOverflow.DROP_OLDEST)
  val events: SharedFlow<Pair<String, String>> = _events

  fun start(url: String, headers: Map<String, String> = emptyMap()) {
    val req = Request.Builder().url(url).headers(Headers.of(headers)).addHeader("Accept", "text/event-stream").build()
    val factory = EventSources.createFactory(client)
    source = factory.newEventSource(req, object: EventSourceListener() {
      override fun onEvent(eventSource: EventSource, id: String?, type: String?, data: String) {
        _events.tryEmit(Pair(type ?: "message", data))
      }
    })
  }

  fun stop() { source?.cancel(); source = null }
}


