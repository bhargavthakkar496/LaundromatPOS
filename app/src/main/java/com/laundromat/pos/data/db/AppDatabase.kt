package com.laundromat.pos.data.db
import android.content.Context
import androidx.room.*
import com.laundromat.pos.data.model.*
@Database(entities=[Machine::class,Order::class],version=1)
abstract class AppDatabase:RoomDatabase(){
abstract fun posDao():PosDao
companion object{fun getInstance(ctx:Context)=Room.databaseBuilder(ctx,AppDatabase::class.java,"laundromat.db").allowMainThreadQueries().build()}}