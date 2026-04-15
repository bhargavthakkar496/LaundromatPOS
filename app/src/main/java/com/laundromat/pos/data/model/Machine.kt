package com.laundromat.pos.data.model
import androidx.room.Entity
import androidx.room.PrimaryKey
@Entity(tableName = "machines")
data class Machine(@PrimaryKey(autoGenerate = true) val id:Int=0,val name:String,val type:String,val capacityKg:Int,val price:Double,val status:String)