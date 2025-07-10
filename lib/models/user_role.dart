enum UserRole {
  customer,
  pro;

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'pro':
        return UserRole.pro;
      case 'customer':
      default:
        return UserRole.customer;
    }
  }

  String toString() => name;
}
