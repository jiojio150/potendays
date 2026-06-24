import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    hide User;

import '../services/local_notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _scheduleNotifications = true;
  bool _settlementNotifications = true;
  bool _longTermReminders = true;

  bool _isLoadingProfile = true;
  bool _isLoggingOut = false;

  String _displayName = '사용자';
  String _email = '';
  String? _photoUrl;
  String _loginProvider = '로그인 정보 없음';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser != null) {
      if (!mounted) return;

      setState(() {
        _displayName = firebaseUser.displayName?.trim().isNotEmpty == true
            ? firebaseUser.displayName!.trim()
            : '사용자';
        _email = firebaseUser.email ?? '';
        _photoUrl = firebaseUser.photoURL;
        _loginProvider = _firebaseProviderName(firebaseUser);
        _isLoadingProfile = false;
      });

      return;
    }

    try {
      if (await AuthApi.instance.hasToken()) {
        final kakaoUser = await UserApi.instance.me();
        final String? nickname =
            kakaoUser.kakaoAccount?.profile?.nickname;
        final String? profileImage =
            kakaoUser.kakaoAccount?.profile?.profileImageUrl;
        final String? email = kakaoUser.kakaoAccount?.email;

        if (!mounted) return;

        setState(() {
          _displayName =
              nickname?.trim().isNotEmpty == true ? nickname!.trim() : '카카오 사용자';
          _email = email ?? '';
          _photoUrl = profileImage;
          _loginProvider = '카카오 로그인';
          _isLoadingProfile = false;
        });

        return;
      }
    } catch (error) {
      debugPrint('카카오 사용자 정보 확인 오류: $error');
    }

    if (!mounted) return;

    setState(() {
      _displayName = '사용자';
      _email = '';
      _photoUrl = null;
      _loginProvider = '로그인 정보 없음';
      _isLoadingProfile = false;
    });
  }

  String _firebaseProviderName(User user) {
    final List<UserInfo> providers = user.providerData;

    if (providers.any(
      (UserInfo info) => info.providerId == GoogleAuthProvider.PROVIDER_ID,
    )) {
      return 'Google 로그인';
    }

    return 'Firebase 로그인';
  }


  Future<void> _requestLocalNotificationPermission() async {
    final LocalNotificationService service =
        LocalNotificationService.instance;

    if (!service.isSupported) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '웹에서는 로컬 예약 알림을 지원하지 않습니다. '
            'Android 또는 iOS 앱에서 설정해 주세요.',
          ),
        ),
      );
      return;
    }

    final bool granted = await service.requestPermissions();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          granted
              ? '기기 알림 권한이 허용되었습니다.'
              : '알림 권한이 허용되지 않았습니다. '
                  '기기 설정에서 알림 권한을 확인해 주세요.',
        ),
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;

    setState(() => _isLoggingOut = true);

    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }

      try {
        if (await AuthApi.instance.hasToken()) {
          await UserApi.instance.logout();
        }
      } catch (error) {
        debugPrint('카카오 로그아웃 확인 오류: $error');
      }

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/',
        (Route<dynamic> route) => false,
      );
    } catch (error) {
      debugPrint('로그아웃 오류: $error');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('로그아웃 중 오류가 발생했습니다.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoggingOut = false);
      }
    }
  }

  Future<void> _showLogoutDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2E),
          title: const Text(
            '로그아웃',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            '현재 계정에서 로그아웃할까요?',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text(
                '취소',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF453A),
              ),
              child: const Text(
                '로그아웃',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isLoadingProfile
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 22),
                        _buildSectionTitle('알림 설정'),
                        const SizedBox(height: 10),
                        _buildNotificationCard(),
                        const SizedBox(height: 22),
                        _buildSectionTitle('계정'),
                        const SizedBox(height: 10),
                        _buildAccountCard(),
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed:
                                _isLoggingOut ? null : _showLogoutDialog,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFFF6B63),
                              side: const BorderSide(
                                color: Color(0xFFFF453A),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: _isLoggingOut
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.logout_rounded),
                            label: Text(
                              _isLoggingOut ? '로그아웃 중...' : '로그아웃',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Poten Day',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white24,
                            fontSize: 12,
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

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFF3A3A3C),
            width: 0.5,
          ),
        ),
      ),
      child: const Text(
        '설정',
        style: TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Row(
        children: [
          _buildProfileImage(),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _displayName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_email.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    _email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 5),
                Text(
                  _loginProvider,
                  style: const TextStyle(
                    color: Color(0xFF8AA4FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileImage() {
    final String? photoUrl = _photoUrl;

    if (photoUrl != null && photoUrl.trim().isNotEmpty) {
      return CircleAvatar(
        radius: 30,
        backgroundColor: const Color(0xFF3A3A3C),
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    final String initial =
        _displayName.trim().isEmpty ? '?' : _displayName.trim()[0];

    return CircleAvatar(
      radius: 30,
      backgroundColor: const Color(0xFF4A6CF7),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        children: [
          _SettingsMenuItem(
            icon: Icons.notifications_active_rounded,
            title: '기기 알림 권한',
            subtitle: '일정과 정산 리마인드를 표시할 수 있도록 알림 권한을 요청합니다.',
            onTap: _requestLocalNotificationPermission,
          ),
          const _SettingsDivider(),
          _SettingsSwitchItem(
            icon: Icons.event_rounded,
            title: '일정 알림',
            subtitle: '확정된 모임 일정이 가까워지면 알려줍니다.',
            value: _scheduleNotifications,
            onChanged: (bool value) {
              setState(() => _scheduleNotifications = value);
            },
          ),
          const _SettingsDivider(),
          _SettingsSwitchItem(
            icon: Icons.payments_rounded,
            title: '정산 알림',
            subtitle: '모임 이후 정산이 필요할 때 알려줍니다.',
            value: _settlementNotifications,
            onChanged: (bool value) {
              setState(() => _settlementNotifications = value);
            },
          ),
          const _SettingsDivider(),
          _SettingsSwitchItem(
            icon: Icons.history_toggle_off_rounded,
            title: '장기간 미모임 리마인드',
            subtitle: '설정 기간 동안 모임이 없으면 알려줍니다.',
            value: _longTermReminders,
            onChanged: (bool value) {
              setState(() => _longTermReminders = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard() {
    final User? user = FirebaseAuth.instance.currentUser;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF3A3A3C)),
      ),
      child: Column(
        children: [
          _ReadOnlyInfoRow(
            icon: Icons.badge_outlined,
            label: '사용자 이름',
            value: _displayName,
          ),
          const _SettingsDivider(),
          _ReadOnlyInfoRow(
            icon: Icons.login_rounded,
            label: '로그인 방식',
            value: _loginProvider,
          ),
          if (user != null) ...[
            const _SettingsDivider(),
            _ReadOnlyInfoRow(
              icon: Icons.fingerprint_rounded,
              label: '사용자 ID',
              value: user.uid,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 15,
          ),
          child: Row(
            children: [
              _SettingsIcon(icon: icon),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: Colors.white30,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          _SettingsIcon(icon: icon),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white38,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF8AA4FF),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ReadOnlyInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 15,
      ),
      child: Row(
        children: [
          _SettingsIcon(icon: icon),
          const SizedBox(width: 13),
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  final IconData icon;

  const _SettingsIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: const Color(0xFF4A6CF7).withOpacity(0.16),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        color: const Color(0xFF8AA4FF),
        size: 21,
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.6,
      indent: 66,
      color: Color(0xFF3A3A3C),
    );
  }
}
