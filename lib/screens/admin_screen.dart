import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../services/token_storage.dart';
import '../utils/download.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiClient();

  // Doctors list (for per-doctor CSV)
  bool _loadingUsers = true;
  List<Map<String, dynamic>> _doctors = [];
  Map<String, dynamic>? _selectedDoctor;

  // Month selector
  late DateTime _selectedMonth;

  // Custom range selector (for payroll exports)
  late DateTime _rangeStart;
  late DateTime _rangeEnd;
  String _rangePreset = 'this_month';
  bool _rangeSummaryLoading = false;
  Map<String, dynamic>? _rangeSummary;

  // Busy flags
  bool _busy = false;
  bool _rangeBusy = false;
  bool _creatingUser = false;
  bool _creatingDevice = false;

  // Create User form
  final _userForm = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: 'Password123!');
  String _role = 'doctor'; // doctor | admin

  // Create Device form
  final _deviceForm = GlobalKey<FormState>();
  final _deviceName = TextEditingController();
  final _deviceLocation = TextEditingController();

  // Tabs
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _rangeStart = _selectedMonth;
    _rangeEnd = DateTime(now.year, now.month, now.day);
    _tab = TabController(length: 4, vsync: this); // was 3
    _loadDoctors();
  }

  @override
  void dispose() {
    _tab.dispose();
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _deviceName.dispose();
    _deviceLocation.dispose();
    super.dispose();
  }

  Future<void> _loadDoctors() async {
    setState(() => _loadingUsers = true);
    try {
      final list = await _api.listDoctors();
      setState(() {
        _doctors = list;
        if (_doctors.isNotEmpty) {
          // Keep selection if still present, else choose first
          final prevId = _selectedDoctor?['id'];
          _selectedDoctor = _doctors.firstWhere(
            (d) => d['id'] == prevId,
            orElse: () => _doctors.first,
          );
        } else {
          _selectedDoctor = null;
        }
      });
      if (_doctors.isNotEmpty) {
        await _loadRangeSummary();
      } else if (mounted) {
        setState(() => _rangeSummary = null);
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load doctors.')),
      );
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(_selectedMonth.year - 3, 1),
      lastDate: DateTime(_selectedMonth.year + 3, 12),
      helpText: 'Select month',
    );
    if (picked != null) {
      setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
    }
  }

  Future<void> _exportDoctorCsv() async {
    if (_busy || _selectedDoctor == null) return;
    setState(() => _busy = true);
    try {
      final uid = _selectedDoctor!['id'] as String;
      final y = _selectedMonth.year, m = _selectedMonth.month;
      final csv = await _api.doctorMonthCsv(userId: uid, year: y, month: m);
      final mm = m.toString().padLeft(2, '0');
      final namePart =
          (_selectedDoctor!['name'] as String).replaceAll(' ', '_');
      await saveAndShareTextFile('doctor-$namePart-$y-$mm.csv', csv);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Export failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportClinicWorkbook() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final y = _selectedMonth.year, m = _selectedMonth.month;
      final workbook = await _api.clinicMonthWorkbook(year: y, month: m);
      final mm = m.toString().padLeft(2, '0');
      await saveAndShareBinaryFile('clinic-$y-$mm.xlsx', workbook);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Export failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportDoctorRangeCsv() async {
    if (_rangeBusy || _selectedDoctor == null) return;
    setState(() => _rangeBusy = true);
    try {
      final uid = _selectedDoctor!['id'] as String;
      final csv = await _api.doctorRangeCsv(
        userId: uid,
        start: _rangeStart,
        end: _rangeEnd,
      );
      final namePart = (_selectedDoctor!['name'] as String).replaceAll(' ', '_');
      await saveAndShareTextFile(
        'doctor-$namePart-${_rangeFileSuffix()}.csv',
        csv,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Range export failed.')),
      );
    } finally {
      if (mounted) setState(() => _rangeBusy = false);
    }
  }

  Future<void> _exportClinicRangeWorkbook() async {
    if (_rangeBusy) return;
    setState(() => _rangeBusy = true);
    try {
      final workbook = await _api.clinicRangeWorkbook(
        start: _rangeStart,
        end: _rangeEnd,
      );
      await saveAndShareBinaryFile(
        'clinic-${_rangeFileSuffix()}.xlsx',
        workbook,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Range export failed.')),
      );
    } finally {
      if (mounted) setState(() => _rangeBusy = false);
    }
  }

  Future<void> _exportSummaryCsv() async {
    final summary = _rangeSummary;
    if (summary == null) return;
    final days = (summary['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final buffer = StringBuffer();
    buffer.writeln('Date,Weekday,First IN,Last OUT,Worked (hh:mm)');
    for (final day in days) {
      buffer.writeln(
          '${day['date']},${day['weekday'] ?? ''},${day['in'] ?? ''},${day['out'] ?? ''},${day['hours'] ?? ''}');
    }
    buffer.writeln();
    buffer.writeln('Total,,,${summary['totalHours'] ?? ''}');
    buffer.writeln('Worked Days,,,${summary['workedDays'] ?? ''}');
    buffer.writeln(
        'Average per Worked Day,,,${summary['averagePerWorkedDay'] ?? ''}');
    await saveAndShareTextFile(
      'doctor-summary-${_rangeFileSuffix()}.csv',
      buffer.toString(),
    );
  }

  String _rangeFileSuffix() {
    final formatter = DateFormat('yyyyMMdd');
    return '${formatter.format(_rangeStart)}-${formatter.format(_rangeEnd)}';
  }

  Widget _buildExportsTab() {
    if (_loadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_doctors.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No doctors found yet. Create doctors first, then come back to export their attendance.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDoctorSelectorCard(),
          const SizedBox(height: 16),
          _buildMonthlyExportsCard(),
          const SizedBox(height: 16),
          _buildRangeExportsCard(),
        ],
      ),
    );
  }

  Widget _buildDoctorSelectorCard() {
    final theme = Theme.of(context);
    final selected = _selectedDoctor;
    final doctorEmail = selected?['email'] as String? ?? '';
    final doctorId = selected?['id'] as String? ?? '';
    final shortenedId = doctorId.isEmpty
        ? '—'
        : (doctorId.length > 10 ? '${doctorId.substring(0, 10)}…' : doctorId);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select doctor',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Map<String, dynamic>>(
              key: ValueKey<String>(
                (_selectedDoctor?['id'] as String?) ?? 'doctor-null',
              ),
              initialValue: _selectedDoctor,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Doctor',
                border: OutlineInputBorder(),
              ),
              items: _doctors.map((d) {
                final email = d['email'] as String? ?? '';
                return DropdownMenuItem(
                  value: d,
                  child: Text('${d['name']}  ($email)'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedDoctor = value);
                _loadRangeSummary();
              },
            ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.mail, size: 16),
                    label: Text(doctorEmail),
                  ),
                  Chip(
                    avatar: const Icon(Icons.badge_outlined, size: 16),
                    label: Text('ID: $shortenedId'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyExportsCard() {
    final theme = Theme.of(context);
    final monthLabel = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Quick monthly exports',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickMonth,
                  icon: const Icon(Icons.calendar_month_outlined),
                  label: Text(monthLabel),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
                'Download full-month attendance for payroll and archival purposes.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: (_selectedDoctor == null || _busy)
                      ? null
                      : _exportDoctorCsv,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_outline),
                  label: const Text('Doctor CSV (month)'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _exportClinicWorkbook,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.apartment_outlined),
                  label: const Text('Clinic CSV (month)'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangeExportsCard() {
    final theme = Theme.of(context);
    final rangeLabel =
        '${DateFormat('MMM d, yyyy').format(_rangeStart)} – ${DateFormat('MMM d, yyyy').format(_rangeEnd)}';
    final totalDays = _rangeEnd.difference(_rangeStart).inDays + 1;
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Custom range & payroll insights',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.date_range_outlined),
                  label: const Text('Pick dates'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Range: $rangeLabel � $totalDays days'),
            const SizedBox(height: 12),
            _buildRangePresetChips(),
            const SizedBox(height: 16),
            _buildRangeSummaryContent(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: (_selectedDoctor == null || _rangeBusy)
                      ? null
                      : _exportDoctorRangeCsv,
                  icon: _rangeBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.person_pin_circle_outlined),
                  label: const Text('Doctor CSV (range)'),
                ),
                OutlinedButton.icon(
                  onPressed: _rangeBusy ? null : _exportClinicRangeWorkbook,
                  icon: _rangeBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.domain_outlined),
                  label: const Text('Clinic CSV (range)'),
                ),
                OutlinedButton.icon(
                  onPressed: (_rangeSummary == null || _rangeSummaryLoading)
                      ? null
                      : _exportSummaryCsv,
                  icon: const Icon(Icons.table_view_outlined),
                  label: const Text('Download summary CSV'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRangePresetChips() {
    final presets = [
      {'key': 'last_7', 'label': 'Last 7 days'},
      {'key': 'this_month', 'label': 'This month'},
      {'key': 'last_month', 'label': 'Last month'},
      {'key': 'custom', 'label': 'Custom'},
    ];
    return Wrap(
      spacing: 8,
      children: presets.map((preset) {
        final key = preset['key']!;
        final label = preset['label']!;
        return ChoiceChip(
          label: Text(label),
          selected: _rangePreset == key,
          onSelected: (selected) {
            if (!selected) return;
            if (key == 'custom') {
              _pickCustomRange();
            } else {
              _applyRangePreset(key);
            }
          },
        );
      }).toList(),
    );
  }

  Widget _buildRangeSummaryContent() {
    if (_rangeSummaryLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedDoctor == null) {
      return const Text('Choose a doctor to see payroll insights.');
    }
    final summary = _rangeSummary;
    if (summary == null) {
      return const Text('No summary available for this doctor yet.');
    }
    final totalHours = summary['totalHours'] as String? ?? '00:00';
    final workedDays = summary['workedDays'] as int? ?? 0;
    final avg = summary['averagePerWorkedDay'] as String? ?? '--';
    final days =
        (summary['days'] as List?)?.cast<Map<String, dynamic>>() ?? <Map<String, dynamic>>[];

    final listHeight = days.isEmpty
        ? 120.0
        : math.min(360.0, 64.0 * days.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.timer_outlined, size: 18),
              label: Text('Total $totalHours'),
            ),
            Chip(
              avatar: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text('$workedDays worked day${workedDays == 1 ? '' : 's'}'),
            ),
            Chip(
              avatar: const Icon(Icons.bar_chart_outlined, size: 18),
              label: Text('Avg / worked day: $avg'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: days.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No attendance found in this range.'),
                )
              : SizedBox(
                  height: listHeight,
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: days.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, index) {
                        final day = days[index];
                        final date = DateTime.parse(day['date'] as String);
                            DateFormat('EEE').format(date);
                        final inStr = (day['in'] as String?) ?? '\u2014';
                        final outStr = (day['out'] as String?) ?? '\u2014';
                        final hours = (day['hours'] as String?) ?? '00:00';
                        final minutes = day['minutes'] as int? ?? 0;
                        final hasWork = minutes > 0;
                        final colorScheme = Theme.of(context).colorScheme;
                        final avatarBg = hasWork
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainerHighest;
                        final avatarFg = hasWork
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: avatarBg,
                            foregroundColor: avatarFg,
                            child: Text(
                              DateFormat('d').format(date),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(
                            DateFormat('EEE, MMM d').format(date),
                            style: TextStyle(
                              fontWeight:
                                  hasWork ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text('In: $inStr   |   Out: $outStr'),
                          trailing: Text(
                            hours,
                            style: TextStyle(
                              fontWeight:
                                  hasWork ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _applyRangePreset(String preset) async {
    final now = DateTime.now();
    late DateTime start;
    late DateTime end;
    switch (preset) {
      case 'last_7':
        end = DateTime(now.year, now.month, now.day);
        start = end.subtract(const Duration(days: 6));
        break;
      case 'last_month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        end = firstOfThisMonth.subtract(const Duration(days: 1));
        start = DateTime(end.year, end.month, 1);
        break;
      case 'this_month':
      default:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month, now.day);
        preset = 'this_month';
        break;
    }
    setState(() {
      _rangePreset = preset;
      _rangeStart = start;
      _rangeEnd = end;
    });
    await _loadRangeSummary();
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(
        start: _rangeStart,
        end: _rangeEnd,
      ),
      helpText: 'Select date range',
    );
    if (picked == null) return;
    final start = DateTime(picked.start.year, picked.start.month, picked.start.day);
    final end = DateTime(picked.end.year, picked.end.month, picked.end.day);
    setState(() {
      _rangePreset = 'custom';
      _rangeStart = start;
      _rangeEnd = end;
    });
    await _loadRangeSummary();
  }

  Future<void> _loadRangeSummary() async {
    if (_selectedDoctor == null) {
      if (mounted) setState(() => _rangeSummary = null);
      return;
    }
    setState(() => _rangeSummaryLoading = true);
    try {
      final summary = await _api.doctorRangeSummary(
        userId: _selectedDoctor!['id'] as String,
        start: _rangeStart,
        end: _rangeEnd,
      );
      if (!mounted) return;
      setState(() => _rangeSummary = summary);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load range summary.')),
      );
    } finally {
      if (mounted) setState(() => _rangeSummaryLoading = false);
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    }
  }

  Future<void> _submitCreateUser() async {
    if (!_userForm.currentState!.validate()) return;
    setState(() => _creatingUser = true);
    try {
      await _api.createUser(
        fullName: _fullName.text.trim(),
        email: _email.text.trim(),
        password: _password.text, // already trimmed from input
        role: _role,
      );
      // Clear inputs
      _fullName.clear();
      _email.clear();
      // Keep password & role for convenience
      await _loadDoctors(); // refresh list so new doctor appears
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User created.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create user failed (email taken?).')),
      );
    } finally {
      if (mounted) setState(() => _creatingUser = false);
    }
  }

  Future<void> _submitCreateDevice() async {
    if (!_deviceForm.currentState!.validate()) return;
    setState(() => _creatingDevice = true);
    try {
      final res = await _api.createDevice(
        name: _deviceName.text.trim(),
        location: _deviceLocation.text.trim().isEmpty
            ? null
            : _deviceLocation.text.trim(),
      );
      final apiKey = res['apiKey'] as String? ?? '';
      _deviceName.clear();
      _deviceLocation.clear();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Device Created'),
          content: SelectableText('''API Key:
$apiKey

Copy this into the kiosk app config.dart'''),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create device failed.')),
      );
    } finally {
      if (mounted) setState(() => _creatingDevice = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = DateFormat('MMMM yyyy').format(_selectedMonth);
    return Scaffold(
      appBar: AppBar(
        title: Text('Admin - $header'),
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(icon: Icon(Icons.download), text: 'Exports'),
            Tab(icon: Icon(Icons.person_add), text: 'Create User'),
            Tab(icon: Icon(Icons.devices_other), text: 'Create Device'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'Manage'), // NEW
          ],
        ),
        actions: [
          IconButton(
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month),
              tooltip: 'Pick Month'),
          IconButton(
              onPressed: _loadingUsers ? null : _loadDoctors,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Doctors'),
          IconButton(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              tooltip: 'Logout'),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ======== Tab 1: Exports ========
          _buildExportsTab(),

          // ======== Tab 2: Create User ========
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _userForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create User',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Enter a valid name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@'))
                        ? 'Enter a valid email'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) =>
                        (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Role:'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _role,
                        items: const [
                          DropdownMenuItem(
                              value: 'doctor', child: Text('Doctor')),
                          DropdownMenuItem(
                              value: 'admin', child: Text('Admin')),
                        ],
                        onChanged: (v) => setState(() => _role = v ?? 'doctor'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creatingUser ? null : _submitCreateUser,
                      icon: _creatingUser
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.person_add),
                      label: const Text('Create User'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======== Tab 3: Create Device ========
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _deviceForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create Device',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deviceName,
                    decoration: const InputDecoration(labelText: 'Device name'),
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Enter a valid name'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deviceLocation,
                    decoration:
                        const InputDecoration(labelText: 'Location (optional)'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creatingDevice ? null : _submitCreateDevice,
                      icon: _creatingDevice
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.devices_other),
                      label: const Text('Create Device'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ======== Tab 4: Manage Users & Devices ========
          Padding(
            padding: const EdgeInsets.all(12),
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(tabs: [
                    Tab(text: 'Users'),
                    Tab(text: 'Devices'),
                  ]),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _UsersManager(
                          api: _api,
                          reloadDoctors: _loadDoctors,
                        ),
                        _DevicesManager(api: _api),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersManager extends StatefulWidget {
  final ApiClient api;
  final Future<void> Function()
      reloadDoctors; // to refresh dropdown on Admin Exports tab
  const _UsersManager({required this.api, required this.reloadDoctors});

  @override
  State<_UsersManager> createState() => _UsersManagerState();
}

class _UsersManagerState extends State<_UsersManager> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final doctors = await widget.api.listDoctors();
      setState(() => _users = doctors);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    final next = !(u['isActive'] as bool? ?? true);
    await widget.api.updateUser(id, isActive: next);
    await _load();
    await widget.reloadDoctors();
    if (!mounted) return;
    final name = u['name'] as String? ?? 'Doctor';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(next
              ? '$name has been reactivated.'
              : '$name has been suspended.')),
    );
  }

  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    final ctrl = TextEditingController(text: 'Password123!');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Enter a new temporary password to share with the doctor.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Update')),
        ],
      ),
    );
    if (confirm == true) {
      await widget.api.resetUserPassword(id, ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Password updated. Share it securely with the doctor.')),
      );
    }
  }

  Future<void> _bindDevice(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Bind device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Paste the Device ID shown on the doctor\'s login screen.'),
            SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Device ID'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, ctrl.text.trim()),
              child: const Text('Save')),
        ],
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
    final trimmed = result?.trim();
    ctrl.dispose();
    if (trimmed == null || trimmed.isEmpty) return;
    if (trimmed.length < 3 || trimmed.length > 128) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Device ID must be between 3 and 128 characters.')),
        );
      }
      return;
    }
    try {
      await widget.api.setUserDevice(id, trimmed);
      await _load();
      await widget.reloadDoctors();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Device ID saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to bind device.')),
        );
      }
    }
  }

  Future<void> _clearDeviceBinding(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    try {
      await widget.api.clearUserDevice(id);
      await _load();
      await widget.reloadDoctors();
      if (mounted) {
        final name = u['name'] as String? ?? 'Doctor';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Device binding cleared for $name.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to clear device.')),
        );
      }
    }
  }

  Future<void> _allowNewDevice(Map<String, dynamic> u) async {
    final name = u['name'] as String? ?? 'Doctor';
    final hasDevice = (u['hasDevice'] as bool? ?? false);
    final boundAt = _formatDeviceBound(u['deviceBoundAt'] as String?);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Allow a new device'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hasDevice
                  ? 'This will unlink the current device for $name. On the next login, the doctor will be prompted with a new Device ID to share with you.'
                  : '$name has not yet registered a device. Clearing will allow them to link the first device on their next login.',
            ),
            const SizedBox(height: 12),
            if (hasDevice)
              Text('Last linked: $boundAt',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            const Text(
                'Use this whenever a doctor upgrades or replaces their phone.'),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Allow new device'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _clearDeviceBinding(u);
    }
  }

  String _formatDeviceBound(String? iso) {
    if (iso == null || iso.isEmpty) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    final name = u['name'] as String? ?? 'this doctor';
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text(
            'This will permanently remove $name and their history will no longer appear in admin lists.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.deleteUser(id);
      await _load();
      await widget.reloadDoctors();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_users.isEmpty) return const Center(child: Text('No doctors'));
    final theme = Theme.of(context);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _users.length,
        itemBuilder: (_, i) {
          final u = _users[i];
          final active = (u['isActive'] as bool? ?? true);
          final hasDevice = (u['hasDevice'] as bool? ?? false);
          final deviceBoundAt =
              _formatDeviceBound(u['deviceBoundAt'] as String?);
          final email = u['email'] as String? ?? '';
          final name = u['name'] as String? ?? '';
          final statusColor =
              active ? Colors.green.shade700 : Colors.red.shade700;
          final statusBg = active ? Colors.green.shade50 : Colors.red.shade50;
          final deviceColor =
              hasDevice ? Colors.teal.shade600 : Colors.orange.shade700;
          final deviceBg =
              hasDevice ? Colors.teal.shade50 : Colors.orange.shade50;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              email,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(active ? 'Active' : 'Suspended'),
                        backgroundColor: statusBg,
                        avatar: Icon(
                            active
                                ? Icons.verified_user
                                : Icons.pause_circle_outline,
                            color: statusColor),
                        labelStyle: TextStyle(
                            color: statusColor, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                            color: deviceBg, shape: BoxShape.circle),
                        child: Icon(
                            hasDevice ? Icons.verified : Icons.devices_other,
                            color: deviceColor,
                            size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          hasDevice
                              ? 'Device registered${deviceBoundAt == '-' ? '' : ' on $deviceBoundAt'}'
                              : 'Awaiting first device registration',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _allowNewDevice(u),
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(
                            hasDevice ? 'Allow new device' : 'Allow device'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _bindDevice(u),
                        icon: const Icon(Icons.link),
                        label:
                            Text(hasDevice ? 'Update device' : 'Bind device'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _resetPassword(u),
                        icon: const Icon(Icons.password),
                        label: const Text('Reset password'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _toggleActive(u),
                        icon: Icon(
                            active ? Icons.visibility_off : Icons.visibility),
                        label:
                            Text(active ? 'Suspend access' : 'Enable access'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _delete(u),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Remove user'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DevicesManager extends StatefulWidget {
  final ApiClient api;
  const _DevicesManager({required this.api});

  @override
  State<_DevicesManager> createState() => _DevicesManagerState();
}

class _DevicesManagerState extends State<_DevicesManager> {
  List<Map<String, dynamic>> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await widget.api.listDevices();
      setState(() => _devices = list);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> d) async {
    final id = d['id'] as String;
    final next = !(d['isActive'] as bool? ?? true);
    await widget.api.updateDevice(id, isActive: next);
    await _load();
  }

  Future<void> _rename(Map<String, dynamic> d) async {
    final id = d['id'] as String;
    final ctrl = TextEditingController(text: d['name'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Device'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.updateDevice(id, name: ctrl.text.trim());
      await _load();
    }
  }

  Future<void> _relocate(Map<String, dynamic> d) async {
    final id = d['id'] as String;
    final ctrl = TextEditingController(text: d['location'] as String? ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Update Location'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Location')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.updateDevice(id, location: ctrl.text.trim());
      await _load();
    }
  }

  Future<void> _delete(Map<String, dynamic> d) async {
    final id = d['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Device?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.deleteDevice(id);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_devices.isEmpty) return const Center(child: Text('No devices'));
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _devices.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final d = _devices[i];
          final active = (d['isActive'] as bool? ?? true);
          return ListTile(
            title: Text(d['name'] as String? ?? ''),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Location: ${(d['location'] as String?) ?? '-'}'),
                Text('Key: ${(d['apiKey'] as String?) ?? '-'}'),
              ],
            ),
            isThreeLine: true,
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: active ? 'Disable' : 'Enable',
                  icon: Icon(active ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => _toggleActive(d),
                ),
                IconButton(
                  tooltip: 'Rename',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _rename(d),
                ),
                IconButton(
                  tooltip: 'Update location',
                  icon: const Icon(Icons.place),
                  onPressed: () => _relocate(d),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(d),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}








