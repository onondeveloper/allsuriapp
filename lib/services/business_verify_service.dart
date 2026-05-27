import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'api_service.dart';

/// 진위확인 결과 코드
enum BusinessVerifyCode {
  ok,
  duplicate,
  notMatched,
  closed,
  notRegistered,
  invalidFormat,
  rateLimited,
  unauthorized,
  forbidden,
  upstreamError,
  serverMisconfigured,
  serviceUnavailable,
  networkError,
  unknownError,
}

BusinessVerifyCode _parseCode(String? raw) {
  switch (raw) {
    case 'OK':
      return BusinessVerifyCode.ok;
    case 'DUPLICATE':
      return BusinessVerifyCode.duplicate;
    case 'NOT_MATCHED':
      return BusinessVerifyCode.notMatched;
    case 'CLOSED':
      return BusinessVerifyCode.closed;
    case 'NOT_REGISTERED':
      return BusinessVerifyCode.notRegistered;
    case 'INVALID_FORMAT':
      return BusinessVerifyCode.invalidFormat;
    case 'RATE_LIMITED':
      return BusinessVerifyCode.rateLimited;
    case 'UNAUTHORIZED':
      return BusinessVerifyCode.unauthorized;
    case 'FORBIDDEN':
      return BusinessVerifyCode.forbidden;
    case 'UPSTREAM_ERROR':
      return BusinessVerifyCode.upstreamError;
    case 'SERVER_MISCONFIGURED':
      return BusinessVerifyCode.serverMisconfigured;
    case 'SERVICE_UNAVAILABLE':
      return BusinessVerifyCode.serviceUnavailable;
    case 'NETWORK_ERROR':
      return BusinessVerifyCode.networkError;
    default:
      return BusinessVerifyCode.unknownError;
  }
}

class BusinessVerifyResult {
  final bool success;
  final BusinessVerifyCode code;
  final String message;
  final String? taxType;
  final String? bStt;
  final String? maskedRepName;

  const BusinessVerifyResult({
    required this.success,
    required this.code,
    required this.message,
    this.taxType,
    this.bStt,
    this.maskedRepName,
  });

  factory BusinessVerifyResult.fromMap(Map<String, dynamic> map) {
    return BusinessVerifyResult(
      success: map['success'] == true,
      code: _parseCode(map['code'] as String?),
      message: (map['message'] as String?) ?? '',
      taxType: map['tax_type'] as String?,
      bStt: map['b_stt'] as String?,
      maskedRepName: map['rep_name'] as String?,
    );
  }
}

/// 사업자등록정보 진위확인 클라이언트.
///
/// Netlify Function `/api/business/verify` 를 호출한다. 인증된 사용자만 호출 가능.
class BusinessVerifyService {
  // 호환성을 위해 ApiService 의존성 주입은 받되, 실제 호출은 직접 http 사용.
  // ignore: unused_field
  final ApiService? _api;

  BusinessVerifyService({ApiService? api}) : _api = api;

  /// 사업자번호 정규화 (하이픈/공백 제거 후 10자리 검증)
  static String? normalizeBusinessNumber(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 10 ? digits : null;
  }

  /// 개업일 → YYYYMMDD 문자열 변환
  static String formatStartDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  /// 진위확인 호출.
  ///
  /// 일반 ApiService.post를 우회하고 직접 http로 호출한다.
  /// 이유: 서버(business-verify Netlify Function)가 NOT_MATCHED/CLOSED/NOT_REGISTERED
  /// 같은 *비즈니스* 실패를 HTTP 4xx로 응답하고 본문에 `{success:false, code, message}`
  /// 를 담아주는데, ApiService.post는 4xx면 본문을 버리고 'HTTP 404: Not Found' 같은
  /// raw 문자열만 남기기 때문이다. 본문을 항상 파싱해서 사용자에게 친절한 메시지를 보장한다.
  Future<BusinessVerifyResult> verify({
    required String businessNumber,
    required String repName,
    required DateTime openDate,
    String? businessName,
  }) async {
    final normalizedBNo = normalizeBusinessNumber(businessNumber);
    if (normalizedBNo == null) {
      return const BusinessVerifyResult(
        success: false,
        code: BusinessVerifyCode.invalidFormat,
        message: '사업자번호를 숫자 10자리로 정확히 입력해 주세요.',
      );
    }
    if (repName.trim().length < 2) {
      return const BusinessVerifyResult(
        success: false,
        code: BusinessVerifyCode.invalidFormat,
        message: '대표자(사장님) 성함을 입력해 주세요.',
      );
    }

    final payload = <String, dynamic>{
      'b_no': normalizedBNo,
      'p_nm': repName.trim(),
      'start_dt': formatStartDate(openDate),
      if (businessName != null && businessName.trim().isNotEmpty)
        'b_nm': businessName.trim(),
    };

    final uri = Uri.parse('${ApiService.baseUrl}/business/verify');

    // 서버는 Supabase JWT(access_token)를 검증하므로,
    // 항상 현재 활성 Supabase 세션의 토큰을 직접 사용한다.
    // (ApiService.currentBearerToken은 stale 가능성이 있음)
    String? token;
    String tokenSource = 'none';
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null && session.accessToken.isNotEmpty) {
        token = session.accessToken;
        tokenSource = 'supabase_session';
      }
    } catch (e) {
      debugPrint('[BusinessVerifyService] supabase session lookup error: $e');
    }
    if (token == null || token.isEmpty) {
      // fallback: ApiService 정적 캐시
      token = ApiService.currentBearerToken;
      if (token != null && token.isNotEmpty) tokenSource = 'api_service_cache';
    }

    if (token == null || token.isEmpty) {
      debugPrint('[BusinessVerifyService] no auth token available');
      return const BusinessVerifyResult(
        success: false,
        code: BusinessVerifyCode.unauthorized,
        message: '로그인이 만료되었습니다. 앱을 다시 시작해 주세요.',
      );
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    debugPrint('[BusinessVerifyService] POST $uri keys=${payload.keys.toList()} '
        'tokenSource=$tokenSource tokenLen=${token.length}');

    http.Response resp;
    try {
      resp = await http
          .post(uri, headers: headers, body: jsonEncode(payload))
          .timeout(const Duration(seconds: 20));
    } catch (e) {
      debugPrint('[BusinessVerifyService] network error: $e');
      return const BusinessVerifyResult(
        success: false,
        code: BusinessVerifyCode.networkError,
        message: '인터넷 연결을 확인하고 다시 시도해 주세요.',
      );
    }

    debugPrint('[BusinessVerifyService] status=${resp.statusCode} '
        'body=${resp.body.length > 500 ? '${resp.body.substring(0, 500)}...' : resp.body}');

    // 본문 JSON 파싱 시도 (4xx/5xx여도 본문에 code/message가 있을 수 있음)
    Map<String, dynamic>? body;
    if (resp.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // JSON이 아닌 응답: 인프라 오류(라우트 미배포, 502 게이트웨이 등)
      }
    }

    // 정상 케이스 (200 + 본문에 success:true)
    if (resp.statusCode == 200 && body != null && body['success'] == true) {
      return BusinessVerifyResult.fromMap(body);
    }

    // 본문에 표준 실패 페이로드가 들어 있는 케이스
    if (body != null && body.containsKey('code')) {
      return BusinessVerifyResult(
        success: false,
        code: _parseCode(body['code'] as String?),
        message: (body['message'] as String?) ?? '',
      );
    }

    // 본문이 없거나 JSON이 아닌 경우 — 인프라성 에러를 사용자 친화 코드로 매핑
    final BusinessVerifyCode mapped;
    if (resp.statusCode == 401 || resp.statusCode == 403) {
      mapped = BusinessVerifyCode.unauthorized;
    } else if (resp.statusCode == 404) {
      mapped = BusinessVerifyCode.serviceUnavailable;
    } else if (resp.statusCode == 429) {
      mapped = BusinessVerifyCode.rateLimited;
    } else if (resp.statusCode >= 500 && resp.statusCode < 600) {
      mapped = BusinessVerifyCode.serviceUnavailable;
    } else {
      mapped = BusinessVerifyCode.unknownError;
    }

    return BusinessVerifyResult(
      success: false,
      code: mapped,
      message: '', // friendlyMessage()가 코드 기반으로 덮어쓴다
    );
  }

  /// 임의 사용자(주로 낙찰 후보 사업자)가 사업자 활동 가능 상태인지 조회.
  /// 2026-05 완화: 관리자 우회 또는 사업자번호 보유만 확인 (fn_business_can_act 와 동일).
  static Future<bool> isUserEligibleAsBusiness(String userId) async {
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('role, businessstatus, businessnumber, business_verify_bypass')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) return false;
      if ((row['role'] ?? '') != 'business') return false;
      if ((row['businessstatus']?.toString() ?? '') != 'approved') return false;
      if (row['business_verify_bypass'] == true) return true;

      final bNo = (row['businessnumber'] ?? '').toString();
      final hasBNo = bNo.replaceAll(RegExp(r'[^0-9]'), '').length == 10;
      return hasBNo;
    } catch (e) {
      debugPrint('[BusinessVerifyService] isUserEligibleAsBusiness error: $e');
      return false;
    }
  }

  /// 코드별 사용자 친화 메시지로 변환
  static String friendlyMessage(BusinessVerifyResult r) {
    if (r.success) return '사업자등록 진위확인이 완료되었습니다.';
    switch (r.code) {
      case BusinessVerifyCode.duplicate:
        return '이미 다른 계정에서 인증된 사업자번호입니다.\n'
            '본인 계정이 맞는데도 이 메시지가 보인다면 고객센터로 문의해 주세요.';
      case BusinessVerifyCode.notMatched:
        return '국세청에 등록된 정보와 입력하신 내용이 일치하지 않습니다.\n\n'
            '아래 항목을 다시 확인해 주세요.\n'
            '• 사업자등록번호 10자리\n'
            '• 대표자(사장님) 성함\n'
            '• 개업일자 (사업자등록증 기준)\n\n'
            '※ 신규 사업자는 국세청 DB 반영까지 며칠 걸릴 수 있습니다.\n'
            '   인증이 완료되지 않아도 사업자번호만 등록되어 있으면 '
            '오더 등록·입찰·낙찰은 정상적으로 사용하실 수 있습니다.';
      case BusinessVerifyCode.closed:
        return r.message.isNotEmpty
            ? r.message
            : '국세청 조회 결과 휴업 또는 폐업 상태로 등록된 사업자입니다.\n'
                '계속 사업 중이시라면 사업자등록 변경 후 다시 시도해 주세요.';
      case BusinessVerifyCode.notRegistered:
        return '국세청에 등록되지 않은 사업자번호로 조회됩니다.\n'
            '사업자등록번호 10자리를 다시 확인해 주세요.\n\n'
            '※ 신규 사업자는 국세청 DB 반영까지 며칠 걸릴 수 있습니다.\n'
            '   사업자번호가 정확하다면 그대로 두셔도 오더 등록·입찰·낙찰은 사용 가능합니다.';
      case BusinessVerifyCode.invalidFormat:
        return r.message.isNotEmpty ? r.message : '입력 형식을 확인해 주세요.';
      case BusinessVerifyCode.rateLimited:
        return '진위확인 요청이 너무 잦습니다. 잠시 후 다시 시도해 주세요.';
      case BusinessVerifyCode.unauthorized:
        return r.message.isNotEmpty
            ? r.message
            : '로그인이 만료되어 진위확인 요청을 보낼 수 없습니다.\n'
                '앱을 종료한 뒤 다시 실행하여 카카오 로그인을 갱신한 후 시도해 주세요.';
      case BusinessVerifyCode.forbidden:
        return r.message.isNotEmpty
            ? r.message
            : '사업자 회원만 진위확인을 진행할 수 있습니다.';
      case BusinessVerifyCode.upstreamError:
        return '국세청 진위확인 서비스가 일시적으로 응답하지 않습니다.\n'
            '잠시 후 다시 시도해 주세요.';
      case BusinessVerifyCode.serverMisconfigured:
        return '진위확인 서비스 설정에 문제가 있어 일시적으로 사용할 수 없습니다.\n'
            '잠시 후 다시 시도해 주시고, 계속 같은 문제가 발생하면 고객센터로 문의해 주세요.';
      case BusinessVerifyCode.serviceUnavailable:
        return '진위확인 서비스를 일시적으로 사용할 수 없습니다.\n'
            '잠시 후 다시 시도해 주세요.';
      case BusinessVerifyCode.networkError:
        return r.message.isNotEmpty
            ? r.message
            : '인터넷 연결을 확인하고 다시 시도해 주세요.';
      case BusinessVerifyCode.ok:
        return '인증되었습니다.';
      case BusinessVerifyCode.unknownError:
        return r.message.isNotEmpty
            ? r.message
            : '진위확인 중 알 수 없는 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.';
    }
  }
}
