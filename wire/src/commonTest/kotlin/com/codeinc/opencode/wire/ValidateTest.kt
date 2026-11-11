package com.codeinc.opencode.wire

import com.codeinc.opencode.wire.common.v1.SolanaAccountId
import com.codeinc.opencode.wire.currency.v1.StreamLiveMintDataRequest
import com.codeinc.opencode.wire.currency.v1.validate
import dev.bmcreations.protovalidate.ValidationResult
import okio.ByteString.Companion.toByteString
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs

// commonTest, so it runs on every target with a test task: jvm and js (node) here.
class ValidateTest {
    @Test
    fun validRequestPasses() {
        val request = StreamLiveMintDataRequest(
            request = StreamLiveMintDataRequest.Request(
                mints = listOf(SolanaAccountId(value_ = ByteArray(32) { it.toByte() }.toByteString())),
            ),
        )
        assertIs<ValidationResult.Valid>(request.validate())
    }

    @Test
    fun shortMintFails() {
        val request = StreamLiveMintDataRequest(
            request = StreamLiveMintDataRequest.Request(
                mints = listOf(SolanaAccountId(value_ = ByteArray(31).toByteString())),
            ),
        )
        val result = assertIs<ValidationResult.Invalid>(request.validate())
        assertEquals(listOf("request.mints[0].value"), result.violations.map { it.field })
    }

    @Test
    fun emptyOneofFails() {
        val result = assertIs<ValidationResult.Invalid>(StreamLiveMintDataRequest().validate())
        assertEquals(listOf("type"), result.violations.map { it.field })
    }
}
