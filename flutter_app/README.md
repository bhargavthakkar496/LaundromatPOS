# Laundromat POS Flutter

Flutter is now the primary implementation path for new features in this repo.

## Current Flow

- Staff login with `admin / 1234`
- Machine list for cashier operations
- Checkout and order history
- Customer self-service flow for mobile or kiosk use

## Run

From `flutter_app/`:

```bash
flutter pub get
flutter run -d windows
```

You can also target Android, iOS, Chrome, or another supported Flutter device.

## Customer Self-Service

The first customer-facing Flutter feature is available from the login screen via `Open Customer Self-Service`.

That flow lets a customer:

- choose an available machine
- enter basic contact details
- select a payment method
- complete a demo payment and receive an order reference
