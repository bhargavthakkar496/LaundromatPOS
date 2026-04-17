package com.laundromat.pos.data.model

import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "pos_users",
    indices = [Index(value = ["username"], unique = true)]
)
data class PosUser(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val username: String,
    val displayName: String,
    val pin: String,
    val role: String,
    val isActive: Boolean = true,
    val lastLoginAt: Long? = null
)
