package com.thankful.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.thankful.app.data.CachedTicket
import com.thankful.app.data.TicketsCacheService
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class TicketsCacheInstrumentedTest {
    @Test
    fun cacheRoundtrip() {
        val appContext = InstrumentationRegistry.getInstrumentation().targetContext
        val cache = TicketsCacheService(appContext)
        val org = "org_test"
        val t = CachedTicket("j1", "tkn", "ord", "p1", "A-1", org, 0, null)
        cache.upsert(org, t)
        val list = cache.list(org)
        assertTrue(list.any { it.jti == "j1" })
        cache.remove(org, "j1")
        assertFalse(cache.list(org).any { it.jti == "j1" })
    }
}


