package com.washpos.app.data.model

import androidx.room.Embedded
import androidx.room.Relation

data class OrderWithDetails(
    @Embedded val order: Order,
    @Relation(parentColumn = "machineId", entityColumn = "id")
    val machine: Machine,
    @Relation(parentColumn = "customerId", entityColumn = "id")
    val customer: Customer?,
    @Relation(parentColumn = "id", entityColumn = "orderId")
    val payments: List<PaymentTransaction>
)

data class MachineWithServiceHistory(
    @Embedded val machine: Machine,
    @Relation(parentColumn = "id", entityColumn = "machineId")
    val serviceRecords: List<ServiceRecord>
)

data class DashboardSummary(
    val totalRevenue: Double,
    val totalOrders: Int,
    val availableMachines: Int,
    val lowStockItems: Int
)

data class PaymentMethodTotal(
    val paymentMethod: String,
    val totalAmount: Double,
    val transactionCount: Int
)
