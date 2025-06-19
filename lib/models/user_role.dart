enum UserRole {
  customer('customer'),
  pro('pro');

  final String value;
  const UserRole(this.value);

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => throw ArgumentError('Invalid role value: $value'),
    );
  }
}