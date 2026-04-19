package com.washpos.app.data.model

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "customers",
    indices = [Index(value = ["phone"], unique = true)]
)
data class Customer(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val fullName: String,
    val phone: String,
    val email: String? = null,
    val loyaltyPoints: Int = 0,
    val notes: String = "",
    val createdAt: Long = System.currentTimeMillis()
)
