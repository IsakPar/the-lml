package com.thankful.app.data

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKeys
import org.json.JSONArray
import org.json.JSONObject

data class CachedTicket(
    val jti: String,
    val token: String,
    val orderId: String,
    val performanceId: String,
    val seatId: String,
    val tenantId: String,
    val issuedAt: Long,
    val expiresAt: Long?
)

class TicketsCacheService(ctx: Context) {
    private val masterKey = MasterKeys.getOrCreate(MasterKeys.AES256_GCM_SPEC)
    private val prefs = EncryptedSharedPreferences.create(
        "tickets_cache",
        masterKey,
        ctx,
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    private fun key(orgId: String) = "tickets_" + orgId

    fun list(orgId: String): List<CachedTicket> {
        val json = prefs.getString(key(orgId), "[]") ?: "[]"
        val arr = JSONArray(json)
        val out = mutableListOf<CachedTicket>()
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            out.add(
                CachedTicket(
                    jti = o.getString("jti"),
                    token = o.getString("token"),
                    orderId = o.getString("orderId"),
                    performanceId = o.getString("performanceId"),
                    seatId = o.getString("seatId"),
                    tenantId = o.getString("tenantId"),
                    issuedAt = o.getLong("issuedAt"),
                    expiresAt = if (o.has("expiresAt")) o.getLong("expiresAt") else null
                )
            )
        }
        return out
    }

    fun save(orgId: String, tickets: List<CachedTicket>) {
        val arr = JSONArray()
        tickets.forEach { t ->
            val o = JSONObject()
                .put("jti", t.jti)
                .put("token", t.token)
                .put("orderId", t.orderId)
                .put("performanceId", t.performanceId)
                .put("seatId", t.seatId)
                .put("tenantId", t.tenantId)
                .put("issuedAt", t.issuedAt)
            if (t.expiresAt != null) o.put("expiresAt", t.expiresAt)
            arr.put(o)
        }
        prefs.edit().putString(key(orgId), arr.toString()).apply()
    }

    fun upsert(orgId: String, ticket: CachedTicket) {
        val list = list(orgId).toMutableList()
        val idx = list.indexOfFirst { it.jti == ticket.jti }
        if (idx >= 0) list[idx] = ticket else list.add(ticket)
        save(orgId, list)
    }

    fun remove(orgId: String, jti: String) {
        val list = list(orgId).filterNot { it.jti == jti }
        save(orgId, list)
    }
}


