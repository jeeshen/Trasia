part of '../main.dart';

// ignore: unused_element
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.role,
    required this.wallet,
    required this.showWallet,
  });

  final UserRole role;
  final double wallet;
  final bool showWallet;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: () {},
            icon: const Icon(Icons.menu_rounded),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role == UserRole.admin ? 'Admin Dashboard' : 'Discover KL',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  role == UserRole.admin
                      ? 'Registry and system controls'
                      : showWallet
                      ? 'Wallet RM ${wallet.toStringAsFixed(2)}'
                      : 'Classic destination itinerary',
                  style: TextStyle(color: Colors.white.withValues(alpha: .7)),
                ),
              ],
            ),
          ),
          const CircleAvatar(
            radius: 24,
            backgroundColor: TrasiaColors.primary,
            child: Icon(Icons.person_rounded),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _BlueShell extends StatelessWidget {
  const _BlueShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF061827), Color(0xFF083F7C), Color(0xFF06111D)],
        ),
      ),
      child: child,
    );
  }
}

// ignore: unused_element
class _GlassPanel extends StatelessWidget {
  const _GlassPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: child,
    );
  }
}

// ignore: unused_element
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF40A9FF)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            trailing,
            style: TextStyle(color: Colors.white.withValues(alpha: .62)),
          ),
        ],
      ),
    );
  }
}

class _MapSearchWindow extends StatelessWidget {
  const _MapSearchWindow({
    required this.fromController,
    required this.toController,
    required this.statusMessage,
    required this.candidate,
    required this.candidates,
    required this.routes,
    required this.selectedRoute,
    required this.navigating,
    required this.searchingDestination,
    required this.favoritePlaceNames,
    required this.onTextChanged,
    required this.onSearch,
    required this.onClearDestination,
    required this.onConfirmDestination,
    required this.onSelectRoute,
    required this.onToggleFavorite,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final String? statusMessage;
  final DestinationCandidate? candidate;
  final List<DestinationCandidate> candidates;
  final List<TransitOption> routes;
  final TransitOption? selectedRoute;
  final bool navigating;
  final bool searchingDestination;
  final Set<String> favoritePlaceNames;
  final VoidCallback onTextChanged;
  final VoidCallback onSearch;
  final VoidCallback onClearDestination;
  final ValueChanged<DestinationCandidate> onConfirmDestination;
  final ValueChanged<TransitOption> onSelectRoute;
  final ValueChanged<DestinationCandidate> onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final hasResults =
        statusMessage != null || candidates.isNotEmpty || routes.isNotEmpty;
    final panelMaxHeight = MediaQuery.sizeOf(context).height * .76;
    final resultMaxHeight = max(220.0, panelMaxHeight - 140);

    return Container(
      constraints: BoxConstraints(maxHeight: panelMaxHeight),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2D001844),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F6FB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        size: 18,
                        color: TrasiaColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          fromController.text,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: toController,
                  builder: (context, value, _) {
                    return TextField(
                      key: const Key('feature-a-destination'),
                      controller: toController,
                      onChanged: (_) => onTextChanged(),
                      onSubmitted: (_) => onSearch(),
                      style: const TextStyle(color: Color(0xFF172033)),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF2F6FB),
                        border: const OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(99)),
                          borderSide: BorderSide.none,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: value.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear destination',
                                onPressed: onClearDestination,
                                icon: const Icon(Icons.close_rounded),
                              ),
                        hintText: 'Search and Navigate',
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Search route options',
                onPressed: searchingDestination ? null : onSearch,
                style: IconButton.styleFrom(
                  backgroundColor: TrasiaColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFB9D7FF),
                  disabledForegroundColor: Colors.white,
                ),
                icon: searchingDestination
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.near_me_rounded),
              ),
            ],
          ),
          if (hasResults) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: resultMaxHeight),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: 12),
                children: [
                  if (statusMessage != null)
                    _SheetNotice(message: statusMessage!),
                  if (candidates.isNotEmpty && routes.isEmpty) ...[
                    const Text(
                      'Choose a destination',
                      style: TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final option in candidates) ...[
                      _DestinationConfirmCard(
                        candidate: option,
                        selected: option == candidate,
                        actionLabel: 'Calculate Distance',
                        favorite: favoritePlaceNames.contains(
                          option.name.toLowerCase(),
                        ),
                        onConfirm: () => onConfirmDestination(option),
                        onToggleFavorite: () => onToggleFavorite(option),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                  if (candidate != null && routes.isNotEmpty) ...[
                    _DestinationConfirmCard(
                      candidate: candidate!,
                      selected: true,
                      actionLabel: 'Destination Selected',
                      favorite: favoritePlaceNames.contains(
                        candidate!.name.toLowerCase(),
                      ),
                      onConfirm: null,
                      onToggleFavorite: () => onToggleFavorite(candidate!),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (routes.isNotEmpty) ...[
                    Text(
                      navigating
                          ? 'Navigation in progress'
                          : 'Choose a travel option',
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final route in routes) ...[
                      _RouteChoiceCard(
                        route: route,
                        selected: route == selectedRoute,
                        onTap: () => onSelectRoute(route),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MapLocationButton extends StatelessWidget {
  const _MapLocationButton({required this.loading, required this.onPressed});

  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-current-location'),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: loading ? null : onPressed,
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.black87,
                    ),
                  )
                : const Icon(
                    Icons.my_location_rounded,
                    color: Colors.black87,
                    size: 24,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DemoArrivalButton extends StatelessWidget {
  const _DemoArrivalButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('demo-arrival'),
      color: TrasiaColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: const SizedBox.square(
          dimension: 48,
          child: Center(
            child: Icon(Icons.flag_rounded, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

class _MapFavoritesButton extends StatelessWidget {
  const _MapFavoritesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('map-favorites'),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 8,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onPressed,
        child: const Tooltip(
          message: 'Favorites',
          child: SizedBox.square(
            dimension: 48,
            child: Center(
              child: Icon(
                Icons.favorite_rounded,
                color: Color(0xFFE04470),
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetNotice extends StatelessWidget {
  const _SheetNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6DF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFFFFA800)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              softWrap: true,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DestinationConfirmCard extends StatelessWidget {
  const _DestinationConfirmCard({
    required this.candidate,
    required this.selected,
    required this.favorite,
    required this.onConfirm,
    required this.onToggleFavorite,
    this.actionLabel,
  });

  final DestinationCandidate candidate;
  final bool selected;
  final bool favorite;
  final VoidCallback? onConfirm;
  final VoidCallback onToggleFavorite;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEAF3FF) : const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? TrasiaColors.primary : const Color(0xFFE0E7F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                backgroundColor: TrasiaColors.primary,
                foregroundColor: Colors.white,
                child: Icon(Icons.place_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      candidate.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF172033),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      candidate.address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF687386)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: favorite
                    ? 'Remove from Favorites'
                    : 'Save to Favorites',
                onPressed: onToggleFavorite,
                color: favorite
                    ? const Color(0xFFE04470)
                    : TrasiaColors.primary,
                icon: Icon(
                  favorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
              ),
            ],
          ),
          if (actionLabel != null && onConfirm != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onConfirm,
                style: FilledButton.styleFrom(
                  foregroundColor: Colors.black,
                  disabledForegroundColor: Colors.black,
                ),
                icon: const Icon(Icons.alt_route_rounded),
                label: Text(actionLabel!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RouteChoiceCard extends StatelessWidget {
  const _RouteChoiceCard({
    required this.route,
    required this.selected,
    required this.onTap,
  });

  final TransitOption route;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? route.color.withValues(alpha: .14)
              : const Color(0xFFF4F7FB),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? route.color : const Color(0xFFE0E7F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: route.color,
                  foregroundColor: Colors.white,
                  child: Icon(
                    route.label == 'Drive'
                        ? Icons.directions_car_rounded
                        : Icons.alt_route_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    route.label,
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _userFacingTransitText(route.chain),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF687386)),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _DarkMiniMetric(
                  Icons.schedule_rounded,
                  _compactDurationLabel(route.time),
                ),
                const SizedBox(width: 8),
                _DarkMiniMetric(Icons.straighten_rounded, route.distance),
                const SizedBox(width: 8),
                _DarkMiniMetric(Icons.payments_rounded, route.fare),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _DarkMiniMetric(Icons.sync_alt_rounded, route.transfers),
                const SizedBox(width: 8),
                Expanded(child: _PeakCrowdBars(crowd: route.crowd)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DarkMiniMetric extends StatelessWidget {
  const _DarkMiniMetric(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: TrasiaColors.primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _compactDurationLabel(String value) {
  final hours = RegExp(
    r'(\d+)\s*(?:hours?|hrs?|h)\b',
    caseSensitive: false,
  ).firstMatch(value);
  final minutes = RegExp(
    r'(\d+)\s*(?:minutes?|mins?|m)\b',
    caseSensitive: false,
  ).firstMatch(value);
  if (hours == null && minutes == null) {
    return value;
  }
  final hourValue = hours?.group(1);
  final minuteValue = minutes?.group(1);
  return [
    if (hourValue != null) '${hourValue}H',
    if (minuteValue != null) '${minuteValue}M',
  ].join();
}

class _PeakCrowdBars extends StatelessWidget {
  const _PeakCrowdBars({required this.crowd});

  final double crowd;

  @override
  Widget build(BuildContext context) {
    final levels = [
      (crowd * .75).clamp(.08, 1).toDouble(),
      crowd.clamp(.08, 1).toDouble(),
      (crowd * .62).clamp(.08, 1).toDouble(),
      (crowd * .9).clamp(.08, 1).toDouble(),
    ];
    return Row(
      children: [
        const Icon(
          Icons.bar_chart_rounded,
          size: 16,
          color: TrasiaColors.primary,
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 20,
          width: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final level in levels) ...[
                Expanded(
                  child: Container(
                    height: 18 * level,
                    decoration: BoxDecoration(
                      color: TrasiaColors.primary.withValues(alpha: .78),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 3),
              ],
            ],
          ),
        ),
        const Text(
          'Peak',
          style: TextStyle(
            color: Color(0xFF172033),
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _TripDetailsDropdown extends StatefulWidget {
  const _TripDetailsDropdown({
    required this.destination,
    required this.route,
    required this.ongoing,
    required this.onStop,
  });

  final DestinationCandidate? destination;
  final TransitOption route;
  final bool ongoing;
  final VoidCallback onStop;

  @override
  State<_TripDetailsDropdown> createState() => _TripDetailsDropdownState();
}

class _TripDetailsDropdownState extends State<_TripDetailsDropdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final destination = widget.destination?.name ?? 'Destination';
    final nextLeg = route.legs.isEmpty ? null : route.legs.first;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .58,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2D001844),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: route.color,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.alt_route_rounded),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        destination,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        '${route.label} / ${route.time} / ${route.distance}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: route.time == 'Calculating'
                              ? Colors.black
                              : const Color(0xFF687386),
                          fontWeight: route.time == 'Calculating'
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      if (widget.ongoing)
                        const Text(
                          'On Going',
                          style: TextStyle(
                            color: TrasiaColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: _expanded ? 'Hide details' : 'Show details',
                  onPressed: () => setState(() => _expanded = !_expanded),
                  icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF172033),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Stop navigation',
                  onPressed: widget.onStop,
                  icon: const Icon(Icons.stop_rounded),
                ),
              ],
            ),
            if (_expanded && nextLeg != null) ...[
              const SizedBox(height: 10),
              _NextLegCard(leg: nextLeg),
            ],
            if (_expanded && route.legs.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (var i = 0; i < route.legs.length; i++)
                _TripLegRow(
                  leg: route.legs[i],
                  active: i == 0,
                  isLast: i == route.legs.length - 1,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextLegCard extends StatelessWidget {
  const _NextLegCard({required this.leg});

  final RouteLeg leg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF8FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF22C7F4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me_rounded, color: TrasiaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next: ${leg.toName}',
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${leg.mode} / ${leg.time} / ${leg.distance}',
                  style: TextStyle(
                    color: leg.time == 'Calculating'
                        ? Colors.black
                        : const Color(0xFF687386),
                    fontWeight: leg.time == 'Calculating'
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripLegRow extends StatelessWidget {
  const _TripLegRow({
    required this.leg,
    required this.active,
    required this.isLast,
  });

  final RouteLeg leg;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = active ? const Color(0xFF22C7F4) : const Color(0xFF8FB7E8);
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: color,
                foregroundColor: Colors.white,
                child: Icon(leg.icon, size: 17),
              ),
              if (!isLast)
                Container(
                  width: 3,
                  height: 32,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: const Color(0xFFE0E7F0),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: active
                    ? const Color(0xFFEAF8FF)
                    : const Color(0xFFF7F9FC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${leg.fromName} to ${leg.toName}',
                    style: const TextStyle(
                      color: Color(0xFF172033),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${leg.mode} / ${leg.time} / ${leg.distance}',
                    style: TextStyle(
                      color: leg.time == 'Calculating'
                          ? Colors.black
                          : const Color(0xFF687386),
                      fontWeight: leg.time == 'Calculating'
                          ? FontWeight.w700
                          : FontWeight.normal,
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

class _MapLoadingPill extends StatefulWidget {
  const _MapLoadingPill();

  @override
  State<_MapLoadingPill> createState() => _MapLoadingPillState();
}

class _MapLoadingPillState extends State<_MapLoadingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              size: const Size(64, 64),
              painter: _SegmentedSpinnerPainter(_controller.value),
            );
          },
        ),
      ],
    );
  }
}

class _SegmentedSpinnerPainter extends CustomPainter {
  _SegmentedSpinnerPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final strokeWidth = size.width * 0.16;
    final radius = size.width / 2 - strokeWidth / 2;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    const segmentCount = 12;
    const sweepAngle = (2 * pi / segmentCount) * 0.75;

    final step = (progress * segmentCount).floor();

    for (int i = 0; i < segmentCount; i++) {
      final startAngle = (i * 2 * pi / segmentCount) - pi / 2;

      int distance = (step - i) % segmentCount;
      if (distance < 0) distance += segmentCount;

      final opacity = 1.0 - (distance / segmentCount);

      paint.color = const Color(0xFF26648E).withValues(alpha: opacity);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentedSpinnerPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver});

  final Driver driver;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: driver.color.withValues(alpha: 0.15),
          child: Icon(Icons.directions_car_filled_rounded, color: driver.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                driver.name,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '${driver.vehicle} / rating ${driver.rating}',
                style: const TextStyle(color: Color(0xFF667085)),
              ),
            ],
          ),
        ),
        const Icon(Icons.star_rounded, color: Color(0xFFFFCE3D)),
      ],
    );
  }
}

class _PlanSlider extends StatelessWidget {
  const _PlanSlider({
    required this.icon,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF40A9FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                valueLabel,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueLabel,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _PlanSectionTitle extends StatelessWidget {
  const _PlanSectionTitle({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE9F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120B7CFF),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: TrasiaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF102033),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            trailing,
            style: const TextStyle(
              color: Color(0xFF68788C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPanel extends StatelessWidget {
  const _PlanPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFDCE9F8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F174A7E),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BlindBoxTravelModeSelector extends StatelessWidget {
  const _BlindBoxTravelModeSelector({
    required this.value,
    required this.onChanged,
  });

  final BlindBoxTravelMode value;
  final ValueChanged<BlindBoxTravelMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(value.icon, size: 18, color: const Color(0xFF40A9FF)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Travel mode',
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                value.label,
                style: const TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<BlindBoxTravelMode>(
            segments: const [
              ButtonSegment(
                value: BlindBoxTravelMode.drive,
                icon: Icon(Icons.directions_car_rounded),
                label: Text('Drive'),
              ),
              ButtonSegment(
                value: BlindBoxTravelMode.transit,
                icon: Icon(Icons.directions_transit_rounded),
                label: Text('Transit'),
              ),
            ],
            selected: {value},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => onChanged(selection.first),
          ),
        ],
      ),
    );
  }
}

enum _MapStopAction { proceed, cancel }

class _FeatureCResultsToggle extends StatelessWidget {
  const _FeatureCResultsToggle({
    required this.count,
    required this.expanded,
    required this.onTap,
  });

  final int count;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      key: const Key('feature-c-results-toggle'),
      heroTag: 'feature-c-results-toggle',
      onPressed: onTap,
      backgroundColor: TrasiaColors.primary,
      foregroundColor: Colors.white,
      icon: Icon(expanded ? Icons.close_rounded : Icons.list_alt_rounded),
      label: Text(expanded ? 'Hide results' : '$count results'),
    );
  }
}

class _FeatureCTripCompletedBanner extends StatelessWidget {
  const _FeatureCTripCompletedBanner({required this.onPlanAnotherTrip});

  final VoidCallback onPlanAnotherTrip;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33001844),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Icon(Icons.flag_rounded, color: TrasiaColors.primary),
              const Text(
                'Trip completed',
                style: TextStyle(
                  color: Color(0xFF172033),
                  fontWeight: FontWeight.w900,
                ),
              ),
              FilledButton.icon(
                onPressed: onPlanAnotherTrip,
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Plan another trip'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              minHeight: 8,
              value: 1,
              backgroundColor: Color(0x3322C7F4),
              color: TrasiaColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCResultsSheet extends StatelessWidget {
  const _FeatureCResultsSheet({
    required this.stops,
    required this.priceTier,
    required this.ongoingDestination,
    required this.tripStatus,
    required this.activeStopIndex,
    required this.tripTotalStops,
    required this.completedStopCount,
    required this.completedStopNames,
    required this.onClose,
    required this.onCancel,
    required this.onFocusStop,
    required this.onChooseRoute,
    required this.onStartTrip,
    required this.onArrived,
    required this.onNextPlace,
    required this.onFinishTrip,
  });

  final List<ItineraryStop> stops;
  final PriceTier priceTier;
  final String? ongoingDestination;
  final FeatureCTripStatus tripStatus;
  final int activeStopIndex;
  final int tripTotalStops;
  final int completedStopCount;
  final Set<String> completedStopNames;
  final VoidCallback onClose;
  final Future<bool> Function(ItineraryStop stop) onCancel;
  final ValueChanged<ItineraryStop> onFocusStop;
  final ValueChanged<String> onChooseRoute;
  final VoidCallback onStartTrip;
  final VoidCallback onArrived;
  final VoidCallback onNextPlace;
  final VoidCallback onFinishTrip;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          key: const Key('feature-c-results-list'),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .56,
          ),
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFDCE9F8)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24174A7E),
                blurRadius: 26,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.list_alt_rounded,
                        color: Color(0xFF40A9FF),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Results',
                          style: TextStyle(
                            color: Color(0xFF172033),
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Hide results',
                        onPressed: onClose,
                        icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _FeatureCTripProgressPanel(
                    stops: stops,
                    status: tripStatus,
                    activeStopIndex: activeStopIndex,
                    totalStops: tripTotalStops,
                    completedStops: completedStopCount,
                    onStartTrip: onStartTrip,
                    onArrived: onArrived,
                    onNextPlace: onNextPlace,
                    onFinishTrip: onFinishTrip,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: stops.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        return Dismissible(
                          key: ValueKey(
                            'itinerary-${stops[i].attraction.name}',
                          ),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) => onCancel(stops[i]),
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 18),
                            decoration: BoxDecoration(
                              color: TrasiaColors.primary,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Colors.white,
                            ),
                          ),
                          child: _ItineraryStopCard(
                            stop: stops[i],
                            active:
                                i == activeStopIndex &&
                                !completedStopNames.contains(
                                  stops[i].attraction.name,
                                ) &&
                                tripStatus != FeatureCTripStatus.notStarted,
                            completed: completedStopNames.contains(
                              stops[i].attraction.name,
                            ),
                            arrived:
                                i == activeStopIndex &&
                                tripStatus == FeatureCTripStatus.arrived,
                            ongoing:
                                ongoingDestination == stops[i].attraction.name,
                            onFocus: () => onFocusStop(stops[i]),
                            onNavigate: () =>
                                onChooseRoute(stops[i].attraction.name),
                          ),
                        );
                      },
                    ),
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

class _MapStopActionSheet extends StatelessWidget {
  const _MapStopActionSheet({required this.stop, required this.canGo});

  final ItineraryStop stop;
  final bool canGo;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          key: const Key('feature-c-stop-details'),
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      stop.attraction.imageAsset,
                      width: 76,
                      height: 76,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 76,
                        height: 76,
                        color: stop.attraction.color,
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
                          stop.attraction.name,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontSize: 19,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${_formatClock(stop.startMinute)} - ${_formatClock(stop.endMinute)} / ${stop.attraction.hours}',
                          style: const TextStyle(color: Color(0xFF687386)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MapStopDetailRow(
                icon: Icons.schedule_rounded,
                text:
                    '${_formatClock(stop.startMinute)} - ${_formatClock(stop.endMinute)}',
              ),
              _MapStopDetailRow(
                icon: Icons.access_time_rounded,
                text: 'Opening hours: ${stop.attraction.hours}',
              ),
              _MapStopDetailRow(
                icon: Icons.route_rounded,
                text: 'Distance: ${stop.distanceKm.toStringAsFixed(1)} km',
              ),
              _MapStopDetailRow(
                icon: stop.travelMode.icon,
                text: stop.travelMinutes == 0
                    ? 'Start point / ${stop.travelMode.label}'
                    : '${stop.travelMode.label}: ${stop.travelMinutes} min',
              ),
              _MapStopDetailRow(
                icon: Icons.payments_rounded,
                text: 'Cost: RM ${stop.cost}',
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: canGo
                      ? () => Navigator.of(context).pop(_MapStopAction.proceed)
                      : null,
                  style: FilledButton.styleFrom(
                    foregroundColor: Colors.black,
                    disabledBackgroundColor: const Color(0xFFE9EEF5),
                    disabledForegroundColor: const Color(0xFF475467),
                  ),
                  icon: Icon(
                    canGo ? Icons.navigation_rounded : Icons.schedule_rounded,
                  ),
                  label: Text(canGo ? 'Going' : 'Queue'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_MapStopAction.cancel),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.cancel_rounded),
                  label: const Text('Cancel this stop'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapStopDetailRow extends StatelessWidget {
  const _MapStopDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TrasiaColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF41556B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCTripProgressPanel extends StatelessWidget {
  const _FeatureCTripProgressPanel({
    required this.stops,
    required this.status,
    required this.activeStopIndex,
    required this.totalStops,
    required this.completedStops,
    required this.onStartTrip,
    required this.onArrived,
    required this.onNextPlace,
    required this.onFinishTrip,
  });

  final List<ItineraryStop> stops;
  final FeatureCTripStatus status;
  final int activeStopIndex;
  final int totalStops;
  final int completedStops;
  final VoidCallback onStartTrip;
  final VoidCallback onArrived;
  final VoidCallback onNextPlace;
  final VoidCallback onFinishTrip;

  @override
  Widget build(BuildContext context) {
    final safeIndex = activeStopIndex
        .clamp(0, max(0, stops.length - 1))
        .toInt();
    final activeStop = stops.isEmpty ? null : stops[safeIndex];
    final total = max(1, totalStops == 0 ? stops.length : totalStops);
    final completed = completedStops.clamp(0, total).toDouble();
    final progress = switch (status) {
      FeatureCTripStatus.notStarted => 0.0,
      FeatureCTripStatus.traveling => completed / total,
      FeatureCTripStatus.arrived => min(1.0, (completed + .5) / total),
      FeatureCTripStatus.completed => 1.0,
    };
    final title = switch (status) {
      FeatureCTripStatus.notStarted => 'Ready to start',
      FeatureCTripStatus.traveling =>
        'Going to ${activeStop?.attraction.name ?? 'next place'}',
      FeatureCTripStatus.arrived =>
        'Arrived at ${activeStop?.attraction.name ?? 'this place'}',
      FeatureCTripStatus.completed => 'Trip completed',
    };
    final subtitle = switch (status) {
      FeatureCTripStatus.notStarted => '$total places queued',
      FeatureCTripStatus.traveling =>
        'Completed ${completed.toInt()} of $total',
      FeatureCTripStatus.arrived =>
        completedStops >= total - 1
            ? 'Last place reached'
            : 'Current place will be removed from the list',
      FeatureCTripStatus.completed => 'End of itinerary',
    };
    final String actionLabel;
    final VoidCallback? actionCallback;
    switch (status) {
      case FeatureCTripStatus.notStarted:
        actionLabel = 'Start Trip';
        actionCallback = onStartTrip;
        break;
      case FeatureCTripStatus.traveling:
        actionLabel = 'Arrived';
        actionCallback = onArrived;
        break;
      case FeatureCTripStatus.arrived:
        actionLabel = safeIndex >= stops.length - 1
            ? 'Finish Trip'
            : 'Next Place';
        actionCallback = safeIndex >= stops.length - 1
            ? onFinishTrip
            : onNextPlace;
        break;
      case FeatureCTripStatus.completed:
        actionLabel = 'Completed';
        actionCallback = null;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBFD9FA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline_rounded, color: Color(0xFF40A9FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFF41556B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  FilledButton(
                    onPressed: actionCallback,
                    child: Text(actionLabel),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress.clamp(0, 1).toDouble(),
              backgroundColor: const Color(0x3322C7F4),
              color: TrasiaColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItineraryStopCard extends StatelessWidget {
  const _ItineraryStopCard({
    required this.stop,
    required this.active,
    required this.completed,
    required this.arrived,
    required this.ongoing,
    required this.onFocus,
    required this.onNavigate,
  });

  final ItineraryStop stop;
  final bool active;
  final bool completed;
  final bool arrived;
  final bool ongoing;
  final VoidCallback onFocus;
  final VoidCallback onNavigate;

  @override
  Widget build(BuildContext context) {
    final statusLabel = completed
        ? 'Done'
        : arrived
        ? 'Arrived'
        : active
        ? 'Going'
        : 'Queued';
    final statusIcon = completed
        ? Icons.check_circle_rounded
        : arrived
        ? Icons.place_rounded
        : active
        ? Icons.navigation_rounded
        : Icons.radio_button_unchecked_rounded;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onFocus,
      child: _PlanPanel(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                stop.attraction.imageAsset,
                width: 84,
                height: 84,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 84,
                  height: 84,
                  color: stop.attraction.color,
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          stop.attraction.name,
                          style: const TextStyle(
                            color: Color(0xFF172033),
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ItineraryDetailRow(
                    icon: Icons.schedule_rounded,
                    text:
                        '${_formatClock(stop.startMinute)} - ${_formatClock(stop.endMinute)}',
                  ),
                  _ItineraryDetailRow(
                    icon: Icons.access_time_rounded,
                    text: 'Opening hours: ${stop.attraction.hours}',
                  ),
                  _ItineraryDetailRow(
                    icon: Icons.route_rounded,
                    text: 'Distance: ${stop.distanceKm.toStringAsFixed(1)} km',
                  ),
                  _ItineraryDetailRow(
                    icon: stop.travelMode.icon,
                    text: stop.travelMinutes == 0
                        ? 'Start point / ${stop.travelMode.label}'
                        : '${stop.travelMode.label}: ${stop.travelMinutes} min',
                  ),
                  _ItineraryDetailRow(
                    icon: Icons.payments_rounded,
                    text: 'Cost: RM ${stop.cost}',
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: active && !arrived && !completed
                          ? onNavigate
                          : onFocus,
                      icon: Icon(statusIcon),
                      label: Text(ongoing ? 'On Going' : statusLabel),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItineraryDetailRow extends StatelessWidget {
  const _ItineraryDetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: TrasiaColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF41556B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _LedgerRow extends StatelessWidget {
  const _LedgerRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
