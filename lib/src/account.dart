part of '../main.dart';

class AccountConsoleScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (role == UserRole.admin) {
      return _AdminConsole(
        email: email,
        savedTransitRoutes: savedTransitRoutes,
        hubPoolTransactions: hubPoolTransactions,
        carbonSavedKg: carbonSavedKg,
        onLogout: onLogout,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      children: [
        const _SectionTitle(
          icon: Icons.account_balance_wallet_rounded,
          title: 'User Wallet',
          trailing: 'SDG 9 log',
        ),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: TextStyle(color: Colors.white.withValues(alpha: .72)),
              ),
              const SizedBox(height: 10),
              Text(
                'RM ${wallet.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Available app credit for Hub-Pool rides',
                style: TextStyle(color: Colors.white.withValues(alpha: .72)),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton(
                    onPressed: () => onTopUp(20),
                    child: const Text('Top Up RM20'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => onTopUp(50),
                    child: const Text('Top Up RM50'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassPanel(
          child: Column(
            children: [
              _LedgerRow('Saved transit routes', '$savedTransitRoutes'),
              _LedgerRow('Hub-Pool transactions', '$hubPoolTransactions'),
              _LedgerRow(
                'Carbon saved',
                '${carbonSavedKg.toStringAsFixed(1)} kg CO2e',
              ),
              const _LedgerRow('Green travel score', '91 / 100'),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminConsole extends StatelessWidget {
  const _AdminConsole({
    required this.email,
    required this.savedTransitRoutes,
    required this.hubPoolTransactions,
    required this.carbonSavedKg,
    required this.onLogout,
  });

  final String email;
  final int savedTransitRoutes;
  final int hubPoolTransactions;
  final double carbonSavedKg;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final users = [
      ('Aina Rahman', 'RM 128.40', 'Active'),
      ('Ben Tan', 'RM 42.00', 'Frozen'),
      ('Chong Wei', 'RM 305.20', 'Active'),
      ('Deepa Kumar', 'RM 76.80', 'Active'),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
      children: [
        const _SectionTitle(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Admin Console',
          trailing: 'CRUD demo',
        ),
        _GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: TextStyle(color: Colors.white.withValues(alpha: .72)),
              ),
              const SizedBox(height: 12),
              for (final user in users)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: TrasiaColors.primary,
                        child: Text(user.$1.substring(0, 1)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.$1,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text('${user.$2} / ${user.$3}'),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Adjust credit',
                        onPressed: () {},
                        icon: const Icon(Icons.tune_rounded),
                      ),
                      IconButton(
                        tooltip: 'Freeze profile',
                        onPressed: () {},
                        icon: const Icon(Icons.lock_rounded),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _GlassPanel(
          child: Column(
            children: [
              const _LedgerRow('GTFS cache status', 'Loaded'),
              _LedgerRow('Saved transit routes', '$savedTransitRoutes'),
              _LedgerRow('Hub-Pool transactions', '$hubPoolTransactions'),
              _LedgerRow(
                'Carbon saved',
                '${carbonSavedKg.toStringAsFixed(1)} kg CO2e',
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
