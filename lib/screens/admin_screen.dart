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

  Future<void> _exportClinicCsv() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final y = _selectedMonth.year, m = _selectedMonth.month;
      final csv = await _api.clinicMonthCsv(year: y, month: m);
      final mm = m.toString().padLeft(2, '0');
      await saveAndShareTextFile('clinic-$y-$mm.csv', csv);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Export failed.')));
    } finally {
      if (mounted) setState(() => _busy = false);
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: _loadingUsers
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Doctor',
                          style: TextStyle(fontWeight: FontWeight.bold)),
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
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          ElevatedButton.icon(
                            onPressed: (_selectedDoctor == null || _busy)
                                ? null
                                : _exportDoctorCsv,
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
