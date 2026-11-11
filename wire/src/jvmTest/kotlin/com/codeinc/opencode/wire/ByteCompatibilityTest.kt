package com.codeinc.opencode.wire

import com.codeinc.opencode.gen.common.v1.Model
import com.codeinc.opencode.gen.currency.v1.OcpCurrencyService
import com.codeinc.opencode.gen.transaction.v1.OcpTransactionService
import com.codeinc.opencode.wire.common.v1.ClientPong
import com.codeinc.opencode.wire.common.v1.ServerPing
import com.codeinc.opencode.wire.common.v1.Signature
import com.codeinc.opencode.wire.common.v1.SolanaAccountId
import com.codeinc.opencode.wire.currency.v1.CoreMintFiatExchangeRate
import com.codeinc.opencode.wire.currency.v1.StreamLiveMintDataRequest
import com.codeinc.opencode.wire.currency.v1.StreamLiveMintDataResponse
import com.codeinc.opencode.wire.currency.v1.VerifiedCoreMintFiatExchangeRate
import com.codeinc.opencode.wire.currency.v1.VerifiedCoreMintFiatExchangeRateBatch
import com.codeinc.opencode.wire.transaction.v1.GetLimitsRequest
import com.codeinc.opencode.wire.transaction.v1.GetLimitsResponse
import com.codeinc.opencode.wire.transaction.v1.SendLimit
import com.google.protobuf.ByteString
import com.google.protobuf.Timestamp
import com.squareup.wire.ProtoAdapter
import com.squareup.wire.durationOfSeconds
import com.squareup.wire.ofEpochSecond
import okio.ByteString.Companion.toByteString
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals

/**
 * The same message built with protobuf-java and with Wire must encode to the same bytes, and
 * each library must decode the other's output back to an equal message. Every field is set,
 * including both arms of each oneof, so a default instance cannot pass by encoding to nothing.
 */
class ByteCompatibilityTest {
    private val mint = ByteArray(32) { (it + 1).toByte() }
    private val owner = ByteArray(32) { (0xA0 + it).toByte() }
    private val signature = ByteArray(64) { (it * 3).toByte() }
    private val seconds = 1_762_790_400L
    private val nanos = 123_456_789

    private fun javaTimestamp() = Timestamp.newBuilder().setSeconds(seconds).setNanos(nanos).build()
    private fun javaAccount(bytes: ByteArray) =
        Model.SolanaAccountId.newBuilder().setValue(ByteString.copyFrom(bytes)).build()
    private fun javaSignature() = Model.Signature.newBuilder().setValue(ByteString.copyFrom(signature)).build()

    private fun wireAccount(bytes: ByteArray) = SolanaAccountId(value_ = bytes.toByteString())

    @Test
    fun streamLiveMintDataRequestWithMints() = assertCompatible(
        java = OcpCurrencyService.StreamLiveMintDataRequest.newBuilder()
            .setRequest(
                OcpCurrencyService.StreamLiveMintDataRequest.Request.newBuilder()
                    .addMints(javaAccount(mint))
                    .addMints(javaAccount(owner)),
            )
            .build(),
        wire = StreamLiveMintDataRequest(
            request = StreamLiveMintDataRequest.Request(mints = listOf(wireAccount(mint), wireAccount(owner))),
        ),
        adapter = StreamLiveMintDataRequest.ADAPTER,
        parse = OcpCurrencyService.StreamLiveMintDataRequest::parseFrom,
    )

    @Test
    fun streamLiveMintDataRequestWithPong() = assertCompatible(
        java = OcpCurrencyService.StreamLiveMintDataRequest.newBuilder()
            .setPong(Model.ClientPong.newBuilder().setTimestamp(javaTimestamp()))
            .build(),
        wire = StreamLiveMintDataRequest(pong = ClientPong(timestamp = ofEpochSecond(seconds, nanos.toLong()))),
        adapter = StreamLiveMintDataRequest.ADAPTER,
        parse = OcpCurrencyService.StreamLiveMintDataRequest::parseFrom,
    )

    @Test
    fun streamLiveMintDataResponseWithRates() = assertCompatible(
        java = OcpCurrencyService.StreamLiveMintDataResponse.newBuilder()
            .setData(
                OcpCurrencyService.StreamLiveMintDataResponse.LiveData.newBuilder()
                    .setCoreMintFiatExchangeRates(
                        OcpCurrencyService.VerifiedCoreMintFiatExchangeRateBatch.newBuilder()
                            .addExchangeRates(javaRate("usd", 1.0))
                            .addExchangeRates(javaRate("cad", 1.3712)),
                    ),
            )
            .build(),
        wire = StreamLiveMintDataResponse(
            data_ = StreamLiveMintDataResponse.LiveData(
                core_mint_fiat_exchange_rates = VerifiedCoreMintFiatExchangeRateBatch(
                    exchange_rates = listOf(wireRate("usd", 1.0), wireRate("cad", 1.3712)),
                ),
            ),
        ),
        adapter = StreamLiveMintDataResponse.ADAPTER,
        parse = OcpCurrencyService.StreamLiveMintDataResponse::parseFrom,
    )

    @Test
    fun streamLiveMintDataResponseWithPing() = assertCompatible(
        java = OcpCurrencyService.StreamLiveMintDataResponse.newBuilder()
            .setPing(
                Model.ServerPing.newBuilder()
                    .setTimestamp(javaTimestamp())
                    .setPingDelay(com.google.protobuf.Duration.newBuilder().setSeconds(5).setNanos(250_000_000)),
            )
            .build(),
        wire = StreamLiveMintDataResponse(
            ping = ServerPing(
                timestamp = ofEpochSecond(seconds, nanos.toLong()),
                ping_delay = durationOfSeconds(5, 250_000_000),
            ),
        ),
        adapter = StreamLiveMintDataResponse.ADAPTER,
        parse = OcpCurrencyService.StreamLiveMintDataResponse::parseFrom,
    )

    @Test
    fun getLimitsRequest() = assertCompatible(
        java = OcpTransactionService.GetLimitsRequest.newBuilder()
            .setOwner(javaAccount(owner))
            .setSignature(javaSignature())
            .setConsumedSince(javaTimestamp())
            .build(),
        wire = GetLimitsRequest(
            owner = wireAccount(owner),
            signature = Signature(value_ = signature.toByteString()),
            consumed_since = ofEpochSecond(seconds, nanos.toLong()),
        ),
        adapter = GetLimitsRequest.ADAPTER,
        parse = OcpTransactionService.GetLimitsRequest::parseFrom,
    )

    @Test
    fun getLimitsResponse() = assertCompatible(
        // Map entries encode in iteration order in both libraries, so both maps are built in
        // the same order.
        java = OcpTransactionService.GetLimitsResponse.newBuilder()
            .setResult(OcpTransactionService.GetLimitsResponse.Result.OK)
            .putSendLimitsByCurrency("usd", javaLimit(250f, 1000f, 5000f))
            .putSendLimitsByCurrency("cad", javaLimit(10.5f, 1370f, 6850f))
            .setUsdTransacted(42.25)
            .build(),
        wire = GetLimitsResponse(
            result = GetLimitsResponse.Result.OK,
            send_limits_by_currency = linkedMapOf(
                "usd" to SendLimit(next_transaction = 250f, max_per_transaction = 1000f, max_per_day = 5000f),
                "cad" to SendLimit(next_transaction = 10.5f, max_per_transaction = 1370f, max_per_day = 6850f),
            ),
            usd_transacted = 42.25,
        ),
        adapter = GetLimitsResponse.ADAPTER,
        parse = OcpTransactionService.GetLimitsResponse::parseFrom,
    )

    private fun javaRate(code: String, rate: Double) =
        OcpCurrencyService.VerifiedCoreMintFiatExchangeRate.newBuilder()
            .setExchangeRate(
                OcpCurrencyService.CoreMintFiatExchangeRate.newBuilder()
                    .setCurrencyCode(code)
                    .setExchangeRate(rate)
                    .setTimestamp(javaTimestamp()),
            )
            .setSignature(javaSignature())
            .build()

    private fun wireRate(code: String, rate: Double) = VerifiedCoreMintFiatExchangeRate(
        exchange_rate = CoreMintFiatExchangeRate(
            currency_code = code,
            exchange_rate = rate,
            timestamp = ofEpochSecond(seconds, nanos.toLong()),
        ),
        signature = Signature(value_ = signature.toByteString()),
    )

    private fun javaLimit(next: Float, perTx: Float, perDay: Float) =
        OcpTransactionService.SendLimit.newBuilder()
            .setNextTransaction(next)
            .setMaxPerTransaction(perTx)
            .setMaxPerDay(perDay)
            .build()

    private fun <J : com.google.protobuf.MessageLite, W : Any> assertCompatible(
        java: J,
        wire: W,
        adapter: ProtoAdapter<W>,
        parse: (ByteArray) -> J,
    ) {
        val javaBytes = java.toByteArray()
        val wireBytes = adapter.encode(wire)
        check(javaBytes.isNotEmpty()) { "the protobuf-java message encodes to nothing" }
        assertContentEquals(javaBytes, wireBytes, "protobuf-java and Wire encode differently")
        assertEquals(wire, adapter.decode(javaBytes), "Wire decodes protobuf-java's bytes to a different message")
        assertEquals(java, parse(wireBytes), "protobuf-java decodes Wire's bytes to a different message")
    }
}
