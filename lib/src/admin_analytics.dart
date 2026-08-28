part of '../main.dart';

class _AdminAnalyticsView extends StatefulWidget {
  const _AdminAnalyticsView();
  @override
  State<_AdminAnalyticsView> createState() => _AdminAnalyticsViewState();
}

class _AdminAnalyticsViewState extends State<_AdminAnalyticsView> {
  int _section = 0;
  bool _loading = true;
  String? _error;
  late DateTime _selectedWeekStart;
  bool _hasData = false;
  int _usersTotal = 0;
  int _driversTotal = 0;
  int _vouchersTotal = 0;
  List<int> _usersDaily = List<int>.filled(7, 0);
  List<int> _driversDaily = List<int>.filled(7, 0);
  List<int> _vouchersDaily = List<int>.filled(7, 0);
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedWeekStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: now.weekday - 1));
    _fetchAnalytics();
  }

  Future<void> _showWeekPickerBottomSheet() async {
    final DateTime? newWeek = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TrasiaRadii.card),
        ),
      ),
      builder: (context) {
        return _WeekPickerSheet(currentWeekStart: _selectedWeekStart);
      },
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
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final startStr =
        '${_selectedWeekStart.day.toString().padLeft(2, '0')} ${months[_selectedWeekStart.month - 1]} ${_selectedWeekStart.year}';
    final endStr =
        '${end.day.toString().padLeft(2, '0')} ${months[end.month - 1]} ${end.year}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          prefix,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: TrasiaColors.ink,
          ),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _showWeekPickerBottomSheet,
          borderRadius: BorderRadius.circular(TrasiaRadii.control),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: TrasiaColors.surface,
              borderRadius: BorderRadius.circular(TrasiaRadii.control),
              border: Border.all(color: TrasiaColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: TrasiaColors.primary,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$startStr – $endStr',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TrasiaColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: TrasiaColors.muted,
                  size: 20,
                ),
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
      final response = await Supabase.instance.client.rpc(
        'admin_get_analytics',
        params: {
          'p_week_start':
              '${_selectedWeekStart.year.toString().padLeft(4, '0')}-'
              '${_selectedWeekStart.month.toString().padLeft(2, '0')}-'
              '${_selectedWeekStart.day.toString().padLeft(2, '0')}',
        },
      );
      final analytics = Map<String, dynamic>.from(response as Map);
      if (analytics['error'] != null) {
        throw analytics['error']!;
      }
      _usersTotal = (analytics['users_total'] as num?)?.toInt() ?? 0;
      _driversTotal = (analytics['drivers_total'] as num?)?.toInt() ?? 0;
      _vouchersTotal = (analytics['vouchers_total'] as num?)?.toInt() ?? 0;
      _usersDaily = _dailyCounts(analytics['users_daily']);
      _driversDaily = _dailyCounts(analytics['drivers_daily']);
      _vouchersDaily = _dailyCounts(analytics['vouchers_daily']);
      _hasData = true;
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

  List<int> _dailyCounts(dynamic value) {
    final values = value is List ? value : const <dynamic>[];
    return List<int>.generate(
      7,
      (index) =>
          index < values.length ? (values[index] as num?)?.toInt() ?? 0 : 0,
      growable: false,
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: TrasiaColors.surface,
        borderRadius: BorderRadius.circular(TrasiaRadii.card),
        border: Border.all(color: TrasiaColors.borderSubtle),
      ),
      child: const Center(
        child: Text(
          'No analytics available.',
          style: TextStyle(
            color: TrasiaColors.muted,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    String? title,
    Widget? titleWidget,
    required Widget child,
    double height = 300,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TrasiaColors.surface,
        borderRadius: BorderRadius.circular(TrasiaRadii.card),
        border: Border.all(color: TrasiaColors.borderSubtle),
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
                color: TrasiaColors.ink,
              ),
            ),
          const SizedBox(height: 24),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TrasiaColors.surface,
        borderRadius: BorderRadius.circular(TrasiaRadii.card),
        border: Border.all(color: TrasiaColors.borderSubtle),
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
              color: TrasiaColors.muted,
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

  Widget _buildLineChart(List<int> data, Color color, String tooltipLabel) {
    if (data.isEmpty) return _buildEmptyState();
    final maxY = data.reduce(max).toDouble();
    if (maxY == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: TrasiaColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(TrasiaRadii.control),
        ),
        child: const Center(
          child: Text(
            'No registrations in the selected week.',
            style: TextStyle(
              color: TrasiaColors.muted,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    final spots = <FlSpot>[
      for (var index = 0; index < data.length; index++)
        FlSpot(index.toDouble(), data[index].toDouble()),
    ];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: max(1, (maxY / 4).ceilToDouble()),
          getDrawingHorizontalLine: (value) =>
              FlLine(color: TrasiaColors.borderSubtle, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final dayOffset = value.toInt();
                if (dayOffset < 0 || dayOffset > 6) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    weekdays[dayOffset],
                    style: const TextStyle(
                      fontSize: 11,
                      color: TrasiaColors.muted,
                    ),
                  ),
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
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: TrasiaColors.muted,
                  ),
                );
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
              getDotPainter: (spot, percent, barData, index) =>
                  FlDotCirclePainter(
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
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: TrasiaMotion.responsive(context, TrasiaMotion.standard),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildUsersTab() {
    final newThisWeek = _usersDaily.fold<int>(0, (sum, count) => sum + count);
    return Column(
      children: [
        _buildCard(
          titleWidget: _buildWeekPickerTitle('User Registrations'),
          child: _buildLineChart(
            _usersDaily,
            TrasiaColors.primary,
            'New Users',
          ),
        ),
        const SizedBox(height: 24),
        _buildSummaryPair(
          _buildSummaryCard(
            title: 'Total Users',
            value: _usersTotal.toString(),
            color: TrasiaColors.ink,
          ),
          _buildSummaryCard(
            title: 'New This Week',
            value: '+$newThisWeek',
            color: TrasiaColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildDriversTab() {
    final newThisWeek = _driversDaily.fold<int>(0, (sum, count) => sum + count);
    return Column(
      children: [
        _buildCard(
          titleWidget: _buildWeekPickerTitle('Driver Registrations'),
          child: _buildLineChart(
            _driversDaily,
            const Color(0xFFF97316),
            'New Drivers',
          ),
        ),
        const SizedBox(height: 24),
        _buildSummaryPair(
          _buildSummaryCard(
            title: 'Total Drivers',
            value: _driversTotal.toString(),
            color: TrasiaColors.ink,
          ),
          _buildSummaryCard(
            title: 'New This Week',
            value: '+$newThisWeek',
            color: const Color(0xFFF97316),
          ),
        ),
      ],
    );
  }

  Widget _buildVouchersTab() {
    final newThisWeek = _vouchersDaily.fold<int>(
      0,
      (sum, count) => sum + count,
    );
    return Column(
      children: [
        _buildCard(
          titleWidget: _buildWeekPickerTitle('Vouchers Created'),
          child: _buildLineChart(
            _vouchersDaily,
            const Color(0xFF10B981),
            'New Vouchers',
          ),
        ),
        const SizedBox(height: 24),
        _buildSummaryPair(
          _buildSummaryCard(
            title: 'Total Vouchers',
            value: _vouchersTotal.toString(),
            color: TrasiaColors.ink,
          ),
          _buildSummaryCard(
            title: 'Created This Week',
            value: '+$newThisWeek',
            color: const Color(0xFF10B981),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryPair(Widget first, Widget second) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 440
            ? constraints.maxWidth
            : (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(width: cardWidth, child: first),
            SizedBox(width: cardWidth, child: second),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Analytics',
                    style: TextStyle(
                      color: TrasiaColors.inkStrong,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Real-time platform insights',
                    style: TextStyle(
                      color: TrasiaColors.mutedSoft,
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
              color: TrasiaColors.primary,
            ),
          ],
        ),
        const SizedBox(height: 24),
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
              borderRadius: BorderRadius.circular(TrasiaRadii.control),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: TrasiaColors.danger),
                const SizedBox(width: 12),
                Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
              ],
            ),
          )
        else if (_loading && !_hasData)
          const Padding(
            padding: EdgeInsets.only(top: 100),
            child: Center(
              child: TrasiaLoadingCompass(
                size: 56,
                semanticLabel: 'Loading analytics',
              ),
            ),
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
    _scrollController = ScrollController(
      initialScrollOffset: _baseIndex * 56.0 - 150.0,
    );
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
        return Theme(data: TrasiaTheme.light, child: child!);
      },
    );
    if (picked != null) {
      final selectedWeekStart = DateTime(
        picked.year,
        picked.month,
        picked.day,
      ).subtract(Duration(days: picked.weekday - 1));
      if (mounted) Navigator.pop(context, selectedWeekStart);
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return Container(
      height: 400,
      padding: const EdgeInsets.only(top: 24, bottom: 16),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Select Week',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: TrasiaColors.ink,
              ),
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
                final weekStart = widget.currentWeekStart.add(
                  Duration(days: offsetWeeks * 7),
                );
                final weekEnd = weekStart.add(const Duration(days: 6));
                final startStr =
                    '${weekStart.day.toString().padLeft(2, '0')} ${months[weekStart.month - 1]} ${weekStart.year}';
                final endStr =
                    '${weekEnd.day.toString().padLeft(2, '0')} ${months[weekEnd.month - 1]} ${weekEnd.year}';
                final isSelected = offsetWeeks == 0;
                return InkWell(
                  onTap: () => Navigator.pop(context, weekStart),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 0,
                    ),
                    color: isSelected
                        ? TrasiaColors.primary.withValues(alpha: 0.1)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        if (isSelected)
                          const Icon(
                            Icons.check_rounded,
                            color: TrasiaColors.primary,
                            size: 20,
                          )
                        else
                          const SizedBox(width: 20),
                        const SizedBox(width: 16),
                        Text(
                          '$startStr – $endStr',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? TrasiaColors.primary
                                : TrasiaColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, color: TrasiaColors.borderSubtle),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton.icon(
              onPressed: _jumpToDate,
              icon: const Icon(
                Icons.calendar_today_rounded,
                color: TrasiaColors.primary,
                size: 20,
              ),
              label: const Text(
                'Jump to Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TrasiaColors.primary,
                ),
              ),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(TrasiaRadii.control),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
