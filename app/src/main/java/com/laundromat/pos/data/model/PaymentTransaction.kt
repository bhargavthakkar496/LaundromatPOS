package com.washpos.app.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "payment_transactions",
    foreignKeys = [
        ForeignKey(
            entity = Order::class,
            parentColumns = ["id"],
            childColumns = ["orderId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("orderId")]
)
data class PaymentTransaction(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val orderId: Int,
    val paymentMethod: String,
    val amount: Double,
    val provider: String = "MANUAL",
    val reference: String? = null,
    val status: String = PaymentStatus.PAID,
    val createdAt: Long = System.currentTimeMillis()
)
