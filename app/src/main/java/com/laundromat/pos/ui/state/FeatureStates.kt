package com.washpos.app.ui.state

import com.washpos.app.data.model.Customer
import com.washpos.app.data.model.DashboardSummary
import com.washpos.app.data.model.InventoryItem
import com.washpos.app.data.model.Machine
import com.washpos.app.data.model.OrderWithDetails
import com.washpos.app.data.model.PaymentMethodTotal
import com.washpos.app.data.model.PosUser

data class LoginUiState(
    val username: String = "",
    val pin: String = "",
    val isAuthenticating: Boolean = false,
    val currentUser: PosUser? = null,
    val errorMessage: String? = null
)

data class CheckoutUiState(
    val selectedMachine: Machine? = null,
    val selectedCustomer: Customer? = null,
    val amount: Double = 0.0,
    val paymentMethod: String = "QR",
    val paymentProvider: String = "MANUAL",
    val paymentReference: String? = null,
    val isSubmitting: Boolean = false
)

data class MachineManagementUiState(
    val machines: List<Machine> = emptyList(),
    val selectedMachine: Machine? = null,
    val isEditing: Boolean = false
)

data class CustomerManagementUiState(
    val customers: List<Customer> = emptyList(),
    val searchQuery: String = "",
    val selectedCustomer: Customer? = null
)

data class OrderHistoryUiState(
    val orders: List<OrderWithDetails> = emptyList(),
    val selectedOrderId: Int? = null
)

data class DashboardUiState(
    val summary: DashboardSummary = DashboardSummary(
        totalRevenue = 0.0,
        totalOrders = 0,
        availableMachines = 0,
        lowStockItems = 0
    ),
    val paymentBreakdown: List<PaymentMethodTotal> = emptyList()
)

data class InventoryUiState(
    val items: List<InventoryItem> = emptyList(),
    val lowStockOnly: Boolean = false
)

data class ServiceTrackingUiState(
    val machines: List<Machine> = emptyList(),
    val selectedMachine: Machine? = null,
    val technicianName: String = "",
    val serviceNotes: String = ""
)
