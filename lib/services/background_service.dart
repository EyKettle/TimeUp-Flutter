import 'dart:async';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// import 'package:awesome_notifications/awesome_notifications.dart';
Timer? _timer;
int _seconds = 0;
final service = FlutterBackgroundService();

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on("stopService").listen((event) {
    service.stopSelf();
  });

  service.on('startTimer').listen((event) async {
    print('计时中');
    if (event == null) return;
    final totalSeconds = event['totalSeconds'] as int?;
    if (totalSeconds != null && totalSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        print('下一秒');
        service.invoke('update');
      });
    }
  });
}

class BackgroundTimerService {
  bool isForeground = false;
  final notificationChannelId = 'kettle_timeup_timer';
  final notificationId = 1260;
  final audioPlayer = AudioPlayer();

  Function(int seconds)? onUpdate;
  Function({required bool shouldRefresh})? onStop;

  Future<bool> init({
    required Function(int seconds) onUpdate,
    required Function({required bool shouldRefresh}) onStop,
  }) async {
    onUpdate = onUpdate;
    onStop = onStop;

    if (await service.isRunning()) {
      print('使用现有服务');
      return true;
    }

    audioPlayer.setSourceAsset('audio/timer_finished.wav');
    audioPlayer.setReleaseMode(ReleaseMode.stop);

    AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      '计时通知',
      description: '活动计时通知',
      importance: Importance.low,
    );
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await flutterLocalNotificationsPlugin.initialize(
      InitializationSettings(
        android: AndroidInitializationSettings('ic_launcher_singlecolor'),
      ),
      onDidReceiveNotificationResponse: (action) {
        if (action.actionId == 'stop') {
          stopTimer();
        }
      },
    );

    await service.configure(
      iosConfiguration: IosConfiguration(),
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true, // TODO: 记得发布时关闭
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: '活动',
        initialNotificationContent: '活动计时通知',
        foregroundServiceNotificationId: notificationId,
      ),
    );

    service.on('update').listen((event) async {
      if (event != null) {
        print('更新计时');
        updateTimer();
      }
    });

    // await AwesomeNotifications()
    //     .isNotificationAllowed()
    //     .then((isAllowed) async {
    //   if (!isAllowed) {
    //     final isAllowed =
    //         await AwesomeNotifications().requestPermissionToSendNotifications();
    //     if (!isAllowed) {
    //       print('通知权限被拒绝');
    //       return false;
    //     }
    //   }
    // });
    // await AwesomeNotifications().initialize(
    //   'resource://drawable/ic_launcher_singlecolor',
    //   [
    //     NotificationChannel(
    //       channelKey: 'kettle_timeup_timer',
    //       channelName: '活动计时',
    //       channelDescription: '计时器通知',
    //       defaultColor: const Color(0xFF9D50DD),
    //       importance: NotificationImportance.High,
    //       playSound: false,
    //       enableVibration: false,
    //     ),
    //   ],
    // );

    final runningState = await service.isRunning();
    print('初始化新服务: $runningState');
    return true;
  }

  Future<bool> dispose() async {
    audioPlayer.dispose();
    service.invoke('stopService');
    return true;
  }

  Future<void> setForegroundState(bool isForeground) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();
    if (isForeground) {
      service.invoke('setAsForeground');
      this.isForeground = true;
      await flutterLocalNotificationsPlugin.cancelAll();
    } else {
      service.invoke('setAsBackground');
      this.isForeground = false;
    }
  }

  Future<bool> startTimer(int totalSeconds) async {
    final runningState = await service.isRunning();
    print('开始计时: $runningState');
    service.invoke('startTimer', {'totalSeconds': totalSeconds});
    return true;
  }

  Future<void> updateTimer() async {
    _seconds--;
    onUpdate!(_seconds);

    if (isForeground) {
      final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
          FlutterLocalNotificationsPlugin();
      String description;
      if (_seconds > 0) {
        description = '剩余时间: ${formatTime(_seconds)}';
      } else {
        description = '活动已结束';
        audioPlayer.resume();
      }
      flutterLocalNotificationsPlugin.show(
        notificationId,
        '活动',
        description,
        NotificationDetails(
          android: AndroidNotificationDetails(
            notificationChannelId,
            '活动',
            icon: 'ic_launcher_singlecolor',
            ongoing: true,
            actions: [
              AndroidNotificationAction(
                'stop',
                '停止',
              ),
            ],
          ),
        ),
      );
    }
  }

  Future<void> stopTimer() async {
    _timer?.cancel();
    onStop!(shouldRefresh: _seconds <= 0);
    _seconds = 0;
  }

  String formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '$hours时 $minutes分 $secs秒';
    } else if (minutes > 0) {
      return '$minutes分 $secs秒';
    } else {
      return '$secs秒';
    }
  }
}
