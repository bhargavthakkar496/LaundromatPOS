import 'active_order_session_sync_stub.dart'
    if (dart.library.io) 'active_order_session_sync_io.dart' as impl;

Future<String?> readActiveOrderSessionRaw() => impl.readActiveOrderSessionRaw();

Future<void> writeActiveOrderSessionRaw(String raw) =>
    impl.writeActiveOrderSessionRaw(raw);

Future<void> clearActiveOrderSessionRaw() => impl.clearActiveOrderSessionRaw();
