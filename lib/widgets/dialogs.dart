import 'package:flutter/material.dart';
import 'package:kettle_timeup/models/permission_models.dart';

class PermissionsDialog extends StatelessWidget {
  final List<PermissionStatus> permissions;
  final Function(PermissionStatus) onPermissionRequest;
  final VoidCallback onCancel;

  const PermissionsDialog({
    super.key,
    required this.permissions,
    required this.onPermissionRequest,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题
            const Text(
              '缺少权限',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // 权限列表
            ...permissions.map((permission) => Column(
                  children: [
                    _buildPermissionItem(
                      context,
                      permission,
                      () => onPermissionRequest(permission),
                    ),
                    const SizedBox(height: 8),
                  ],
                )),

            // 说明文本
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '• 为了确保计时器能在后台正常运行，我们需要相关权限来保持服务运行。\n'
                '• 本应用不会过度消耗电量，仅用于维持计时功能。\n'
                '• 如果取消授权，计时器将只能在应用保持前台运行时正常工作。',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 14,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 取消按钮
            SizedBox(
              height: 56,
              child: TextButton(
                onPressed: onCancel,
                child: const Text(
                  '取消授权',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionItem(
    BuildContext context,
    PermissionStatus permission,
    VoidCallback onTap,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getPermissionTitle(permission.type),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        permission.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.secondary.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  permission.isGranted ? Icons.check_circle : Icons.error,
                  color: permission.isGranted ? Colors.green : Colors.red,
                  semanticLabel: permission.isGranted ? '已授予' : '未授予',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getPermissionTitle(PermissionType type) {
    switch (type) {
      case PermissionType.batteryOptimization:
        return '电池优化';
      case PermissionType.notification:
        return '通知权限';
    }
  }
}
