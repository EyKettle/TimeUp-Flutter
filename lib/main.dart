import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'widgets/history_list.dart';
import 'widgets/time_components.dart';
import 'services/notification_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    context.read<NotificationService>().dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Provider.of<MyAppState>(context, listen: false)
        .setAppState(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      return MaterialApp(
        title: 'TimeUp',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              lightDynamic ?? ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: darkDynamic ??
              ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
        ),
        home: const MyHomePage(),
      );
    });
  }
}

class TimerRecord {
  final String id;
  final String duration;
  final int startTime;
  final String? name;

  TimerRecord({
    required this.id,
    required this.duration,
    required this.startTime,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'duration': duration,
        'startTime': startTime,
        'name': name,
      };

  factory TimerRecord.fromJson(Map<String, dynamic> json) {
    // 创建默认记录
    if (!_isValidJson(json)) {
      return _createDefaultRecord();
    }

    return TimerRecord(
      id: json['id'] as String,
      duration: json['duration'] as String,
      startTime: json['startTime'] as int,
      name: json['name'] as String?,
    );
  }

  static bool _isValidJson(Map<String, dynamic> json) {
    return json['id'] is String &&
        json['duration'] is String &&
        json['startTime'] is int &&
        (json['name'] == null || json['name'] is String);
  }

  static TimerRecord _createDefaultRecord() {
    return TimerRecord(
      id: '',
      duration: '',
      startTime: DateTime.now().millisecondsSinceEpoch,
      name: '无法想象的活动',
    );
  }
}

class MyAppState extends ChangeNotifier {
  static const String _recordsKey = 'timer_records';
  static const String _initialTimeKey = 'initial_time';

  int _minutes = 0;
  int _seconds = 0;
  int _hours = 0;
  int _initialMinutes = 0;
  int _initialSeconds = 0;
  int _initialHours = 0;
  Timer? _timer;
  bool isFinished = false;
  bool isRunning = false;
  bool _isLoadingData = false;
  bool _isLoadingRecords = false;
  List<TimerRecord> _records = [];
  DateTime? _startTime;

  final NotificationService _notificationService = NotificationService();
  bool _isInForeground = true;

  Map<String, List<TimerRecord>> _groupedRecords = {};
  List<String> _sortedDates = [];
  int _itemCount = 0;

  // 构造函数中加载数据
  MyAppState() {
    _loadData();
    _loadRecords().then((_) {
      _groupRecords();
    });
    _notificationService.initialize();
  }

  void setAppState(bool isInForeground) {
    _isInForeground = isInForeground;
  }

  // 加载保存的数据
  Future<void> _loadData() async {
    if (_isLoadingData) return;

    try {
      _isLoadingData = true;

      final prefs = await SharedPreferences.getInstance();
      await _loadInitialTime(prefs);
    } catch (e) {
      print('加载数据失败: $e');
    } finally {
      _isLoadingData = false;
      notifyListeners();
    }
  }

  // 保存记录
  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final recordsJson = _records.map((record) {
      final json = record.toJson();
      if (json['hours'] == 0) {
        json.remove('hours');
      }
      return jsonEncode(json);
    }).toList();
    await prefs.setStringList(_recordsKey, recordsJson);
    print('记录保存成功'); // 添加保存成功的调试输出
    _groupRecords(); // 保存完毕重新分组
    notifyListeners();
  }

  Future<void> _loadRecords() async {
    if (_isLoadingRecords) {
      print('正在加载中,跳过重复加载');
      return;
    }

    try {
      _isLoadingRecords = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();
      final recordsJson = prefs.getStringList(_recordsKey);

      if (recordsJson != null) {
        // 使用 compute 在后台解析数据
        final parsedRecords = await compute(_parseRecords, recordsJson);
        _records = parsedRecords;
        print('成功加载记录: ${_records.length} 条'); // 添加调试输出
        for (var record in _records) {
          // 遍历输出每条记录的详情
          print('记录ID: ${record.id}, 持续时间: ${record.duration}');
        }
      } else {
        print('没有找到已保存的记录');
        _records = [];
      }
    } catch (e) {
      print('加载记录时出错: $e');
      _records = []; // 出错时确保记录列表为空而不是 null
    } finally {
      _isLoadingRecords = false;
      notifyListeners();
      print('记录加载完成');
    }
  }

  // 添加静态解析方法
  static List<TimerRecord> _parseRecords(List<String> jsonList) {
    try {
      return jsonList.map((str) {
        final jsonMap = Map<String, dynamic>.from(json.decode(str) as Map);
        return TimerRecord.fromJson(jsonMap);
      }).toList();
    } catch (e) {
      print('解析记录时出错: $e');
      return []; // 解析错误时返回空列表
    }
  }

  Future<void> _loadInitialTime(SharedPreferences prefs) async {
    final timeJson = prefs.getString(_initialTimeKey);
    if (timeJson != null) {
      final timeMap = json.decode(timeJson) as Map<String, dynamic>;

      // 计算当前时间
      int totalSeconds = _calculateTotalSeconds(
        timeMap['hours'] as int? ?? 0,
        timeMap['minutes'] as int,
        timeMap['seconds'] as int,
      );

      _setTimeFromSeconds(totalSeconds);

      // 计算初始时间
      totalSeconds = _calculateTotalSeconds(
        timeMap['initialHours'] as int? ?? 0,
        timeMap['initialMinutes'] as int,
        timeMap['initialSeconds'] as int,
      );

      _setInitialTimeFromSeconds(totalSeconds);
    }
  }

  int _calculateTotalSeconds(int hours, int minutes, int seconds) {
    int total = hours * 3600 + minutes * 60 + seconds;
    return total < 0 ? 0 : total;
  }

  void _setTimeFromSeconds(int totalSeconds) {
    _hours = totalSeconds ~/ 3600;
    _minutes = (totalSeconds % 3600) ~/ 60;
    _seconds = totalSeconds % 60;
  }

  void _setInitialTimeFromSeconds(int totalSeconds) {
    _initialHours = totalSeconds ~/ 3600;
    _initialMinutes = (totalSeconds % 3600) ~/ 60;
    _initialSeconds = totalSeconds % 60;
  }

  // 更新记录名称
  Future<void> updateRecordName(String recordId, String newName) async {
    final index = _records.indexWhere((r) => r.id == recordId);
    if (index != -1) {
      _records[index] = TimerRecord(
        id: recordId,
        duration: _records[index].duration,
        startTime: _records[index].startTime,
        name: newName,
      );
      _saveRecords();
    }
  }

  // 保存时间设置
  Future<void> _saveTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeMap = {
      'minutes': _minutes,
      'seconds': _seconds,
      'hours': _hours,
      'initialMinutes': _initialMinutes,
      'initialSeconds': _initialSeconds,
      'initialHours': _initialHours,
    };
    await prefs.setString(_initialTimeKey, json.encode(timeMap));
  }

  // 修改现有方法
  void setTime(int min, int sec, [int hours = 0]) {
    _minutes = min;
    _seconds = sec;
    _hours = hours;
    _initialMinutes = min;
    _initialSeconds = sec;
    _initialHours = hours;
    isFinished = false;
    _saveTime(); // 保存时间设置
    notifyListeners();
  }

  void startTimer() {
    // 计算总秒数
    int totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;

    _startTime = DateTime.now();
    isRunning = true;
    notifyListeners();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (--totalSeconds <= 0) {
        timer.cancel();
        isFinished = true;
        isRunning = false;
        _addRecord();
        _resetTimer();

        if (_isInForeground) {
          _notificationService.playTimerFinishedSound();
        } else {
          _notificationService.showTimerFinishedNotification();
        }

        notifyListeners();
        return;
      }

      // 更新时分秒
      _hours = totalSeconds ~/ 3600;
      _minutes = (totalSeconds % 3600) ~/ 60;
      _seconds = totalSeconds % 60;

      notifyListeners();
    });
  }

  void stopTimer() {
    _timer?.cancel();
    isRunning = false;
    if (_startTime != null) {
      _addRecord();
      if (_isInForeground) {
        _notificationService.playTimerFinishedSound();
      } else {
        _notificationService.showTimerFinishedNotification();
      }
    }
    notifyListeners();
  }

  void _resetTimer() {
    _minutes = _initialMinutes;
    _seconds = _initialSeconds;
    _hours = _initialHours;
    isFinished = false;
  }

  void _addRecord() async {
    if (_startTime == null) return;
    final stopTime = DateTime.now();
    final duration = stopTime.difference(_startTime!);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    _records.insert(
      0,
      TimerRecord(
        id: DateTime.now().toString(),
        duration:
            hours > 0 ? '$hours小时$minutes分$seconds秒' : '$minutes分$seconds秒',
        startTime: _startTime!.millisecondsSinceEpoch,
      ),
    );
    _startTime = null;
    _saveRecords();
  }

  void removeRecord(String recordId) async {
    final record = _records.firstWhere((r) => r.id == recordId);
    final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
    final dateStr = '${date.year}年${date.month}月${date.day}日';

    if (_groupedRecords.containsKey(dateStr)) {
      _groupedRecords[dateStr]!.remove(record);

      if (_groupedRecords[dateStr]!.isEmpty) {
        _groupedRecords.remove(dateStr);
        _sortedDates.remove(dateStr);
      }
    }

    _itemCount = _sortedDates.length * 2 +
        _sortedDates.fold(
            0, (sum, date) => sum + _groupedRecords[date]!.length);

    _records.remove(record);
    print('删除记录: ${record.id}');
    _saveRecords();
  }

  void _groupRecords() {
    try {
      _groupedRecords = {};
      _sortedDates = [];
      _itemCount = 0;

      if (_records.isEmpty) {
        print('记录分组完成: 无记录');
        return;
      }

      for (var record in _records) {
        final date = DateTime.fromMillisecondsSinceEpoch(record.startTime);
        final dateStr = '${date.year}年${date.month}月${date.day}日';
        _groupedRecords.putIfAbsent(dateStr, () => []).add(record);
      }

      _sortedDates = _groupedRecords.keys.toList()
        ..sort((a, b) => b.compareTo(a));

      _itemCount = _sortedDates.length * 2 +
          _sortedDates.fold(
              0, (sum, date) => sum + _groupedRecords[date]!.length);

      print('记录分组完成: ${_sortedDates.length}个日期, 共$_itemCount条记录');
    } catch (e) {
      print('记录分组失败: $e');
    }
  }

  int get minutes => _minutes;
  int get seconds => _seconds;
  int get hours => _hours;
  bool get isLoadingData => _isLoadingData;
  bool get isLoadingRecords => _isLoadingRecords;

  List<TimerRecord> get records => _records;
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final theme = Theme.of(context);

    if (appState.isFinished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('计时结束！'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: theme.colorScheme.surface,
        statusBarIconBrightness: theme.brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
      ),
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            Navigator.of(context).push(
              PageRouteBuilder(
                transitionDuration: const Duration(milliseconds: 300),
                reverseTransitionDuration: const Duration(milliseconds: 300),
                pageBuilder: (context, animation, secondaryAnimation) =>
                    TimerHistoryPage(parentContext: context),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  final curvedAnimation = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutQuart,
                    reverseCurve: Curves.easeInQuart,
                  );

                  return RepaintBoundary(
                    child: Stack(
                      fit: StackFit.passthrough,
                      children: [
                        SlideTransition(
                          transformHitTests: true,
                          position: Tween<Offset>(
                            begin: Offset.zero,
                            end: const Offset(-1.0, 0.0),
                          ).animate(curvedAnimation),
                          child: RepaintBoundary(child: widget),
                        ),
                        SlideTransition(
                          transformHitTests: true,
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(curvedAnimation),
                          child: RepaintBoundary(child: child),
                        ),
                      ],
                    ),
                  );
                },
                opaque: false,
                barrierDismissible: true,
              ),
            );
          }
        },
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            automaticallyImplyLeading: false,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TimeCard(
                  displayStyle: TimeDisplayStyle.stacked,
                  hours: appState.hours,
                  minutes: appState.minutes,
                  seconds: appState.seconds,
                  onTap: () => _showTimePickerDialog(context, appState.minutes,
                      appState.seconds, appState.hours),
                  onLongPress: () => _showTimeInputDialog(context,
                      appState.minutes, appState.seconds, appState.hours),
                  enabled: !appState.isRunning, // 根据计时状态禁用TimeCard
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: (appState.hours > 0 ||
                          appState.minutes > 0 ||
                          appState.seconds > 0)
                      ? () {
                          if (appState.isRunning) {
                            appState.stopTimer();
                          } else {
                            appState.startTimer();
                          }
                        }
                      : null,
                  icon:
                      Icon(appState.isRunning ? Icons.pause : Icons.play_arrow),
                  label: Text(appState.isRunning ? '暂停' : '开始'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTimePickerDialog(
      BuildContext context, int minutes, int seconds, int hours) {
    showDialog(
      context: context,
      builder: (BuildContext context) => TimerPickerDialog(
          initialMinutes: minutes,
          initialSeconds: seconds,
          initialHours: hours),
    );
  }

  void _showTimeInputDialog(
      BuildContext context, int minutes, int seconds, int hours) {
    showDialog(
      context: context,
      builder: (BuildContext context) => TimerInputDialog(
          initialMinutes: minutes,
          initialSeconds: seconds,
          initialHours: hours),
    );
  }
}

class TimerHistoryPage extends StatefulWidget {
  final BuildContext parentContext;

  const TimerHistoryPage({super.key, required this.parentContext});

  @override
  State<TimerHistoryPage> createState() => _TimerHistoryPageState();
}

class _TimerHistoryPageState extends State<TimerHistoryPage>
    with SingleTickerProviderStateMixin {
  void goBack() {
    // Navigator.of(context).pushReplacement(
    //   PageRouteBuilder(
    //     transitionDuration: const Duration(milliseconds: 300),
    //     reverseTransitionDuration: const Duration(milliseconds: 300),
    //     pageBuilder: (context, animation, secondaryAnimation) => MyHomePage(),
    //     transitionsBuilder: (context, animation, secondaryAnimation, child) {
    //       final curvedAnimation = CurvedAnimation(
    //         parent: animation,
    //         curve: Curves.easeOutQuart,
    //       );

    //       return RepaintBoundary(
    //         child: Stack(
    //           fit: StackFit.passthrough,
    //           children: [
    //             SlideTransition(
    //               transformHitTests: true,
    //               position: Tween<Offset>(
    //                 begin: Offset.zero,
    //                 end: const Offset(1.0, 0.0),
    //               ).animate(curvedAnimation),
    //               child: RepaintBoundary(child: widget),
    //             ),
    //             SlideTransition(
    //               transformHitTests: true,
    //               position: Tween<Offset>(
    //                 begin: const Offset(-1.0, 0.0),
    //                 end: Offset.zero,
    //               ).animate(curvedAnimation),
    //               child: RepaintBoundary(child: child),
    //             ),
    //           ],
    //         ),
    //       );
    //     },
    //     opaque: false,
    //     barrierDismissible: true,
    //   ),
    // );
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _buildContent(MyAppState appState) {
    if (appState.isLoadingRecords) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (appState.records.isEmpty) {
      return const Center(
        child: Text(
          '暂无记录',
          style: TextStyle(
            fontSize: 18,
            color: Colors.grey,
          ),
        ),
      );
    }

    return TimerHistoryList(
      groupedRecords: appState._groupedRecords,
      sortedDates: appState._sortedDates,
      itemCount: appState._itemCount,
      onRecordDeleted: (recordId) {
        appState.removeRecord(recordId);
      },
      onNameEvent: (recordId, name) {
        appState.updateRecordName(recordId, name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final theme = Theme.of(context);

    return Stack(
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: theme.brightness == Brightness.light
                ? Brightness.dark
                : Brightness.light,
          ),
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                goBack();
              }
            },
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              floatingActionButton: Padding(
                padding: const EdgeInsets.only(right: 280),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32.0),
                  child: FloatingActionButton(
                    onPressed: goBack,
                    child: const Icon(Icons.arrow_back),
                  ),
                ),
              ),
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.endFloat,
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildContent(appState),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                height: MediaQuery.of(context).padding.top,
                color: theme.scaffoldBackgroundColor.withOpacity(0.2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
