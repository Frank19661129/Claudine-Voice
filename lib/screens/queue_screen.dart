import 'package:flutter/material.dart';
import '../models/queue_item.dart';
import '../services/queue_manager.dart';

/// Queue Screen - Toon alle queue items in FIFO volgorde
class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  final QueueManager _queueManager = QueueManager();
  List<QueueItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadItems();

    // Luister naar updates
    _queueManager.queueItemsStream.listen((items) {
      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    });
  }

  Future<void> _loadItems() async {
    final items = await _queueManager.getAllItems();
    setState(() {
      _items = items;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Opdrachten Wachtrij'),
        actions: [
          if (_items.where((i) => i.status == QueueItemStatus.completed || i.status == QueueItemStatus.cancelled).isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () async {
                await _queueManager.clearCompleted();
                _loadItems();
              },
              tooltip: 'Wis voltooide',
            ),
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Geen opdrachten in de wachtrij',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadItems,
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return _buildQueueItem(item);
                },
              ),
            ),
    );
  }

  Widget _buildQueueItem(QueueItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: _buildStatusIcon(item.status),
        title: Text(
          item.command,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.type.displayName,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDateTime(item.createdAt),
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[600],
              ),
            ),
            if (item.error != null) ...[
              const SizedBox(height: 4),
              Text(
                'Fout: ${item.error}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.red,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatusChip(item.status),
            if (item.status == QueueItemStatus.pending)
              IconButton(
                icon: const Icon(Icons.cancel, size: 20),
                onPressed: () => _cancelItem(item),
                tooltip: 'Annuleer',
              ),
            if (item.status == QueueItemStatus.completed ||
                item.status == QueueItemStatus.failed ||
                item.status == QueueItemStatus.cancelled)
              IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () => _deleteItem(item),
                tooltip: 'Verwijder',
              ),
          ],
        ),
        isThreeLine: true,
        onTap: () => _showItemDetails(item),
      ),
    );
  }

  Widget _buildStatusIcon(QueueItemStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case QueueItemStatus.pending:
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case QueueItemStatus.processing:
        icon = Icons.autorenew;
        color = Colors.blue;
        break;
      case QueueItemStatus.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case QueueItemStatus.failed:
        icon = Icons.error;
        color = Colors.red;
        break;
      case QueueItemStatus.cancelled:
        icon = Icons.cancel;
        color = Colors.grey;
        break;
    }

    return Icon(icon, color: color, size: 32);
  }

  Widget _buildStatusChip(QueueItemStatus status) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (status) {
      case QueueItemStatus.pending:
        backgroundColor = Colors.orange;
        break;
      case QueueItemStatus.processing:
        backgroundColor = Colors.blue;
        break;
      case QueueItemStatus.completed:
        backgroundColor = Colors.green;
        break;
      case QueueItemStatus.failed:
        backgroundColor = Colors.red;
        break;
      case QueueItemStatus.cancelled:
        backgroundColor = Colors.grey;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) {
      return 'Nu';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} min geleden';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} uur geleden';
    } else {
      return '${dt.day}-${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _cancelItem(QueueItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opdracht annuleren?'),
        content: Text('Weet je zeker dat je "${item.command}" wilt annuleren?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nee'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && item.id != null) {
      await _queueManager.cancelItem(item.id!);
      _loadItems();
    }
  }

  Future<void> _deleteItem(QueueItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Opdracht verwijderen?'),
        content: Text('Weet je zeker dat je "${item.command}" wilt verwijderen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nee'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ja', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && item.id != null) {
      await _queueManager.deleteItem(item.id!);
      _loadItems();
    }
  }

  void _showItemDetails(QueueItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.type.displayName),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Opdracht', item.command),
              _buildDetailRow('Status', item.status.displayName),
              _buildDetailRow('Type', item.type.displayName),
              _buildDetailRow('Aangemaakt', _formatFullDateTime(item.createdAt)),
              if (item.processedAt != null)
                _buildDetailRow('Verwerkt', _formatFullDateTime(item.processedAt!)),
              if (item.result != null)
                _buildDetailRow('Resultaat', item.result!),
              if (item.error != null)
                _buildDetailRow('Fout', item.error!, isError: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sluiten'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: isError ? Colors.red : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFullDateTime(DateTime dt) {
    return '${dt.day}-${dt.month}-${dt.year} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
