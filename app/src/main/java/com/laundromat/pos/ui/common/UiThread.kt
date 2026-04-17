package com.laundromat.pos.ui.common

import android.os.Handler
import android.os.Looper

object UiThread {
    private val handler = Handler(Looper.getMainLooper())

    fun post(action: () -> Unit) {
        handler.post(action)
    }
}
