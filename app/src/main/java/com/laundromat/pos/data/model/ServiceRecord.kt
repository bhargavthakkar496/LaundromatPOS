package com.washpos.app.data.model

import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "service_records",
    foreignKeys = [
        ForeignKey(
            entity = Machine::class,
            parentColumns = ["id"],
            childColumns = ["machineId"],
            onDelete = ForeignKey.CASCADE
        )
    ],
    indices = [Index("machineId")]
)
data class ServiceRecord(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val machineId: Int,
    val description: String,
    val technicianName: String,
    val cost: Double = 0.0,
    val performedAt: Long = System.currentTimeMillis(),
    val nextDueAt: Long? = null
)
