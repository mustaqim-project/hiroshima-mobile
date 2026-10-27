// @req FR-OFF-02, FR-OFF-03, FR-OFF-04, FR-OFF-05, FR-POS-16, FSD-10

import 'dart:collection';

class OutboxItem {
  final String uuid;
  final String orderNo;
  final DateTime clientCreatedAt;
  final Map<String, dynamic> payload;
  int retryCount;
  DateTime? lastAttemptAt;

  OutboxItem({
    required this.uuid,
    required this.orderNo,
    required this.clientCreatedAt,
    required this.payload,
    this.retryCount = 0,
    this.lastAttemptAt,
  });

  Map<String, dynamic> toMap() => {
    'uuid': uuid,
    'order_no': orderNo,
    'client_created_at': clientCreatedAt.toIso8601String(),
    'payload': payload,
    'retry_count': retryCount,
  };
}

/// OutboxManager manages the FIFO offline transaction synchronization queue.
class OutboxManager {
  static final OutboxManager _instance = OutboxManager._internal();
  factory OutboxManager() => _instance;
  OutboxManager._internal();

  final Queue<OutboxItem> _queue = Queue<OutboxItem>();

  /// Enqueue new offline transaction
  void enqueue(OutboxItem item) {
    _queue.addLast(item);
  }

  /// Get pending items as list for batch push
  List<OutboxItem> getPendingItems({int limit = 50}) {
    return _queue.take(limit).toList();
  }

  /// Remove item from queue only when server acknowledges final status
  void acknowledgeFinalStatus(String uuid) {
    _queue.removeWhere((item) => item.uuid == uuid);
  }

  /// Queue size
  int get queueSize => _queue.length;

  /// Warning condition: Queue size > 100 (FR-POS-16)
  bool get hasHighQueueWarning => _queue.length > 100;

  /// Warning condition: Offline duration > 24 hours
  bool hasLongOfflineWarning(DateTime lastSyncTime) {
    return DateTime.now().difference(lastSyncTime).inHours > 24;
  }

  /// Testing helpers
  void clearForTesting() => _queue.clear();
  List<String> get allQueueUuids => _queue.map((e) => e.uuid).toList();
}
