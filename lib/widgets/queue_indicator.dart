import 'package:flutter/material.dart';
import '../services/queue_manager.dart';
import '../screens/queue_screen.dart';

/// Queue Indicator Widget - Floating badge met queue count
/// Tikken opent de queue screen
class QueueIndicator extends StatefulWidget {
  const QueueIndicator({super.key});

  @override
  State<QueueIndicator> createState() => _QueueIndicatorState();
}

class _QueueIndicatorState extends State<QueueIndicator> {
  final QueueManager _queueManager = QueueManager();
  int _queueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();

    // Luister naar updates
    _queueManager.queueCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _queueCount = count;
        });
      }
    });
  }

  Future<void> _loadCount() async {
    final count = await _queueManager.getActiveCount();
    setState(() {
      _queueCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Toon alleen als er items zijn
    if (_queueCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 60,
      right: 16,
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const QueueScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.queue,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$_queueCount',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kleine versie van queue indicator (voor in app bar)
class QueueBadge extends StatefulWidget {
  const QueueBadge({super.key});

  @override
  State<QueueBadge> createState() => _QueueBadgeState();
}

class _QueueBadgeState extends State<QueueBadge> {
  final QueueManager _queueManager = QueueManager();
  int _queueCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCount();

    _queueManager.queueCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _queueCount = count;
        });
      }
    });
  }

  Future<void> _loadCount() async {
    final count = await _queueManager.getActiveCount();
    setState(() {
      _queueCount = count;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Stack(
        children: [
          const Icon(Icons.queue_outlined),
          if (_queueCount > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  _queueCount > 99 ? '99+' : '$_queueCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const QueueScreen(),
          ),
        );
      },
      tooltip: 'Opdrachten wachtrij',
    );
  }
}
