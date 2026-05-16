import 'package:cloud_firestore/cloud_firestore.dart';

// REQ-F-03, REQ-F-04: 사용자별 가능 일정 데이터를 표현하는 모델
class ScheduleModel {
  final String uid; // 일정을 입력한 사용자 식별값
  final String userName; // 공용 캘린더에 표시할 사용자 이름

  // 날짜별 선택 시간대 저장
  // 예: {'2026-05-17': ['오전', '오후'], '2026-05-18': ['저녁']}
  final Map<String, List<String>> timeSelection;

  // 마지막 일정 수정 시간
  final DateTime? updatedAt;

  ScheduleModel({
    required this.uid,
    required this.userName,
    required this.timeSelection,
    this.updatedAt,
  });

  // Firestore에서 가져온 Map 데이터를 ScheduleModel 객체로 변환
  factory ScheduleModel.fromMap(Map<String, dynamic> map) {
    return ScheduleModel(
      uid: map['uid'] ?? '',
      userName: map['userName'] ?? '',
      timeSelection: (map['timeSelection'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, List<String>.from(value)),
          ) ?? {},
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ScheduleModel 객체를 Firestore에 저장할 수 있는 Map 형태로 변환
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'userName': userName,
      'timeSelection': timeSelection,
      'updatedAt': FieldValue.serverTimestamp(), // 서버 기준 수정 시간 저장
    };
  }
}
