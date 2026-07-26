part of '../main.dart';

class AccountConsoleScreen extends StatefulWidget {
  const AccountConsoleScreen({
    required this.role,
    required this.email,
    required this.wallet,
    required this.savedTransitRoutes,
    required this.hubPoolTransactions,
    required this.carbonSavedKg,
    required this.favoritePlaces,
    required this.tripHistory,
    required this.onTopUp,
    required this.onRemoveFavorite,
    required this.onRevisitFavorite,
    required this.onRevisitHistory,
    required this.onLogout,
    super.key,
  });

  final UserRole role;
  final String email;
  final double wallet;
  final int savedTransitRoutes;
  final int hubPoolTransactions;
  final double carbonSavedKg;
  final List<FavoritePlace> favoritePlaces;
  final List<TripHistoryEntry> tripHistory;
  final ValueChanged<double> onTopUp;
  final ValueChanged<FavoritePlace> onRemoveFavorite;
  final ValueChanged<FavoritePlace> onRevisitFavorite;
  final ValueChanged<TripHistoryEntry> onRevisitHistory;
  final VoidCallback onLogout;

  @override
  State<AccountConsoleScreen> createState() => _AccountConsoleScreenState();
}

class _AccountConsoleScreenState extends State<AccountConsoleScreen> {
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _avatarBytes;
  bool _savingAvatar = false;

  String get _avatarStorageKey {
    final accountKey = base64Url
        .encode(utf8.encode(widget.email.toLowerCase()))
        .replaceAll('=', '');
    return 'trasia.profile.avatar.$accountKey';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadAvatar());
  }

  @override
  void didUpdateWidget(covariant AccountConsoleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email != widget.email) {
      _avatarBytes = null;
      unawaited(_loadAvatar());
    }
  }

  Future<void> _loadAvatar() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_avatarStorageKey);
    if (encoded == null || !mounted) {
      return;
    }
    try {
      setState(() => _avatarBytes = base64Decode(encoded));
    } on FormatException {
      await preferences.remove(_avatarStorageKey);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 82,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) {
        return;
      }
      setState(() => _savingAvatar = true);
      final bytes = await image.readAsBytes();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_avatarStorageKey, base64Encode(bytes));
      if (mounted) {
        setState(() {
          _avatarBytes = bytes;
          _savingAvatar = false;
        });
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _savingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update profile photo.')),
      );
    }
  }

  void _showWallet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (context) => _ProfileSheet(
        title: 'Wallet',
        icon: Icons.account_balance_wallet_rounded,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'RM ${widget.wallet.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Color(0xFF102033),
                fontSize: 34,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Available credit for Hub-Pool rides',
              style: TextStyle(color: Color(0xFF607086)),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      widget.onTopUp(20);
                      Navigator.pop(context);
                    },
                    child: const Text('Top up RM20'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onTopUp(50);
                      Navigator.pop(context);
                    },
                    child: const Text('Top up RM50'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .42,
        maxChildSize: .92,
        builder: (context, scrollController) => _HistorySheet(
          entries: widget.tripHistory,
          scrollController: scrollController,
          onRevisit: _confirmRevisit,
        ),
      ),
    );
  }

  Future<void> _confirmRevisit(TripHistoryEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RevisitConfirmDialog(placeName: entry.placeName),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    widget.onRevisitHistory(entry);
  }

  void _showFavorites() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .72,
        minChildSize: .42,
        maxChildSize: .92,
        builder: (context, scrollController) => _FavoritesSheet(
          places: widget.favoritePlaces,
          scrollController: scrollController,
          onRemove: widget.onRemoveFavorite,
          onRevisit: widget.onRevisitFavorite,
        ),
      ),
    );
  }

  void _showGovernmentData() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .78,
        minChildSize: .46,
        maxChildSize: .92,
        builder: (context, scrollController) =>
            _GovernmentDataSheet(scrollController: scrollController),
      ),
    );
  }

  void _showTerms() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => const _ProfileSheet(
        title: 'Terms & Conditions',
        icon: Icons.description_outlined,
        child: Text(
          'By using Trasia, you agree to provide accurate account information, '
          'use transport and routing features responsibly, and follow applicable '
          'local laws. Route times, fares, and availability are estimates and may '
          'change based on live service conditions.',
          style: TextStyle(
            color: Color(0xFF536477),
            fontSize: 15,
            height: 1.55,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF102033);
    const muted = Color(0xFF68788C);

    return Theme(
      data: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: TrasiaColors.primary,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      child: ColoredBox(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            const Text(
              'Profile',
              style: TextStyle(
                color: ink,
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 26),
            Center(
              child: Semantics(
                button: true,
                label: 'Change profile photo',
                child: GestureDetector(
                  onTap: _savingAvatar ? null : _pickAvatar,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 108,
                        height: 108,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: const Color(0xFFD8E8FF),
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x1A0B7CFF),
                              blurRadius: 18,
                              offset: Offset(0, 7),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: _avatarBytes == null
                              ? const ColoredBox(
                                  color: Color(0xFFEAF3FF),
                                  child: Icon(
                                    Icons.person_rounded,
                                    size: 58,
                                    color: TrasiaColors.primary,
                                  ),
                                )
                              : Image.memory(
                                  _avatarBytes!,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: 3,
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: TrasiaColors.primary,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                          child: _savingAvatar
                              ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.photo_camera_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.email,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ink,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.role == UserRole.admin ? 'Administrator' : 'Trasia member',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TrasiaColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 34),
            const Text(
              'Settings',
              style: TextStyle(
                color: ink,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            _ProfileSettingRow(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Wallet',
              subtitle: 'RM ${widget.wallet.toStringAsFixed(2)}',
              onTap: _showWallet,
            ),
            _ProfileSettingRow(
              icon: Icons.history_rounded,
              title: 'History',
              subtitle: widget.tripHistory.isEmpty
                  ? 'Completed places will appear here'
                  : '${widget.tripHistory.length} completed places',
              onTap: _showHistory,
            ),
            _ProfileSettingRow(
              icon: Icons.favorite_border_rounded,
              title: 'Favorites',
              subtitle: widget.favoritePlaces.isEmpty
                  ? 'Save places from search or KL Blind Box'
                  : '${widget.favoritePlaces.length} saved places',
              onTap: _showFavorites,
            ),
            _ProfileSettingRow(
              icon: Icons.dataset_rounded,
              title: 'Government Data',
              subtitle: 'data.gov.my, OpenDOSM, MYSA, World Bank',
              onTap: _showGovernmentData,
            ),
            _ProfileSettingRow(
              icon: Icons.description_outlined,
              title: 'Terms & Conditions',
              onTap: _showTerms,
            ),
            _ProfileSettingRow(
              icon: Icons.logout_rounded,
              title: 'Logout',
              destructive: true,
              showDivider: false,
              onTap: widget.onLogout,
            ),
            const SizedBox(height: 8),
            const Text(
              'Profile photos are saved on this device.',
              textAlign: TextAlign.center,
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _RevisitConfirmDialog extends StatelessWidget {
  const _RevisitConfirmDialog({required this.placeName});

  final String placeName;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.near_me_rounded, color: TrasiaColors.primary),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Go again?',
                    style: TextStyle(
                      color: Color(0xFF102033),
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Do you want to go to $placeName again?',
              style: const TextStyle(
                color: Color(0xFF536477),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('No'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Yes'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistorySheet extends StatelessWidget {
  const _HistorySheet({
    required this.entries,
    required this.scrollController,
    required this.onRevisit,
  });

  final List<TripHistoryEntry> entries;
  final ScrollController scrollController;
  final ValueChanged<TripHistoryEntry> onRevisit;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          const Row(
            children: [
              Icon(Icons.history_rounded, color: TrasiaColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'History',
                  style: TextStyle(
                    color: Color(0xFF102033),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entries.isEmpty
                ? 'Completed trips will appear here.'
                : '${entries.length} completed places',
            style: const TextStyle(
              color: Color(0xFF536477),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            const _HistoryEmptyState()
          else
            for (final entry in entries) ...[
              _HistoryEntryCard(entry: entry, onTap: () => onRevisit(entry)),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF5)),
      ),
      child: const Column(
        children: [
          Icon(Icons.flag_outlined, color: TrasiaColors.primary, size: 36),
          SizedBox(height: 10),
          Text(
            'No completed places yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF102033),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Start a Transit, Ride, or Plan trip and tap the arrival button.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF68788C), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  const _HistoryEntryCard({required this.entry, required this.onTap});

  final TripHistoryEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = switch (entry.category) {
      'Transit' => TrasiaColors.primary,
      'Ride' => const Color(0xFF00A86B),
      'Plan' => const Color(0xFFFFA800),
      _ => const Color(0xFF68788C),
    };
    final icon = switch (entry.category) {
      'Transit' => Icons.directions_transit_rounded,
      'Ride' => Icons.directions_car_rounded,
      'Plan' => Icons.backpack_rounded,
      _ => Icons.place_rounded,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE1EAF5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.placeName,
                          style: const TextStyle(
                            color: Color(0xFF102033),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _HistoryCategoryPill(label: entry.category, color: color),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _historyTimestamp(entry.completedAt),
                    style: const TextStyle(
                      color: Color(0xFF8A98AA),
                      fontSize: 12,
                    ),
                  ),
                  if (entry.category == 'Ride' && entry.amountPaid != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.payments_outlined,
                          size: 15,
                          color: Color(0xFF536477),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Paid RM ${entry.amountPaid!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Color(0xFF536477),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCategoryPill extends StatelessWidget {
  const _HistoryCategoryPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _historyTimestamp(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}

class _FavoritesSheet extends StatefulWidget {
  const _FavoritesSheet({
    required this.places,
    required this.scrollController,
    required this.onRemove,
    required this.onRevisit,
  });

  final List<FavoritePlace> places;
  final ScrollController scrollController;
  final ValueChanged<FavoritePlace> onRemove;
  final ValueChanged<FavoritePlace> onRevisit;

  @override
  State<_FavoritesSheet> createState() => _FavoritesSheetState();
}

class _FavoritesSheetState extends State<_FavoritesSheet> {
  late List<FavoritePlace> _places;

  @override
  void initState() {
    super.initState();
    _places = List<FavoritePlace>.of(widget.places);
  }

  void _remove(FavoritePlace place) {
    setState(() {
      _places = [
        for (final favorite in _places)
          if (favorite.key != place.key) favorite,
      ];
    });
    widget.onRemove(place);
  }

  Future<void> _revisit(FavoritePlace place) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RevisitConfirmDialog(placeName: place.name),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    Navigator.of(context).pop();
    widget.onRevisit(place);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        controller: widget.scrollController,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_rounded, color: Color(0xFFE04470)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Favorites',
                  style: TextStyle(
                    color: Color(0xFF102033),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _places.isEmpty
                ? 'Places you save in Trasia will appear here.'
                : '${_places.length} saved places',
            style: const TextStyle(
              color: Color(0xFF536477),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          if (_places.isEmpty)
            const _FavoritesEmptyState()
          else
            for (final place in _places) ...[
              _FavoritePlaceCard(
                place: place,
                onRemove: () => _remove(place),
                onRevisit: () => _revisit(place),
              ),
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

class _FavoritesEmptyState extends StatelessWidget {
  const _FavoritesEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFE),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF5)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.favorite_border_rounded,
            color: TrasiaColors.primary,
            size: 36,
          ),
          SizedBox(height: 10),
          Text(
            'No favorite places yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF102033),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Tap the heart on any destination or Blind Box place.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF68788C), height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _FavoritePlaceCard extends StatelessWidget {
  const _FavoritePlaceCard({
    required this.place,
    required this.onRemove,
    required this.onRevisit,
  });

  final FavoritePlace place;
  final VoidCallback onRemove;
  final VoidCallback onRevisit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE1EAF5)),
      ),
      child: InkWell(
        onTap: onRevisit,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: place.imageAsset.isEmpty
                    ? Container(
                        width: 72,
                        height: 72,
                        color: place.color.withValues(alpha: .14),
                        alignment: Alignment.center,
                        child: Icon(Icons.place_rounded, color: place.color),
                      )
                    : Image.asset(
                        place.imageAsset,
                        width: 72,
                        height: 72,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          width: 72,
                          height: 72,
                          color: place.color,
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_not_supported_rounded),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      style: const TextStyle(
                        color: Color(0xFF102033),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (place.address.isNotEmpty)
                      _FavoritePlaceMeta(
                        icon: Icons.place_rounded,
                        text: place.address,
                      ),
                    _FavoritePlaceMeta(
                      icon: Icons.schedule_rounded,
                      text: place.hours,
                    ),
                    if (place.suggestedDistanceKm > 0)
                      _FavoritePlaceMeta(
                        icon: Icons.route_rounded,
                        text:
                            '${place.suggestedDistanceKm.toStringAsFixed(1)} km suggested distance',
                      ),
                    if (place.baseCost > 0)
                      _FavoritePlaceMeta(
                        icon: Icons.payments_rounded,
                        text: 'From RM ${place.baseCost}',
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove from Favorites',
                onPressed: onRemove,
                color: const Color(0xFFE04470),
                icon: const Icon(Icons.favorite_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritePlaceMeta extends StatelessWidget {
  const _FavoritePlaceMeta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: TrasiaColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF68788C), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernmentDataSheet extends StatelessWidget {
  const _GovernmentDataSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          const Row(
            children: [
              Icon(Icons.dataset_rounded, color: TrasiaColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Government Data',
                  style: TextStyle(
                    color: Color(0xFF102033),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Key Initiatives & Portals used to support Trasia route planning, tourism discovery, and assignment data justification.',
            style: TextStyle(
              color: Color(0xFF536477),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          const _GovernmentDataSummary(),
          const SizedBox(height: 16),
          for (final source in governmentDataSources) ...[
            _GovernmentDataCard(source: source),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          const _OfficialEndpointPanel(),
        ],
      ),
    );
  }
}

class _GovernmentDataSummary extends StatelessWidget {
  const _GovernmentDataSummary();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFD9FA)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_rounded, color: TrasiaColors.primary),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assignment angle: Trasia is a data-driven Malaysian mobility planner built around official open data, public transport standards, and national statistics.',
              style: TextStyle(
                color: Color(0xFF102033),
                fontWeight: FontWeight.w700,
                height: 1.38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GovernmentDataCard extends StatelessWidget {
  const _GovernmentDataCard({required this.source});

  final GovernmentDataSource source;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1EAF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: source.color.withValues(alpha: .13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(source.icon, color: source.color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: const TextStyle(
                        color: Color(0xFF102033),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      source.portal,
                      style: const TextStyle(
                        color: Color(0xFF68788C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DataDetailBlock(title: 'Data focus', text: source.focus),
          const SizedBox(height: 10),
          _DataDetailBlock(
            title: 'How Trasia uses it',
            text: source.projectUse,
          ),
          const SizedBox(height: 12),
          SelectableText(
            source.url,
            style: const TextStyle(
              color: TrasiaColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _DataDetailBlock extends StatelessWidget {
  const _DataDetailBlock({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF102033),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF536477),
            fontSize: 13,
            height: 1.38,
          ),
        ),
      ],
    );
  }
}

class _OfficialEndpointPanel extends StatelessWidget {
  const _OfficialEndpointPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF102033),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.directions_transit_rounded, color: Colors.white),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Official transit API endpoints',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'These endpoints are already referenced in Trasia for Malaysia public transport data.',
            style: TextStyle(color: Color(0xFFBFD0E5), height: 1.35),
          ),
          const SizedBox(height: 12),
          for (final endpoint in officialTransitDataEndpoints) ...[
            SelectableText(
              endpoint,
              style: const TextStyle(
                color: Color(0xFF9DFFCB),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _ProfileSettingRow extends StatelessWidget {
  const _ProfileSettingRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.destructive = false,
    this.showDivider = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? const Color(0xFFD63C3C)
        : const Color(0xFF102033);
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 68),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: Color(0xFFE8EEF5)))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFEAF3FF),
              ),
              child: Icon(
                icon,
                size: 20,
                color: destructive
                    ? const Color(0xFFD63C3C)
                    : TrasiaColors.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF718095),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: destructive
                  ? const Color(0xFFD63C3C)
                  : const Color(0xFF93A1B2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSheet extends StatelessWidget {
  const _ProfileSheet({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          4,
          22,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: TrasiaColors.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF102033),
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            child,
          ],
        ),
      ),
    );
  }
}
