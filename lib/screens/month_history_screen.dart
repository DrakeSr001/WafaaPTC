import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/file_utils.dart';

class MonthHistoryScreen extends StatefulWidget {
  const MonthHistoryScreen({super.key});

  @override
  State<MonthHistoryScreen> createState() => _MonthHistoryScreenState();
}

class _MonthHistoryScreenState extends State<MonthHistoryScreen> {
  final _api = ApiClient();
  late DateTime _selected; // first day of the selected month
  bool _loading = true;
  String? _error;
  List<dynamic> _days = [];
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = DateTime(now.year, now.month, 1);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res =
          await _api.myMonth(year: _selected.year, month: _selected.month);
      setState(() => _days = List<dynamic>.from(res['days'] as List));
    } catch (e) {
      setState(() => _error = 'Failed to load month.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime(_selected.year - 3, 1),
      lastDate: DateTime(_selected.year + 3, 12),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() => _selected = DateTime(picked.year, picked.month, 1));
      _load();
    }
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final csv =
          await _api.myMonthCsv(year: _selected.year, month: _selected.month);
      final mm = _selected.month.toString().padLeft(2, '0');
      final yy = _selected.year;
      final path = await saveTextFile('my-attendance-$yy-$mm.csv', csv);

      await Share.shareXFiles([XFile(path)], text: 'My attendance for $mm/$yy');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('CSV saved & ready to share: $path')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Export failed. Check connection and try again.')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header =
        DateFormat('MMMM yyyy').format(_selected); // e.g., September 2025
    return Scaffold(
      appBar: AppBar(
        title: Text('My History — $header'),
        actions: [
          IconButton(
            onPressed: _pickMonth,
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Pick Month',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _exporting ? null : _exportCsv,
            icon: _exporting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _days.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final row = _days[i] as Map<String, dynamic>;
                    final iso = row['date'] as String?; // "YYYY-MM-DD"
                    final inStr = (row['in'] as String?) ?? '—';
                    final outStr = (row['out'] as String?) ?? '—';

                    // Display as MM/DD/YY
                    final d = iso == null
                        ? null
                        : DateTime.tryParse('${iso}T00:00:00');
                    final dateStr = d == null
                        ? (iso ?? '')
                        : DateFormat('MM/dd/yy').format(d);

                    return ListTile(
                      title: Text('$dateStr  —  IN: $inStr  —  OUT: $outStr'),
                    );
                  },
                ),
    );
  }
}
