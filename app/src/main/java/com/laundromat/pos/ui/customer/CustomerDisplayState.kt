package com.laundromat.pos.ui.customer

data class CustomerDisplayState(
    val amountLabel: String = "Amount: INR 0",
    val message: String = "Scan QR to Pay",
    val orderStatus: String = "Awaiting order",
    val paymentReference: String = ""
)
