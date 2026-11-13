import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';
import 'auth_controller.dart';
import 'calendar_page.dart';
import 'ferms_animations.dart';
import 'feedback_page.dart';
import 'ferms_models.dart';
import 'ferms_repository.dart';
import 'reservation_form.dart';
import 'reservations_page.dart';
import 'resources_page.dart';

class FermsApp extends StatefulWidget {
  const FermsApp({super.key, required this.api, required this.repository});

  final FermsApiClient api;
  final FermsRepository repository;

  @override
  State<FermsApp> createState() => _FermsAppState();
}

class _FermsAppState extends State<FermsApp> with WidgetsBindingObserver {
  late final AuthController _auth;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _darkMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTheme();
    _auth = AuthController(
      api: widget.api,
      repository: widget.repository,
      baseUrl: const String.fromEnvironment('API_BASE_URL'),
    )..addListener(_onAuthChanged);
    _auth.initialize();
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  Future<void> _loadTheme() async {
    final value = await _storage.read(key: 'ferms_dark_mode');
    if (mounted && value != null) {
      setState(() => _darkMode = value == 'true');
    }
  }

  Future<void> _setDarkMode(bool value) async {
    try {
      await _storage.write(key: 'ferms_dark_mode', value: '$value');
      if (mounted) setState(() => _darkMode = value);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not save appearance preference: $error'),
          ),
        );
      }
    }
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _auth
      ..removeListener(_onAuthChanged)
      ..dispose();
    WidgetsBinding.instance.removeObserver(this);
    widget.api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MCC FERMS',
    debugShowCheckedModeBanner: false,
    theme: _buildTheme(Brightness.light),
    darkTheme: _buildTheme(Brightness.dark),
    themeMode: _darkMode ? ThemeMode.dark : ThemeMode.light,
    themeAnimationDuration:
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 650),
    themeAnimationCurve: Curves.easeInOut,
    home: _auth.loading
        ? const _LoadingScreen()
        : _auth.user == null
        ? _SignInScreen(auth: _auth)
        : _FermsHome(
            auth: _auth,
            repository: widget.repository,
            darkMode: _darkMode,
            onDarkModeChanged: _setDarkMode,
          ),
  );

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1769AA),
      primary: const Color(0xFF1769AA),
      brightness: brightness,
      surface: brightness == Brightness.light ? const Color(0xFFFAFAF8) : null,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(0, 48)),
      ),
    );
  }
}

class _SignInScreen extends StatelessWidget {
  const _SignInScreen({required this.auth});
  final AuthController auth;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F7FC),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 900;
          if (wide) {
            return Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF287FC1), Color(0xFF0B3768)],
                      ),
                    ),
                    padding: const EdgeInsets.all(56),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _BrandLockup(onDark: true),
                        FermsAppear(
                          index: 1,
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.account_balance_outlined,
                                size: 72,
                                color: Color(0x33FFFFFF),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'Your campus,\nready when you are.',
                                style: TextStyle(
                                  fontSize: 42,
                                  height: 1.12,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'A simpler way to reserve facilities and equipment at Mabalacat City College.',
                                style: TextStyle(
                                  color: Color(0xFFDCEEFF),
                                  fontSize: 16,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'MABALACAT CITY COLLEGE',
                          style: TextStyle(
                            color: Color(0xFFDCEEFF),
                            fontSize: 11,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: FermsAppear(
                          index: 1,
                          child: _SignInCard(auth: auth),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 56,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const FermsAppear(child: _BrandLockup(onDark: false)),
                      const SizedBox(height: 28),
                      FermsAppear(index: 1, child: _SignInCard(auth: auth)),
                      const SizedBox(height: 24),
                      const Text(
                        'MABALACAT CITY COLLEGE',
                        style: TextStyle(
                          color: Color(0xFF7C7E80),
                          fontSize: 10,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.onDark});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : const Color(0xFF282526);
    final secondary = onDark
        ? const Color(0xFFDCEEFF)
        : const Color(0xFF747477);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: onDark ? Colors.white.withValues(alpha: 0.14) : Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            Icons.account_balance_outlined,
            color: onDark ? Colors.white : const Color(0xFF1769AA),
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MCC FERMS',
              style: TextStyle(
                color: foreground,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'FACILITY & EQUIPMENT RESERVATIONS',
              style: TextStyle(
                color: secondary,
                fontSize: 9,
                letterSpacing: 0.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE9E6E3)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x120E1420),
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F2FC),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.waving_hand_outlined,
            color: Color(0xFF1769AA),
            size: 22,
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Welcome back',
          style: TextStyle(
            color: Color(0xFF282526),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in with your Mabalacat City College Microsoft account to continue.',
          style: TextStyle(color: Color(0xFF747477), fontSize: 14, height: 1.5),
        ),
        if (auth.error != null) ...[
          const SizedBox(height: 20),
          _ErrorBanner(auth.error!),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: auth.signingIn ? null : auth.beginSignIn,
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: auth.signingIn
              ? const FermsLoadingIndicator(size: 20)
              : const Icon(Icons.login),
          label: Text(
            auth.signingIn ? 'Opening sign-in…' : 'Continue with Microsoft',
          ),
        ),
        const SizedBox(height: 16),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 15,
              color: Color(0xFF747477),
            ),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'MCC accounts ending in @mcc.edu.ph are required.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF747477), fontSize: 11),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FermsHome extends StatefulWidget {
  const _FermsHome({
    required this.auth,
    required this.repository,
    required this.darkMode,
    required this.onDarkModeChanged,
  });
  final AuthController auth;
  final FermsRepository repository;
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  @override
  State<_FermsHome> createState() => _FermsHomeState();
}

class _FermsHomeState extends State<_FermsHome> {
  int _section = 0;
  bool _history = false;
  bool _loading = true;
  String? _error;
  List<Reservation> _reservations = const [];
  List<Facility> _facilities = const [];
  List<Equipment> _equipment = const [];
  dynamic _dashboard;
  int _loadId = 0;
  bool _profileRequired = false;

  FermsUser get _user => widget.auth.user!;

  @override
  void initState() {
    super.initState();
    _profileRequired = _user.profileIncomplete;
    _load();
  }

  Future<void> _load({bool? history}) async {
    if (history != null) _history = history;
    final currentLoad = ++_loadId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        widget.repository.dashboard(),
        _profileRequired
            ? Future.value(<Reservation>[])
            : widget.repository.reservations(user: _user, history: _history),
        widget.repository.facilities(),
        widget.repository.equipment(),
      ]);
      if (!mounted || currentLoad != _loadId) return;
      setState(() {
        _dashboard = results[0];
        _reservations = results[1] as List<Reservation>;
        _facilities = results[2] as List<Facility>;
        _equipment = results[3] as List<Equipment>;
      });
    } catch (error) {
      if (mounted && currentLoad == _loadId) {
        if (error is ApiException && error.profileRequired) {
          setState(() => _profileRequired = true);
          await _load(history: _history);
        } else if (error is ApiException && error.statusCode == 403) {
          return;
        } else {
          setState(() => _error = error.toString());
        }
      }
    } finally {
      if (mounted && currentLoad == _loadId) setState(() => _loading = false);
    }
  }

  Future<void> _openRequest() async {
    if (_profileRequired || _user.profileIncomplete) {
      setState(() => _section = 4);
      return;
    }
    final changed = await Navigator.of(context).push<bool>(
      fermsPageRoute(
        ReservationForm(
          repository: widget.repository,
          facilities: _facilities,
          equipment: _equipment,
        ),
      ),
    );
    if (changed == true) await _load(history: false);
  }

  Future<void> _saveProfile(String organization, String position) async {
    await widget.repository.saveProfile(
      organization: organization,
      position: position,
    );
    final updatedUser = await widget.repository.me();
    if (mounted) {
      setState(() => _profileRequired = updatedUser.profileIncomplete);
    }
    widget.auth.setUser(updatedUser);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Profile updated.')));
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 820;
      final content = _buildSection();
      return Scaffold(
        appBar: AppBar(
          titleSpacing: wide ? 28 : 16,
          title: Row(
            children: [
              const Icon(
                Icons.account_balance_outlined,
                color: Color(0xFF1769AA),
              ),
              const SizedBox(width: 10),
              const Text(
                'MCC FERMS',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (wide)
                Text(
                  _user.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              const SizedBox(width: 8),
              Tooltip(
                message: widget.darkMode ? 'Use light mode' : 'Use dark mode',
                child: IconButton(
                  onPressed: () => widget.onDarkModeChanged(!widget.darkMode),
                  icon: Icon(
                    widget.darkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                ),
              ),
              Tooltip(
                message: 'Sign out',
                child: IconButton(
                  onPressed: widget.auth.signOut,
                  icon: const Icon(Icons.logout),
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _section == 0 || _section == 1
            ? FloatingActionButton.extended(
                onPressed: _openRequest,
                backgroundColor: const Color(0xFF1769AA),
                foregroundColor: Colors.white,
                icon: const Icon(Icons.add),
                label: const Text('New request'),
              )
            : null,
        body: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: _section,
                onDestinationSelected: (index) =>
                    setState(() => _section = index),
                labelType: NavigationRailLabelType.all,
                leading: Padding(
                  padding: const EdgeInsets.only(bottom: 14, top: 4),
                  child: Text(
                    _user.displayRole.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard),
                    label: Text('Overview'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: Text('Requests'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.apartment_outlined),
                    selectedIcon: Icon(Icons.apartment),
                    label: Text('Resources'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: Text('Calendar'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.account_circle_outlined),
                    selectedIcon: Icon(Icons.account_circle),
                    label: Text('Profile'),
                  ),
                ],
              ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  wide ? 26 : 18,
                  18,
                  wide ? 26 : 18,
                  8,
                ),
                child: _error != null
                    ? _PageError(message: _error!, onRetry: _load)
                    : content,
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: _section,
                onDestinationSelected: (index) =>
                    setState(() => _section = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.space_dashboard_outlined),
                    selectedIcon: Icon(Icons.space_dashboard),
                    label: 'Overview',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.event_note_outlined),
                    selectedIcon: Icon(Icons.event_note),
                    label: 'Requests',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.apartment_outlined),
                    selectedIcon: Icon(Icons.apartment),
                    label: 'Resources',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    selectedIcon: Icon(Icons.calendar_month),
                    label: 'Calendar',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.account_circle_outlined),
                    selectedIcon: Icon(Icons.account_circle),
                    label: 'Profile',
                  ),
                ],
              ),
      );
    },
  );

  Widget _buildSection() {
    if ((_profileRequired || _user.profileIncomplete) &&
        _section != 3 &&
        _section != 4) {
      return _ProfileRequired(onComplete: () => setState(() => _section = 4));
    }
    if (_loading && _reservations.isEmpty && _facilities.isEmpty) {
      return const Center(child: FermsLoadingIndicator());
    }
    return switch (_section) {
      0 => _DashboardPage(
        user: _user,
        dashboard: _dashboard,
        reservations: _reservations,
        facilities: _facilities,
        equipment: _equipment,
        onNewRequest: _openRequest,
        onRequests: () => setState(() => _section = 1),
        onRefresh: _load,
      ),
      1 => ReservationsPage(
        repository: widget.repository,
        user: _user,
        reservations: _reservations,
        facilities: _facilities,
        equipment: _equipment,
        loading: _loading,
        error: null,
        onRefresh: (history) => _load(history: history),
      ),
      2 => ResourcesPage(
        repository: widget.repository,
        user: _user,
        facilities: _facilities,
        equipment: _equipment,
        onRefresh: _load,
      ),
      3 => CalendarPage(repository: widget.repository),
      _ => _ProfilePage(
        user: _user,
        repository: widget.repository,
        onSave: _saveProfile,
        onSignOut: widget.auth.signOut,
      ),
    };
  }
}

class _DashboardPage extends StatelessWidget {
  const _DashboardPage({
    required this.user,
    required this.dashboard,
    required this.reservations,
    required this.facilities,
    required this.equipment,
    required this.onNewRequest,
    required this.onRequests,
    required this.onRefresh,
  });

  final FermsUser user;
  final dynamic dashboard;
  final List<Reservation> reservations;
  final List<Facility> facilities;
  final List<Equipment> equipment;
  final VoidCallback onNewRequest;
  final VoidCallback onRequests;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final data = asJsonMap(unwrapData(dashboard));
    final pending = intValue(
      data['pending_requests'] ?? data['pending'] ?? data['pending_count'],
      reservations.where((item) => item.isAwaitingDecision).length,
    );
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          FermsAppear(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Good day, ${user.name.split(' ').first}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  user.canManageResources
                      ? 'Facility and equipment activity at a glance.'
                      : 'Your campus requests and available resources.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FermsAppear(
            index: 1,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 4 : 2;
                return GridView.count(
                  crossAxisCount: columns,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.8,
                  children: [
                    _StatTile(
                      label: 'Pending',
                      value: '$pending',
                      icon: Icons.hourglass_top_outlined,
                      color: const Color(0xFF9A5A00),
                    ),
                    _StatTile(
                      label: 'Requests',
                      value: '${reservations.length}',
                      icon: Icons.event_note_outlined,
                      color: const Color(0xFF1769AA),
                    ),
                    _StatTile(
                      label: 'Facilities',
                      value: '${facilities.length}',
                      icon: Icons.apartment_outlined,
                      color: const Color(0xFF28664D),
                    ),
                    _StatTile(
                      label: 'Equipment',
                      value: '${equipment.length}',
                      icon: Icons.inventory_2_outlined,
                      color: const Color(0xFF455A64),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          FermsAppear(
            index: 2,
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: onNewRequest,
                  icon: const Icon(Icons.add),
                  label: const Text('New request'),
                ),
                OutlinedButton.icon(
                  onPressed: onRequests,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('View requests'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          FermsAppear(
            index: 3,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Upcoming requests',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton(
                  onPressed: onRequests,
                  child: const Text('All requests'),
                ),
              ],
            ),
          ),
          if (reservations.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('No upcoming requests to show.'),
            )
          else
            ...reservations.take(4).indexed.map((entry) {
              final reservation = entry.$2;
              return FermsAppear(
                index: entry.$1 + 4,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFE7F2FC),
                        foregroundColor: Color(0xFF1769AA),
                        child: Icon(Icons.event_outlined),
                      ),
                      title: Text(
                        reservation.purpose,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${reservation.date} · ${reservation.startTime}–${reservation.endTime}',
                      ),
                      trailing: Text(
                        reservation.status.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF9A5A00),
                        ),
                      ),
                      onTap: onRequests,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      border: const Border.fromBorderSide(BorderSide(color: Color(0xFFE7E6E2))),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfilePage extends StatefulWidget {
  const _ProfilePage({
    required this.user,
    required this.repository,
    required this.onSave,
    required this.onSignOut,
  });

  final FermsUser user;
  final FermsRepository repository;
  final Future<void> Function(String organization, String position) onSave;
  final VoidCallback onSignOut;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  static const _otherOrganization = '__other__';
  late final TextEditingController _customOrganization;
  late final TextEditingController _position;
  List<Organization> _organizations = const [];
  String _selectedOrganization = '';
  bool _loadingOrganizations = true;
  String? _organizationError;
  bool _saving = false;
  String? _error;

  Future<void> _openFeedback() => Navigator.of(context).push<void>(
    fermsPageRoute<void>(
      FeedbackPage(repository: widget.repository, user: widget.user),
    ),
  );

  @override
  void initState() {
    super.initState();
    _customOrganization = TextEditingController();
    _position = TextEditingController(text: widget.user.position);
    _loadOrganizations();
  }

  Future<void> _loadOrganizations() async {
    try {
      final organizations = await widget.repository.organizations();
      if (!mounted) return;
      final matching = organizations
          .where(
            (organization) => organization.name == widget.user.organization,
          )
          .firstOrNull;
      setState(() {
        _organizations = organizations;
        if (matching != null) {
          _selectedOrganization = matching.name;
        } else if (widget.user.organization.isNotEmpty) {
          _selectedOrganization = _otherOrganization;
          _customOrganization.text = widget.user.organization;
        }
        _loadingOrganizations = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _organizationError = error.toString();
          _loadingOrganizations = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _customOrganization.dispose();
    _position.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    if (_selectedOrganization == _otherOrganization) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_selectedOrganization, _position.text);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.only(bottom: 32),
    children: [
      Text(
        'Profile',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 20),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person_outline)),
        title: Text(widget.user.name),
        subtitle: Text(widget.user.email),
      ),
      const SizedBox(height: 8),
      Text('Role: ${widget.user.displayRole}'),
      const SizedBox(height: 8),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.rate_review_outlined),
        title: Text(
          widget.user.canViewFeedback
              ? 'Feedback inbox and submission'
              : 'Send feedback',
        ),
        subtitle: Text(
          widget.user.canViewFeedback
              ? 'View feedback or submit your own.'
              : 'Share a rating and comment with the administrators.',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openFeedback,
      ),
      if (widget.user.normalizedRole == 'student') ...[
        const SizedBox(height: 24),
        Text(
          'Organization details',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedOrganization),
                initialValue: _selectedOrganization,
                decoration: const InputDecoration(
                  labelText: 'Organization or institute council',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Choose an organization'),
                  ),
                  ..._organizations.map(
                    (organization) => DropdownMenuItem(
                      value: organization.name,
                      child: Text(organization.name),
                    ),
                  ),
                  const DropdownMenuItem(
                    value: _otherOrganization,
                    child: Text('Other (not listed)'),
                  ),
                ],
                onChanged: _saving || _loadingOrganizations
                    ? null
                    : (value) =>
                          setState(() => _selectedOrganization = value ?? ''),
                validator: (_) => _selectedOrganization.isEmpty
                    ? 'Choose your organization.'
                    : null,
              ),
              if (_selectedOrganization == _otherOrganization) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customOrganization,
                  enabled: !_saving,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Custom organization',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter your organization.'
                      : null,
                ),
                const SizedBox(height: 8),
                const _ErrorBanner(
                  'Custom organizations cannot be saved yet. The mobile profile API only accepts organizations from its managed list.',
                ),
              ],
              if (_organizationError != null) ...[
                const SizedBox(height: 10),
                _ErrorBanner(
                  'Could not load organization choices: $_organizationError',
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _loadingOrganizations = true;
                      _organizationError = null;
                    });
                    _loadOrganizations();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry organization list'),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _position,
                enabled: !_saving,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Position'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter your position.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _ErrorBanner(_error!),
              ],
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed:
                      _saving ||
                          _loadingOrganizations ||
                          _organizationError != null ||
                          _selectedOrganization == _otherOrganization
                      ? null
                      : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save profile'),
                ),
              ),
            ],
          ),
        ),
      ],
      if (widget.user.isSuperAdmin) ...[
        const SizedBox(height: 28),
        const _ErrorBanner(
          'IT Administrator account management is currently available on the web portal only. Laravel enforces the three-account limit.',
        ),
      ],
      const SizedBox(height: 28),
      OutlinedButton.icon(
        onPressed: widget.onSignOut,
        icon: const Icon(Icons.logout),
        label: const Text('Sign out'),
      ),
    ],
  );
}

class _ProfileRequired extends StatelessWidget {
  const _ProfileRequired({required this.onComplete});
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assignment_ind_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            'Complete your organization profile',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your organization or institute council and position before submitting a request.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onComplete,
            child: const Text('Complete profile'),
          ),
        ],
      ),
    ),
  );
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: FermsLoadingIndicator(size: 64)));
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 40,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFECEF),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(message, style: const TextStyle(color: Color(0xFF8A1C32))),
  );
}
