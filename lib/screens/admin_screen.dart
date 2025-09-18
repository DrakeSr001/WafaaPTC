import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../services/file_utils.dart';
import '../services/token_storage.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});
  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient();

  // Doctors list (for per-doctor CSV)
  bool _loadingUsers = true;
  List<Map<String, dynamic>> _doctors = [];
  Map<String, dynamic>? _selectedDoctor;

  // Month selector
  late DateTime _selectedMonth;

  // Busy flags
  bool _busy = false;
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
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
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
    if (picked != null) setState(() => _selectedMonth = DateTime(picked.year, picked.month, 1));
  }

  Future<void> _exportDoctorCsv() async {
    if (_busy || _selectedDoctor == null) return;
    setState(() => _busy = true);
    try {
      final uid = _selectedDoctor!['id'] as String;
      final y = _selectedMonth.year, m = _selectedMonth.month;
      final csv = await _api.doctorMonthCsv(userId: uid, year: y, month: m);
      final mm = m.toString().padLeft(2, '0');
      final namePart = (_selectedDoctor!['name'] as String).replaceAll(' ', '_');
      final path = await saveTextFile('doctor-$namePart-$y-$mm.csv', csv);
      await Share.shareXFiles([XFile(path)], text: 'Doctor $namePart $mm/$y');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportClinicCsv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final y = _selectedMonth.year, m = _selectedMonth.month;
      final csv = await _api.clinicMonthCsv(year: y, month: m);
      final mm = m.toString().padLeft(2, '0');
      final path = await saveTextFile('clinic-$y-$mm.csv', csv);
      await Share.shareXFiles([XFile(path)], text: 'Clinic $mm/$y');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout() async {
    await TokenStorage.clear();
    if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
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
        location: _deviceLocation.text.trim().isEmpty ? null : _deviceLocation.text.trim(),
      );
      final apiKey = res['apiKey'] as String? ?? '';
      _deviceName.clear();
      _deviceLocation.clear();
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Device Created'),
          content: SelectableText('API Key:\n$apiKey\n\nCopy this into the kiosk app config.dart'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
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
        title: Text('Admin — $header'),
        bottom: const TabBar(
          tabs: [
            Tab(icon: Icon(Icons.download), text: 'Exports'),
            Tab(icon: Icon(Icons.person_add), text: 'Create User'),
            Tab(icon: Icon(Icons.devices_other), text: 'Create Device'),
            Tab(icon: Icon(Icons.manage_accounts), text: 'Manage'), // NEW
          ],
        ),
        actions: [
          IconButton(onPressed: _pickMonth, icon: const Icon(Icons.calendar_month), tooltip: 'Pick Month'),
          IconButton(onPressed: _loadingUsers ? null : _loadDoctors, icon: const Icon(Icons.refresh), tooltip: 'Refresh Doctors'),
          IconButton(onPressed: _logout, icon: const Icon(Icons.logout), tooltip: 'Logout'),
        ],
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // ======== Tab 1: Exports ========
          Padding(
            padding: const EdgeInsets.all(16),
            child: _loadingUsers
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Doctor', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButton<Map<String, dynamic>>(
                        isExpanded: true,
                        value: _selectedDoctor,
                        items: _doctors.map((d) {
                          return DropdownMenuItem(
                            value: d,
                            child: Text('${d['name']}  (${d['email']})'),
                          );
                        }).toList(),
                        onChanged: (v) => setState(() => _selectedDoctor = v),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: (_selectedDoctor == null || _busy) ? null : _exportDoctorCsv,
                            icon: const Icon(Icons.file_download),
                            label: const Text('Export Doctor CSV'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _busy ? null : _exportClinicCsv,
                            icon: const Icon(Icons.file_download_done),
                            label: const Text('Export Clinic CSV'),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          // ======== Tab 2: Create User ========
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _userForm,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Create User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _fullName,
                    decoration: const InputDecoration(labelText: 'Full name'),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a valid name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Min 6 characters' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text('Role:'),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _role,
                        items: const [
                          DropdownMenuItem(value: 'doctor', child: Text('Doctor')),
                          DropdownMenuItem(value: 'admin', child: Text('Admin')),
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
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
                  const Text('Create Device', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deviceName,
                    decoration: const InputDecoration(labelText: 'Device name'),
                    validator: (v) => (v == null || v.trim().length < 2) ? 'Enter a valid name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _deviceLocation,
                    decoration: const InputDecoration(labelText: 'Location (optional)'),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _creatingDevice ? null : _submitCreateDevice,
                      icon: _creatingDevice
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
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
  final Future<void> Function() reloadDoctors; // to refresh dropdown on Admin Exports tab
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
      final doctors = await widget.api.listDoctors(); // only doctors; adjust if you want admins too
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
  }

  Future<void> _resetPassword(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    final ctrl = TextEditingController(text: 'Password123!');
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Set')),
        ],
      ),
    );
    if (ok == true) {
      await widget.api.resetUserPassword(id, ctrl.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated.')));
    }
  }

  Future<void> _delete(Map<String, dynamic> u) async {
    final id = u['id'] as String;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        itemCount: _users.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final u = _users[i];
          final active = (u['isActive'] as bool? ?? true);
          return ListTile(
            title: Text(u['name'] as String? ?? ''),
            subtitle: Text(u['email'] as String? ?? ''),
            trailing: Wrap(
              spacing: 8,
              children: [
                IconButton(
                  tooltip: active ? 'Disable' : 'Enable',
                  icon: Icon(active ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => _toggleActive(u),
                ),
                IconButton(
                  tooltip: 'Reset password',
                  icon: const Icon(Icons.password),
                  onPressed: () => _resetPassword(u),
                ),
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(u),
                ),
              ],
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
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
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
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Location')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
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
            subtitle: Text('Location: ${(d['location'] as String?) ?? '—'}\nKey: ${(d['apiKey'] as String?) ?? '—'}'),
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
