
package com.laundromat.pos.data.model
import androidx.room.Entity
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(
    tableName = "machines",
    indices = [Index(value = ["name"], unique = true)]
)
data class Machine(
    @PrimaryKey(autoGenerate = true) val id: Int = 0,
    val name: String,
    val type: String,
    val capacityKg: Int,
    val price: Double,
    val status: String = MachineStatus.AVAILABLE,
    val notes: String = "",
    val lastServiceAt: Long? = null
)

object MachineStatus {
    const val AVAILABLE = "AVAILABLE"
    const val IN_USE = "IN_USE"
    const val OUT_OF_SERVICE = "OUT_OF_SERVICE"
    const val MAINTENANCE = "MAINTENANCE"
}
