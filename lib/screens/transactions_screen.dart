import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _transactions = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // TODO: Replace with actual API endpoint
      final response = await http.get(
        Uri.parse('http://localhost:5000/api/transactions'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List;
        setState(() {
          _transactions = data
              .map((json) => Transaction.fromJson(json))
              .toList()
              .reversed
              .toList(); // Most recent first
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        // Show mock data for now
        _transactions = _getMockTransactions();
      });
    }
  }

  List<Transaction> _getMockTransactions() {
    return [
      Transaction(
        id: '1',
        type: 'set_primary_provider',
        provider: 'o365',
        status: 'success',
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        details: 'Set Office 365 as primary mailbox',
      ),
      Transaction(
        id: '2',
        type: 'calendar_event',
        provider: 'google',
        status: 'failed',
        timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        details: 'Create calendar event: Team meeting',
        errorMessage: 'Connection timeout',
      ),
      Transaction(
        id: '3',
        type: 'send_email',
        provider: 'o365',
        status: 'success',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        details: 'Send email to john@example.com',
      ),
      Transaction(
        id: '4',
        type: 'set_primary_provider',
        provider: 'google',
        status: 'success',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        details: 'Set Google as primary mailbox',
      ),
      Transaction(
        id: '5',
        type: 'calendar_event',
        provider: 'o365',
        status: 'failed',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        details: 'Create calendar event: Project review',
        errorMessage: 'Invalid credentials',
      ),
    ];
  }

  Future<void> _retryTransaction(Transaction transaction) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retrying transaction ${transaction.id}...'),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      // TODO: Implement actual retry logic
      final response = await http.post(
        Uri.parse('http://localhost:5000/api/transactions/${transaction.id}/retry'),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction retried successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadTransactions(); // Reload to get updated status
        }
      } else {
        throw Exception('Retry failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _retryAllFailed() async {
    final failedTransactions =
        _transactions.where((t) => t.status == 'failed').toList();

    if (failedTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No failed transactions to retry')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Retrying ${failedTransactions.length} failed transactions...'),
      ),
    );

    // TODO: Implement bulk retry
    for (var transaction in failedTransactions) {
      await _retryTransaction(transaction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Monitor'),
        elevation: 0,
        actions: [
          if (_transactions.any((t) => t.status == 'failed'))
            TextButton.icon(
              onPressed: _retryAllFailed,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text(
                'Retry All',
                style: TextStyle(color: Colors.white),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTransactions,
      child: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _transactions.length,
        itemBuilder: (context, index) {
          final transaction = _transactions[index];
          return _buildTransactionCard(transaction);
        },
      ),
    );
  }

  Widget _buildTransactionCard(Transaction transaction) {
    final isSuccess = transaction.status == 'success';
    final isFailed = transaction.status == 'failed';
    final isPending = transaction.status == 'pending';

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.pending;

    if (isSuccess) {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (isFailed) {
      statusColor = Colors.red;
      statusIcon = Icons.error;
    } else if (isPending) {
      statusColor = Colors.orange;
      statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: Icon(statusIcon, color: statusColor, size: 32),
        title: Text(
          transaction.details,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _formatTimestamp(transaction.timestamp),
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: isFailed
            ? IconButton(
                icon: const Icon(Icons.refresh, color: Colors.blue),
                onPressed: () => _retryTransaction(transaction),
                tooltip: 'Retry',
              )
            : null,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('ID', transaction.id),
                _buildDetailRow('Type', transaction.type),
                _buildDetailRow('Provider', transaction.provider ?? 'N/A'),
                _buildDetailRow('Status', transaction.status.toUpperCase()),
                if (transaction.errorMessage != null)
                  _buildDetailRow('Error', transaction.errorMessage!,
                      valueColor: Colors.red),
                const SizedBox(height: 8),
                if (isFailed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _retryTransaction(transaction),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry Transaction'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

class Transaction {
  final String id;
  final String type;
  final String? provider;
  final String status; // 'success', 'failed', 'pending'
  final DateTime timestamp;
  final String details;
  final String? errorMessage;

  Transaction({
    required this.id,
    required this.type,
    this.provider,
    required this.status,
    required this.timestamp,
    required this.details,
    this.errorMessage,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'].toString(),
      type: json['type'] as String,
      provider: json['provider'] as String?,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      details: json['details'] as String,
      errorMessage: json['error_message'] as String?,
    );
  }
}
