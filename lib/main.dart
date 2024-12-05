import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:kettle_timeup/models/permission_models.dart';
// import 'package:kettle_timeup/widgets/dialogs.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'widgets/history_list.dart';
import 'widgets/time_components.dart';
// import 'services/background_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final appState = context.read<MyAppState>();
    if (state == AppLifecycleState.paused) {
      // TODO: 寻找更优的异常退出保护
      appState._saveState();
      // appState._backgroundService.setForegroundState(false);
      // } else if (state == AppLifecycleState.resumed) {
      // appState._backgroundService.setForegroundState(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(builder: (lightDynamic, darkDynamic) {
      return MaterialApp(
        navigatorKey: navigatorKey,
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
  static const String _timerStateKey = 'timer_state';

  int _minutes = 0;
  int _seconds = 0;
  int _hours = 0;
  int _initialMinutes = 0;
  int _initialSeconds = 0;
  int _initialHours = 0;
  bool isFinished = false;
  bool _isLoadingData = false;
  bool _isLoadingRecords = false;
  List<TimerRecord> _records = [];
  DateTime? _startTime;
  Timer? _timer;
  int _totalSeconds = 0;

  bool isTimerRunning = false;

  // final _backgroundService = BackgroundTimerService();

  Map<String, List<TimerRecord>> _groupedRecords = {};
  List<String> _sortedDates = [];
  int _itemCount = 0;

  // 构造函数中加载数据
  MyAppState() {
    _loadData();
    _loadRecords().then((_) {
      _groupRecords();
    });
    // _initBackgroundService();
  }

  @override
  void dispose() {
    // _backgroundService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  //// [BACKGROUND_SERVICE]
  // Future<void> _initBackgroundService() async {
  //   print('准备初始化后台服务');
  //   _backgroundService.init(onUpdate: (seconds) {
  //     _hours = seconds ~/ 3600;
  //     _minutes = (seconds % 3600) ~/ 60;
  //     _seconds = seconds % 60;
  //     notifyListeners();
  //   }, onStop: ({required bool shouldRefresh}) {
  //     isTimerRunning = false;
  //     _addRecord();
  //     if (shouldRefresh) {
  //       _resetTimer();
  //     }
  //     notifyListeners();
  //   });
  // }

  //// [KEEP_FOR_FUTURE]
  // Future<bool> showPermissionDialog(
  //     BuildContext context, List<PermissionStatus> permissions) async {
  //   final result = await showDialog<bool>(
  //     context: context,
  //     barrierDismissible: false,
  //     builder: (BuildContext dialogContext) {
  //       return PermissionsDialog(
  //         permissions: permissions,
  //         onPermissionRequest: (status) async {
  //           final navContext = dialogContext;
  //           await _backgroundService.requestPermission(status.type);
  //           if (!context.mounted) return;
  //           final newStatus = await _backgroundService.checkPermissions();
  //           if (!context.mounted) return;
  //           for (final status in newStatus) {
  //             if (!status.isGranted) {
  //               notifyListeners();
  //               break;
  //             }
  //           }
  //           if (newStatus.every((p) => p.isGranted)) {
  //             Navigator.of(navContext).pop(true);
  //           }
  //         },
  //         onCancel: () {
  //           Navigator.of(dialogContext).pop(false);
  //         },
  //       );
  //     },
  //   );
  //   return result ?? false;
  // }

  Future<void> _loadData() async {
    if (_isLoadingData) return;

    try {
      _isLoadingData = true;

      final prefs = await SharedPreferences.getInstance();

      await _loadState();
      await _loadInitialTime(prefs);
      final totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
      if (totalSeconds <= 0) {
        _hours = _initialHours;
        _minutes = _initialMinutes;
        _seconds = _initialSeconds;
      }
    } catch (e) {
      print('加载数据失败: $e');
    } finally {
      _isLoadingData = false;
      notifyListeners();
    }
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final timerStateJson = prefs.getString(_timerStateKey);
    if (timerStateJson != null) {
      final timerState = json.decode(timerStateJson);
      _hours = timerState['currentHours'] ?? 0;
      _minutes = timerState['currentMinutes'] ?? 0;
      _seconds = timerState['currentSeconds'] ?? 0;
    }
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _timerStateKey,
      json.encode({
        'currentHours': _hours,
        'currentMinutes': _minutes,
        'currentSeconds': _seconds,
      }),
    );
  }

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
    print('记录保存成功');

    final timerState = {
      'currentHours': _hours,
      'currentMinutes': _minutes,
      'currentSeconds': _seconds,
    };
    await prefs.setString(_timerStateKey, json.encode(timerState));

    _groupRecords();
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
        final parsedRecords = await compute(_parseRecords, recordsJson);
        _records = parsedRecords;
        print('加载 ${_records.length} 条记录');
      } else {
        print('没有找到已保存的记录');
        _records = [];
      }
    } catch (e) {
      print('加载记录时出错: $e');
      _records = [];
    } finally {
      _isLoadingRecords = false;
      notifyListeners();
      print('记录加载完成');
    }
  }

  static List<TimerRecord> _parseRecords(List<String> jsonList) {
    try {
      return jsonList.map((str) {
        final jsonMap = Map<String, dynamic>.from(json.decode(str) as Map);
        return TimerRecord.fromJson(jsonMap);
      }).toList();
    } catch (e) {
      print('解析记录时出错: $e');
      return [];
    }
  }

  Future<void> _loadInitialTime(SharedPreferences prefs) async {
    final timeJson = prefs.getString(_initialTimeKey);
    if (timeJson != null) {
      final timeMap = json.decode(timeJson) as Map<String, dynamic>;

      // 计算初始时间
      int totalSeconds = _calculateTotalSeconds(
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

  void _setInitialTimeFromSeconds(int totalSeconds) {
    _initialHours = totalSeconds ~/ 3600;
    _initialMinutes = (totalSeconds % 3600) ~/ 60;
    _initialSeconds = totalSeconds % 60;
  }

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

  void setTime(int min, int sec, [int hours = 0]) {
    _minutes = min;
    _seconds = sec;
    _hours = hours;
    _initialMinutes = min;
    _initialSeconds = sec;
    _initialHours = hours;
    isFinished = false;
    _saveTime();
    notifyListeners();
  }

  //// [BACKGROUND_SERVICE]
  Future<void> startTimer() async {
    // final totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
    // final success = await _backgroundService.startTimer(totalSeconds);
    // if (success) {
    if (isTimerRunning) return;
    isTimerRunning = true;
    _startTime = DateTime.now();
    _totalSeconds = _hours * 3600 + _minutes * 60 + _seconds;
    notifyListeners();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _totalSeconds--;
      if (_totalSeconds <= 0) {
        stopTimer();
      } else {
        _refreshTimer();
      }
    });
    // }
  }

  //// [BACKGROUND_SERVICE]
  // Future<void> updateTimer(int remainingSeconds) async {
  //   _hours = remainingSeconds ~/ 3600;
  //   _minutes = (remainingSeconds % 3600) ~/ 60;
  //   _seconds = remainingSeconds % 60;
  //   notifyListeners();
  // }

  Future<void> stopTimer() async {
    isTimerRunning = false;
    _timer?.cancel();
    if (_totalSeconds <= 0) {
      _resetTimer();
    }
    _addRecord();
  }

  void _refreshTimer() {
    _hours = _totalSeconds ~/ 3600;
    _minutes = (_totalSeconds % 3600) ~/ 60;
    _seconds = _totalSeconds % 60;
    notifyListeners();
  }

  void _resetTimer() {
    _hours = _initialHours;
    _minutes = _initialMinutes;
    _seconds = _initialSeconds;
    isFinished = false;
    notifyListeners();
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
          if (details.primaryVelocity! < -1000) {
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
                  enabled: !appState.isTimerRunning,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: (appState.hours > 0 ||
                          appState.minutes > 0 ||
                          appState.seconds > 0)
                      ? () {
                          if (appState.isTimerRunning) {
                            appState.stopTimer();
                          } else {
                            appState.startTimer();
                          }
                        }
                      : null,
                  icon: Icon(
                    appState.isTimerRunning ? Icons.pause : Icons.play_arrow,
                    color: theme.colorScheme.onPrimary,
                  ),
                  label: Text(
                    appState.isTimerRunning ? '暂停' : '开始',
                    style: const TextStyle(fontSize: 20),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 48,
                      vertical: 16,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<bool>(
                      future: WakelockPlus.enabled,
                      initialData: false,
                      builder: (context, snapshot) {
                        return Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              bool isKeptOn = await WakelockPlus.enabled;
                              WakelockPlus.toggle(enable: !isKeptOn);
                              setState(() {});
                            },
                            icon: Icon(
                              snapshot.data!
                                  ? Icons.lightbulb
                                  : Icons.lightbulb_outlined,
                              color: snapshot.data!
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.primary.withOpacity(0.5),
                            ),
                            padding: EdgeInsets.zero,
                            tooltip: '屏幕常亮',
                          ),
                        );
                      },
                    ),
                    SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: !appState.isTimerRunning &&
                              (appState._hours != appState._initialHours ||
                                  appState._minutes !=
                                      appState._initialMinutes ||
                                  appState._seconds != appState._initialSeconds)
                          ? () {
                              appState._resetTimer();
                            }
                          : null,
                      icon: const Icon(Icons.refresh),
                      label: Text('重置'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: theme.colorScheme.primary,
                        disabledForegroundColor:
                            theme.colorScheme.primary.withOpacity(0.5),
                        disabledBackgroundColor: Colors.transparent,
                      ),
                    ),
                  ],
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
              if (details.primaryVelocity! > 1000) {
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
