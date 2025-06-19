enum UserRole {
  admin('ADMIN'),
  business('BUSINESS'),
  customer('CUSTOMER');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.customer,
    );
  }
}

class RolePermissions {
  static const Map<UserRole, List<String>> permissions = {
    UserRole.admin: [
      'manage_users',
      'manage_estimates',
      'view_admin_dashboard',
      'edit_all_estimates',
      'delete_all_estimates',
      'manage_businesses',
    ],
    UserRole.business: [
      'create_estimate',
      'transfer_estimate',
      'reply_to_estimate',
      'edit_own_estimates',
      'delete_own_estimates',
    ],
    UserRole.customer: [
      'create_request',
      'select_estimate',
      'edit_own_requests',
      'delete_own_requests',
    ],
  };

  static bool hasPermission(UserRole role, String permission) {
    return permissions[role]?.contains(permission) ?? false;
  }
} 