import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final supabase = Supabase.instance.client;
  bool notificationsEnabled = true;
  bool locationNotificationsEnabled = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => isLoading = true);
    
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        try {
          final response = await supabase
              .from('users')
              .select('notifications_enabled, location_notifications_enabled')
              .eq('id', userId)
              .single();
          
          setState(() {
            notificationsEnabled = response['notifications_enabled'] ?? true;
            locationNotificationsEnabled = response['location_notifications_enabled'] ?? false;
          });
        } catch (e) {
          print('Error loading user settings: $e');
          // Use defaults if user settings don't exist
        }
      }
      setState(() => isLoading = false);
    } catch (e) {
      print('Error loading settings: $e');
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateNotifications(bool value) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase
            .from('users')
            .update({'notifications_enabled': value})
            .eq('id', userId);
        
        setState(() => notificationsEnabled = value);
        
        if (mounted) {
          final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(languageProvider.getText('Settings updated', 'সেটিংস আপডেট হয়েছে')),
            ),
          );
        }
      }
    } catch (e) {
      print('Error updating notifications: $e');
    }
  }

  Future<void> _updateLocationNotifications(bool value) async {
    try {
      // Try RPC first
      try {
        await supabase.rpc('toggle_location_notifications', params: {
          'enabled': value,
        });
      } catch (e) {
        // Fallback: direct database update
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase
              .from('users')
              .update({'location_notifications_enabled': value})
              .eq('id', userId);
        }
      }
      
      setState(() => locationNotificationsEnabled = value);
      
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText('Location notifications updated', 'লোকেশন বিজ্ঞপ্তি আপডেট হয়েছে')),
          ),
        );
      }
    } catch (e) {
      print('Error updating location notifications: $e');
    }
  }

  Future<void> _clearSearchHistory() async {
    try {
      // Try RPC first
      try {
        await supabase.rpc('clear_search_history');
      } catch (e) {
        // Fallback: direct delete from search history table
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          await supabase
              .from('user_searches')
              .delete()
              .eq('user_id', userId);
        }
      }
      
      if (mounted) {
        final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(languageProvider.getText('Search history cleared', 'অনুসন্ধানের ইতিহাস মুছে ফেলা হয়েছে')),
          ),
        );
      }
    } catch (e) {
      print('Error clearing search history: $e');
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
                // Green Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getText('Settings', 'সেটিংস'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              languageProvider.getText(
                                'Customize your app preferences',
                                'আপনার অ্যাপের পছন্দগুলি কাস্টমাইজ করুন'
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          languageProvider.currentLanguage.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
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
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Language Section
                              Text(
                                languageProvider.getText('Language', 'ভাষা'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Card(
                                child: Column(
                                  children: [
                                    RadioListTile<String>(
                                      title: const Text('English'),
                                      value: 'en',
                                      groupValue: languageProvider.currentLanguage,
                                      onChanged: (value) {
                                        if (value != null) {
                                          languageProvider.setLanguage(value);
                                        }
                                      },
                                      activeColor: const Color(0xFF00A896),
                                    ),
                                    const Divider(height: 1),
                                    RadioListTile<String>(
                                      title: const Text('বাংলা (Bengali)'),
                                      value: 'bn',
                                      groupValue: languageProvider.currentLanguage,
                                      onChanged: (value) {
                                        if (value != null) {
                                          languageProvider.setLanguage(value);
                                        }
                                      },
                                      activeColor: const Color(0xFF00A896),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Notifications Section
                              Text(
                                languageProvider.getText('Notifications', 'বিজ্ঞপ্তি'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Card(
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      title: Text(languageProvider.getText('Push Notifications', 'পুশ বিজ্ঞপ্তি')),
                                      subtitle: Text(
                                        languageProvider.getText(
                                          'Receive updates about new articles',
                                          'নতুন নিবন্ধের আপডেট পান'
                                        ),
                                      ),
                                      value: notificationsEnabled,
                                      onChanged: _updateNotifications,
                                      activeColor: const Color(0xFF00A896),
                                    ),
                                    const Divider(height: 1),
                                    SwitchListTile(
                                      title: Text(languageProvider.getText('Event Notifications', 'ইভেন্ট বিজ্ঞপ্তি')),
                                      subtitle: Text(
                                        languageProvider.getText(
                                          'Get notified about nearby health events',
                                          'কাছাকাছি স্বাস্থ্য ইভেন্টের বিজ্ঞপ্তি পান'
                                        ),
                                      ),
                                      value: locationNotificationsEnabled,
                                      onChanged: _updateLocationNotifications,
                                      activeColor: const Color(0xFF00A896),
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // Privacy Section
                              Text(
                                languageProvider.getText('Privacy', 'গোপনীয়তা'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Card(
                                child: ListTile(
                                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                                  title: Text(languageProvider.getText('Clear Search History', 'অনুসন্ধানের ইতিহাস মুছুন')),
                                  subtitle: Text(
                                    languageProvider.getText(
                                      'Remove all your search queries',
                                      'আপনার সমস্ত অনুসন্ধান মুছে ফেলুন'
                                    ),
                                  ),
                                  onTap: () async {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text(languageProvider.getText('Clear Search History?', 'অনুসন্ধানের ইতিহাস মুছবেন?')),
                                        content: Text(
                                          languageProvider.getText(
                                            'This action cannot be undone.',
                                            'এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।'
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(languageProvider.getText('Cancel', 'বাতিল')),
                                          ),
                                          TextButton(
                                            onPressed: () async {
                                              Navigator.pop(context);
                                              await _clearSearchHistory();
                                            },
                                            child: Text(
                                              languageProvider.getText('Clear', 'মুছুন'),
                                              style: const TextStyle(color: Colors.red),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              // About Section
                              Text(
                                languageProvider.getText('About', 'সম্পর্কে'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              
                              Card(
                                child: Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.info_outline, color: Color(0xFF00A896)),
                                      title: Text(languageProvider.getText('About Healthy Bangla', 'স্বাস্থ্যকর বাংলা সম্পর্কে')),
                                      onTap: () {
                                        showAboutDialog(
                                          context: context,
                                          applicationName: 'Healthy Bangla',
                                          applicationVersion: '1.0.0',
                                          applicationIcon: const Icon(
                                            Icons.health_and_safety,
                                            size: 48,
                                            color: Color(0xFF00A896),
                                          ),
                                          children: [
                                            Text(
                                              languageProvider.getText(
                                                'Healthy Bangla is dedicated to delivering accurate, '
                                                'easy-to-understand health information to Bengali-speaking '
                                                'communities worldwide.',
                                                'স্বাস্থ্যকর বাংলা বিশ্বব্যাপী বাংলা ভাষী সম্প্রদায়ের কাছে '
                                                'নির্ভুল, সহজবোধ্য স্বাস্থ্য তথ্য পৌঁছে দিতে প্রতিশ্রুতিবদ্ধ।'
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(Icons.policy_outlined, color: Color(0xFF00A896)),
                                      title: Text(languageProvider.getText('Privacy Policy', 'গোপনীয়তা নীতি')),
                                      onTap: () {
                                        // Open privacy policy
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(languageProvider.getText('Privacy Policy', 'গোপনীয়তা নীতি')),
                                            content: SingleChildScrollView(
                                              child: Text(
                                                languageProvider.getText(
                                                  'We respect your privacy and are committed to protecting your personal data.',
                                                  'আমরা আপনার গোপনীয়তাকে সম্মান করি এবং আপনার ব্যক্তিগত তথ্য সুরক্ষিত রাখতে প্রতিশ্রুতিবদ্ধ।'
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(languageProvider.getText('Close', 'বন্ধ করুন')),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                    const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(Icons.description_outlined, color: Color(0xFF00A896)),
                                      title: Text(languageProvider.getText('Terms of Service', 'সেবার শর্তাবলী')),
                                      onTap: () {
                                        // Open terms of service
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(languageProvider.getText('Terms of Service', 'সেবার শর্তাবলী')),
                                            content: SingleChildScrollView(
                                              child: Text(
                                                languageProvider.getText(
                                                  'By using this app, you agree to our terms and conditions.',
                                                  'এই অ্যাপ ব্যবহার করে, আপনি আমাদের নিয়ম ও শর্তাবলীতে সম্মত হচ্ছেন।'
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: Text(languageProvider.getText('Close', 'বন্ধ করুন')),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
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
          ),
        );
      },
    );
  }
}