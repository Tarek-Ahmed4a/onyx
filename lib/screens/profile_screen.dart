import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../widgets/elite_header.dart';
import '../widgets/elite_card.dart';
import '../widgets/custom_toast.dart';
import 'calendar_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _backgroundAlertsEnabled = true;
  bool _appLockEnabled = false;
  bool _isLoadingPrefs = true;
  final TextEditingController _nameController = TextEditingController();
  bool _isUpdatingName = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _nameController.text = FirebaseAuth.instance.currentUser?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _updateName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    setState(() => _isUpdatingName = true);

    try {
      await user.updateDisplayName(newName);
      await user.reload();
      
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Name updated successfully | GOOD LUCK',
          icon: Icons.check_circle_outline,
          color: Colors.greenAccent,
        );
      }
    } catch (e) {
      if (mounted) {
        CustomToast.show(
          context: context,
          message: 'Failed to update name',
          icon: Icons.error_outline,
          color: Colors.redAccent,
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingName = false);
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _backgroundAlertsEnabled = prefs.getBool('background_alerts_enabled') ?? true;
      _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
      _isLoadingPrefs = false;
    });
  }

  Future<void> _toggleBackgroundAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('background_alerts_enabled', value);
    setState(() {
      _backgroundAlertsEnabled = value;
    });

    if (value) {
      await NotificationService().subscribeToMarketOpportunities();
    } else {
      // Unsubscribe logic could be added here
      debugPrint("FCM Topic Unsubscription not implemented in this UI demo.");
    }
  }

  Future<void> _toggleAppLock(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_lock_enabled', value);
    setState(() {
      _appLockEnabled = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.black,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.black,
            floating: true,
            pinned: true,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.calendar_today_outlined, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CalendarScreen()),
                  );
                },
              ),
            ],
          ),
          const SliverToBoxAdapter(
            child: EliteHeader(
              title: 'Preferences & Profile',
              showBackButton: false,
              showGreeting: false,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            sliver: uid == null
                ? SliverToBoxAdapter(child: _buildAccessRestricted())
                : _buildProfileSliverContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessRestricted() {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Access Restricted',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 8),
          const Text(
            'Please sign in to view your profile.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            child: const Text('Sign In'),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSliverContent() {
    return SliverList(
      delegate: SliverChildListDelegate([
        const SizedBox(height: 10),
        const Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFF1E1E1E),
            child: Icon(Icons.person, size: 40, color: Colors.white),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            FirebaseAuth.instance.currentUser?.displayName ?? 'Onyx User',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 32),
        
        // Personal Information Section
        const Text(
          'PERSONAL INFORMATION',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        EliteCard(
          glowColor: Colors.purpleAccent,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: const TextStyle(fontSize: 12),
                  hintText: 'Enter your name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isUpdatingName ? null : _updateName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                child: _isUpdatingName 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Update Name', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        
        // Settings Section
        const Text(
          'SETTINGS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        EliteCard(
          glowColor: Colors.blueAccent,
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              _buildSettingRow(
                icon: Icons.radar_rounded,
                color: Colors.blueAccent,
                title: 'Alpha Signals & Radar',
                subtitle: 'Push alerts for Volume Spikes & Breakouts',
                value: _backgroundAlertsEnabled,
                onChanged: _isLoadingPrefs ? null : _toggleBackgroundAlerts,
              ),
              const Divider(color: Colors.white10, height: 16),
              _buildSettingRow(
                icon: Icons.fingerprint_rounded,
                color: Colors.greenAccent,
                title: 'App Lock',
                subtitle: 'Secure access with Biometrics / FaceID',
                value: _appLockEnabled,
                onChanged: _isLoadingPrefs ? null : _toggleAppLock,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 48),
        
        // Sign Out Button
        ElevatedButton(
          onPressed: () => _confirmSignOut(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5)),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.logout_rounded),
              SizedBox(width: 12),
              Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
    }
  }
}
