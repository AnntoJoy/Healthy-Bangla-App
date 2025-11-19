import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../auth/login_screen.dart';
import '../admin/admin_dashboard_screen.dart';
import 'reading_history_screen.dart';
import 'saved_articles_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  User? currentUser;
  Map<String, dynamic>? userProfile;
  Map<String, int> userStats = {
    'saved': 0,
    'read': 0,
    'days_active': 0,
  };
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);

    try {
      currentUser = supabase.auth.currentUser;

      if (currentUser != null) {
        // Load user profile
        try {
          final profileResponse = await supabase
              .from('users')
              .select('*')
              .eq('id', currentUser!.id)
              .single();
          userProfile = profileResponse;
        } catch (e) {
          print('Error loading user profile: $e');
          userProfile = {
            'id': currentUser!.id,
            'email': currentUser!.email,
            'name': currentUser!.userMetadata?['name'] ?? 'User',
            'role': 'user',
            'created_at': currentUser!.createdAt,
          };
        }

        // Load user stats
        await _loadUserStats();
      }

      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadUserStats() async {
    try {
      final userId = currentUser?.id;
      if (userId != null) {
        // Get saved articles count - try RPC function first
        int savedCount = 0;
        try {
          final currentLanguage =
              Provider.of<LanguageProvider>(context, listen: false)
                  .currentLanguage;
          final savedRPCResponse = await supabase
              .rpc('get_bookmarked_articles', params: {'user_lang': currentLanguage});
          savedCount = (savedRPCResponse as List).length;
        } catch (e) {
          // Fallback to direct table queries
          try {
            final savedResponse1 = await supabase
                .from('user_bookmarks')
                .select('id')
                .eq('user_id', userId)
                .eq('is_bookmarked', true);
            savedCount = (savedResponse1 as List).length;
          } catch (e2) {
            print('Error loading saved articles: $e2');
            savedCount = 0;
          }
        }

        // Get reading history count
        int readCount = 0;
        try {
          final readResponse = await supabase
              .from('reading_history')
              .select('id')
              .eq('user_id', userId);
          readCount = (readResponse as List).length;
          print('Reading history rows for $userId: $readCount');

          // If no results, try alternative table name (kept same for now)
          if (readCount == 0) {
            final readResponse2 = await supabase
                .from('reading_history')
                .select('id')
                .eq('user_id', userId);
            readCount = (readResponse2 as List).length;
          }
        } catch (e) {
          print('Error loading reading history: $e');
          readCount = 0;
        }

        // Calculate days active (days since user created account)
        int daysActive = 1;
        try {
          if (userProfile != null && userProfile!['created_at'] != null) {
            final userCreatedAt = DateTime.parse(userProfile!['created_at']);
            daysActive = DateTime.now().difference(userCreatedAt).inDays;
            if (daysActive <= 0) daysActive = 1;
          }
        } catch (e) {
          print('Error calculating days active: $e');
          daysActive = 1;
        }

        setState(() {
          userStats = {
            'saved': savedCount,
            'read': readCount,
            'days_active': daysActive,
          };
        });

        print(
            'User stats loaded: saved=$savedCount, read=$readCount, days=$daysActive');
      } else {
        // No user logged in - set all to 0
        setState(() {
          userStats = {
            'saved': 0,
            'read': 0,
            'days_active': 0,
          };
        });
      }
    } catch (e) {
      print('Error loading user stats: $e');
      // If there's an error, show 0 instead of fake numbers
      setState(() {
        userStats = {
          'saved': 0,
          'read': 0,
          'days_active': 0,
        };
      });
    }
  }

  Future<void> _signOut() async {
    try {
      await supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error signing out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF00A896),
          body: SafeArea(
            child: Column(
              children: [
                // Green Header with User Info
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Top row with title and icons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔽 changed to simpler Bangla like other screens
                              Text(
                                languageProvider.getText(
                                  'Healthy Bangla',
                                  'হেলদি বাংলা',
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                languageProvider.getText(
                                  'Your Health Companion',
                                  'আপনার স্বাস্থ্য সহায়ক',
                                ),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.language, color: Colors.white),
                                onPressed: () {
                                  languageProvider.toggleLanguage();
                                  _loadUserData(); // Reload to update language
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.logout, color: Colors.white),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text(languageProvider.getText(
                                          'Sign Out', 'সাইন আউট')),
                                      content: Text(
                                        languageProvider.getText(
                                          'Are you sure you want to sign out?',
                                          'আপনি কি নিশ্চিত যে আপনি সাইন আউট করতে চান?',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: Text(languageProvider.getText(
                                              'Cancel', 'বাতিল')),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _signOut();
                                          },
                                          child: Text(
                                            languageProvider.getText(
                                                'Sign Out', 'সাইন আউট'),
                                            style: const TextStyle(
                                                color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // User Info Row
                      if (!isLoading && currentUser != null) ...[
                        Row(
                          children: [
                            // User Avatar
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: Text(
                                (userProfile?['name']?.toString() ?? 'U')
                                    .substring(0, 1)
                                    .toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),

                            // User Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    userProfile?['name']?.toString() ??
                                        languageProvider.getText(
                                            'User', 'ব্যবহারকারী'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    currentUser?.email ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // White Content Area
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : currentUser == null
                            ? _buildNotLoggedInView(languageProvider)
                            : _buildLoggedInView(languageProvider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotLoggedInView(LanguageProvider languageProvider) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            languageProvider.getText(
              'Welcome to Healthy Bangla',
              'হেলদি বাংলায় স্বাগতম',
            ),
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            languageProvider.getText(
              'Sign in to save your favorite articles, track your health journey, and get personalized recommendations.',
              'আপনার পছন্দের লেখা সংরক্ষণ করতে, স্বাস্থ্য যাত্রা দেখার জন্য এবং নিজের মতো সাজানো পরামর্শ পেতে সাইন ইন করুন।',
            ),
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A896),
              padding:
                  const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              languageProvider.getText('Sign In', 'সাইন ইন'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoggedInView(LanguageProvider languageProvider) {
    return ListView(
      padding: const EdgeInsets.all(0),
      children: [
        const SizedBox(height: 24),

        // Stats Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  userStats['saved'].toString(),
                  languageProvider.getText('Saved', 'সংরক্ষিত'),
                  Colors.green,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  userStats['read'].toString(),
                  languageProvider.getText('Read', 'পঠিত'),
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  userStats['days_active'].toString(),
                  languageProvider.getText('Days Active', 'দিন সক্রিয়'),
                  Colors.orange,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // Quick Access Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            languageProvider.getText('Quick Access', 'দ্রুত প্রবেশ'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Quick Access Items
        _buildQuickAccessItem(
          Icons.bookmark_outline,
          languageProvider.getText('Saved Articles', 'সংরক্ষিত নিবন্ধ'),
          userStats['saved'].toString(),
          Colors.green,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SavedArticlesScreen()),
            );
          },
        ),

        _buildQuickAccessItem(
          Icons.history,
          languageProvider.getText('Reading History', 'পড়ার ইতিহাস'),
          userStats['read'].toString(),
          Colors.blue,
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReadingHistoryScreen()),
            );
          },
        ),

        const SizedBox(height: 24),

        // Settings Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            languageProvider.getText('Settings', 'সেটিংস'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Settings Items
        _buildSettingsItem(
          Icons.notifications_outlined,
          languageProvider.getText('Notifications', 'বিজ্ঞপ্তি'),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),

        _buildSettingsItem(
          Icons.language,
          languageProvider.getText('Language', 'ভাষা'),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),

        _buildSettingsItem(
          Icons.privacy_tip_outlined,
          languageProvider.getText('Privacy', 'গোপনীয়তা'),
          () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),

        _buildSettingsItem(
          Icons.help_outline,
          languageProvider.getText('Help & Support', 'সাহায্য ও সহায়তা'),
          () {
            // Show help dialog or navigate to help screen
          },
        ),

        // Admin Dashboard (only for admins)
        if (userProfile?['role'] == 'admin') ...[
          _buildSettingsItem(
            Icons.admin_panel_settings,
            languageProvider.getText(
                'Admin Dashboard', 'অ্যাডমিন ড্যাশবোর্ড'),
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const AdminDashboardScreen()),
              );
            },
            color: Colors.red,
          ),
        ],

        const SizedBox(height: 24),

        // About Section
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            languageProvider.getText('About', 'সম্পর্কে'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        const SizedBox(height: 16),

        // About Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            languageProvider.getText(
              'Healthy Bangla is dedicated to delivering accurate, easy-to-understand health information to Bengali-speaking communities worldwide.',
              'হেলদি বাংলা সহজ ও বোঝার মতো স্বাস্থ্য তথ্য বাংলা ভাষায় সবার কাছে পৌঁছে দিতে কাজ করে।',
            ),
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 16),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            languageProvider.getText('Version 1.0.0', 'সংস্করণ ১.০.০'),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Log Out Button
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title:
                      Text(languageProvider.getText('Sign Out', 'সাইন আউট')),
                  content: Text(
                    languageProvider.getText(
                      'Are you sure you want to sign out?',
                      'আপনি কি নিশ্চিত যে আপনি সাইন আউট করতে চান?',
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                          languageProvider.getText('Cancel', 'বাতিল')),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _signOut();
                      },
                      child: Text(
                        languageProvider.getText('Log Out', 'লগ আউট'),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout, color: Colors.red),
            label: Text(
              languageProvider.getText('Log Out', 'লগ আউট'),
              style: const TextStyle(color: Colors.red),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessItem(
    IconData icon,
    String title,
    String count,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSettingsItem(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: color ?? Colors.grey[700], size: 24),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: color ?? Colors.black87,
          ),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
