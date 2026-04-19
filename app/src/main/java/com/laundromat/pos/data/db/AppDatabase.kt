
package com.washpos.app.data.db
import android.content.Context
import androidx.room.*
import com.washpos.app.data.model.*

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
                    "washpos.db"
                )
                    .fallbackToDestructiveMigration()
                    .build()
                    .also { instance = it }
            }
    }
}
