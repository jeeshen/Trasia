part of '../main.dart';

class AccountConsoleScreen extends StatefulWidget {
  const AccountConsoleScreen({
    required this.role,
    required this.email,
    required this.wallet,
    required this.savedTransitRoutes,
    required this.hubPoolTransactions,
    required this.carbonSavedKg,
    required this.onTopUp,
    required this.onLogout,
    super.key,
  });

  final UserRole role;
  final String email;
  final double wallet;
  final int savedTransitRoutes;
  final int hubPoolTransactions;
  final double carbonSavedKg;
  final ValueChanged<double> onTopUp;
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
      backgroundColor: Colors.white,
      builder: (context) => _ProfileSheet(
        title: 'History',
        icon: Icons.history_rounded,
        child: Column(
          children: [
            _HistoryRow(
              label: 'Saved transit routes',
              value: '${widget.savedTransitRoutes}',
            ),
            _HistoryRow(
              label: 'Hub-Pool transactions',
              value: '${widget.hubPoolTransactions}',
            ),
            _HistoryRow(
              label: 'Carbon saved',
              value: '${widget.carbonSavedKg.toStringAsFixed(1)} kg',
              showDivider: false,
            ),
          ],
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
        builder: (context, scrollController) => _GovernmentDataSheet(
          scrollController: scrollController,
        ),
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
              subtitle:
                  '${widget.savedTransitRoutes} saved routes · ${widget.hubPoolTransactions} rides',
              onTap: _showHistory,
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
          _DataDetailBlock(title: 'How Trasia uses it', text: source.projectUse),
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

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFE8EEF5)))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF536477),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF102033),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
