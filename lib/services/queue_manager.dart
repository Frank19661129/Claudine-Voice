import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/queue_item.dart';
import 'queue_database.dart';
import 'claudine_api.dart';

/// Queue Manager - Verwerkt opdrachten asynchroon
/// Opdrachten worden altijd eerst in de queue gezet en dan asynchroon verwerkt
class QueueManager {
  static final QueueManager _instance = QueueManager._internal();
  factory QueueManager() => _instance;
  QueueManager._internal();

  final QueueDatabase _db = QueueDatabase();
  final ClaudineApiService _api = ClaudineApiService();

  Timer? _processTimer;
  bool _isProcessing = false;
  bool _isServerAvailable = false;

  // Stream controller voor UI updates
  final StreamController<int> _queueCountController =
      StreamController<int>.broadcast();
  Stream<int> get queueCountStream => _queueCountController.stream;

  final StreamController<List<QueueItem>> _queueItemsController =
      StreamController<List<QueueItem>>.broadcast();
  Stream<List<QueueItem>> get queueItemsStream => _queueItemsController.stream;

  /// Start queue processing
  Future<void> start() async {
    debugPrint('🚀 Queue Manager starting...');

    // Check server status
    await _checkServerStatus();

    // Start periodic processing (elke 2 seconden)
    _processTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _processQueue();
    });

    // Broadcast initial state
    await _broadcastQueueState();

    debugPrint('✅ Queue Manager started');
  }

  /// Stop queue processing
  void stop() {
    debugPrint('🛑 Queue Manager stopping...');
    _processTimer?.cancel();
    _processTimer = null;
  }

  /// Voeg item toe aan queue
  Future<int> addToQueue(QueueItem item) async {
    debugPrint('📥 Adding to queue: ${item.command}');

    final id = await _db.insert(item);
    await _broadcastQueueState();

    // Trigger immediate processing als er maar 1 item is
    final count = await _db.countActiveItems();
    if (count == 1) {
      debugPrint('⚡ Single item, processing immediately');
      _processQueue();
    }

    return id;
  }

  /// Annuleer een item
  Future<void> cancelItem(int id) async {
    final item = await _db.getItem(id);
    if (item == null) return;

    if (item.status == QueueItemStatus.pending) {
      await _db.update(
        item.copyWith(
          status: QueueItemStatus.cancelled,
          processedAt: DateTime.now(),
        ),
      );
      await _broadcastQueueState();
    }
  }

  /// Verwijder item uit queue
  Future<void> deleteItem(int id) async {
    await _db.delete(id);
    await _broadcastQueueState();
  }

  /// Verwijder voltooide items
  Future<void> clearCompleted() async {
    final allItems = await _db.getAllItems();
    for (final item in allItems) {
      if (item.status == QueueItemStatus.completed ||
          item.status == QueueItemStatus.cancelled) {
        await _db.delete(item.id!);
      }
    }
    await _broadcastQueueState();
  }

  /// Verwijder alle items (for cache clear on server restart)
  Future<void> clearAll() async {
    final allItems = await _db.getAllItems();
    for (final item in allItems) {
      await _db.delete(item.id!);
    }
    await _broadcastQueueState();
  }

  /// Haal alle queue items op
  Future<List<QueueItem>> getAllItems() async {
    return await _db.getAllItems();
  }

  /// Tel actieve items
  Future<int> getActiveCount() async {
    return await _db.countActiveItems();
  }

  /// Check server status
  Future<void> _checkServerStatus() async {
    try {
      _isServerAvailable = await _api.checkHealth();
      debugPrint(
          '🌐 Server available: $_isServerAvailable');
    } catch (e) {
      _isServerAvailable = false;
      debugPrint('❌ Server check failed: $e');
    }
  }

  /// Verwerk queue (hoofdlogica)
  Future<void> _processQueue() async {
    if (_isProcessing) {
      debugPrint('⏭️  Already processing, skipping...');
      return;
    }

    _isProcessing = true;

    try {
      // Check server status
      await _checkServerStatus();

      if (!_isServerAvailable) {
        debugPrint('⚠️  Server not available, keeping items in queue');
        return;
      }

      // Haal pending items op
      final pendingItems = await _db.getPendingItems();

      if (pendingItems.isEmpty) {
        return;
      }

      debugPrint('📋 Processing ${pendingItems.length} items...');

      // Verwerk items één voor één (FIFO)
      for (final item in pendingItems) {
        await _processItem(item);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Verwerk één item
  Future<void> _processItem(QueueItem item) async {
    debugPrint('⚙️  Processing item ${item.id}: ${item.command}');

    // Update status naar processing
    await _db.update(item.copyWith(status: QueueItemStatus.processing));
    await _broadcastQueueState();

    try {
      // Verwerk op basis van type
      String? result;
      switch (item.type) {
        case QueueItemType.calendarCreate:
          result = await _processCalendarCreate(item);
          break;

        case QueueItemType.reminder:
          result = await _processReminder(item);
          break;

        case QueueItemType.general:
        default:
          result = await _processGeneral(item);
          break;
      }

      // Update naar completed
      await _db.update(
        item.copyWith(
          status: QueueItemStatus.completed,
          processedAt: DateTime.now(),
          result: result,
        ),
      );

      debugPrint('✅ Item ${item.id} completed');
    } catch (e) {
      debugPrint('❌ Item ${item.id} failed: $e');

      // Update naar failed
      await _db.update(
        item.copyWith(
          status: QueueItemStatus.failed,
          processedAt: DateTime.now(),
          error: e.toString(),
        ),
      );
    }

    await _broadcastQueueState();
  }

  /// Verwerk calendar create opdracht
  Future<String> _processCalendarCreate(QueueItem item) async {
    final metadata = item.metadata ?? {};

    final response = await _api.createEvent(
      title: metadata['title'] ?? 'Afspraak',
      start: metadata['start'] != null
          ? DateTime.parse(metadata['start'])
          : DateTime.now(),
      end: metadata['end'] != null ? DateTime.parse(metadata['end']) : null,
      description: metadata['description'],
      location: metadata['location'],
      provider: metadata['provider'],
    );

    if (response?['success'] == true) {
      return response?['message'] ?? 'Event created';
    } else {
      throw Exception(response?['error'] ?? 'Failed to create event');
    }
  }

  /// Verwerk reminder opdracht
  Future<String> _processReminder(QueueItem item) async {
    debugPrint('🔔 Processing reminder: ${item.command}');
    final metadata = item.metadata ?? {};
    final location = metadata['location'] as String?;

    // Use createEventFromVoice which has Claude AI processing
    final response = await _api.createEventFromVoice(
      item.command,
      location: location,
    );

    if (response?['success'] == true) {
      return response?['response'] ?? response?['message'] ?? 'Herinnering aangemaakt';
    } else {
      throw Exception(response?['error'] ?? 'Kon herinnering niet aanmaken');
    }
  }

  /// Verwerk algemene opdracht
  Future<String> _processGeneral(QueueItem item) async {
    final metadata = item.metadata ?? {};
    final action = metadata['action'] as String?;

    // Check for specific actions
    if (action == 'set_primary_provider') {
      final provider = metadata['provider'] as String?;
      if (provider == null) {
        throw Exception('No provider specified');
      }

      debugPrint('⭐ Processing set_primary_provider: $provider');
      final success = await _api.setPrimaryProvider(provider);

      if (success) {
        return 'Primary provider set to $provider';
      } else {
        throw Exception('Failed to set primary provider');
      }
    } else if (action == 'login') {
      final provider = metadata['provider'] as String?;
      debugPrint('🔐 Processing login: $provider');
      // TODO: Implement login logic
      return 'Login request queued for $provider';
    } else if (action == 'logout') {
      final provider = metadata['provider'] as String?;
      debugPrint('🔓 Processing logout: $provider');
      // TODO: Implement logout logic
      return 'Logout request queued for $provider';
    } else {
      // Fallback to voice command processing
      final location = metadata['location'] as String?;
      final response = await _api.createEventFromVoice(
        item.command,
        location: location,
      );

      if (response?['success'] == true) {
        return response?['response'] ?? response?['message'] ?? 'Command processed';
      } else {
        throw Exception(response?['error'] ?? 'Failed to process command');
      }
    }
  }

  /// Broadcast queue state naar listeners
  Future<void> _broadcastQueueState() async {
    final count = await _db.countActiveItems();
    final items = await _db.getAllItems();

    _queueCountController.add(count);
    _queueItemsController.add(items);
  }

  /// Dispose
  void dispose() {
    stop();
    _queueCountController.close();
    _queueItemsController.close();
  }
}
