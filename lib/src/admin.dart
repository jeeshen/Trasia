part of '../main.dart';

enum _AdminView { dashboard, drivers, users, vouchers }

class AdminPanel extends StatefulWidget {
  const AdminPanel({
    required this.profile,
    required this.onLogout,
    super.key,
  });

  final AuthProfile profile;
  final Future<void> Function(BuildContext context) onLogout;

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  _AdminView _currentView = _AdminView.dashboard;
  late AuthProfile _currentProfile;

  @override
  void initState() {
    super.initState();
    _currentProfile = widget.profile;
  }

  Future<void> _refreshProfile() async {
    final updated = await const AuthService().currentProfile();
    if (updated != null && mounted) {
      setState(() => _currentProfile = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TrasiaColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        snackBarTheme: _trasiaSnackBarTheme,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentView == _AdminView.dashboard 
                ? 'Admin Dashboard' 
                : _currentView == _AdminView.drivers 
                    ? 'Manage Drivers'
                    : _currentView == _AdminView.users
                        ? 'Manage Users'
                        : 'Manage Vouchers',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF102033)),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: const IconThemeData(color: Color(0xFF93A1B2)),
          leading: _currentView != _AdminView.dashboard
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => setState(() => _currentView = _AdminView.dashboard),
                )
              : null,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: 'Logout',
              onPressed: () => widget.onLogout(context),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case _AdminView.dashboard:
        return _AdminDashboardView(
          profile: _currentProfile,
          onNavigate: (view) => setState(() => _currentView = view),
          onProfileRefresh: _refreshProfile,
        );
      case _AdminView.drivers:
        return const _AdminDriversView();
      case _AdminView.users:
        return const _AdminUsersView();
      case _AdminView.vouchers:
        return const _AdminVouchersView();
    }
  }
}

class _AdminDashboardView extends StatefulWidget {
  const _AdminDashboardView({
    required this.profile, 
    required this.onNavigate,
    required this.onProfileRefresh,
  });
  final AuthProfile profile;
  final ValueChanged<_AdminView> onNavigate;
  final Future<void> Function() onProfileRefresh;

  @override
  State<_AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<_AdminDashboardView> {
  bool _loading = true;
  int _driversCount = 0;
  int _usersCount = 0;
  int _vouchersCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }

  Future<void> _fetchCounts() async {
    if (!SupabaseConfig.isReady) return;
    try {
      final res = await Supabase.instance.client.rpc('admin_get_dashboard_counts');
      
      if (mounted) {
        setState(() {
          _driversCount = (res['drivers'] as num?)?.toInt() ?? 0;
          _usersCount = (res['users'] as num?)?.toInt() ?? 0;
          _vouchersCount = (res['vouchers'] as num?)?.toInt() ?? 0;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 800;
        return GridView.count(
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isDesktop ? 3 : (constraints.maxWidth > 600 ? 2 : 1),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: isDesktop ? 1.5 : (constraints.maxWidth > 600 ? 1.2 : 2.0),
          children: [
            _DashboardCard(
              title: 'Drivers',
              description: 'Manage all drivers stored in the Supabase table: drivers',
              count: _driversCount,
              icon: Icons.directions_car_rounded,
              color: Theme.of(context).colorScheme.primary,
              onTap: () => widget.onNavigate(_AdminView.drivers),
            ),
            _DashboardCard(
              title: 'Users',
              description: 'Manage all application users stored in: profiles',
              count: _usersCount,
              icon: Icons.people_outline_rounded,
              color: Theme.of(context).colorScheme.secondary,
              onTap: () => widget.onNavigate(_AdminView.users),
            ),
            _DashboardCard(
              title: 'Vouchers',
              description: 'Manage all vouchers stored in: vouchers',
              count: _vouchersCount,
              icon: Icons.local_activity_outlined,
              color: Theme.of(context).colorScheme.tertiary,
              onTap: () => widget.onNavigate(_AdminView.vouchers),
            ),
            _DashboardCard(
              title: 'Profile',
              description: 'Manage your administrator account',
              count: null,
              icon: Icons.person_rounded,
              color: Colors.blueGrey,
              onTap: () async {
                showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
                await widget.onProfileRefresh();
                if (!context.mounted) return;
                Navigator.of(context).pop();

                Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (context) => _SettingsPage(
                    currentUsername: widget.profile.username,
                    onUsernameChanged: (_) => widget.onProfileRefresh(),
                    onEmailChanged: (_) => widget.onProfileRefresh(),
                  ),
                ));
              },
            ),
          ],
        );
      },
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.description,
    required this.count,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final int? count;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE0E7F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .14),
                  foregroundColor: color,
                  radius: 24,
                  child: Icon(icon, size: 28),
                ),
                const Spacer(),
                if (count != null)
                  Text(
                    count.toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF102033),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF102033),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF68788C),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// DRIVERS MANAGEMENT
// ----------------------------------------------------------------------

class _AdminDriversView extends StatefulWidget {
  const _AdminDriversView();

  @override
  State<_AdminDriversView> createState() => _AdminDriversViewState();
}

class _AdminDriversViewState extends State<_AdminDriversView> {
  bool _loading = true;
  String _searchQuery = '';
  bool _sortAscending = true;
  List<Map<String, dynamic>> _drivers = [];

  @override
  void initState() {
    super.initState();
    _fetchDrivers();
  }

  Future<void> _fetchDrivers() async {
    if (!SupabaseConfig.isReady) return;
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .rpc('admin_get_drivers', params: {
            'p_search_query': _searchQuery,
            'p_sort_asc': _sortAscending,
          });
      if (mounted) {
        setState(() {
          _drivers = List<Map<String, dynamic>>.from(response as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading drivers: $e')));
      }
    }
  }

  void _onSortChanged(bool ascending) {
    setState(() {
      _sortAscending = ascending;
      _fetchDrivers();
    });
  }

  Future<void> _deleteDriver(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Driver'),
        content: const Text('Are you sure you want to delete this driver?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.rpc('admin_delete_driver', params: {'p_id': id});
        _fetchDrivers();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showDriverForm([Map<String, dynamic>? driver]) async {
    final isEditing = driver != null;
    final nameCtrl = TextEditingController(text: driver?['name']);
    final vehicleCtrl = TextEditingController(text: driver?['vehicle']);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEditing ? 'Edit Driver' : 'Add Driver', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF102033))),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Driver Name',
                        filled: true,
                        fillColor: const Color(0xFFF2F6FB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: vehicleCtrl,
                      decoration: InputDecoration(
                        labelText: 'Vehicle Details',
                        filled: true,
                        fillColor: const Color(0xFFF2F6FB),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Vehicle is required' : null,
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF68788C)),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              FilledButton(
                onPressed: saving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  
                  setState(() => saving = true);
                  final name = nameCtrl.text.trim();
                  final vehicle = vehicleCtrl.text.trim();
                  
                  try {
                    if (isEditing) {
                      await Supabase.instance.client.rpc('admin_update_driver', params: {
                        'p_id': driver['id'],
                        'p_name': name,
                        'p_vehicle': vehicle,
                      });
                    } else {
                      final rnd = Random();
                      
                      final ratings = [4.5, 4.6, 4.7, 4.8, 4.9, 5.0];
                      final rating = ratings[rnd.nextInt(ratings.length)];
                      
                      final colors = ['0xFF00E2A7', '0xFFFFCE3D', '0xFF40A9FF'];
                      final color = colors[rnd.nextInt(colors.length)];
                      
                      final lat = 3.0000 + rnd.nextDouble() * 0.2500;
                      final lng = 101.6000 + rnd.nextDouble() * 0.3000;
                      
                      await Supabase.instance.client.rpc('admin_add_driver', params: {
                        'p_name': name,
                        'p_vehicle': vehicle,
                        'p_rating': rating,
                        'p_color': color,
                        'p_lat': double.parse(lat.toStringAsFixed(4)),
                        'p_lng': double.parse(lng.toStringAsFixed(4)),
                      });
                    }
                    if (mounted) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEditing ? 'Driver updated successfully' : 'Driver added successfully')));
                      _fetchDrivers();
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: TrasiaColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: saving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        }
      ),
    );
    } finally {
      nameCtrl.dispose();
      vehicleCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _drivers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by name',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF93A1B2), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF2F6FB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(color: Color(0xFF102033)),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _fetchDrivers();
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6FB),
                borderRadius: BorderRadius.circular(99),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                  value: _sortAscending,
                  icon: const Icon(Icons.sort_rounded, color: Color(0xFF93A1B2), size: 18),
                  style: const TextStyle(color: Color(0xFF102033), fontWeight: FontWeight.w700),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('A-Z')),
                    DropdownMenuItem(value: false, child: Text('Z-A')),
                  ],
                  onChanged: (val) => _onSortChanged(val ?? true),
                ),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showDriverForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                backgroundColor: TrasiaColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDrivers,
            child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty 
                    ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No drivers found.', style: TextStyle(color: Color(0xFF68788C)))))])
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final d = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE1EAF5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: TrasiaColors.primary.withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.directions_car_rounded, color: TrasiaColors.primary, size: 21),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Color(0xFF102033),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${d['vehicle'] ?? 'No vehicle'} • ${d['rating'] ?? 'N/A'}',
                                        style: const TextStyle(color: Color(0xFF68788C), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF93A1B2)),
                                  onPressed: () => _showDriverForm(d),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFD63C3C)),
                                  onPressed: () => _deleteDriver(d['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// USERS MANAGEMENT
// ----------------------------------------------------------------------

class _AdminUsersView extends StatefulWidget {
  const _AdminUsersView();

  @override
  State<_AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<_AdminUsersView> {
  bool _loading = true;
  String _searchQuery = '';
  bool _sortAscending = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  List<Map<String, dynamic>> _profiles = [];
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers({bool refresh = false}) async {
    if (!SupabaseConfig.isReady) return;
    if (refresh) {
      _currentPage = 0;
      _profiles.clear();
      _hasMore = true;
    }
    if (!_hasMore) return;

    setState(() => _loading = true);
    try {
      final from = _currentPage * _pageSize;
      final to = from + _pageSize - 1;
      
      final response = await Supabase.instance.client
          .rpc('admin_get_users', params: {
            'p_search_query': _searchQuery,
            'p_offset': from,
            'p_limit': _pageSize,
            'p_sort_asc': _sortAscending,
          });
      
      final data = List<Map<String, dynamic>>.from(response as List);
      if (mounted) {
        setState(() {
          _profiles.addAll(data);
          _hasMore = data.length == _pageSize;
          _currentPage++;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading profiles: $e')));
      }
    }
  }
  Future<void> _deleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: const Text('Are you sure? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.rpc('admin_delete_user', params: {'p_user_id': id});
        _fetchUsers(refresh: true);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting user: $e')));
      }
    }
  }

  void _showUserForm(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) {
        String role = user['role'] ?? 'user';
        bool saving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit User Role', style: TextStyle(fontWeight: FontWeight.w900)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Username', style: TextStyle(color: Color(0xFF68788C), fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(user['username'] ?? 'Unknown', style: const TextStyle(color: Color(0xFF102033), fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    const Text('Email Address', style: TextStyle(color: Color(0xFF68788C), fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(user['email'] ?? 'Unknown', style: const TextStyle(color: Color(0xFF102033), fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 24),
                    const Text('Account Role', style: TextStyle(color: Color(0xFF68788C), fontSize: 13, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'user', label: Text('User')),
                        ButtonSegment(value: 'admin', label: Text('Admin')),
                      ],
                      selected: {role},
                      onSelectionChanged: (Set<String> newSelection) {
                        setDialogState(() => role = newSelection.first);
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white,
                        selectedBackgroundColor: const Color(0xFFF2F6FB),
                        selectedForegroundColor: TrasiaColors.primary,
                        side: const BorderSide(color: Color(0xFFE1EAF5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF68788C)),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving ? null : () async {
                    setDialogState(() => saving = true);
                    try {
                      await Supabase.instance.client.rpc('admin_update_user_role', params: {
                        'p_user_id': user['id'],
                        'p_role': role,
                      });
                      
                      final currentUserId = Supabase.instance.client.auth.currentUser?.id;
                      final isSelf = user['id'] == currentUserId;
                      final wasAdmin = user['role'] == 'admin';
                      final isNewRoleUser = role == 'user';

                      if (isSelf && wasAdmin && isNewRoleUser) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Your administrator privileges have been removed. Please sign in again.')),
                          );
                        }
                        await Supabase.instance.client.auth.signOut();
                        if (mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                            (_) => false,
                          );
                        }
                      } else {
                        if (mounted) {
                          Navigator.of(context).pop();
                          _fetchUsers(refresh: true);
                        }
                      }
                    } catch (e) {
                      if (mounted) {
                        setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: TrasiaColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  ),
                  child: saving 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onSortChanged(bool ascending) {
    setState(() => _sortAscending = ascending);
    _fetchUsers(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _profiles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by username or email',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF93A1B2), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF2F6FB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(color: Color(0xFF102033)),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _fetchUsers(refresh: true);
                },
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6FB),
                borderRadius: BorderRadius.circular(99),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<bool>(
                  value: _sortAscending,
                  icon: const Icon(Icons.sort_rounded, color: Color(0xFF93A1B2), size: 18),
                  style: const TextStyle(color: Color(0xFF102033), fontWeight: FontWeight.w700),
                  items: const [
                    DropdownMenuItem(value: true, child: Text('A-Z')),
                    DropdownMenuItem(value: false, child: Text('Z-A')),
                  ],
                  onChanged: (val) => _onSortChanged(val ?? true),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchUsers(refresh: true),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No users found.', style: TextStyle(color: Color(0xFF68788C)))))])
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filtered.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == filtered.length) {
                            if (!_loading) {
                              Future.microtask(() => _fetchUsers());
                            }
                            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator()));
                          }
                          final p = filtered[index];
                          final isAdmin = p['role'] == 'admin';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE1EAF5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: (isAdmin ? const Color(0xFF00A86B) : TrasiaColors.primary).withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded, color: isAdmin ? const Color(0xFF00A86B) : TrasiaColors.primary, size: 21),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        (p['username'] != null && p['username'].toString().trim().isNotEmpty) 
                                            ? p['username'] 
                                            : 'Not Set',
                                        style: const TextStyle(
                                          color: Color(0xFF102033),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${p['role']} • ${p['email'] ?? 'Unknown'}',
                                        style: const TextStyle(color: Color(0xFF68788C), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF93A1B2)),
                                  onPressed: () => _showUserForm(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFD63C3C)),
                                  onPressed: () => _deleteUser(p['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------------
// VOUCHERS MANAGEMENT
// ----------------------------------------------------------------------

class _AdminVouchersView extends StatefulWidget {
  const _AdminVouchersView();

  @override
  State<_AdminVouchersView> createState() => _AdminVouchersViewState();
}

class _AdminVouchersViewState extends State<_AdminVouchersView> {
  bool _loading = true;
  String _searchQuery = '';
  List<Map<String, dynamic>> _vouchers = [];

  @override
  void initState() {
    super.initState();
    _fetchVouchers();
  }

  Future<void> _fetchVouchers() async {
    if (!SupabaseConfig.isReady) return;
    setState(() => _loading = true);
    try {
      final response = await Supabase.instance.client
          .rpc('admin_get_vouchers', params: {
            'p_search_query': _searchQuery,
          });
      if (mounted) {
        setState(() {
          _vouchers = List<Map<String, dynamic>>.from(response as List);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading vouchers: $e')));
      }
    }
  }

  Future<void> _deleteVoucher(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Voucher'),
        content: const Text('Are you sure you want to delete this voucher?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.rpc('admin_delete_voucher', params: {'p_id': id});
        _fetchVouchers();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showVoucherForm([Map<String, dynamic>? voucher]) async {
    final titleCtrl = TextEditingController(text: voucher?['title']);
    final descCtrl = TextEditingController(text: voucher?['description']);
    final costCtrl = TextEditingController(text: voucher?['point_cost']?.toString());
    final creditCtrl = TextEditingController(text: voucher?['hub_pool_credit']?.toString());
    final iconCtrl = TextEditingController(text: voucher?['icon'] ?? 'local_offer');

    try {
      final result = await showDialog<bool>(
        context: context,
      builder: (context) => AlertDialog(
        title: Text(voucher == null ? 'Add Voucher' : 'Edit Voucher'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Point Cost', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: creditCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Credit Value (RM)', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              TextField(controller: iconCtrl, decoration: const InputDecoration(labelText: 'Icon Name (e.g. local_offer)', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true && titleCtrl.text.isNotEmpty) {
      try {
        final data = {
          'title': titleCtrl.text,
          'description': descCtrl.text,
          'point_cost': int.tryParse(costCtrl.text) ?? 0,
          'hub_pool_credit': double.tryParse(creditCtrl.text) ?? 0.0,
          'icon': iconCtrl.text,
          'kind': voucher?['kind'] ?? 'discount',
          'accent_color': voucher?['accent_color'] ?? '#0B7CFF',
        };
        if (voucher == null) {
          await Supabase.instance.client.rpc('admin_add_voucher', params: {
            'p_id': 'voucher-${DateTime.now().millisecondsSinceEpoch}',
            'p_title': titleCtrl.text,
            'p_description': descCtrl.text,
            'p_point_cost': int.tryParse(costCtrl.text) ?? 0,
            'p_hub_pool_credit': double.tryParse(creditCtrl.text) ?? 0.0,
            'p_icon': iconCtrl.text,
            'p_kind': voucher?['kind'] ?? 'discount',
            'p_accent_color': voucher?['accent_color'] ?? '#0B7CFF',
          });
        } else {
          await Supabase.instance.client.rpc('admin_update_voucher', params: {
            'p_id': voucher['id'],
            'p_title': titleCtrl.text,
            'p_description': descCtrl.text,
            'p_point_cost': int.tryParse(costCtrl.text) ?? 0,
            'p_hub_pool_credit': double.tryParse(creditCtrl.text) ?? 0.0,
            'p_icon': iconCtrl.text,
            'p_kind': voucher?['kind'] ?? 'discount',
            'p_accent_color': voucher?['accent_color'] ?? '#0B7CFF',
          });
        }
        _fetchVouchers();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
    } finally {
      titleCtrl.dispose();
      descCtrl.dispose();
      costCtrl.dispose();
      creditCtrl.dispose();
      iconCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _vouchers;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search by title',
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF93A1B2), size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF2F6FB),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: BorderSide.none),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                style: const TextStyle(color: Color(0xFF102033)),
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _fetchVouchers();
                },
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: () => _showVoucherForm(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
              style: FilledButton.styleFrom(
                backgroundColor: TrasiaColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchVouchers,
            child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty 
                    ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No vouchers found.', style: TextStyle(color: Color(0xFF68788C)))))])
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final v = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE1EAF5)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFA800).withValues(alpha: .12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.local_activity_rounded, color: Color(0xFFFFA800), size: 21),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v['title'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Color(0xFF102033),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${v['point_cost']} Points • RM ${v['hub_pool_credit']}',
                                        style: const TextStyle(color: Color(0xFF68788C), fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: Color(0xFF93A1B2)),
                                  onPressed: () => _showVoucherForm(v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFFD63C3C)),
                                  onPressed: () => _deleteVoucher(v['id']),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ],
    );
  }
}


