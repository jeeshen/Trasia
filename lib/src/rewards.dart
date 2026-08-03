part of '../main.dart';

class _RewardsData {
  static List<_RewardVoucher> vouchers = [];

  static Future<void> load() async {
    final data = await Supabase.instance.client.from('vouchers').select();
    vouchers = data
        .map(
          (d) => _RewardVoucher(
            id: d['id'] as String,
            title: d['title'] as String,
            description: d['description'] as String,
            pointCost: d['point_cost'] as int,
            kind: _RewardKind.values.firstWhere((e) => e.name == d['kind']),
            icon: _getIconData(d['icon'] as String),
            accentColor: Color(int.parse(d['accent_color'] as String)),
            hubPoolCredit: (d['hub_pool_credit'] as num).toDouble(),
          ),
        )
        .toList();
  }

  static IconData _getIconData(String name) {
    switch (name) {
      case 'Icons.local_taxi_rounded':
        return Icons.local_taxi_rounded;
      case 'Icons.directions_car_rounded':
        return Icons.directions_car_rounded;
      case 'Icons.restaurant_rounded':
        return Icons.restaurant_rounded;
      default:
        return Icons.star_rounded;
    }
  }
}

const _kfcVoucherImage = 'assets/branding/kfc_voucher.png';

class RedeemedVoucher {
  const RedeemedVoucher({
    required this.id,
    required this.title,
    required this.description,
    required this.code,
    required this.redeemedAt,
    this.usedAt,
  });

  final String id;
  final String title;
  final String description;
  final String code;
  final DateTime redeemedAt;
  final DateTime? usedAt;

  RedeemedVoucher copyWith({DateTime? usedAt}) {
    return RedeemedVoucher(
      id: id,
      title: title,
      description: description,
      code: code,
      redeemedAt: redeemedAt,
      usedAt: usedAt ?? this.usedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'code': code,
    'redeemedAt': redeemedAt.toIso8601String(),
    'usedAt': usedAt?.toIso8601String(),
  };

  factory RedeemedVoucher.fromJson(Map<String, dynamic> json) {
    return RedeemedVoucher(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Voucher',
      description: json['description'] as String? ?? '',
      code: json['code'] as String? ?? '',
      redeemedAt:
          DateTime.tryParse(json['redeemedAt'] as String? ?? '') ??
          DateTime.now(),
      usedAt: DateTime.tryParse(json['usedAt'] as String? ?? ''),
    );
  }
}

class CheckedInPlace {
  const CheckedInPlace({required this.placeKey, required this.checkedInAt});

  final String placeKey;
  final DateTime checkedInAt;

  Map<String, dynamic> toJson() => {
    'placeKey': placeKey,
    'checkedInAt': checkedInAt.toIso8601String(),
  };

  factory CheckedInPlace.fromJson(Map<String, dynamic> json) {
    return CheckedInPlace(
      placeKey: json['placeKey'] as String? ?? '',
      checkedInAt:
          DateTime.tryParse(json['checkedInAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

enum _RewardKind { hubPool, kfc }

class _RewardVoucher {
  const _RewardVoucher({
    required this.id,
    required this.title,
    required this.description,
    required this.pointCost,
    required this.kind,
    required this.icon,
    required this.accentColor,
    this.hubPoolCredit = 0,
  });

  final String id;
  final String title;
  final String description;
  final int pointCost;
  final _RewardKind kind;
  final IconData icon;
  final Color accentColor;
  final double hubPoolCredit;
}

class _RewardsEntryCard extends StatelessWidget {
  const _RewardsEntryCard({required this.points, required this.onTap});

  final int points;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF064D9F), Color(0xFF0B7CFF)],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260B7CFF),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: InkWell(
          key: const Key('blind-box-rewards'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .16),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Colors.white,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rewards',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$points points available · Redeem vouchers',
                        style: const TextStyle(
                          color: Color(0xFFDCEEFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckInMemoriesEntryCard extends StatelessWidget {
  const _CheckInMemoriesEntryCard({
    required this.checkedInCount,
    required this.onTap,
  });

  final int checkedInCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFDDE7F3)),
        ),
        child: InkWell(
          key: const Key('blind-box-check-in-memories'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: TrasiaColors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.confirmation_number_rounded,
                    color: TrasiaColors.primary,
                    size: 29,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check-in Memories',
                        style: TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$checkedInCount places checked in',
                        style: const TextStyle(
                          color: Color(0xFF687386),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF98A2B3),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckInMemoriesPage extends StatelessWidget {
  const CheckInMemoriesPage({
    required this.checkedInPlaces,
    required this.allPlaces,
    super.key,
  });

  final Map<String, CheckedInPlace> checkedInPlaces;
  final List<Attraction> allPlaces;

  @override
  Widget build(BuildContext context) {
    final placeByKey = {
      for (final place in allPlaces) _placeCheckInKey(place.name): place,
    };
    final memories = checkedInPlaces.values.toList()
      ..sort((a, b) => b.checkedInAt.compareTo(a.checkedInAt));
    return Scaffold(
      key: const Key('check-in-memories-page'),
      backgroundColor: const Color(0xFFF5F8FC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: const Color(0xFF051EA8),
            expandedHeight: 210,
            title: const Text('Check-in Memories'),
            flexibleSpace: FlexibleSpaceBar(
              background: _CheckInMemoriesHeader(count: memories.length),
            ),
          ),
          if (memories.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyCheckInMemories(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
              sliver: SliverList.separated(
                itemCount: memories.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final memory = memories[index];
                  final place = placeByKey[memory.placeKey];
                  return _CheckInMemoryTicket(
                    memory: memory,
                    place: place,
                    fallbackName: memory.placeKey.replaceAll('-', ' '),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _CheckInMemoriesHeader extends StatelessWidget {
  const _CheckInMemoriesHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF051EA8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF00179D), Color(0xFF0B7CFF)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 28,
            top: 72,
            child: _MemoryBubble(size: 68, opacity: .22),
          ),
          Positioned(
            left: 76,
            bottom: 20,
            child: _MemoryBubble(size: 92, opacity: .16),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 84, 24, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Checked-in places',
                    style: TextStyle(
                      color: Color(0xFFDCEEFF),
                      fontWeight: FontWeight.w800,
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

class _MemoryBubble extends StatelessWidget {
  const _MemoryBubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptyCheckInMemories extends StatelessWidget {
  const _EmptyCheckInMemories();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.confirmation_number_outlined,
              color: TrasiaColors.primary,
              size: 58,
            ),
            SizedBox(height: 14),
            Text(
              'No check-ins yet',
              style: TextStyle(
                color: Color(0xFF172033),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 7),
            Text(
              'Places you check in from KL Blind Box will appear here as memories.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF687386), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInMemoryTicket extends StatelessWidget {
  const _CheckInMemoryTicket({
    required this.memory,
    required this.place,
    required this.fallbackName,
  });

  final CheckedInPlace memory;
  final Attraction? place;
  final String fallbackName;

  @override
  Widget build(BuildContext context) {
    final checkedInAt = memory.checkedInAt.toLocal();
    final date = _voucherDate(checkedInAt);
    final time =
        '${checkedInAt.hour.toString().padLeft(2, '0')}:${checkedInAt.minute.toString().padLeft(2, '0')}';
    final title = place?.name ?? _titleCase(fallbackName);
    return Container(
      key: Key('check-in-memory-${memory.placeKey}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDDE7F3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14001844),
            blurRadius: 14,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 126,
            color: const Color(0xFFFFD7B5),
            alignment: Alignment.center,
            child: const RotatedBox(
              quarterTurns: 3,
              child: Text(
                'CHECK IN',
                style: TextStyle(
                  color: Color(0xFF051EA8),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  ClipOval(
                    child: place == null
                        ? Container(
                            width: 62,
                            height: 62,
                            color: TrasiaColors.primary.withValues(alpha: .12),
                            child: const Icon(
                              Icons.place_rounded,
                              color: TrasiaColors.primary,
                            ),
                          )
                        : Image.asset(
                            place!.imageAsset,
                            width: 62,
                            height: 62,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Checked in on $date',
                          style: const TextStyle(
                            color: Color(0xFF687386),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Time: $time',
                          style: const TextStyle(
                            color: Color(0xFF8A98AA),
                            fontSize: 12,
                          ),
                        ),
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

String _titleCase(String value) {
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

class RewardsPage extends StatefulWidget {
  const RewardsPage({
    required this.initialPoints,
    required this.onRedeem,
    super.key,
  });

  final int initialPoints;
  final bool Function(String voucherId, int pointCost, double hubPoolCredit)
  onRedeem;

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  late int _points = widget.initialPoints;

  Future<void> _openVoucher(_RewardVoucher voucher) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => _RewardDetailsSheet(
        voucher: voucher,
        availablePoints: _points,
        onRedeem: () {
          final redeemed = widget.onRedeem(
            voucher.id,
            voucher.pointCost,
            voucher.hubPoolCredit,
          );
          if (!redeemed) {
            return;
          }
          setState(() => _points -= voucher.pointCost);
          Navigator.of(sheetContext).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (voucher.kind == _RewardKind.kfc) {
              _showVoucherSaved();
            } else {
              _showCreditSuccess(voucher);
            }
          });
        },
      ),
    );
  }

  Future<void> _showCreditSuccess(_RewardVoucher voucher) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(
          Icons.check_circle_rounded,
          color: TrasiaColors.primary,
          size: 52,
        ),
        title: const Text('Reward redeemed!'),
        content: Text(
          'RM${voucher.hubPoolCredit.toStringAsFixed(0)} has been added to your HubPool credit.',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Future<void> _showVoucherSaved() {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Container(
          key: const Key('reward-voucher-saved'),
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF086EDB), Color(0xFF0B7CFF)],
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(
                  _kfcVoucherImage,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  semanticLabel: 'KFC',
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Voucher redeemed!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your KFC voucher has been added to My Vouchers.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFDCEEFF), height: 1.4),
              ),
              const SizedBox(height: 12),
              const Text(
                'Open it from Profile > My Vouchers to show the code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: TrasiaColors.primary,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FC),
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: TrasiaColors.primary,
            expandedHeight: 230,
            title: const Text('Rewards'),
            flexibleSpace: FlexibleSpaceBar(
              background: _RewardPointsHeader(points: _points),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 36),
            sliver: SliverList.list(
              children: [
                const Text(
                  'Redeem vouchers',
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Use your KL Blind Box points for Trasia credit and partner rewards.',
                  style: TextStyle(color: Color(0xFF687386), height: 1.4),
                ),
                const SizedBox(height: 16),
                for (final voucher in _RewardsData.vouchers) ...[
                  _RewardVoucherCard(
                    voucher: voucher,
                    availablePoints: _points,
                    onTap: () => _openVoucher(voucher),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class VoucherWalletPage extends StatefulWidget {
  const VoucherWalletPage({
    required this.vouchers,
    required this.onVoucherUsed,
    super.key,
  });

  final List<RedeemedVoucher> vouchers;
  final ValueChanged<String> onVoucherUsed;

  @override
  State<VoucherWalletPage> createState() => _VoucherWalletPageState();
}

class _VoucherWalletPageState extends State<VoucherWalletPage> {
  late List<RedeemedVoucher> _vouchers = List.of(widget.vouchers);

  Future<void> _openVoucher(RedeemedVoucher voucher, {required bool history}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) => _RedeemedVoucherDetailsSheet(
        voucher: voucher,
        history: history,
        onMarkUsed: () {
          Navigator.of(sheetContext).pop();
          _markUsed(voucher);
        },
      ),
    );
  }

  void _markUsed(RedeemedVoucher voucher) {
    widget.onVoucherUsed(voucher.id);
    setState(() {
      _vouchers = [
        for (final item in _vouchers)
          if (item.id == voucher.id)
            item.copyWith(usedAt: DateTime.now())
          else
            item,
      ];
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Voucher moved to History')));
  }

  @override
  Widget build(BuildContext context) {
    final available = [
      for (final voucher in _vouchers)
        if (voucher.usedAt == null) voucher,
    ];
    final history = [
      for (final voucher in _vouchers)
        if (voucher.usedAt != null) voucher,
    ];
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: const Key('voucher-wallet-page'),
        backgroundColor: const Color(0xFFF5F8FC),
        appBar: AppBar(
          title: const Text('My Vouchers'),
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF172033),
          bottom: TabBar(
            labelColor: TrasiaColors.primary,
            unselectedLabelColor: const Color(0xFF687386),
            indicatorColor: TrasiaColors.primary,
            tabs: [
              Tab(text: 'Available (${available.length})'),
              Tab(text: 'History (${history.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _VoucherList(
              vouchers: available,
              emptyTitle: 'No available vouchers',
              emptyMessage:
                  'Code-based rewards you redeem from KL Blind Box will appear here.',
              onOpenVoucher: (voucher) => _openVoucher(voucher, history: false),
            ),
            _VoucherList(
              vouchers: history,
              emptyTitle: 'No voucher history',
              emptyMessage: 'Vouchers you have used will appear here.',
              history: true,
              onOpenVoucher: (voucher) => _openVoucher(voucher, history: true),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}

class _VoucherList extends StatelessWidget {
  const _VoucherList({
    required this.vouchers,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.onOpenVoucher,
    this.history = false,
  });

  final List<RedeemedVoucher> vouchers;
  final String emptyTitle;
  final String emptyMessage;
  final ValueChanged<RedeemedVoucher> onOpenVoucher;
  final bool history;

  @override
  Widget build(BuildContext context) {
    if (vouchers.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: vouchers.length,
        separatorBuilder: (context, index) => const SizedBox(height: 14),
        itemBuilder: (context, index) => _RedeemedVoucherCard(
          voucher: vouchers[index],
          history: history,
          onTap: () => onOpenVoucher(vouchers[index]),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.confirmation_number_outlined,
              color: TrasiaColors.primary,
              size: 58,
            ),
            const SizedBox(height: 14),
            Text(
              emptyTitle,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontSize: 21,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              emptyMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF687386), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _RedeemedVoucherCard extends StatelessWidget {
  const _RedeemedVoucherCard({
    required this.voucher,
    required this.history,
    required this.onTap,
  });

  final RedeemedVoucher voucher;
  final bool history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: Key('saved-voucher-${voucher.id}'),
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: const Color(0x14001844),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _KfcVoucherImage(width: 58, height: 58, used: history),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.title,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      voucher.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF687386),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      history
                          ? 'Used ${_voucherDate(voucher.usedAt!)}'
                          : 'Redeemed ${_voucherDate(voucher.redeemedAt)}',
                      style: const TextStyle(
                        color: Color(0xFF8A98AA),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.grey.shade400,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RedeemedVoucherDetailsSheet extends StatelessWidget {
  const _RedeemedVoucherDetailsSheet({
    required this.voucher,
    required this.history,
    required this.onMarkUsed,
  });

  final RedeemedVoucher voucher;
  final bool history;
  final VoidCallback onMarkUsed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _KfcVoucherImage(width: 92, height: 92, used: history),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                voucher.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                voucher.description,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF687386), height: 1.4),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              key: const Key('saved-voucher-code'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F6FB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFDDE7F3)),
              ),
              child: Text(
                voucher.code,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                history
                    ? 'Used ${_voucherDate(voucher.usedAt!)} - Demo voucher'
                    : 'Redeemed ${_voucherDate(voucher.redeemedAt)} - Demo voucher',
                style: const TextStyle(color: Color(0xFF8A98AA), fontSize: 12),
              ),
            ),
            if (!history) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('mark-voucher-used'),
                  onPressed: onMarkUsed,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Mark as used'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _KfcVoucherImage extends StatelessWidget {
  const _KfcVoucherImage({
    required this.width,
    required this.height,
    required this.used,
  });

  final double width;
  final double height;
  final bool used;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('saved-voucher-kfc-image'),
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _kfcVoucherImage,
            fit: BoxFit.cover,
            semanticLabel: 'KFC voucher',
          ),
          if (used) ...[
            ColoredBox(color: Colors.black.withValues(alpha: .30)),
            Center(
              child: Transform.rotate(
                angle: -0.16,
                child: Container(
                  key: const Key('saved-voucher-used-stamp'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  constraints: BoxConstraints(maxWidth: width - 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .88),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: const Color(0xFFE1251B)),
                  ),
                  child: const Text(
                    'USED',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: TextStyle(
                      color: Color(0xFFE1251B),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .8,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _voucherDate(DateTime dateTime) {
  final localDate = dateTime.toLocal();
  return '${localDate.day.toString().padLeft(2, '0')}/${localDate.month.toString().padLeft(2, '0')}/${localDate.year}';
}

class _RewardPointsHeader extends StatelessWidget {
  const _RewardPointsHeader({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF064D9F), Color(0xFF0B7CFF), Color(0xFF31A8FF)],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Icon(Icons.stars_rounded, color: Color(0xFFFFD166), size: 38),
          const SizedBox(height: 8),
          Text(
            '$points',
            key: const Key('reward-points-balance'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Available points',
            style: TextStyle(
              color: Color(0xFFDCEEFF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardBrandMark extends StatelessWidget {
  const _RewardBrandMark({required this.voucher, required this.iconSize});

  final _RewardVoucher voucher;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    if (voucher.kind == _RewardKind.kfc) {
      return Image.asset(
        _kfcVoucherImage,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        semanticLabel: 'KFC',
      );
    }
    return Icon(voucher.icon, color: voucher.accentColor, size: iconSize);
  }
}

class _RewardVoucherCard extends StatelessWidget {
  const _RewardVoucherCard({
    required this.voucher,
    required this.availablePoints,
    required this.onTap,
  });

  final _RewardVoucher voucher;
  final int availablePoints;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final canRedeem = availablePoints >= voucher.pointCost;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      elevation: 2,
      shadowColor: const Color(0x18001844),
      child: InkWell(
        key: Key('reward-${voucher.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: voucher.accentColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(18),
                ),
                clipBehavior: Clip.antiAlias,
                child: _RewardBrandMark(voucher: voucher, iconSize: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      voucher.title,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      voucher.description,
                      style: const TextStyle(
                        color: Color(0xFF687386),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: canRedeem
                      ? TrasiaColors.primary.withValues(alpha: .10)
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      size: 16,
                      color: canRedeem
                          ? TrasiaColors.primary
                          : const Color(0xFF98A2B3),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${voucher.pointCost}',
                      style: TextStyle(
                        color: canRedeem
                            ? TrasiaColors.primary
                            : const Color(0xFF667085),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardDetailsSheet extends StatelessWidget {
  const _RewardDetailsSheet({
    required this.voucher,
    required this.availablePoints,
    required this.onRedeem,
  });

  final _RewardVoucher voucher;
  final int availablePoints;
  final VoidCallback onRedeem;

  @override
  Widget build(BuildContext context) {
    final canRedeem = availablePoints >= voucher.pointCost;
    final missingPoints = max(0, voucher.pointCost - availablePoints);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: voucher.accentColor.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: _RewardBrandMark(voucher: voucher, iconSize: 40),
            ),
            const SizedBox(height: 16),
            Text(
              voucher.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              voucher.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF687386), height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF3FF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stars_rounded, color: TrasiaColors.primary),
                  const SizedBox(width: 7),
                  Text(
                    '${voucher.pointCost} points',
                    style: const TextStyle(
                      color: TrasiaColors.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('reward-redeem-button'),
                onPressed: canRedeem ? onRedeem : null,
                icon: const Icon(Icons.redeem_rounded),
                label: Text(
                  canRedeem
                      ? 'Redeem points'
                      : 'Need $missingPoints more points',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
