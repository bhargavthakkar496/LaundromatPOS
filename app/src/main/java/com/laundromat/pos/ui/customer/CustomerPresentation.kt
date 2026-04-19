
package com.washpos.app.ui.customer

import android.app.Presentation
import android.content.Context
import android.os.Bundle
import android.view.Display
import android.widget.TextView
import com.washpos.app.R

class CustomerPresentation(context: Context, display: Display) : Presentation(context, display) {
    private var amountView: TextView? = null
    private var messageView: TextView? = null
    private var statusView: TextView? = null
    private var referenceView: TextView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.presentation_customer)
        amountView = findViewById(R.id.txtAmount)
        messageView = findViewById(R.id.txtMessage)
        statusView = findViewById(R.id.txtOrderStatus)
        referenceView = findViewById(R.id.txtPaymentReference)
    }

    fun render(state: CustomerDisplayState) {
        amountView?.text = state.amountLabel
        messageView?.text = state.message
        statusView?.text = state.orderStatus
        referenceView?.text = state.paymentReference
    }
}
