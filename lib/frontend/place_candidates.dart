// lib/frontend/place_candidates.dart

import 'package:flutter/material.dart';

// 장소 후보 입력 / 투표 — REQ-F-06, F-07
class PlaceCandidatesScreen extends StatefulWidget {
  final String meetingTitle;
  final String meetingEmoji;

  const PlaceCandidatesScreen({
    super.key,
    this.meetingTitle = '종강 파티',
    this.meetingEmoji = '🎉',
  });

  @override
  State<PlaceCandidatesScreen> createState() => _PlaceCandidatesScreenState();
}

class _PlaceCandidatesScreenState extends State<PlaceCandidatesScreen> {
  int? _votedIndex;

  final List<Map<String, dynamic>> _places = [
    {
      'name': '강남 파스타집',
      'address': '서울 강남구 역삼동 123',
      'votes': 3,
    },
    {
      'name': '홍대 삼겹살',
      'address': '서울 마포구 홍익로 45',
      'votes': 1,
    },
    {
      'name': '합정 고깃집',
      'address': '서울 마포구 양화로 21',
      'votes': 2,
    },
  ];

  void _vote(int index) {
    setState(() {
      if (_votedIndex != null) {
        _places[_votedIndex!]['votes'] = (_places[_votedIndex!]['votes'] as int) - 1;
      }
      _votedIndex = index;
      _places[index]['votes'] = (_places[index]['votes'] as int) + 1;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_places[index]['name']}에 투표했습니다.')),
    );
  }

  void _showAddPlaceMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('장소 추가 입력창은 추후 연결 예정입니다.')),
    );
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.meetingEmoji} ${widget.meetingTitle}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildMapPlaceholder(),
                    const SizedBox(height: 20),
                    const Text(
                      '후보 장소 목록',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_places.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _PlaceCard(
                          place: _places[index],
                          isVoted: _votedIndex == index,
                          onVote: () => _vote(index),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 12, 20, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF3A3A3C), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Expanded(
            child: Text(
              '장소 후보',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _showAddPlaceMessage,
            icon: const Icon(Icons.add, size: 16, color: Colors.white),
            label: const Text('추가', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder() {
    return Container(
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white38,
          width: 1,
        ),
      ),
      child: const Center(
        child: Text(
          '📍지도 (장소 핀 표시)',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final bool isVoted;
  final VoidCallback onVote;

  const _PlaceCard({
    required this.place,
    required this.isVoted,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final votes = place['votes'] as int;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF242424),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isVoted ? const Color(0xFF4A6CF7) : Colors.transparent,
          width: 1.3,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  place['name'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  place['address'] as String,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: onVote,
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isVoted ? const Color(0xFF294C7A) : Colors.transparent,
                    side: BorderSide(
                      color: isVoted ? const Color(0xFF4A6CF7) : Colors.white24,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    isVoted ? '투표 완료' : '투표하기',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$votes\n표',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF4AA3FF),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
