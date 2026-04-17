package com.laundromat.pos.data.model

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "inventory_items",
    indices = [Index(value = ["name"], unique = true)]
)
data class InventoryItem(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val category: String,
    val quantityOnHand: Int,
    val reorderLevel: Int,
    val unit: String,
    val unitCost: Double = 0.0,
    val updatedAt: Long = System.currentTimeMillis()
)
