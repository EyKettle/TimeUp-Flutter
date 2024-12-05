# Flutter 后台服务 (Flutter Background Service)

## 概述

Flutter 后台服务是一个强大的插件，允许在 Android 和 iOS 平台上持续运行后台服务，即使应用程序处于后台或关闭状态。这个插件为开发者提供了在移动设备上执行长时间运行任务的解决方案。

## 主要特性

1. **跨平台支持**
   - Android
   - iOS
   - 统一的 API 接口

2. **后台任务管理**
   - 持续运行服务
   - 后台定时任务
   - 系统资源优化

3. **服务生命周期控制**
   - 启动服务
   - 停止服务
   - 前台服务模式
   - 后台服务模式

4. **通信机制**
   - 主线程与后台服务间双向通信
   - 数据传输
   - 状态同步

5. **电池和性能优化**
   - 最小化系统资源消耗
   - 遵循平台后台执行最佳实践

## 安装

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  flutter_background_service: ^latest_version
```

## 基本使用

### 初始化服务

```dart
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await initializeService();
  runApp(MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();
  
  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 后台服务逻辑
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // 执行后台任务
  Timer.periodic(Duration(seconds: 60), (timer) {
    // 定期执行的后台任务
  });
}
```

### 服务控制

```dart
// 启动服务
FlutterBackgroundService().startService();

// 停止服务
FlutterBackgroundService().invoke('stopService');

// 设置为前台服务
FlutterBackgroundService().invoke('setAsForeground');

// 设置为后台服务
FlutterBackgroundService().invoke('setAsBackground');
```

## Android 配置

### Android 清单配置

在 Android 项目的 `AndroidManifest.xml` 中，你需要添加特定的权限和服务配置：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android" 
          xmlns:tools="http://schemas.android.com/tools" 
          package="com.example">
  ...
  <!-- 前台服务权限 -->
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
  
  <!-- 
    这里的权限取决于你为 foregroundServiceType 选择的值 - 请参考 Android 文档。
    例如，如果选择 'location'，使用 'android.permission.FOREGROUND_SERVICE_LOCATION'
  -->
  <uses-permission android:name="android.permission.FOREGROUND_SERVICE_..." />
  
  <application
        android:label="example"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        ...>

        <activity
            android:name=".MainActivity"
            android:exported="true"
            ...>

        <!-- 添加后台服务 -->
        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="WhatForegroundServiceTypeDoYouWant"
        />
        ...
  </application>
</manifest>
```

### 配置说明

1. **前台服务权限**：`FOREGROUND_SERVICE` 是基本权限，允许应用创建前台服务。

2. **特定前台服务类型权限**：根据服务的具体类型，你需要添加相应的特定权限。常见的前台服务类型包括：
   - `location`：位置服务
   - `mediaPlayback`：媒体播放
   - `camera`：相机服务
   - `microphone`：麦克风服务
   - `connectedDevice`：连接设备服务

3. **服务配置**：`<service>` 标签中的 `android:name` 指定了 Flutter 后台服务的实现类。

4. **前台服务类型**：`android:foregroundServiceType` 应根据你的具体使用场景选择适当的类型。

**注意**：确保根据你的应用需求选择正确的前台服务类型和相应权限。

## 最佳实践

1. 最小化后台任务执行时间
2. 优化电池消耗
3. 处理服务重启场景
4. 使用轻量级任务
5. 实现错误处理和日志记录

## 注意事项

- 不同平台的后台执行限制
- 电池和性能影响
- 用户隐私和系统资源
- 遵循平台指南

## 高级用法

- 多线程后台任务
- 与通知服务集成
- 状态同步机制
- 远程配置

## 常见问题与解决方案

- 服务意外停止
- 电池优化冲突
- 跨平台兼容性
- 性能瓶颈

## 更多信息

- [官方文档](https://pub.dev/packages/flutter_background_service)
- [GitHub 仓库](https://github.com/ekasetiawans/flutter_background_service)

## 许可证

根据插件的开源许可证发布。

### 自定义前台服务通知

您可以为前台服务创建自定义通知，提供更多功能和用户交互。以下示例使用 [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) 插件，但您可以使用其他通知插件。

#### 通知通道配置

```dart
Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeService();
    runApp(MyApp());
}

// 通知通道ID
const notificationChannelId = 'my_foreground';

// 通知ID，用于更新自定义通知
const notificationId = 888;

Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    // 创建 Android 通知通道
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
        notificationChannelId,
        'MY FOREGROUND SERVICE',
        description: '用于重要通知的通道',
        importance: Importance.low, // 重要性必须为低或更高级别
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // 创建通知通道
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 配置后台服务
    await service.configure(
        androidConfiguration: AndroidConfiguration(
            // 在前台或后台的独立隔离区中执行
            onStart: onStart,

            // 自动启动服务
            autoStart: true,
            isForegroundMode: true,

            notificationChannelId: notificationChannelId, // 必须与上面创建的通知通道匹配
            initialNotificationTitle: '牛逼的服务',
            initialNotificationContent: '正在初始化',
            foregroundServiceNotificationId: notificationId,
        ),
        // ...
    );
}
```

#### 动态更新通知信息

```dart
Future<void> onStart(ServiceInstance service) async {
    // 仅适用于 Flutter 3.0.0 及更高版本
    DartPluginRegistrant.ensureInitialized();

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    // 定期更新前台服务通知
    Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (service is AndroidServiceInstance) {
            if (await service.isForegroundService()) {
                flutterLocalNotificationsPlugin.show(
                    notificationId,
                    '酷炫服务',
                    '牛逼 ${DateTime.now()}',
                    const NotificationDetails(
                        android: AndroidNotificationDetails(
                            notificationChannelId,
                            'MY FOREGROUND SERVICE',
                            icon: 'ic_bg_service_small',
                            ongoing: true,
                        ),
                    ),
                );
            }
        }
    });
}
```

### 后台服务的高级使用

#### 即使应用程序已关闭也能运行的后台服务

您可以使用此功能在后台执行代码，特别适用于实时数据获取和推送通知。

> 重要注意事项：
> 
> - `isForegroundMode: false`：后台模式需要在发布模式下运行，并禁用电池优化，以确保应用关闭后服务继续运行。
> - `isForegroundMode: true`：根据 [Android 策略](https://developer.android.com/develop/background-work/services)显示静默通知

#### 使用 Socket.io 实现后台通信示例

```dart
import 'dart:async';
import 'dart:ui';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

Future<void> main() async {
    WidgetsFlutterBinding.ensureInitialized();
    await initializeService();
    runApp(MyApp());
}

void startBackgroundService() {
    final service = FlutterBackgroundService();
    service.startService();
}

void stopBackgroundService() {
    final service = FlutterBackgroundService();
    service.invoke("stop");
}

Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    await service.configure(
        androidConfiguration: AndroidConfiguration(
            autoStart: true,
            onStart: onStart,
            isForegroundMode: false,
            autoStartOnBoot: true,
        ),
    );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
    final socket = io.io("your-server-url", <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
    });

    socket.onConnect((_) {
        print('已连接。Socket ID: ${socket.id}');
        // 在此实现您的 socket 逻辑
        // 例如，监听事件或发送数据
    });

    socket.onDisconnect((_) {
        print('已断开连接');
    });

    socket.on("event-name", (data) {
        // 在这里执行操作，如推送通知
    });

    service.on("stop").listen((event) {
        service.stopSelf();
        print("后台进程已停止");
    });

    service.on("start").listen((event) {});

    Timer.periodic(const Duration(seconds: 1), (timer) {
        socket.emit("event-name", "您的消息");
        print("服务正在成功运行 ${DateTime.now().second}");
    });
}
```

# 使用方法

- 调用 `FlutterBackgroundService.configure()` 配置服务将要执行的处理程序。

> 强烈建议在 `main()` 方法中调用此方法，以确保回调处理程序已更新。
> 
- 如果未启用 `autoStart`，则需要调用 `FlutterBackgroundService.start` 来启动服务。
- 由于服务使用隔离区（Isolates），因此您无法在 UI 和服务之间共享引用。您可以使用 `invoke()` 和 `on(String method)` 在 UI 和服务之间进行通信。

# 迁移指南

- `sendData()` 已更名为 `invoke(String method)`
- `onDataReceived()` 已更名为 `on(String method)`
- 现在您必须在 `onStart` 方法中使用 `ServiceInstance` 对象，而不是创建新的 `FlutterBackgroundService` 对象。请参考示例项目。
- 在 UI 隔离区中只使用 `FlutterBackgroundService` 类，在后台隔离区中使用 `ServiceInstance`。

# 常见问题

### 为什么服务没有自动启动？

一些 Android 设备制造商有定制的 Android 操作系统，例如小米的 MIUI。您必须处理这些特定的系统策略。

### 服务被系统终止后没有重新启动？

尝试为您的应用程序禁用电池优化。

### 通知图标没有更改，如何解决？

确保您已创建名为 `ic_bg_service_small` 的通知图标，并将其放置在以下位置：
- PNG 文件：
  - res/drawable-mdpi
  - res/drawable-hdpi
  - res/drawable-xhdpi
  - res/drawable-xxhdpi
- XML（矢量）文件：
  - res/drawable-anydpi-v24

### 服务在发布模式下不运行？

将 `@pragma('vm:entry-point')` 添加到 `onStart()` 方法。例如：

```dart
@pragma('vm:entry-point')
void onStart(ServiceInstance service) {
  ...
}
```

# 最佳实践和注意事项

1. **电池优化**：在某些设备上，后台服务可能会受到电池优化的限制。
2. **权限管理**：确保在 `AndroidManifest.xml` 中添加必要的权限。
3. **性能考虑**：长时间运行的后台服务可能会影响设备性能和电池寿命。
4. **错误处理**：在后台服务中实现适当的错误处理和重连机制。
5. **安全性**：保护敏感数据传输，使用安全的通信协议。

通过合理使用后台服务，您可以创建功能强大且用户友好的移动应用程序。
