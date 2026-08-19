part of '../main.dart';
enum _AdminView { dashboard, drivers, vouchers, users, analytics, settings }
extension _AdminViewIndex on _AdminView {
  int get index => switch (this) {
    _AdminView.dashboard => 0,
    _AdminView.drivers => 1,
    _AdminView.vouchers => 2,
    _AdminView.users => 3,
    _AdminView.analytics => 4,
    _AdminView.settings => 5,
  };
}
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
  Widget _buildNavItem(IconData icon, String label, _AdminView view, int index) {
    final isSelected = _currentView == view;
    return Semantics(
      label: label,
      button: true,
      selected: isSelected,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          key: Key('nav-${label.toLowerCase()}'),
          onTap: () => setState(() => _currentView = view),
          behavior: HitTestBehavior.opaque,
          child: SizedBox(
            width: 50,
            height: 50,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                 return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                icon,
                key: ValueKey(isSelected),
                color: isSelected ? Colors.white : const Color(0xFF102033).withValues(alpha: 0.4),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    final pages = [
      _AdminDashboardView(
        key: _adminDashboardKey,
        profile: _currentProfile,
        onNavigate: (view) => setState(() => _currentView = view),
        onProfileRefresh: _refreshProfile,
        onLogout: () => widget.onLogout(context),
      ),
      const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _AdminDriversView(),
        ),
      ),
      const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _AdminVouchersView(),
        ),
      ),
      const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _AdminUsersView(),
        ),
      ),
      const SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: _AdminAnalyticsView(),
        ),
      ),
      _AdminSettingsView(
        profile: _currentProfile,
        onProfileRefresh: _refreshProfile,
        onLogout: () => widget.onLogout(context),
      ),
    ];
    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TrasiaColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9FC),
        useMaterial3: true,
        snackBarTheme: _trasiaSnackBarTheme,
      ),
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _currentView.index,
          children: pages,
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 72,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(40),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 24,
                        spreadRadius: -4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCirc,
                        left: _currentView.index * (50.0 + 8.0),
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0057C8),
                            borderRadius: BorderRadius.circular(25),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0057C8).withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              )
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildNavItem(Icons.dashboard_rounded, 'Dashboard', _AdminView.dashboard, 0),
                          const SizedBox(width: 8),
                          _buildNavItem(Icons.local_taxi_rounded, 'Drivers', _AdminView.drivers, 1),
                          const SizedBox(width: 8),
                          _buildNavItem(Icons.local_offer_rounded, 'Vouchers', _AdminView.vouchers, 2),
                          const SizedBox(width: 8),
                          _buildNavItem(Icons.people_alt_rounded, 'Users', _AdminView.users, 3),
                          const SizedBox(width: 8),
                          _buildNavItem(Icons.analytics_rounded, 'Analytics', _AdminView.analytics, 4),
                          const SizedBox(width: 8),
                          _buildNavItem(Icons.settings_rounded, 'Settings', _AdminView.settings, 5),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
final GlobalKey<_AdminDashboardViewState> _adminDashboardKey = GlobalKey<_AdminDashboardViewState>();
class _AdminDashboardView extends StatefulWidget {
  const _AdminDashboardView({
    super.key,
    required this.profile, 
    required this.onNavigate,
    required this.onProfileRefresh,
    required this.onLogout,
  });
  final AuthProfile profile;
  final ValueChanged<_AdminView> onNavigate;
  final Future<void> Function() onProfileRefresh;
  final VoidCallback onLogout;
  @override
  State<_AdminDashboardView> createState() => _AdminDashboardViewState();
}
class _AdminDashboardViewState extends State<_AdminDashboardView> {
  bool _loading = true;
  int _usersCount = 0;
  int? _newUsersCount;
  int _driversCount = 0;
  int? _newDriversCount;
  int _vouchersCount = 0;
  int? _newVouchersCount;
  int _adminsCount = 0;
  @override
  void initState() {
    super.initState();
    _fetchCounts();
  }
  Future<void> _fetchCounts() async {
    if (!SupabaseConfig.isReady) return;
    setState(() => _loading = true);
    List<dynamic> usersRes = [];
    List<dynamic> adminsRes = [];
    List<dynamic> driversRes = [];
    List<dynamic> vouchersRes = [];
    try {
      final res = await Supabase.instance.client.rpc('admin_get_users', params: {
        'p_search_query': '',
        'p_offset': 0,
        'p_limit': 10000,
        'p_sort_asc': true
      });
      final allProfiles = List<dynamic>.from(res as List);
      usersRes = allProfiles.where((u) => u['role'] == 'user').toList();
      adminsRes = allProfiles.where((u) => u['role'] == 'admin').toList();
    } catch (e) {
      debugPrint('Error fetching profiles: $e');
    }
    try {
      driversRes = await Supabase.instance.client.from('drivers').select();
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
    }
    try {
      vouchersRes = await Supabase.instance.client.from('vouchers').select();
    } catch (e) {
      debugPrint('Error fetching vouchers: $e');
    }
    try {
      final now = DateTime.now();
      final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      int uCount = usersRes.length;
      int uNewCount = usersRes.where((u) {
        if (u['created_at'] == null) return false;
        final date = DateTime.tryParse(u['created_at']);
        return date != null && (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek));
      }).length;
      int dCount = driversRes.length;
      int dNewCount = driversRes.where((d) {
        if (d['created_at'] == null) return false;
        final date = DateTime.tryParse(d['created_at']);
        return date != null && (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek));
      }).length;
      int vCount = vouchersRes.length;
      int vNewCount = vouchersRes.where((v) {
        if (v['created_at'] == null) return false;
        final date = DateTime.tryParse(v['created_at']);
        return date != null && (date.isAfter(startOfWeek) || date.isAtSameMomentAs(startOfWeek));
      }).length;
      int aCount = adminsRes.length;
      if (mounted) {
        setState(() {
          _usersCount = uCount;
          _newUsersCount = uNewCount;
          _driversCount = dCount;
          _newDriversCount = dNewCount;
          _vouchersCount = vCount;
          _newVouchersCount = vNewCount;
          _adminsCount = aCount;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error computing stats: $e');
      if (mounted) setState(() => _loading = false);
    }
  }
  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Good Morning, Admin';
    if (hour >= 12 && hour < 18) return 'Good Afternoon, Admin';
    return 'Good Evening, Admin';
  }
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0057C8)));
    }
    final statCards = [
      _SaasStatCard(
        countText: _usersCount.toString(),
        labelText: _usersCount == 1 ? 'User' : 'Users',
        change: _newUsersCount == null ? null : '+${_newUsersCount} ${_newUsersCount == 1 ? 'user' : 'users'} this week',
        icon: Icons.people_alt_rounded,
        color: const Color(0xFF3B82F6),
      ),
      _SaasStatCard(
        countText: _driversCount.toString(),
        labelText: _driversCount == 1 ? 'Driver' : 'Drivers',
        change: _newDriversCount == null ? null : '+${_newDriversCount} ${_newDriversCount == 1 ? 'driver' : 'drivers'} this week',
        icon: Icons.local_taxi_rounded,
        color: const Color(0xFFF97316),
      ),
      _SaasStatCard(
        countText: _vouchersCount.toString(),
        labelText: _vouchersCount == 1 ? 'Voucher' : 'Vouchers',
        change: _newVouchersCount == null ? null : '+${_newVouchersCount} ${_newVouchersCount == 1 ? 'voucher' : 'vouchers'} this week',
        icon: Icons.local_offer_rounded,
        color: const Color(0xFF10B981),
      ),
      _SaasStatCard(
        countText: _adminsCount.toString(),
        labelText: _adminsCount == 1 ? 'Admin' : 'Admins',
        change: null, 
        icon: Icons.admin_panel_settings_rounded,
        color: const Color(0xFFEF4444),
      ),
    ];
    final actionCards = [
      _SaasActionCard(
        title: 'Manage Drivers',
        description: 'Manage all registered drivers.',
        icon: Icons.local_taxi_rounded,
        onTap: () => widget.onNavigate(_AdminView.drivers)
      ),
      _SaasActionCard(
        title: 'Manage Vouchers',
        description: 'Create and manage rewards.',
        icon: Icons.local_offer_rounded,
        onTap: () => widget.onNavigate(_AdminView.vouchers)
      ),
      _SaasActionCard(
        title: 'Manage Users',
        description: 'View registered users.',
        icon: Icons.people_alt_rounded,
        onTap: () => widget.onNavigate(_AdminView.users)
      ),
      _SaasActionCard(
        title: 'Analytics',
        description: 'View platform reports.',
        icon: Icons.bar_chart_rounded,
        onTap: () => widget.onNavigate(_AdminView.analytics)
      ),
    ];
    return ListView(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF0057C8),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: const Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getGreeting(),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937), letterSpacing: -0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: statCards[0]),
              const SizedBox(width: 24),
              Expanded(child: statCards[1]),
            ],
          ),
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: statCards[2]),
              const SizedBox(width: 24),
              Expanded(child: statCards[3]),
            ],
          ),
        ),
        const SizedBox(height: 48),
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 16),
        actionCards[0],
        const SizedBox(height: 16),
        actionCards[1],
        const SizedBox(height: 16),
        actionCards[2],
        const SizedBox(height: 16),
        actionCards[3],
      ],
    );
  }
}
class _SaasStatCard extends StatelessWidget {
  final String countText;
  final String labelText;
  final String? change;
  final IconData icon;
  final Color color;
  const _SaasStatCard({required this.countText, required this.labelText, this.change, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 16),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$countText ',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF1F2937), letterSpacing: -0.5),
                ),
                TextSpan(
                  text: labelText,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF4B5563), letterSpacing: -0.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            change ?? ' ',
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.w600, 
              color: change != null ? color : Colors.transparent
            ),
          ),
        ],
      ),
    );
  }
}
class _SaasActionCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  const _SaasActionCard({required this.title, required this.description, required this.icon, required this.onTap});
  @override
  State<_SaasActionCard> createState() => _SaasActionCardState();
}
class _SaasActionCardState extends State<_SaasActionCard> {
  bool _isHovered = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _isHovered ? const Color(0xFF0057C8).withValues(alpha: .3) : const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: _isHovered ? const Color(0xFF0057C8).withValues(alpha: .1) : Colors.black.withValues(alpha: .03),
              blurRadius: _isHovered ? 16 : 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(widget.icon, size: 32, color: const Color(0xFF0057C8)),
                  const SizedBox(height: 20),
                  Text(
                    widget.title,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.description,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280), height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Spacer(),
                      AnimatedPadding(
                        duration: const Duration(milliseconds: 200),
                        padding: EdgeInsets.only(right: _isHovered ? 0.0 : 4.0),
                        child: const Icon(Icons.chevron_right_rounded, color: Color(0xFF0057C8), size: 24),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _AdminDriversView extends StatefulWidget {
  const _AdminDriversView();
  @override
  State<_AdminDriversView> createState() => _AdminDriversViewState();
}
class _DriverFormDialog extends StatefulWidget {
  final Map<String, dynamic>? driver;
  const _DriverFormDialog({this.driver});
  @override
  State<_DriverFormDialog> createState() => _DriverFormDialogState();
}
class _DriverFormDialogState extends State<_DriverFormDialog> with SingleTickerProviderStateMixin {
  late final TextEditingController nameCtrl;
  late final TextEditingController vehicleCtrl;
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: widget.driver?['name']);
    vehicleCtrl = TextEditingController(text: widget.driver?['vehicle']);
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }
  @override
  void dispose() {
    _animController.dispose();
    nameCtrl.dispose();
    vehicleCtrl.dispose();
    super.dispose();
  }
  Future<void> _save() async {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final name = nameCtrl.text.trim();
    final vehicle = vehicleCtrl.text.trim();
    try {
      if (widget.driver != null) {
        await Supabase.instance.client.rpc('admin_update_driver', params: {
          'p_id': widget.driver!['id'],
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.driver != null ? 'Driver updated successfully' : 'Driver added successfully')));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 22),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF0057C8), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.driver != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing ? 'Edit Driver' : 'Add Driver',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEditing ? 'Update the driver\'s information.' : 'Create a new driver profile.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildTextField(
                    controller: nameCtrl,
                    label: 'Driver Name',
                    hint: 'Enter driver name',
                    icon: Icons.person_outline,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: vehicleCtrl,
                    label: 'Vehicle',
                    hint: 'e.g. BYD Dolphin',
                    icon: Icons.directions_car_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Vehicle is required' : null,
                  ),
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0057C8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: saving 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        _adminDashboardKey.currentState?._fetchCounts();
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
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DriverFormDialog(driver: driver),
    );
    if (result == true) {
      _fetchDrivers();
    }
  }
  @override
  Widget build(BuildContext context) {
    final filtered = _drivers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Drivers', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF102033), letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Manage all registered drivers.', style: TextStyle(fontSize: 15, color: Color(0xFF68788C))),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search drivers by name or vehicle...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _fetchDrivers();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _showDriverForm(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0057C8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchDrivers,
            child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty 
                    ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No drivers found.', style: TextStyle(color: Color(0xFF6B7280)))))])
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final d = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F9FC),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.local_taxi_rounded, color: Color(0xFF0057C8), size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d['name'] ?? 'Unknown',
                                        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        d['vehicle'] ?? 'Unknown',
                                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF9CA3AF)),
                                  onPressed: () => _showDriverForm(d),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Color(0xFFF43F5E)),
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
        _adminDashboardKey.currentState?._fetchCounts();
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
        const Text('Users', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF102033), letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Manage registered users and admins.', style: TextStyle(fontSize: 15, color: Color(0xFF68788C))),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search users by username or email...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _fetchUsers(refresh: true);
                  },
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchUsers(refresh: true),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No users found.', style: TextStyle(color: Color(0xFF6B7280)))))])
                    : ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(bottom: 120),
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
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F9FC),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(isAdmin ? Icons.admin_panel_settings_rounded : Icons.person_rounded, color: const Color(0xFF0057C8), size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isAdmin 
                                          ? 'Admin'
                                          : ((p['username'] != null && p['username'].toString().trim().isNotEmpty) 
                                              ? p['username'] 
                                              : 'No Username'),
                                        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        p['email'] ?? 'Unknown',
                                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF9CA3AF)),
                                  onPressed: () => _showUserForm(p),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Color(0xFFF43F5E)),
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
class _AdminVouchersView extends StatefulWidget {
  const _AdminVouchersView();
  @override
  State<_AdminVouchersView> createState() => _AdminVouchersViewState();
}
class _VoucherFormDialog extends StatefulWidget {
  final Map<String, dynamic>? voucher;
  const _VoucherFormDialog({this.voucher});
  @override
  State<_VoucherFormDialog> createState() => _VoucherFormDialogState();
}
class _VoucherFormDialogState extends State<_VoucherFormDialog> with SingleTickerProviderStateMixin {
  late final TextEditingController titleCtrl;
  late final TextEditingController descCtrl;
  late final TextEditingController costCtrl;
  late final TextEditingController creditCtrl;
  final formKey = GlobalKey<FormState>();
  bool saving = false;
  String _kind = 'hubPool';
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    titleCtrl = TextEditingController(text: widget.voucher?['title']);
    descCtrl = TextEditingController(text: widget.voucher?['description']);
    costCtrl = TextEditingController(text: widget.voucher?['point_cost']?.toString());
    creditCtrl = TextEditingController(text: widget.voucher?['hub_pool_credit']?.toString());
    _kind = widget.voucher?['kind'] ?? 'hubPool';
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _scaleAnimation = CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic);
    _animController.forward();
  }
  @override
  void dispose() {
    _animController.dispose();
    titleCtrl.dispose();
    descCtrl.dispose();
    costCtrl.dispose();
    creditCtrl.dispose();
    super.dispose();
  }
  void _save() {
    if (!formKey.currentState!.validate()) return;
    setState(() => saving = true);
    final color = _kind == 'hubPool' ? '0xFF0057C8' : '0xFFE1251B';
    final iconName = _kind == 'hubPool' ? 'Icons.local_taxi_rounded' : 'Icons.restaurant_rounded';
    final creditValue = _kind == 'hubPool' ? creditCtrl.text.trim() : '0';
    Navigator.of(context).pop({
      'title': titleCtrl.text.trim(),
      'description': descCtrl.text.trim(),
      'point_cost': costCtrl.text.trim(),
      'hub_pool_credit': creditValue,
      'icon': iconName,
      'kind': _kind,
      'accent_color': color,
    });
  }
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF6B7280), fontSize: 16),
            prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 22),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF0057C8), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          ),
          validator: validator,
        ),
      ],
    );
  }
  PopupMenuItem<String> _buildPopupMenuItem(String value, String title, String emoji) {
    final isSelected = _kind == value;
    return PopupMenuItem<String>(
      value: value,
      padding: EdgeInsets.zero,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0057C8).withValues(alpha: .1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title, 
                style: TextStyle(
                  color: isSelected ? const Color(0xFF0057C8) : const Color(0xFF1A1A1A),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
            if (isSelected) const Icon(Icons.check_rounded, color: Color(0xFF0057C8), size: 20),
          ],
        ),
      ),
    );
  }
  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Voucher Type',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
        ),
        const SizedBox(height: 8),
        PopupMenuButton<String>(
          initialValue: _kind,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          elevation: 8,
          offset: const Offset(0, 64),
          onSelected: (String value) {
            setState(() {
              _kind = value;
            });
          },
          itemBuilder: (BuildContext context) => [
            _buildPopupMenuItem('hubPool', 'HubPool', '🚖'),
            _buildPopupMenuItem('kfc', 'KFC', '🍗'),
          ],
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_offer_outlined, color: Color(0xFF6B7280), size: 22),
                const SizedBox(width: 12),
                Text(
                  _kind == 'hubPool' ? '🚖 HubPool' : '🍗 KFC',
                  style: const TextStyle(fontSize: 16, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B7280)),
              ],
            ),
          ),
        ),
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    final isEditing = widget.voucher != null;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .12),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isEditing ? 'Edit Voucher' : 'Add Voucher',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isEditing ? 'Update the details of this reward voucher.' : 'Create a new reward voucher for users.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildTypeSelector(),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: titleCtrl,
                    label: 'Title',
                    hint: 'Enter voucher title',
                    icon: Icons.confirmation_number_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: descCtrl,
                    label: 'Description',
                    hint: 'Enter voucher description',
                    icon: Icons.description_outlined,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Description is required' : null,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: costCtrl,
                    label: 'Point Cost',
                    hint: 'e.g. 100',
                    icon: Icons.stars_outlined,
                    keyboardType: TextInputType.number,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Point Cost is required' : null,
                  ),
                  if (_kind == 'hubPool') ...[
                    const SizedBox(height: 20),
                    _buildTextField(
                      controller: creditCtrl,
                      label: 'Credit Value',
                      hint: 'e.g. 5',
                      icon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                      validator: (v) => v == null || v.trim().isEmpty ? 'Credit Value is required' : null,
                    ),
                  ],
                  const SizedBox(height: 36),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            onPressed: saving ? null : () => Navigator.of(context).pop(null),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: FilledButton(
                            onPressed: saving ? null : _save,
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF0057C8),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 0,
                            ),
                            child: saving 
                              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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
        _adminDashboardKey.currentState?._fetchCounts();
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
    final result = await showDialog<Map<String, String>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _VoucherFormDialog(voucher: voucher),
    );
    if (result != null && result['title']!.isNotEmpty) {
      try {
        if (voucher == null) {
          await Supabase.instance.client.rpc('admin_add_voucher', params: {
            'p_id': 'voucher-${DateTime.now().millisecondsSinceEpoch}',
            'p_title': result['title'],
            'p_description': result['description'],
            'p_point_cost': int.tryParse(result['point_cost']!) ?? 0,
            'p_hub_pool_credit': double.tryParse(result['hub_pool_credit']!) ?? 0.0,
            'p_icon': result['icon'],
            'p_kind': result['kind'],
            'p_accent_color': result['accent_color'],
          });
        } else {
          await Supabase.instance.client.rpc('admin_update_voucher', params: {
            'p_id': voucher['id'],
            'p_title': result['title'],
            'p_description': result['description'],
            'p_point_cost': int.tryParse(result['point_cost']!) ?? 0,
            'p_hub_pool_credit': double.tryParse(result['hub_pool_credit']!) ?? 0.0,
            'p_icon': result['icon'],
            'p_kind': result['kind'],
            'p_accent_color': result['accent_color'],
          });
        }
        await _RewardsData.load();
        _fetchVouchers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(voucher == null ? 'Voucher added successfully' : 'Voucher updated successfully'),
              backgroundColor: const Color(0xFF1CAF5E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final filtered = _vouchers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Vouchers', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF102033), letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Create and manage reward vouchers.', style: TextStyle(fontSize: 15, color: Color(0xFF68788C))),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(99),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search vouchers by title...',
                    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 15),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  style: const TextStyle(color: Color(0xFF1F2937)),
                  onChanged: (val) {
                    setState(() => _searchQuery = val);
                    _fetchVouchers();
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: () => _showVoucherForm(),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Add', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0057C8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchVouchers,
            child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty 
                    ? ListView(children: const [Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text('No vouchers found.', style: TextStyle(color: Color(0xFF6B7280)))))])
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 120),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final v = filtered[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: .03), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F9FC),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.local_offer_rounded, color: Color(0xFF10B981), size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v['title'] ?? 'Unknown',
                                        style: const TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${v['point_cost']} Points • RM ${v['hub_pool_credit']}',
                                        style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded, color: Color(0xFF9CA3AF)),
                                  onPressed: () => _showVoucherForm(v),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Color(0xFFF43F5E)),
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
class _AdminSettingsView extends StatelessWidget {
  final AuthProfile profile;
  final Future<void> Function() onProfileRefresh;
  final VoidCallback onLogout;
  const _AdminSettingsView({
    required this.profile,
    required this.onProfileRefresh,
    required this.onLogout,
  });
  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, top: 24, right: 24, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          ...children,
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  Widget _buildSettingsTile(IconData icon, String title, String subtitle, {VoidCallback? onTap, bool isDestructive = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDestructive ? const Color(0xFFF43F5E).withValues(alpha: 0.1) : const Color(0xFFF7F9FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: isDestructive ? const Color(0xFFF43F5E) : const Color(0xFF0057C8), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDestructive ? const Color(0xFFF43F5E) : const Color(0xFF1F2937))),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ],
                ),
              ),
              if (onTap != null && !isDestructive)
                const Icon(Icons.chevron_right_rounded, color: Color(0xFFD1D5DB)),
            ],
          ),
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF102033))),
                      SizedBox(height: 6),
                      Text('Manage your admin account and system preferences.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF68788C))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildSettingsGroup('Profile', [
              _buildSettingsTile(Icons.person_outline_rounded, 'Username', profile.username ?? 'Not set', onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => EditUsernamePage(currentUsername: profile.username),
                  ),
                );
                onProfileRefresh();
              }),
              const Divider(height: 1, color: Color(0xFFF3F4F6), indent: 80, endIndent: 24),
              _buildSettingsTile(Icons.email_outlined, 'Email Address', Supabase.instance.client.auth.currentUser?.email ?? 'Unknown', onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => EditEmailPage(currentEmail: Supabase.instance.client.auth.currentUser?.email),
                  ),
                );
                onProfileRefresh();
              }),
            ]),
            _buildSettingsGroup('Security', [
              _buildSettingsTile(Icons.lock_outline_rounded, 'Password', 'Change your password', onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const EditPasswordPage(),
                  ),
                );
              }),
            ]),
            _buildSettingsGroup('Account', [
              _buildSettingsTile(Icons.logout_rounded, 'Log Out', 'Sign out of admin panel', onTap: onLogout, isDestructive: true),
            ]),
          ],
        ),
      ),
    );
  }
}
