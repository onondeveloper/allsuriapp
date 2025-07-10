import 'role.dart';

enum BusinessStatus {
  pending,    // 승인 대기
  approved,   // 승인됨
  rejected,   // 거절됨
}

// 한국 주요 도시 목록
class KoreanCities {
  static const List<String> cities = [
    '서울',
    '부산',
    '대구',
    '인천',
    '광주',
    '대전',
    '울산',
    '세종',
    '수원',
    '고양',
    '용인',
    '창원',
    '성남',
    '부천',
    '안산',
    '안양',
    '남양주',
    '평택',
    '시흥',
    '김포',
    '하남',
    '오산',
    '이천',
    '안성',
    '의왕',
    '양평',
    '여주',
    '과천',
    '광명',
    '군포',
    '의정부',
    '동두천',
    '구리',
    '파주',
    '양주',
    '포천',
    '연천',
    '가평',
    '천안',
    '공주',
    '보령',
    '아산',
    '서산',
    '논산',
    '계룡',
    '당진',
    '금산',
    '부여',
    '서천',
    '청양',
    '홍성',
    '예산',
    '태안',
    '청주',
    '충주',
    '제천',
    '보은',
    '옥천',
    '영동',
    '증평',
    '진천',
    '괴산',
    '음성',
    '단양',
    '전주',
    '군산',
    '익산',
    '정읍',
    '남원',
    '김제',
    '완주',
    '진안',
    '무주',
    '장수',
    '임실',
    '순창',
    '고창',
    '부안',
    '목포',
    '여수',
    '순천',
    '나주',
    '광양',
    '담양',
    '곡성',
    '구례',
    '고흥',
    '보성',
    '화순',
    '장흥',
    '강진',
    '해남',
    '영암',
    '무안',
    '함평',
    '영광',
    '장성',
    '완도',
    '진도',
    '신안',
    '포항',
    '경주',
    '김천',
    '안동',
    '구미',
    '영주',
    '영천',
    '상주',
    '문경',
    '경산',
    '군위',
    '의성',
    '청송',
    '영양',
    '영덕',
    '청도',
    '고령',
    '성주',
    '칠곡',
    '예천',
    '봉화',
    '울진',
    '울릉',
    '창원',
    '진주',
    '통영',
    '사천',
    '김해',
    '밀양',
    '거제',
    '양산',
    '의령',
    '함안',
    '창녕',
    '고성',
    '남해',
    '하동',
    '산청',
    '함양',
    '거창',
    '합천',
    '제주',
  ];
}

// 설비 카테고리 목록
class EquipmentCategories {
  static const List<String> categories = [
    '에어컨',
    '냉장고',
    '세탁기',
    '건조기',
    '가스레인지',
    '전자레인지',
    '오븐',
    '식기세척기',
    '정수기',
    '공기청정기',
    '가습기',
    '제습기',
    '청소기',
    '커피머신',
    '전기밥솥',
    '믹서기',
    '토스터기',
    '전기포트',
    '온수기',
    '보일러',
    '히터',
    '선풍기',
    '전기장판',
    '전기담요',
    '전기히터',
    '온풍기',
    '냉난방기',
    '공조기',
    '환기장치',
    '배수장치',
    '급수장치',
    '소화설비',
    '보안설비',
    'CCTV',
    '인터폰',
    '도어락',
    '자동문',
    '엘리베이터',
    '에스컬레이터',
    '컨베이어',
    '기타',
  ];
}

class User {
  final String id;
  final String? email;  // 익명 사용자는 이메일이 없을 수 있음
  final String name;
  final UserRole role;
  final String? businessName; // For business users
  final String? businessLicense; // For business users
  final String? businessNumber; // 사업자 번호
  final BusinessStatus businessStatus;
  final String? phoneNumber;
  final String? address;
  final List<String> serviceAreas; // 활동 지역 (최대 5개)
  final List<String> specialties; // 전문 분야
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isActive;
  final bool isAnonymous; // 익명 사용자 여부
  final String status; // pending, approved, rejected

  User({
    required this.id,
    this.email,
    required this.name,
    required this.role,
    this.businessName,
    this.businessLicense,
    this.businessNumber,
    this.businessStatus = BusinessStatus.pending,
    this.phoneNumber,
    this.address,
    this.serviceAreas = const [],
    this.specialties = const [],
    DateTime? createdAt,
    this.lastLoginAt,
    this.isActive = true,
    this.isAnonymous = false,
    this.status = 'pending',
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.value,
      'businessName': businessName,
      'businessLicense': businessLicense,
      'businessNumber': businessNumber,
      'businessStatus': businessStatus.name,
      'phoneNumber': phoneNumber,
      'address': address,
      'serviceAreas': serviceAreas,
      'specialties': specialties,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isActive': isActive,
      'isAnonymous': isAnonymous,
      'status': status,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] ?? '',
      email: map['email'],
      name: map['name'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.value == map['role'],
        orElse: () => UserRole.customer,
      ),
      businessName: map['businessName'],
      businessLicense: map['businessLicense'],
      businessNumber: map['businessNumber'],
      businessStatus: BusinessStatus.values.firstWhere(
        (e) => e.name == map['businessStatus'],
        orElse: () => BusinessStatus.pending,
      ),
      phoneNumber: map['phoneNumber'],
      address: map['address'],
      serviceAreas: List<String>.from(map['serviceAreas'] ?? []),
      specialties: List<String>.from(map['specialties'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] ?? ''),
      lastLoginAt: map['lastLoginAt'] != null
          ? DateTime.parse(map['lastLoginAt'])
          : null,
      isActive: map['isActive'] ?? true,
      isAnonymous: map['isAnonymous'] ?? false,
      status: map['status'] ?? 'pending',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'role': role.toString(),
        'businessName': businessName,
        'businessLicense': businessLicense,
        'businessNumber': businessNumber,
        'businessStatus': businessStatus.name,
        'phoneNumber': phoneNumber,
        'address': address,
        'serviceAreas': serviceAreas,
        'specialties': specialties,
        'createdAt': createdAt.toIso8601String(),
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'isActive': isActive,
        'isAnonymous': isAnonymous,
        'status': status,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String?,
        name: json['name'] as String,
        role: UserRole.fromString(json['role'] as String),
        businessName: json['businessName'] as String?,
        businessLicense: json['businessLicense'] as String?,
        businessNumber: json['businessNumber'] as String?,
        businessStatus: BusinessStatus.values.firstWhere((e) => e.name == json['businessStatus']),
        phoneNumber: json['phoneNumber'] as String?,
        address: json['address'] as String?,
        serviceAreas: List<String>.from(json['serviceAreas'] ?? []),
        specialties: List<String>.from(json['specialties'] ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        lastLoginAt: json['lastLoginAt'] != null
            ? DateTime.parse(json['lastLoginAt'] as String)
            : null,
        isActive: json['isActive'] as bool? ?? true,
        isAnonymous: json['isAnonymous'] as bool? ?? false,
        status: json['status'] as String? ?? 'pending',
      );

  User copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    String? businessName,
    String? businessLicense,
    String? businessNumber,
    BusinessStatus? businessStatus,
    String? phoneNumber,
    String? address,
    List<String>? serviceAreas,
    List<String>? specialties,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    bool? isActive,
    bool? isAnonymous,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      businessName: businessName ?? this.businessName,
      businessLicense: businessLicense ?? this.businessLicense,
      businessNumber: businessNumber ?? this.businessNumber,
      businessStatus: businessStatus ?? this.businessStatus,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      specialties: specialties ?? this.specialties,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      isActive: isActive ?? this.isActive,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      status: status ?? this.status,
    );
  }

  // 익명 사용자 생성 팩토리
  factory User.anonymous({
    required String name,
    required String phoneNumber,
    String? address,
  }) {
    return User(
      id: 'anon_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      role: UserRole.customer,
      phoneNumber: phoneNumber,
      address: address,
      isAnonymous: true,
    );
  }

  // 사업자 승인 여부 확인
  bool get isApprovedBusiness => 
      role == UserRole.business && businessStatus == BusinessStatus.approved;

  // 표시용 이름 (사업자의 경우 사업자명, 일반 사용자의 경우 이름)
  String get displayName {
    if (role == UserRole.business && businessName != null && businessName!.isNotEmpty) {
      return businessName!;
    }
    return name;
  }
}
