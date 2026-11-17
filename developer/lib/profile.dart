// Profile: picture, display name, reminder time and sign out.
//
// Stored on the user's own document, users/{uid}:
//   profile:  {name, photo}   photo = small JPEG as base64 (≈20–40 KB)
//   reminder: {hour, minute}
// The photo lives in Firestore rather than Firebase Storage so the project
// doesn't need the paid Blaze plan.

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'notification_service.dart';
import 'theme.dart';

DocumentReference<Map<String, dynamic>> _userDoc() {
  final uid = FirebaseAuth.instance.currentUser!.uid;
  return FirebaseFirestore.instance.collection('users').doc(uid);
}

/// Largest photo we'll store, in bytes (well under Firestore's 1 MB limit).
const int maxPhotoBytes = 200 * 1024;

class UserProfile {
  final String name;
  final String email;
  final Uint8List? photo;
  final int reminderHour;
  final int reminderMinute;

  const UserProfile({
    required this.name,
    required this.email,
    this.photo,
    this.reminderHour = 9,
    this.reminderMinute = 0,
  });

  /// Up to two initials for the avatar placeholder.
  String get initials {
    final source = name.trim().isNotEmpty ? name : email;
    final parts = source
        .split(RegExp(r'[\s@._-]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  static UserProfile fromData(Map<String, dynamic>? d, User? user) {
    final p = d?['profile'];
    final r = d?['reminder'];
    Uint8List? photo;
    if (p is Map && p['photo'] is String) {
      try {
        photo = base64Decode(p['photo'] as String);
      } catch (_) {}
    }
    return UserProfile(
      name: (p is Map ? p['name'] as String? : null) ?? user?.displayName ?? '',
      email: user?.email ?? '',
      photo: photo,
      reminderHour: r is Map && r['hour'] is int ? r['hour'] as int : 9,
      reminderMinute: r is Map && r['minute'] is int ? r['minute'] as int : 0,
    );
  }
}

Stream<UserProfile> profileStream() => _userDoc().snapshots().map(
  (s) => UserProfile.fromData(s.data(), FirebaseAuth.instance.currentUser),
);

/// Loads the saved reminder time into the notification service. Called once
/// after sign-in.
Future<void> applySavedReminderTime() async {
  try {
    final snap = await _userDoc().get();
    final p = UserProfile.fromData(snap.data(), null);
    await NotificationService.setReminderTime(p.reminderHour, p.reminderMinute);
  } catch (e) {
    debugPrint('Could not load reminder time: $e');
  }
}

/// Round avatar: the photo, or initials on leaf green.
class ProfileAvatar extends StatelessWidget {
  final UserProfile? profile;
  final double size;
  const ProfileAvatar({super.key, required this.profile, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final photo = profile?.photo;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: brandLeaf,
        image: photo == null
            ? null
            : DecorationImage(image: MemoryImage(photo), fit: BoxFit.cover),
      ),
      alignment: Alignment.center,
      child: photo != null
          ? null
          : Text(
              profile?.initials ?? '',
              style: appFont(
                fontSize: size * 0.4,
                fontWeight: FontWeight.w900,
                color: inkOnLeaf,
              ),
            ),
    );
  }
}

/// The avatar in the Fridge tab's top bar; opens the profile.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserProfile>(
      stream: profileStream(),
      builder: (context, snap) => IconButton(
        tooltip: 'Profile and settings',
        padding: EdgeInsets.zero,
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
        icon: ProfileAvatar(profile: snap.data, size: 40),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  bool _nameLoaded = false;
  bool _busy = false;
  bool? _notificationsOn;
  int _pending = 0;

  @override
  void initState() {
    super.initState();
    _checkNotifications();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _checkNotifications() async {
    final on = await NotificationService.notificationsEnabled();
    final pending = await NotificationService.pendingCount();
    if (mounted) {
      setState(() {
        _notificationsOn = on;
        _pending = pending;
      });
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > maxPhotoBytes) {
        _snack('That photo is too large. Please try another one.');
        return;
      }
      setState(() => _busy = true);
      await _userDoc().set({
        'profile': {'photo': base64Encode(bytes)},
      }, SetOptions(merge: true));
      if (mounted) _snack('Profile picture updated');
    } catch (e) {
      if (mounted) _snack('Could not update picture: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePhoto() async {
    await _userDoc().set({
      'profile': {'photo': FieldValue.delete()},
    }, SetOptions(merge: true));
  }

  Future<void> _choosePhoto(bool hasPhoto) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: urgentRed),
                title: const Text('Remove photo'),
                onTap: () => Navigator.pop(ctx, 'remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case 'camera':
        await _pickPhoto(ImageSource.camera);
      case 'gallery':
        await _pickPhoto(ImageSource.gallery);
      case 'remove':
        await _removePhoto();
    }
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    FocusScope.of(context).unfocus();
    try {
      await _userDoc().set({
        'profile': {'name': name},
      }, SetOptions(merge: true));
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      if (mounted) _snack('Name saved');
    } catch (e) {
      if (mounted) _snack('Could not save name: $e');
    }
  }

  Future<void> _pickReminderTime(UserProfile p) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: p.reminderHour, minute: p.reminderMinute),
      helpText: 'Remind me about expiring food at',
    );
    if (picked == null) return;
    await _userDoc().set({
      'reminder': {'hour': picked.hour, 'minute': picked.minute},
    }, SetOptions(merge: true));
    await NotificationService.setReminderTime(picked.hour, picked.minute);
    await _checkNotifications();
    if (mounted) _snack('Reminders moved to ${picked.format(context)}');
  }

  Future<void> _turnOnNotifications() async {
    final granted = await NotificationService.requestPermission();
    await _checkNotifications();
    if (granted == false && mounted) {
      _snack(
        'Notifications are blocked. Turn them on for Fridge Mate in '
        'your phone\'s Settings → Apps → Fridge Mate → Notifications.',
      );
    }
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<UserProfile>(
        stream: profileStream(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final p = snap.data!;
          if (!_nameLoaded) {
            _name.text = p.name;
            _nameLoaded = true;
          }
          final time = TimeOfDay(
            hour: p.reminderHour,
            minute: p.reminderMinute,
          ).format(context);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ProfileAvatar(profile: p, size: 112),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: IconButton.filled(
                        tooltip: 'Change profile picture',
                        style: IconButton.styleFrom(
                          backgroundColor: context.palette.hero,
                          foregroundColor: Colors.white,
                          side: BorderSide(
                            color: context.palette.background,
                            width: 3,
                          ),
                        ),
                        onPressed: _busy
                            ? null
                            : () => _choosePhoto(p.photo != null),
                        icon: _busy
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.photo_camera_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Center(child: Text(p.email, style: theme.textTheme.bodyMedium)),
              const SizedBox(height: 24),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Your name',
                  suffixIcon: IconButton(
                    tooltip: 'Save name',
                    icon: const Icon(Icons.check),
                    onPressed: _saveName,
                  ),
                ),
                onSubmitted: (_) => _saveName(),
              ),
              const SizedBox(height: 28),
              Text('Reminders', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                "We'll remind you the day before and on the morning food "
                'expires, with recipes that use it.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Reminder time'),
                      subtitle: Text(
                        '$_pending reminder'
                        '${_pending == 1 ? '' : 's'} scheduled',
                      ),
                      trailing: Text(time, style: theme.textTheme.titleMedium),
                      onTap: () => _pickReminderTime(p),
                    ),
                    if (_notificationsOn == false)
                      ListTile(
                        leading: const Icon(
                          Icons.notifications_off_outlined,
                          color: urgentRed,
                        ),
                        title: const Text('Notifications are off'),
                        subtitle: const Text(
                          "You won't get expiry reminders until you allow them.",
                        ),
                        trailing: FilledButton(
                          onPressed: _turnOnNotifications,
                          child: const Text('Turn on'),
                        ),
                      )
                    else if (_notificationsOn == true)
                      const ListTile(
                        leading: Icon(Icons.notifications_active_outlined),
                        title: Text('Notifications are on'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Text('Appearance', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              ValueListenableBuilder<ThemeMode>(
                valueListenable: themeModeSetting,
                builder: (context, mode, _) => SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: context.palette.selected,
                      selectedForegroundColor: context.palette.onSelected,
                      foregroundColor: context.palette.ink,
                      side: BorderSide(color: context.palette.cardBorder),
                      minimumSize: const Size(0, 48),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined),
                        label: Text('Light'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined),
                        label: Text('Dark'),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (s) => setThemeMode(s.first),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text('Account', style: theme.textTheme.titleLarge),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: urgentRed),
                  title: const Text('Sign out'),
                  onTap: _signOut,
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Fridge Mate · by ShelfLife',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
