
package com.laundromat.pos.data.db
import android.content.Context
import androidx.room.*
import com.laundromat.pos.data.model.*

@Database(
    entities = [
        Machine::class,
        Order::class,
        Customer::class,
        PaymentTransaction::class,
        PosUser::class,
        InventoryItem::class,
        ServiceRecord::class
    ],
    version = 2
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun posDao(): PosDao

    companion object {
        @Volatile
        private var instance: AppDatabase? = null

        fun get(context: Context): AppDatabase =
            instance ?: synchronized(this) {
                instance ?: Room.databaseBuilder(
                    context.applicationContext,
                    AppDatabase::class.java,
                    "laundromat.db"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { instance = it }
            }
    }
}
