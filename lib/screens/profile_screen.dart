import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../widgets/elite_header.dart';
import '../widgets/elite_card.dart';
import '../widgets/custom_toast.dart';

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
      body: Column(
        children: [
          const EliteHeader(
            title: 'Settings',
            showBackButton: true,
            showGreeting: false,
          ),
          Expanded(
            child: uid == null
                ? _buildAccessRestricted()
                : _buildProfileContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildAccessRestricted() {
    return Center(
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

  Widget _buildProfileContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          EliteCard(
            glowColor: Colors.purpleAccent,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      hintText: 'Enter your name',
                      prefixIcon: const Icon(Icons.person_outline, size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdatingName ? null : _updateName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                      ),
                      child: _isUpdatingName 
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Update Name', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Settings Section
          const Text(
            'SETTINGS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          EliteCard(
            glowColor: Colors.blueAccent,
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Alpha Signals & Radar', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Receive push alerts for Volume Spikes & Trend Breakouts', style: TextStyle(fontSize: 12)),
                  value: _backgroundAlertsEnabled,
                  onChanged: _isLoadingPrefs ? null : _toggleBackgroundAlerts,
                  activeThumbColor: Colors.blueAccent,
                  secondary: const Icon(Icons.radar_rounded, color: Colors.blueAccent),
                ),
                const Divider(color: Colors.white10, height: 1),
                SwitchListTile(
                  title: const Text('App Lock', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Secure access with Biometrics / FaceID', style: TextStyle(fontSize: 12)),
                  value: _appLockEnabled,
                  onChanged: _isLoadingPrefs ? null : _toggleAppLock,
                  activeThumbColor: Colors.greenAccent,
                  secondary: const Icon(Icons.fingerprint_rounded, color: Colors.greenAccent),
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
