import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/meeting_service.dart';
import 'create_meeting.dart';
import 'meeting_detail.dart';
import 'confirmed_calendar.dart';
import 'notifications.dart';
import 'settings.dart';

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

  void _showJoinDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2E),
        title: const Text('모임 참여하기', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: codeController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '초대 코드를 입력하세요',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF3A3A3C))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isNotEmpty) {
                Navigator.pop(context);
                
                _joinMeeting(code); 
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4A6CF7),
            ),
            child: const Text('입장', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _joinMeeting(String code) async {
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
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: PreferredSize(
        // 헤더 안의 글자가 잘리지 않도록 높이를 여유 있게 설정
        preferredSize: const Size.fromHeight(76),
        child: _buildHeader(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _meetingService.getMyMeetings(user?.uid ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("참여 중인 모임이 없습니다.", style: TextStyle(color: Colors.white54)),
            );
          }

          final docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
            itemCount: docs.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final String docID = docs[index].id;
              
              final meeting = MeetingModel(
                emoji: data['emoji'] ?? '📍',
                title: data['title'] ?? '이름 없는 모임',
                participantCount: (data['participants'] as List?)?.length ?? 1,
                date: '미정',
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
      ),
      floatingActionButton: _buildFab(context),
      bottomNavigationBar: _buildBottomNavBar(), 
    );
  }

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  // 플로팅 액션 버튼 (모임 생성 버튼)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Widget _buildFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
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
              _CreateButton(onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateMeetingScreen()),
                );
              }),
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
            ? const Color(0xFF4A6CF7).withOpacity(0.20)
            : const Color(0xFF2F7D20).withOpacity(0.35),
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