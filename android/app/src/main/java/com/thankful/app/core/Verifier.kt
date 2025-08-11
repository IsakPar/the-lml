package com.thankful.app.core

import android.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.Request
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec

data class Jwk(val kty: String, val crv: String, val kid: String, val x: String)

class VerifierService(private val api: ApiClient) {
    private var keys: List<Jwk> = emptyList()
    private var fetchedAtMs: Long = 0
    private val ttlMs: Long = 300_000
    private val skewSec: Long = 60

    private fun b64uToBytes(s: String): ByteArray {
        var t = s.replace('-', '+').replace('_', '/')
        val pad = (4 - (t.length % 4)) % 4
        t += "=".repeat(pad)
        return Base64.decode(t, Base64.DEFAULT)
    }

    private fun ed25519Spki(raw: ByteArray): ByteArray {
        return byteArrayOf(
            0x30, 0x2A,
            0x30, 0x05,
            0x06, 0x03, 0x2B, 0x65, 0x70,
            0x03, 0x21, 0x00
        ) + raw
    }

    private suspend fun ensureFreshJwks() = withContext(Dispatchers.IO) {
        val now = System.currentTimeMillis()
        if (keys.isNotEmpty() && now - fetchedAtMs < ttlMs) return@withContext
        val req: Request = api.request("/v1/verification/jwks", method = "GET")
        api.client.newCall(req).execute().use { resp ->
            val body = resp.body?.string() ?: "{}"
            val arr = JSONObject(body).optJSONArray("keys")
            val list = mutableListOf<Jwk>()
            if (arr != null) {
                for (i in 0 until arr.length()) {
                    val o = arr.getJSONObject(i)
                    list.add(Jwk(o.getString("kty"), o.getString("crv"), o.getString("kid"), o.getString("x")))
                }
            }
            keys = list
            fetchedAtMs = System.currentTimeMillis()
        }
    }

    suspend fun refreshJwks() = ensureFreshJwks()

    suspend fun redeem(token: String, orgId: String): Pair<String, String> = withContext(Dispatchers.IO) {
        val body = JSONObject().put("ticket_token", token).toString()
        val (resp, code) = api.request("/v1/verification/redeem", method = "POST", bodyJson = body, headers = mapOf("X-Org-ID" to orgId))
        if (code !in 200..299) throw Problem.fromJson(resp)
        val obj = JSONObject(resp)
        Pair(obj.getString("jti"), obj.getString("status"))
    }

    fun verifyOffline(token: String, expectedTenant: String? = null): Boolean {
        val parts = token.split('.')
        require(parts.size == 5 && parts[0] == "ed25519" && parts[1] == "v1") { "bad token" }
        val kid = parts[2]
        val sig = b64uToBytes(parts[3])
        val payload = b64uToBytes(parts[4])
        val jwk = keys.firstOrNull { it.kid == kid } ?: keys.firstOrNull() ?: throw Problem("urn:thankful:verification:no_key", "no_key", 400, "missing key")
        val spki = ed25519Spki(b64uToBytes(jwk.x))
        val kf = KeyFactory.getInstance("Ed25519")
        val pub = kf.generatePublic(X509EncodedKeySpec(spki))
        val sigv = Signature.getInstance("Ed25519")
        sigv.initVerify(pub)
        sigv.update(payload)
        if (!sigv.verify(sig)) throw Problem("urn:thankful:verification:invalid_signature", "invalid_signature", 401, "sig mismatch")
        val obj = JSONObject(String(payload))
        if (obj.has("exp")) {
            val exp = obj.getLong("exp")
            val now = System.currentTimeMillis() / 1000
            if (now > exp + skewSec) throw Problem("urn:thankful:verification:expired", "expired_ticket", 401, "expired")
        }
        if (expectedTenant != null && obj.has("tenant_id")) {
            val ten = obj.getString("tenant_id")
            if (ten != expectedTenant) throw Problem("urn:thankful:verification:tenant_mismatch", "tenant_mismatch", 409, "tenant mismatch")
        }
        return true
    }
}


