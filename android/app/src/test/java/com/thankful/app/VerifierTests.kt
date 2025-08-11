package com.thankful.app

import com.thankful.app.core.ApiClient
import com.thankful.app.core.VerifierService
import com.thankful.app.data.CachedTicket
import com.thankful.app.data.TicketsCacheService
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.mockito.Mockito
import android.content.Context

class VerifierTests {
    @Test
    fun verifyOfflineRejectsBadFormat() {
        val api = ApiClient("https://example.invalid")
        val verifier = VerifierService(api)
        assertThrows(Exception::class.java) { verifier.verifyOffline("bad.token") }
    }

    @Test
    fun ticketsCacheRoundtrip() {
        val ctx = Mockito.mock(Context::class.java)
        // For EncryptedSharedPreferences, a real Android test environment is needed; this is a placeholder
        val cache = TicketsCacheService(ctx)
        val org = "org_test"
        val t = CachedTicket("j1", "tkn", "ord", "p1", "A-1", org, 0, null)
        cache.upsert(org, t)
        val list = cache.list(org)
        assertTrue(list.any { it.jti == "j1" })
        cache.remove(org, "j1")
    }
}


