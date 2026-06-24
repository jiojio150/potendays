import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    hide User;
import '../services/local_notification_service.dart';
import '../services/meeting_service.dart';
import 'create_meeting.dart';
import 'meeting_detail.dart';
import 'confirmed_calendar.dart';
import 'notifications.dart';
import 'settings.dart';
import 'qr_join.dart';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 모임 데이터 모델
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
enum MeetingStatus { inProgress, completed }

class MeetingModel {
  final String emoji;
  final String title;
  final int participantCount;
  final String date;
  final MeetingStatus status;
  final bool hasWarning;
  final String? warningMessage;

  const MeetingModel({
    required this.emoji,
    required this.title,
    required this.participantCount,
    required this.date,
    required this.status,
    this.hasWarning = false,
    this.warningMessage,
  });
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// 홈 / 모임 목록 화면 — REQ-F-13
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTabIndex = 0;
  final MeetingService _meetingService = MeetingService();
  String? _lastReminderSyncSignature;

  bool _isCheckingKakaoLogin = false;
  bool _isKakaoLoggedIn = false;
  String _kakaoDisplayName = '카카오 사용자';

  @override
  void initState() {
    super.initState();

    if (FirebaseAuth.instance.currentUser != null) {
      LocalNotificationService.instance.syncCurrentUserMeetings();
    } else {
      _loadKakaoLoginState();
    }
  }

  Future<void> _loadKakaoLoginState() async {
    setState(() => _isCheckingKakaoLogin = true);

    try {
      final bool hasToken = await AuthApi.instance.hasToken();

      if (!hasToken) {
        if (!mounted) return;

        setState(() {
          _isKakaoLoggedIn = false;
          _isCheckingKakaoLogin = false;
        });
        return;
      }

      final kakaoUser = await UserApi.instance.me();
      final String? nickname =
          kakaoUser.kakaoAccount?.profile?.nickname;

      if (!mounted) return;

      setState(() {
        _isKakaoLoggedIn = true;
        _kakaoDisplayName =
            nickname?.trim().isNotEmpty == true
                ? nickname!.trim()
                : '카카오 사용자';
        _isCheckingKakaoLogin = false;
      });
    } catch (error) {
      debugPrint('카카오 로그인 상태 확인 오류: $error');

      if (!mounted) return;

      setState(() {
        _isKakaoLoggedIn = false;
        _isCheckingKakaoLogin = false;
      });
    }
  }

  bool _requireFirebaseLogin() {
    if (FirebaseAuth.instance.currentUser != null) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '카카오 로그인은 완료되었지만 Firebase 계정과 연결되지 않아 '
          '현재 모임 생성·참여·캘린더·알림 기능은 Google 로그인에서만 사용할 수 있습니다.',
        ),
      ),
    );

    return false;
  }

  void _syncLocalReminders(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> documents,
  ) {
    final String signature = documents.map((document) {
      final Map<String, dynamic> data = document.data();
      return '${document.id}|'
          '${data['updatedAt']}|'
          '${data['confirmedDateTime']}|'
          '${data['reminderEnabled']}|'
          '${data['settlementCompleted']}';
    }).join('||');

    if (_lastReminderSyncSignature == signature) return;
    _lastReminderSyncSignature = signature;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await LocalNotificationService.instance
            .syncMeetingDocuments(documents);
      } catch (error) {
        debugPrint('로컬 리마인드 동기화 오류: $error');
      }
    });
  }

  void _showJoinDialog(BuildContext context) {
    if (!_requireFirebaseLogin()) return;

    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text(
          '모임 참여하기',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: '초대 코드 또는 링크를 붙여넣으세요',
                hintStyle: TextStyle(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFF3A3A3C),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Color(0xFF4A6CF7),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final String? scannedValue =
                      await Navigator.push<String>(
                    dialogContext,
                    MaterialPageRoute(
                      builder: (_) => const QrJoinScreen(),
                    ),
                  );

                  if (scannedValue == null ||
                      scannedValue.trim().isEmpty) {
                    return;
                  }

                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }

                  _joinMeeting(scannedValue);
                },
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('QR 코드 스캔'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              '취소',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final String input = codeController.text.trim();

              if (input.isEmpty) return;

              Navigator.pop(dialogContext);
              _joinMeeting(input);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
            ),
            child: const Text(
              '참여',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _joinMeeting(String code) async {
    if (!_requireFirebaseLogin()) return;

    final result = await _meetingService.joinMeeting(code);

    if (!mounted) return;

    String message;
    if (result == "success") {
      message = "모임에 성공적으로 참여했습니다! 🎉";
    } else if (result == "already_joined") {
      message = "이미 참여 중인 모임입니다. 😊";
    } else if (result == "not_found") {
      message = "존재하지 않는 모임 코드입니다. 🤔";
    } else {
      message = "오류가 발생했습니다. 다시 시도해 주세요.";
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _formatConfirmedDate(Timestamp? timestamp) {
    if (timestamp == null) return '미정';

    final DateTime value = timestamp.toDate();
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    final String hour = value.hour.toString().padLeft(2, '0');
    final String minute = value.minute.toString().padLeft(2, '0');

    return '${value.year}.$month.$day $hour:$minute';
  }

  void _openMeetingDetail(MeetingModel meeting, String docID) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingDetailScreen(
          docID: docID,
          emoji: meeting.emoji,
          title: meeting.title,
          participantCount: meeting.participantCount,
          date: meeting.date,
          statusText:
          meeting.status == MeetingStatus.inProgress ? '진행중' : '완료',
          hasWarning: meeting.hasWarning,
          warningMessage: meeting.warningMessage,
        ),
      ),
    );
  }

  void _onBottomTabTapped(int index) {
    if (index == 0) {
      setState(() => _currentTabIndex = 0);
      return;
    }

    if ((index == 1 || index == 2) && !_requireFirebaseLogin()) {
      return;
    }

    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ConfirmedCalendarScreen()),
      );
      return;
    }

    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }

    if (index == 3) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SettingsScreen()),
      );
      return;
    }
  }

  final user = FirebaseAuth.instance.currentUser;
  
  @override
  Widget build(BuildContext context) {
    final User? firebaseUser = FirebaseAuth.instance.currentUser;

    Widget body;

    if (firebaseUser != null) {
      body = StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _meetingService.getMyMeetings(firebaseUser.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            debugPrint('모임 목록 조회 오류: ${snapshot.error}');

            return const Center(
              child: Text(
                '모임 정보를 불러오지 못했습니다.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            _syncLocalReminders(
              const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
            );

            return const Center(
              child: Text(
                '참여 중인 모임이 없습니다.',
                style: TextStyle(color: Colors.white54),
              ),
            );
          }

          final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs =
              snapshot.data!.docs;

          _syncLocalReminders(docs);

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: docs.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final Map<String, dynamic> data = docs[index].data();
              final String docID = docs[index].id;

              final MeetingModel meeting = MeetingModel(
                emoji: data['emoji'] ?? '📍',
                title: data['title'] ?? '이름 없는 모임',
                participantCount:
                    (data['participants'] as List?)?.length ?? 1,
                date: _formatConfirmedDate(
                  data['confirmedDateTime'] as Timestamp?,
                ),
                status: MeetingStatus.inProgress,
              );

              return _MeetingCard(
                emoji: meeting.emoji,
                title: meeting.title,
                participantCount: meeting.participantCount,
                date: meeting.date,
                status: meeting.status,
                onTap: () => _openMeetingDetail(meeting, docID),
              );
            },
          );
        },
      );
    } else if (_isCheckingKakaoLogin) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_isKakaoLoggedIn) {
      body = _buildKakaoOnlyHome(_kakaoDisplayName);
    } else {
      body = _buildLoginExpiredHome();
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(76),
        child: _buildHeader(),
      ),
      body: body,
      floatingActionButton:
          firebaseUser != null ? _buildFab(context) : null,
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildKakaoOnlyHome(String displayName) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFFFEE500),
                size: 52,
              ),
              const SizedBox(height: 16),
              Text(
                '$displayName님, 카카오 로그인이 완료되었습니다.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '카카오 계정은 현재 Firebase 계정과 연결되지 않아 '
                '모임 생성·참여·일정 기능은 아직 사용할 수 없습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginExpiredHome() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.login_rounded,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              '로그인 정보를 확인할 수 없습니다.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              },
              child: const Text('로그인 화면으로 이동'),
            ),
          ],
        ),
      ),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 플로팅 액션 버튼 (모임 생성 버튼)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        if (!_requireFirebaseLogin()) return;

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
        );
      },
      backgroundColor: const Color(0xFF4A6CF7),
      label: const Text('모임 만들기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      icon: const Icon(Icons.add, color: Colors.white),
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 하단 네비게이션 바 (필요 시 메뉴 추가)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ignore: unused_element
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFF1C1C1E),
      selectedItemColor: const Color(0xFF4A6CF7),
      unselectedItemColor: Colors.white30,
      currentIndex: 0,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: '홈'),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: '마이'),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      // PreferredSize 높이 안에서 텍스트가 잘리지 않도록 세로 패딩을 줄이고 중앙 정렬
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 10),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '내 모임',
            style: TextStyle(
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Row(
            children: [
              _JoinButton(onPressed: () => _showJoinDialog(context)),
              const SizedBox(width: 8),
              _CreateButton(
                onPressed: () {
                  if (!_requireFirebaseLogin()) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateMeetingScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    const items = [
      {'icon': Icons.home_rounded, 'label': '홈'},
      {'icon': Icons.calendar_month_rounded, 'label': '캘린더'},
      {'icon': Icons.notifications_rounded, 'label': '알림'},
      {'icon': Icons.settings_rounded, 'label': '설정'},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF2C2C2E),
        border: Border(
          top: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final isSelected = _currentTabIndex == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onBottomTabTapped(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[index]['icon'] as IconData,
                        size: 24,
                        color: isSelected
                            ? const Color(0xFF4A6CF7)
                            : Colors.white38,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[index]['label'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? const Color(0xFF4A6CF7)
                              : Colors.white38,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18, color: Colors.white),
      label: const Text(
        '생성',
        style: TextStyle(color: Colors.white, fontSize: 14),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white38, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
    );
  }
}

class _MeetingCard extends StatelessWidget {
  final String emoji;
  final String title;
  final int participantCount;
  final String date;
  final MeetingStatus status;
  final VoidCallback onTap;

  const _MeetingCard({
    required this.emoji,
    required this.title,
    required this.participantCount,
    required this.date,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '참여자 $participantCount명 · $date',
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            _StatusBadge(status: status),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MeetingStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isInProgress = status == MeetingStatus.inProgress;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isInProgress
            ? const Color(0xFF4A6CF7).withValues(alpha: 0.20)
            : const Color(0xFF2F7D20).withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isInProgress ? '진행중' : '완료',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isInProgress ? const Color(0xFF83A5FF) : Colors.lightGreenAccent,
        ),
      ),
    );
  }
}

class _JoinButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _JoinButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFF4A6CF7), width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      child: const Text('참여', style: TextStyle(color: Color(0xFF4A6CF7), fontSize: 14)),
    );
  }
}
