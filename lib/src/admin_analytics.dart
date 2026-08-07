part of '../main.dart';

class _AdminAnalyticsView extends StatefulWidget {
  const _AdminAnalyticsView({super.key});

  @override
  State<_AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<_AdminAnalyticsView> {
  int _section = 0; // 0: Users, 1: Drivers, 2: Vouchers
  bool _loading = true;
  String? _error;

  late DateTime _selectedWeekStart;

  // Data
  List<dynamic> _users = [];
  List<dynamic> _admins = [];
  List<dynamic> _drivers = [];
  List<dynamic> _vouchers = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    _fetchAnalytics();
  }

  Future<void> _showWeekPickerBottomSheet() async {
    final DateTime? newWeek = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return _WeekPickerSheet(currentWeekStart: _selectedWeekStart);
      }
    );

    if (newWeek != null && newWeek != _selectedWeekStart) {
      setState(() {
        _selectedWeekStart = newWeek;
      });
      _fetchAnalytics();
    }
  }

  Widget _buildWeekPickerTitle(String prefix) {
    final end = _selectedWeekStart.add(const Duration(days: 6));
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final startStr = '${_selectedWeekStart.day.toString().padLeft(2, '0')} ${months[_selectedWeekStart.month - 1]} ${_selectedWeekStart.year}';
    final endStr = '${end.day.toString().padLeft(2, '0')} ${months[end.month - 1]} ${end.year}';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefix,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _showWeekPickerBottomSheet,
          borderRadius: BorderRadius.circular(99),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_month_rounded, color: Color(0xFF0057C8), size: 18),
                const SizedBox(width: 8),
                Text(
                  '$startStr – $endStr',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF6B7280), size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _fetchAnalytics() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uRes = await Supabase.instance.client.rpc('admin_get_users', params: {
        'p_search_query': '',
        'p_offset': 0,
        'p_limit': 10000,
        'p_sort_asc': true
      });
      final allProfiles = List<dynamic>.from(uRes as List);
      _users = allProfiles.where((u) => u['role'] == 'user').toList();
      _admins = allProfiles.where((u) => u['role'] == 'admin').toList();

      _drivers = await Supabase.instance.client.from('drivers').select();
      _vouchers = await Supabase.instance.client.from('vouchers').select();
    } catch (e) {
      debugPrint('Error fetching analytics: $e');
      _error = 'Failed to load analytics data.';
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
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
      child: const Center(
        child: Text(
          'No analytics available.',
          style: TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCard({String? title, Widget? titleWidget, required Widget child, double height = 300}) {
    return Container(
      width: double.infinity,
      height: height,
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
          if (titleWidget != null)
            titleWidget
          else if (title != null)
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({required String title, required String value, required Color color}) {
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -1,
            ),
          ),
        ],
      ),
    );
  }

  // --- Line Chart Generator for selected week ---
  Widget _buildLineChart(List<dynamic> data, Color color, String tooltipLabel) {
    if (data.isEmpty) return _buildEmptyState();

    // Count per day for the selected 7 days (Mon to Sun)
    Map<int, int> counts = {for (var i = 0; i <= 6; i++) i: 0};
    
    for (final item in data) {
      if (item['created_at'] == null) continue;
      final dt = DateTime.tryParse(item['created_at']);
      if (dt == null) continue;
      
      // Calculate exact day difference by forcing both to midnight dates
      final dtDate = DateTime(dt.year, dt.month, dt.day);
      final weekStart = DateTime(_selectedWeekStart.year, _selectedWeekStart.month, _selectedWeekStart.day);
      final diff = dtDate.difference(weekStart).inDays;
      
      if (diff >= 0 && diff <= 6) {
        counts[diff] = counts[diff]! + 1;
      }
    }

    double maxY = counts.values.isEmpty ? 0 : counts.values.reduce(max).toDouble();
    if (maxY == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
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
        child: const Center(
          child: Text(
            'No registrations in the selected week.',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    final spots = counts.entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.toDouble());
    }).toList();
    spots.sort((a, b) => a.x.compareTo(b.x));

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: max(1, (maxY / 4).ceilToDouble()),
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFF3F4F6),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final dayOffset = value.toInt();
                if (dayOffset < 0 || dayOffset > 6) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(weekdays[dayOffset], style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: max(1, (maxY / 4).ceilToDouble()),
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                if (value % 1 != 0) return const SizedBox.shrink();
                return Text(value.toInt().toString(), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 5,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: color,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final dayOffset = spot.x.toInt();
                final d = _selectedWeekStart.add(Duration(days: dayOffset));
                final dateStr = '${d.day} ${months[d.month - 1]}';
                return LineTooltipItem(
                  '$dateStr\n',
                  const TextStyle(color: Colors.white, fontSize: 12),
                  children: [
                    TextSpan(
                      text: '$tooltipLabel: ${spot.y.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  // --- Users Tab ---
  Widget _buildUsersTab() {
    int newThisWeek = 0;
    final endOfWeek = _selectedWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    for (final u in _users) {
      if (u['created_at'] != null) {
        final d = DateTime.tryParse(u['created_at']);
        if (d != null && d.isAfter(_selectedWeekStart.subtract(const Duration(seconds: 1))) && d.isBefore(endOfWeek)) {
          newThisWeek++;
        }
      }
    }

    return Column(
      children: [
        _buildCard(
          titleWidget: _buildWeekPickerTitle('User Registrations'),
          child: _buildLineChart(_users, const Color(0xFF0057C8), 'New Users'),
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Users',
                  value: _users.length.toString(),
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSummaryCard(
                  title: 'New This Week',
                  value: '+$newThisWeek',
                  color: const Color(0xFF0057C8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriversTab() {
    int newThisWeek = 0;
    final now = DateTime.now();
    final endOfWeek = _selectedWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    for (final d in _drivers) {
      if (d['created_at'] != null) {
        final dt = DateTime.tryParse(d['created_at']);
        if (dt != null && dt.isAfter(_selectedWeekStart.subtract(const Duration(seconds: 1))) && dt.isBefore(endOfWeek)) {
          newThisWeek++;
        }
      }
    }

    return Column(
      children: [
        _buildCard(
          titleWidget: _buildWeekPickerTitle('Driver Registrations'),
          child: _buildLineChart(_drivers, const Color(0xFFF97316), 'New Drivers'),
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Drivers',
                  value: _drivers.length.toString(),
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSummaryCard(
                  title: 'New This Week',
                  value: '+$newThisWeek',
                  color: const Color(0xFFF97316),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- Vouchers Tab ---
  Widget _buildVouchersTab() {
    int newThisWeek = 0;
    final endOfWeek = _selectedWeekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
    for (final v in _vouchers) {
      if (v['created_at'] != null) {
        final dt = DateTime.tryParse(v['created_at']);
        if (dt != null && dt.isAfter(_selectedWeekStart.subtract(const Duration(seconds: 1))) && dt.isBefore(endOfWeek)) {
          newThisWeek++;
        }
      }
    }

    return Column(
      children: [
        _buildCard(
          titleWidget: _buildWeekPickerTitle('Vouchers Created'),
          child: _buildLineChart(_vouchers, const Color(0xFF10B981), 'New Vouchers'),
        ),
        const SizedBox(height: 24),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildSummaryCard(
                  title: 'Total Vouchers',
                  value: _vouchers.length.toString(),
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildSummaryCard(
                  title: 'Created This Week',
                  value: '+$newThisWeek',
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }



  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics',
                    style: TextStyle(
                      color: Color(0xFF102033),
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Real-time platform insights',
                    style: TextStyle(
                      color: Color(0xFF68788C),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh analytics',
              onPressed: _loading ? null : _fetchAnalytics,
              icon: _loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 28),
              color: const Color(0xFF0057C8),
            ),
          ],
        ),
        const SizedBox(height: 24),
        
        // Segmented Control
        _AnimatedSegmentedBar(
          tabs: const ['Users', 'Drivers', 'Vouchers'],
          selectedIndex: _section,
          onChanged: (index) {
            setState(() {
              _section = index;
            });
          },
        ),
        
        const SizedBox(height: 24),
        
        if (_error != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444)),
                const SizedBox(width: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
              ],
            ),
          )
        else if (_loading && _users.isEmpty && _drivers.isEmpty && _vouchers.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 100),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          if (_section == 0) _buildUsersTab(),
          if (_section == 1) _buildDriversTab(),
          if (_section == 2) _buildVouchersTab(),
        ],
      ],
    );
  }
}

class _WeekPickerSheet extends StatefulWidget {
  final DateTime currentWeekStart;
  const _WeekPickerSheet({required this.currentWeekStart});
  @override
  State<_WeekPickerSheet> createState() => _WeekPickerSheetState();
}

class _WeekPickerSheetState extends State<_WeekPickerSheet> {
  late final ScrollController _scrollController;
  final int _baseIndex = 10000;
  
  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController(initialScrollOffset: _baseIndex * 56.0 - 150.0);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.currentWeekStart,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF0057C8)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final selectedWeekStart = DateTime(picked.year, picked.month, picked.day).subtract(Duration(days: picked.weekday - 1));
      if (mounted) Navigator.pop(context, selectedWeekStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return Container(
      height: 400,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Select Week',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemExtent: 56.0,
              itemCount: 20000,
              itemBuilder: (context, index) {
                final offsetWeeks = index - _baseIndex;
                final weekStart = widget.currentWeekStart.add(Duration(days: offsetWeeks * 7));
                final weekEnd = weekStart.add(const Duration(days: 6));
                
                final startStr = '${weekStart.day.toString().padLeft(2, '0')} ${months[weekStart.month - 1]} ${weekStart.year}';
                final endStr = '${weekEnd.day.toString().padLeft(2, '0')} ${months[weekEnd.month - 1]} ${weekEnd.year}';
                final isSelected = offsetWeeks == 0;

                return InkWell(
                  onTap: () => Navigator.pop(context, weekStart),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                    color: isSelected ? const Color(0xFF0057C8).withValues(alpha: 0.1) : Colors.transparent,
                    child: Row(
                      children: [
                        if (isSelected)
                          const Icon(Icons.check_rounded, color: Color(0xFF0057C8), size: 20)
                        else
                          const SizedBox(width: 20),
                        const SizedBox(width: 16),
                        Text(
                          '$startStr – $endStr',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected ? const Color(0xFF0057C8) : const Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: _jumpToDate,
              icon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF0057C8), size: 20),
              label: const Text(
                'Jump to Date',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0057C8)),
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
