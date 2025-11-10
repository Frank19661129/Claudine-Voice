import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';
import 'transactions_screen.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool o365Authenticated;
  final String o365User;
  final bool googleAuthenticated;
  final String googleUser;
  final String? activeProvider;
  final Function(String provider) onSetPrimaryProvider;
  final Function(String provider) onLogin;
  final Function(String provider) onLogout;
  final String locationName;
  final String locationStreet;
  final String locationInfo;
  final VoidCallback? onUserLogout;  // New: callback for user account logout

  const SettingsScreen({
    super.key,
    required this.o365Authenticated,
    required this.o365User,
    required this.googleAuthenticated,
    required this.googleUser,
    required this.activeProvider,
    required this.onSetPrimaryProvider,
    required this.onLogin,
    required this.onLogout,
    this.locationName = '',
    this.locationStreet = '',
    this.locationInfo = '',
    this.onUserLogout,  // New: optional callback
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User Account Section
          _buildSectionHeader('User Account'),
          const SizedBox(height: 8),
          _buildUserAccountCard(context),
          const SizedBox(height: 24),

          // Mailbox Accounts Section
          _buildSectionHeader('Mailbox Accounts'),
          const SizedBox(height: 8),

          // O365 Card
          _buildProviderCard(
            context,
            provider: 'o365',
            title: 'Office 365',
            icon: Icons.business,
            color: Colors.blue,
            isAuthenticated: widget.o365Authenticated,
            userName: widget.o365User,
            isPrimary: widget.activeProvider == 'o365',
          ),

          const SizedBox(height: 12),

          // Google Card
          _buildProviderCard(
            context,
            provider: 'google',
            title: 'Google',
            icon: Icons.email,
            color: Colors.red,
            isAuthenticated: widget.googleAuthenticated,
            userName: widget.googleUser,
            isPrimary: widget.activeProvider == 'google',
          ),

          const SizedBox(height: 24),

          // Location Section
          if (widget.locationName.isNotEmpty || widget.locationStreet.isNotEmpty) ...[
            _buildSectionHeader('Location'),
            const SizedBox(height: 8),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.locationStreet.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.home, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.locationStreet,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (widget.locationName.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(Icons.location_city, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.locationName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.locationInfo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.gps_fixed, color: Colors.grey, size: 16),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.locationInfo,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Transaction Monitor Section
          _buildSectionHeader('System'),
          const SizedBox(height: 8),

          Card(
            child: ListTile(
              leading: const Icon(Icons.list_alt, color: Colors.orange),
              title: const Text('Transaction Monitor'),
              subtitle: const Text('View and retry failed transactions'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TransactionsScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context, {
    required String provider,
    required String title,
    required IconData icon,
    required Color color,
    required bool isAuthenticated,
    required String userName,
    required bool isPrimary,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon, title and star
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                // Star indicator for primary provider - ALWAYS SHOW IF PRIMARY
                if (isPrimary)
                  const Icon(
                    Icons.star,
                    color: Colors.amber,
                    size: 32,
                  )
                else
                  // Empty space to maintain layout
                  const SizedBox(width: 32),
              ],
            ),

            const SizedBox(height: 12),

            // User info or status
            if (isAuthenticated) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userName.isNotEmpty ? userName : 'Authenticated',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action buttons for authenticated provider
              Row(
                children: [
                  if (!isPrimary)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => widget.onSetPrimaryProvider(provider),
                        icon: const Icon(Icons.star_outline, size: 16),
                        label: const Text('Set as Primary'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: color,
                        ),
                      ),
                    ),
                  if (!isPrimary) const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => widget.onLogout(provider),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('Logout'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Login button for unauthenticated provider
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => widget.onLogin(provider),
                  icon: const Icon(Icons.login),
                  label: const Text('Login'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Build User Account Card showing currently logged-in user
  Widget _buildUserAccountCard(BuildContext context) {
    final userName = authService.userName;
    final userEmail = authService.userEmail;
    final loginProvider = authService.loginProvider;
    final isLoggedIn = userName != null && userEmail != null;

    // Determine icon based on login provider
    Widget providerIcon;
    Color iconColor;

    if (loginProvider == 'google') {
      providerIcon = Image.asset(
        'assets/google_g_icon.png',
        height: 28,
        width: 28,
        errorBuilder: (context, error, stackTrace) {
          // Fallback: use a colored circle with G
          return Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: Color(0xFF4285F4),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'G',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          );
        },
      );
      iconColor = const Color(0xFF4285F4); // Google blue
    } else if (loginProvider == 'microsoft') {
      providerIcon = Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.blue.shade700,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.business,
          color: Colors.white,
          size: 18,
        ),
      );
      iconColor = Colors.blue.shade700;
    } else {
      // Default person icon
      providerIcon = const Icon(Icons.person, size: 28);
      iconColor = Colors.blue;
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                providerIcon,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isLoggedIn ? userName! : 'Not logged in',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            if (isLoggedIn) ...[
              const SizedBox(height: 12),

              // Email
              Row(
                children: [
                  const Icon(Icons.email_outlined, color: Colors.grey, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      userEmail!,
                      style: const TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Logout'),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      await authService.logout();
                      widget.onUserLogout?.call();
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                'Please login to use Claudine Voice',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
