package com.laundromat.pos.data.db
import androidx.room.*
import com.laundromat.pos.data.model.*
@Dao
interface PosDao{
@Query("SELECT * FROM machines") fun getAllMachines():List<Machine>
@Insert fun insertMachine(machine:Machine)
@Insert fun insertOrder(order:Order)}