package com.washpos.app.payment

import com.washpos.app.data.model.PaymentStatus
import com.washpos.app.data.model.PaymentTransaction

interface PaymentGateway {
    fun createPaymentIntent(
        amount: Double,
        method: String,
        orderReference: String
    ): PaymentTransaction
}

class QrPaymentGateway : PaymentGateway {
    override fun createPaymentIntent(
        amount: Double,
        method: String,
        orderReference: String
    ): PaymentTransaction =
        PaymentTransaction(
            orderId = 0,
            paymentMethod = method,
            amount = amount,
            provider = "QR",
            reference = orderReference,
            status = PaymentStatus.PENDING
        )
}
