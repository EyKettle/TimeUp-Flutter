# Awesome Notifications - Flutter 通知插件

## 概述

Awesome Notifications 是一个功能强大且灵活的 Flutter 通知插件，提供了丰富的通知定制和管理功能。

## 生态系统组件

Awesome Notifications 由多个互补的包组成，提供全面的通知解决方案：

### 核心组件

1. **awesome_notifications_core**
   - 提供通知的核心功能
   - 管理通知生命周期
   - 处理本地通知逻辑

2. **awesome_notifications**
   - 本地通知实现
   - 丰富的通知定制选项
   - 跨平台通知支持

### 远程推送通知

3. **awesome_notifications_fcm**
   - Firebase Cloud Messaging 集成
   - 远程推送通知支持
   - 替代 `firebase_messaging`

### 可选依赖

4. **Firebase 集成**
   - `firebase_core`：Firebase 核心功能
   - `firebase_crashlytics`：崩溃报告

## 依赖配置示例

```yaml
dependencies:
  # 核心通知插件
  awesome_notifications_core: ^0.10.0
  awesome_notifications: ^0.10.0

  # 远程推送通知
  awesome_notifications_fcm: ^0.10.0

  # Firebase 集成（可选）
  firebase_core: ^latest_version
  firebase_crashlytics: ^latest_version
```

## 重要注意事项

- 始终使用与 `awesome_notifications_core` 兼容的版本
- 不再需要使用 `firebase_messaging`
- 定期检查并更新到最新版本

## 主要特性

1. **多样化通知类型**
   - 普通通知
   - 渐进式通知
   - 媒体通知
   - 日程通知
   - 操作通知

2. **高级通知定制**
   - 自定义图标
   - 丰富的布局选项
   - 通知声音和振动控制
   - 通道和重要性级别管理

3. **通知调度**
   - 一次性通知
   - 重复通知
   - 精确的时间调度
   - 时区支持

4. **通知交互**
   - 点击事件处理
   - 操作按钮
   - 前台和后台通知处理

5. **跨平台支持**
   - Android
   - iOS
   - Web

## 初始化示例

```dart
import 'package:awesome_notifications/awesome_notifications.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AwesomeNotifications().initialize(
    null,
    [
      NotificationChannel(
        channelKey: 'kettle_timeup_timer',
        channelName: '活动计时',
        channelDescription: '计时器通知',
        defaultColor: const Color(0xFF9D50DD),
        importance: NotificationImportance.High,
        playSound: false,
        enableVibration: false,
      ),
    ],
  );

  // 请求通知权限
  await AwesomeNotifications().isNotificationAllowed().then((isAllowed) async {
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
  });

  runApp(MyApp());
}
```

## 权限管理

### Android
- 在 `AndroidManifest.xml` 中添加必要权限
- 请求通知权限

### iOS
- 配置 `Info.plist`
- 请求通知权限

## 最佳实践

1. 合理使用通知渠道
2. 尊重用户通知偏好
3. 提供通知设置选项
4. 避免过度发送通知

## 注意事项

- 遵守各平台通知指南
- 处理通知权限
- 考虑用户体验

## 更多信息

- [官方文档](https://pub.dev/packages/awesome_notifications)
- [GitHub 仓库](https://github.com/rafaelsetragni/awesome_notifications)

## 许可证

根据插件的开源许可证发布。
