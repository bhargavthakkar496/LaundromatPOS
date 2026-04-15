package com.laundromat.pos.data.model
import androidx.room.Entity
import androidx.room.PrimaryKey
@Entity(tableName = "orders")
data class Order(@PrimaryKey(autoGenerate = true) val id:Int=0,val machineId:Int,val amount:Double,val paymentMethod:String,val timestamp:Long=System.currentTimeMillis())