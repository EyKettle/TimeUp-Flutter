import 'package:flutter/material.dart';
import 'package:kettle_timeup/main.dart';

class TimerHistoryList extends StatefulWidget {
  final Map<String, List<TimerRecord>> groupedRecords;
  final List<String> sortedDates;
  final int itemCount;
  final Function(String) onRecordDeleted;
  final Function(String, String) onNameEvent;

  const TimerHistoryList({
    super.key,
    required this.onRecordDeleted,
    required this.groupedRecords,
    required this.sortedDates,
    required this.itemCount,
    required this.onNameEvent,
  });

  @override
  State<TimerHistoryList> createState() => _TimerHistoryListState();
}

class _TimerHistoryListState extends State<TimerHistoryList> {
  void _showNameEditDialog(
      BuildContext context, String recordId, String? recordName) {
    final controller = TextEditingController(text: recordName);
    final FocusNode focusNode = FocusNode();

    Future.microtask(() => focusNode.requestFocus());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑活动名称'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: '活动名称'),
          focusNode: focusNode,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              controller.dispose();
              focusNode.dispose();
            },
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.onNameEvent(recordId, controller.text);
              controller.dispose();
              focusNode.dispose();
              setState(() {});
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.itemCount,
      itemBuilder: (context, index) => _buildListItem(index, context),
    );
  }

  Widget _buildListItem(int index, BuildContext context) {
    final theme = Theme.of(context);
    int currentIndex = 0;

    for (final date in widget.sortedDates) {
      if (index == currentIndex) {
        return _buildDateHeader(date, theme);
      }
      currentIndex++;

      final records = widget.groupedRecords[date]!;
      if (index - currentIndex < records.length) {
        return _buildRecordItem(
            records[index - currentIndex], index - currentIndex);
      }
      currentIndex += records.length;
    }
    return const SizedBox();
  }

  Widget _buildDateHeader(String date, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          date,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildRecordItem(TimerRecord record, int index) {
    return RepaintBoundary(
      child: TimerHistoryItem(
        record: record,
        index: index,
        onRemove: (recordId) => widget.onRecordDeleted(recordId),
        onNameEdit: _showNameEditDialog,
      ),
    );
  }
}

class TimerHistoryItem extends StatefulWidget {
  final TimerRecord record;
  final int index;
  final Function(String) onRemove;
  final Function(BuildContext, String, String?) onNameEdit;

  const TimerHistoryItem({
    super.key,
    required this.record,
    required this.index,
    required this.onRemove,
    required this.onNameEdit,
  });

  @override
  State<TimerHistoryItem> createState() => _TimerHistoryItemState();
}

class _TimerHistoryItemState extends State<TimerHistoryItem> {
  final double _borderRadius = 20;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(_borderRadius + 1),
        border: Border.all(
          color: theme.brightness == Brightness.dark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.1),
          width: 1,
        ),
      ),
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_borderRadius),
        child: Dismissible(
          key: ValueKey(widget.record.id),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => widget.onRemove(widget.record.id),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onLongPress: () => widget.onNameEdit(
                  context, widget.record.id, widget.record.name),
              splashColor: theme.brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.1)
                  : Colors.black.withOpacity(0.1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (widget.record.name?.trim().isEmpty ?? true)
                          ? '未知活动'
                          : widget.record.name!,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.timer, size: 16),
                              const SizedBox(width: 4),
                              Text(widget.record.duration),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              DateTime.fromMillisecondsSinceEpoch(
                                      widget.record.startTime)
                                  .toLocal()
                                  .toString()
                                  .split(' ')[1]
                                  .substring(0, 8),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
