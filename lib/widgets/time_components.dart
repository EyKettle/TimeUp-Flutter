import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kettle_timeup/main.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:provider/provider.dart';

class TimerInputDialog extends StatefulWidget {
  final int initialMinutes;
  final int initialSeconds;
  final int initialHours;

  const TimerInputDialog({
    super.key,
    required this.initialMinutes,
    required this.initialSeconds,
    this.initialHours = 0,
  });

  @override
  State<TimerInputDialog> createState() => _TimeInputDialogState();
}

class _TimeInputDialogState extends State<TimerInputDialog> {
  late final TextEditingController _hoursController;
  late final TextEditingController _minutesController;
  late final TextEditingController _secondsController;

  @override
  void initState() {
    super.initState();
    _hoursController =
        TextEditingController(text: widget.initialHours.toString());
    _minutesController =
        TextEditingController(text: widget.initialMinutes.toString());
    _secondsController =
        TextEditingController(text: widget.initialSeconds.toString());
  }

  @override
  void dispose() {
    _hoursController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  Widget _buildTimeTextField({
    required TextEditingController controller,
    required int maxValue,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (value) {
        final number = int.tryParse(value);
        if (number != null) {
          if (number < 0) controller.text = '0';
          if (number > maxValue) controller.text = maxValue.toString();
        }
      },
    );
  }

  void _saveTimeAndClose(BuildContext context) {
    final hours = int.tryParse(_hoursController.text) ?? 0;
    final minutes = int.tryParse(_minutesController.text) ?? 0;
    final seconds = int.tryParse(_secondsController.text) ?? 0;
    context.read<MyAppState>().setTime(minutes, seconds, hours);
    Navigator.pop(context);
    dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入时间'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTimeTextField(
                  controller: _hoursController,
                  maxValue: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeTextField(
                  controller: _minutesController,
                  maxValue: 59,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildTimeTextField(
                  controller: _secondsController,
                  maxValue: 59,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            dispose();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => _saveTimeAndClose(context),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class TimerPickerDialog extends StatefulWidget {
  final int initialMinutes;
  final int initialSeconds;
  final int initialHours;

  const TimerPickerDialog({
    super.key,
    required this.initialMinutes,
    required this.initialSeconds,
    this.initialHours = 0,
  });

  @override
  State<TimerPickerDialog> createState() => _TimePickerDialogState();
}

class _TimePickerDialogState extends State<TimerPickerDialog> {
  late int selectedMinutes;
  late int selectedSeconds;
  late int selectedHours;

  @override
  void initState() {
    super.initState();
    selectedMinutes = widget.initialMinutes;
    selectedSeconds = widget.initialSeconds;
    selectedHours = widget.initialHours;
  }

  Widget _buildNumberPickerColumn({
    required String label,
    required int value,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Text(label),
        NumberPicker(
          minValue: 0,
          maxValue: maxValue,
          value: value,
          onChanged: onChanged,
          itemHeight: 40,
        ),
      ],
    );
  }

  Widget _buildHorizontalNumberPicker({
    required String label,
    required int value,
    required int maxValue,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      children: [
        Text(label),
        NumberPicker(
          axis: Axis.horizontal,
          minValue: 0,
          maxValue: maxValue,
          value: value,
          onChanged: onChanged,
          itemCount: 3,
          itemWidth: 48,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('设置时间'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHorizontalNumberPicker(
            label: '小时',
            value: selectedHours,
            maxValue: 24,
            onChanged: (value) => setState(() => selectedHours = value),
          ),
          const SizedBox(height: 32), // 增加间隔
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: _buildNumberPickerColumn(
                  label: '分钟',
                  value: selectedMinutes,
                  maxValue: 59,
                  onChanged: (value) => setState(() => selectedMinutes = value),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _buildNumberPickerColumn(
                  label: '秒',
                  value: selectedSeconds,
                  maxValue: 59,
                  onChanged: (value) => setState(() => selectedSeconds = value),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            dispose();
          },
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            context
                .read<MyAppState>()
                .setTime(selectedMinutes, selectedSeconds, selectedHours);
            Navigator.pop(context);
            dispose();
          },
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class TimeCard extends StatefulWidget {
  const TimeCard({
    super.key,
    required this.minutes,
    required this.seconds,
    required this.onTap,
    required this.onLongPress,
    this.hours = 0,
    this.enabled = true,
    this.displayStyle = TimeDisplayStyle.digital,
  })  : assert(minutes >= 0 && minutes <= 59),
        assert(seconds >= 0 && seconds <= 59),
        assert(hours >= 0 && hours <= 24);

  final int minutes;
  final int seconds;
  final int hours;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool enabled;
  final TimeDisplayStyle displayStyle;

  @override
  State<TimeCard> createState() => _TimeCardState();
}

enum TimeDisplayStyle { digital, stacked }

class _TimeCardState extends State<TimeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _elevation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.06).animate(_controller);
    _elevation = Tween<double>(begin: 1.0, end: 8.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildDigitalDisplay(ThemeData theme) {
    final style = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    final timeText = widget.hours > 0
        ? '${widget.hours.toString().padLeft(2, '0')}:${widget.minutes.toString().padLeft(2, '0')}:${widget.seconds.toString().padLeft(2, '0')}'
        : '${widget.minutes.toString().padLeft(2, '0')}:${widget.seconds.toString().padLeft(2, '0')}';

    return Text(
      timeText,
      style: style,
      semanticsLabel: timeText,
    );
  }

  Widget _buildStackedDisplay(ThemeData theme) {
    final primaryStyle = theme.textTheme.displayMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );
    final secondaryStyle = theme.textTheme.headlineMedium!.copyWith(
      color: theme.colorScheme.onPrimary,
    );

    String firstLine;
    String secondLine;

    if (widget.hours > 0) {
      firstLine = '${widget.hours}小时';
      secondLine = '${widget.minutes}分${widget.seconds}秒';
    } else {
      firstLine = '${widget.minutes}分钟';
      secondLine = '${widget.seconds}秒钟';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          firstLine,
          style: primaryStyle,
        ),
        const SizedBox(height: 8),
        Text(
          secondLine,
          style: secondaryStyle,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => ScaleTransition(
        scale: _scale,
        child: Card(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(32)),
          ),
          elevation: _elevation.value,
          color: widget.enabled
              ? theme.colorScheme.primary
              : theme.colorScheme.primary.withOpacity(0.5),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(32)),
              onTapDown: widget.enabled ? (_) => _controller.forward() : null,
              onTapUp: widget.enabled ? (_) => _controller.reverse() : null,
              onTapCancel: widget.enabled ? () => _controller.reverse() : null,
              onTap: widget.enabled ? widget.onTap : null,
              onLongPress: widget.enabled
                  ? () {
                      HapticFeedback.vibrate();
                      widget.onLongPress();
                    }
                  : null,
              splashFactory: InkSparkle.splashFactory,
              splashColor: theme.colorScheme.onPrimary.withOpacity(0.1),
              highlightColor: Colors.transparent,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
                child: IntrinsicWidth(
                  child: IntrinsicHeight(
                    child: Center(
                      child: widget.displayStyle == TimeDisplayStyle.digital
                          ? _buildDigitalDisplay(theme)
                          : _buildStackedDisplay(theme),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
