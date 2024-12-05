enum PermissionType {
  batteryOptimization,
  notification,
}

class PermissionStatus {
  final bool isGranted;
  final PermissionType type;
  final String message;

  PermissionStatus({
    required this.isGranted,
    required this.type,
    required this.message,
  });
}
