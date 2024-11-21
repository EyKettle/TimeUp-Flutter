import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化通知设置
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(initializationSettings);

    _isInitialized = true;
  }

  Future<void> dispose() async {
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      print('释放音频播放器失败: $e');
    }
  }

  Future<void> showTimerFinishedNotification() async {
    final androidDetails = AndroidNotificationDetails(
      'timer_finished_channel',
      '计时器完成通知',
      channelDescription: '当计时器完成时发送通知',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
    );

    const iOSDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    await _notifications.show(
      0,
      '计时结束',
      '您设置的计时已完成',
      details,
    );
  }

  Future<void> playTimerFinishedSound() async {
    try {
      await _audioPlayer.setVolume(1);
      await _audioPlayer.play(AssetSource('audio/timer_finished.wav'));
    } catch (e) {
      print('播放提示音失败: $e');
    }
  }
}
