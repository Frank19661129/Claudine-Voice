import 'dart:convert';

/// Model voor een queue item (opdracht die uitgevoerd moet worden)
class QueueItem {
  final int? id;
  final String command;
  final QueueItemType type;
  final QueueItemStatus status;
  final DateTime createdAt;
  final DateTime? processedAt;
  final String? result;
  final String? error;
  final Map<String, dynamic>? metadata;

  QueueItem({
    this.id,
    required this.command,
    required this.type,
    required this.status,
    required this.createdAt,
    this.processedAt,
    this.result,
    this.error,
    this.metadata,
  });

  /// Maak een nieuw queue item aan
  factory QueueItem.create({
    required String command,
    required QueueItemType type,
    Map<String, dynamic>? metadata,
  }) {
    return QueueItem(
      command: command,
      type: type,
      status: QueueItemStatus.pending,
      createdAt: DateTime.now(),
      metadata: metadata,
    );
  }

  /// Kopieer met updates
  QueueItem copyWith({
    int? id,
    String? command,
    QueueItemType? type,
    QueueItemStatus? status,
    DateTime? createdAt,
    DateTime? processedAt,
    String? result,
    String? error,
    Map<String, dynamic>? metadata,
  }) {
    return QueueItem(
      id: id ?? this.id,
      command: command ?? this.command,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      result: result ?? this.result,
      error: error ?? this.error,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Converteer naar database map
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'command': command,
      'type': type.name,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      if (processedAt != null) 'processed_at': processedAt!.toIso8601String(),
      if (result != null) 'result': result,
      if (error != null) 'error': error,
      if (metadata != null) 'metadata': _encodeMetadata(metadata!),
    };
  }

  /// Maak van database map
  factory QueueItem.fromMap(Map<String, dynamic> map) {
    return QueueItem(
      id: map['id'] as int?,
      command: map['command'] as String,
      type: QueueItemType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => QueueItemType.general,
      ),
      status: QueueItemStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => QueueItemStatus.pending,
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      processedAt: map['processed_at'] != null
          ? DateTime.parse(map['processed_at'] as String)
          : null,
      result: map['result'] as String?,
      error: map['error'] as String?,
      metadata: map['metadata'] != null
          ? _decodeMetadata(map['metadata'] as String)
          : null,
    );
  }

  /// Encode metadata naar JSON string
  static String _encodeMetadata(Map<String, dynamic> metadata) {
    return json.encode(metadata);
  }

  /// Decode metadata van JSON string
  static Map<String, dynamic>? _decodeMetadata(String metadata) {
    try {
      return json.decode(metadata) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'QueueItem{id: $id, command: $command, type: $type, status: $status, createdAt: $createdAt}';
  }
}

/// Type opdracht in de queue
enum QueueItemType {
  general,          // Algemene opdracht
  calendarCreate,   // Calendar event aanmaken
  calendarUpdate,   // Calendar event updaten
  calendarDelete,   // Calendar event verwijderen
  reminder,         // Reminder instellen
  note,             // Notitie maken
  email,            // Email versturen
  message,          // Bericht versturen
}

/// Status van queue item
enum QueueItemStatus {
  pending,      // Wacht om verwerkt te worden
  processing,   // Wordt nu verwerkt
  completed,    // Succesvol afgerond
  failed,       // Mislukt
  cancelled,    // Geannuleerd door gebruiker
}

/// Extension voor menselijke naam
extension QueueItemTypeExtension on QueueItemType {
  String get displayName {
    switch (this) {
      case QueueItemType.general:
        return 'Algemeen';
      case QueueItemType.calendarCreate:
        return 'Agenda afspraak';
      case QueueItemType.calendarUpdate:
        return 'Agenda wijzigen';
      case QueueItemType.calendarDelete:
        return 'Agenda verwijderen';
      case QueueItemType.reminder:
        return 'Herinnering';
      case QueueItemType.note:
        return 'Notitie';
      case QueueItemType.email:
        return 'Email';
      case QueueItemType.message:
        return 'Bericht';
    }
  }
}

extension QueueItemStatusExtension on QueueItemStatus {
  String get displayName {
    switch (this) {
      case QueueItemStatus.pending:
        return 'In wachtrij';
      case QueueItemStatus.processing:
        return 'Bezig';
      case QueueItemStatus.completed:
        return 'Voltooid';
      case QueueItemStatus.failed:
        return 'Mislukt';
      case QueueItemStatus.cancelled:
        return 'Geannuleerd';
    }
  }
}
