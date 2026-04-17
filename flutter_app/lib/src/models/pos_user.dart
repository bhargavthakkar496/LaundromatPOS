class PosUser {
  const PosUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.pin,
    required this.role,
  });

  final int id;
  final String username;
  final String displayName;
  final String pin;
  final String role;
}
