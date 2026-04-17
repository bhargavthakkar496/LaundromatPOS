
package com.laundromat.pos.data.model
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "orders",
    foreignKeys = [
        ForeignKey(
            entity = Machine::class,
            parentColumns = ["id"],
            childColumns = ["machineId"],
            onDelete = ForeignKey.RESTRICT
        ),
        ForeignKey(
            entity = Customer::class,
            parentColumns = ["id"],
            childColumns = ["customerId"],
            onDelete = ForeignKey.SET_NULL
        ),
        ForeignKey(
            entity = PosUser::class,
            parentColumns = ["id"],
            childColumns = ["createdByUserId"],
            onDelete = ForeignKey.SET_NULL
        )
    ],
    indices = [
        Index("machineId"),
        Index("customerId"),
        Index("createdByUserId")
    ]
)
data class Order(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val machineId: Int,
    val customerId: Int? = null,
    val createdByUserId: Int? = null,
    val serviceType: String = "WASH",
    val amount: Double,
    val status: String = OrderStatus.OPEN,
    val paymentMethod: String,
    val paymentStatus: String = PaymentStatus.PENDING,
    val paymentReference: String? = null,
    val notes: String = "",
    val timestamp: Long = System.currentTimeMillis()
)

object OrderStatus {
    const val OPEN = "OPEN"
    const val IN_PROGRESS = "IN_PROGRESS"
    const val COMPLETED = "COMPLETED"
    const val CANCELLED = "CANCELLED"
}

object PaymentStatus {
    const val PENDING = "PENDING"
    const val PAID = "PAID"
    const val FAILED = "FAILED"
    const val REFUNDED = "REFUNDED"
}
