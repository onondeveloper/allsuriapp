// API 기본 URL
const API_BASE = '/api/admin';
const MARKET_API_BASE = '/api/admin/market';
const ADS_API_BASE = '/api/admin/ads';

// 페이지네이션 및 정렬 상태
let estimatesPage = 1;
const estimatesPerPage = 15;
let estimatesSortColumn = null;
let estimatesSortDirection = 'asc';
let allEstimates = [];

// 관리자 토큰 (.env 파일의 ADMIN_TOKEN과 일치해야 함)
const ADMIN_TOKEN = 'allsuri-admin-2024';
let ADMIN_ROLE = 'developer';

// 로그인 체크
function checkLogin() {
    const password = localStorage.getItem('admin_password');
    if (!password || password !== 'allsuri1912') {
        const inputPassword = prompt('관리자 비밀번호를 입력하세요:');
        if (!inputPassword || inputPassword !== 'allsuri1912') {
            alert('비밀번호가 틀렸습니다.');
            document.body.innerHTML = '<h1 style="text-align:center;margin-top:50px;">접근이 거부되었습니다.</h1>';
            return false;
        }
        localStorage.setItem('admin_password', inputPassword);
    }
    return true;
}

// API 호출 헬퍼 함수
async function apiCall(endpoint, options = {}) {
    const url = `${API_BASE}${endpoint}`;
    const config = {
        headers: {
            'Content-Type': 'application/json',
            'admin-token': ADMIN_TOKEN,
            ...options.headers
        },
        ...options
    };

    // 디버그 로그 추가
    console.log('[API CALL] URL:', url);
    console.log('[API CALL] Headers:', config.headers);
    console.log('[API CALL] Token being sent:', ADMIN_TOKEN);

    try {
        const response = await fetch(url, config);
        if (!response.ok) {
            if (response.status === 401) {
                throw new Error('관리자 권한이 필요합니다. ADMIN_TOKEN을 확인해주세요.');
            }
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return await response.json();
    } catch (error) {
        console.error('API 호출 오류:', error);
        throw error;
    }
}

        // 대시보드 데이터 로드
        async function loadDashboard() {
            try {
                await loadAdminMe();
                const data = await apiCall('/dashboard');
                
                console.log('[DASHBOARD] Received data:', data);
                
                // totalUsers 제거, totalJobs 추가
                document.getElementById('totalJobs').textContent = data.totalJobs || 0;
                document.getElementById('totalBusinessUsers').textContent = data.totalBusinessUsers || 0;
                document.getElementById('totalCustomers').textContent = data.totalCustomers || 0;
                document.getElementById('pendingUsers').textContent = (data.totalBusinessUsers || 0) - (data.approvedUsers || 0);
                document.getElementById('totalEstimates').textContent = data.totalEstimates || 0;
                document.getElementById('pendingEstimates').textContent = data.pendingEstimates || 0;
                document.getElementById('approvedEstimates').textContent = data.approvedEstimates || 0;
                document.getElementById('completedEstimates').textContent = data.completedEstimates || 0;
                document.getElementById('inProgressEstimates').textContent = data.inProgressEstimates || 0;
                document.getElementById('awardedEstimates').textContent = data.awardedEstimates || 0;
                document.getElementById('transferredEstimates').textContent = data.transferredEstimates || 0;
                // 총 수익을 원화 형식으로 표시
                document.getElementById('totalRevenue').textContent = '₩' + (data.totalRevenue?.toLocaleString('ko-KR') || '0');
            } catch (error) {
                console.error('대시보드 로드 오류:', error);
            }
        }

// 권한 조회 및 UI 제어
async function loadAdminMe() {
    try {
        const me = await apiCall('/me');
        ADMIN_ROLE = me.role || 'business';
        // 권한에 따라 UI 버튼 제어
        if (!(me.permissions?.canManageUsers)) {
            const userSection = document.querySelector('h2:nth-of-type(1)'); // 사용자 관리 섹션 헤더 탐색 (간단)
            // no-op for brevity
        }
        if (!(me.permissions?.canManageAds)) {
            const btnNewAd = document.getElementById('btnNewAd');
            if (btnNewAd) btnNewAd.style.display = 'none';
        }
    } catch (e) {
        console.warn('관리자 권한 조회 실패:', e);
    }
}

// 전체 사용자 목록 저장
let allUsers = [];

// 사용자 목록 로드
async function loadUsers() {
    try {
        console.log('[loadUsers] 사용자 목록 로딩 시작...');
        // 캐시 방지를 위해 타임스탬프 추가
        const timestamp = new Date().getTime();
        allUsers = await apiCall(`/users?t=${timestamp}`);
        console.log('[loadUsers] 받은 사용자 수:', allUsers.length);
        console.log('[loadUsers] 사용자 목록:', allUsers);
        
        if (!Array.isArray(allUsers)) {
            console.error('[loadUsers] 응답이 배열이 아닙니다:', allUsers);
            throw new Error('잘못된 응답 형식');
        }
        
        // 검색창 초기화
        const searchInput = document.getElementById('userSearchInput');
        if (searchInput) {
            searchInput.value = '';
        }
        
        displayUsers(allUsers);
    } catch (error) {
        console.error('[loadUsers] 에러:', error);
        document.getElementById('userTableContainer').innerHTML = 
            '<div class="error">사용자 목록을 불러오는데 실패했습니다: ' + error.message + '</div>';
    }
}

// 사용자 검색 필터링
function filterUsers(searchTerm) {
    if (!searchTerm || searchTerm.trim() === '') {
        displayUsers(allUsers);
        return;
    }
    
    const term = searchTerm.toLowerCase().trim();
    const filtered = allUsers.filter(user => {
        const businessName = (user.businessName || user.businessname || '').toLowerCase();
        const name = (user.name || '').toLowerCase();
        const phone = (user.phoneNumber || user.phonenumber || '').replace(/\D/g, '');
        const searchPhone = term.replace(/\D/g, '');
        
        return businessName.includes(term) || 
               name.includes(term) || 
               (searchPhone && phone.includes(searchPhone));
    });
    
    displayUsers(filtered);
}

        // 사용자 표시
        function displayUsers(users) {
            const container = document.getElementById('userTableContainer');
            
            if (users.length === 0) {
                container.innerHTML = `
                    <div class="empty-state">
                        <span class="material-icons">people_outline</span>
                        <p>등록된 사용자가 없습니다</p>
                    </div>
                `;
                return;
            }

            const table = `
                <div class="table-container">
                    <table class="table">
                        <thead>
                            <tr>
                                <th>상호</th>
                                <th>이름</th>
                                <th>카카오 ID</th>
                                <th>상태</th>
                                <th>가입일</th>
                                <th>작업</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${users.map(user => `
                                <tr>
                                    <td><strong>${user.businessName || user.businessname || '-'}</strong></td>
                                    <td>
                                        <span class="clickable" data-user-id="${user.id}" style="color: #1a73e8; cursor: pointer; text-decoration: underline;">
                                            ${user.name || '이름 없음'}
                                        </span>
                                    </td>
                                    <td><code>${user.kakao_id || user.external_id || '-'}</code></td>
                                    <td>
                                        <span class="status-badge ${(user.businessStatus || user.businessstatus || 'pending')}">
                                            ${getStatusText(user.businessStatus || user.businessstatus)}
                                        </span>
                                    </td>
                                    <td>${new Date(user.createdAt || user.createdat).toLocaleDateString('ko-KR')}</td>
                                    <td>
                                        <button class="btn btn-secondary btn-sm" data-user-id="${user.id}" data-action="view" style="margin-right: 0.5rem;">
                                            <span class="material-icons" style="font-size: 1rem;">visibility</span>
                                            상세 보기
                                        </button>
                                    </td>
                                </tr>
                            `).join('')}
                        </tbody>
                    </table>
                </div>
            `;
            
            container.innerHTML = table;
            
            // 사용자 이름 클릭 이벤트 리스너 설정
            const clickableCells = container.querySelectorAll('.clickable');
            clickableCells.forEach(cell => {
                cell.addEventListener('click', () => {
                    const userId = cell.getAttribute('data-user-id');
                    showUserDetail(userId);
                });
            });

            // 사용자 액션 버튼 이벤트 리스너 설정
            const actionButtons = container.querySelectorAll('[data-action]');
            actionButtons.forEach(button => {
                button.addEventListener('click', (e) => {
                    e.stopPropagation();
                    const userId = button.getAttribute('data-user-id');
                    const action = button.getAttribute('data-action');
                    
                    switch(action) {
                        case 'view':
                            showUserDetail(userId);
                            break;
                        case 'approve':
                            approveUser(userId);
                            break;
                        case 'reject':
                            rejectUser(userId);
                            break;
                        case 'delete':
                            deleteUser(userId);
                            break;
                    }
                });
            });
        }

        // 견적 목록 로드
async function loadEstimates() {
    try {
        const params = buildEstimateQueryParams();
        const qs = params ? `?${params}` : '';
        allEstimates = await apiCall(`/estimates${qs}`);
        estimatesPage = 1; // Reset to first page
        displayEstimates();
    } catch (error) {
        document.getElementById('estimateTableContainer').innerHTML = 
            '<div class="error">견적 목록을 불러오는데 실패했습니다.</div>';
    }
}

        // 견적 표시 (페이지네이션 및 정렬 포함)
        function displayEstimates() {
            const container = document.getElementById('estimateTableContainer');
            
            if (allEstimates.length === 0) {
                container.innerHTML = '<div class="loading">등록된 견적이 없습니다.</div>';
                return;
            }

            // 정렬 적용
            let sortedEstimates = [...allEstimates];
            if (estimatesSortColumn) {
                sortedEstimates.sort((a, b) => {
                    let aVal = a[estimatesSortColumn];
                    let bVal = b[estimatesSortColumn];
                    
                    // 날짜 처리
                    if (estimatesSortColumn === 'createdAt' || estimatesSortColumn === 'createdat') {
                        aVal = new Date(a.createdAt || a.createdat || 0).getTime();
                        bVal = new Date(b.createdAt || b.createdat || 0).getTime();
                    }
                    
                    // 금액 처리
                    if (estimatesSortColumn === 'amount' || estimatesSortColumn === 'estimatedPrice') {
                        aVal = a.amount || a.estimatedPrice || 0;
                        bVal = b.amount || b.estimatedPrice || 0;
                    }
                    
                    // 문자열 비교
                    if (typeof aVal === 'string') {
                        aVal = (aVal || '').toLowerCase();
                        bVal = (bVal || '').toLowerCase();
                    }
                    
                    if (aVal < bVal) return estimatesSortDirection === 'asc' ? -1 : 1;
                    if (aVal > bVal) return estimatesSortDirection === 'asc' ? 1 : -1;
                    return 0;
                });
            }

            // 페이지네이션 적용
            const totalPages = Math.ceil(sortedEstimates.length / estimatesPerPage);
            const startIdx = (estimatesPage - 1) * estimatesPerPage;
            const endIdx = startIdx + estimatesPerPage;
            const paginatedEstimates = sortedEstimates.slice(startIdx, endIdx);

            const table = `
                <div class="table-container">
                    <table class="table">
                        <thead>
                            <tr>
                                <th class="sortable" data-column="title">제목</th>
                                <th class="sortable" data-column="customerName">고객</th>
                                <th class="sortable" data-column="businessName">사업자</th>
                                <th class="sortable" data-column="amount">금액</th>
                                <th class="sortable" data-column="status">상태</th>
                                <th class="sortable" data-column="createdAt">생성일</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${paginatedEstimates.map(e => {
                                const title = e.title || e.description || '제목 없음';
                                const customerName = e.customerName || e.customername || '고객명 없음';
                                const businessName = e.businessName || e.businessname || '사업자명 없음';
                                const amountRaw = (e.amount !== undefined && e.amount !== null) ? e.amount : (e.estimatedPrice !== undefined ? e.estimatedPrice : null);
                                const amountText = (typeof amountRaw === 'number') ? amountRaw.toLocaleString() + '원' : '금액 없음';
                                const createdAt = e.createdAt || e.createdat;
                                const createdAtText = createdAt ? new Date(createdAt).toLocaleDateString() : '-';
                                const status = e.status || '-';
                                return `
                                <tr>
                                    <td class="clickable-title" data-estimate-id="${e.id}" style="cursor: pointer; color: #1a73e8; text-decoration: underline;">${title}</td>
                                    <td>${customerName}</td>
                                    <td>${businessName}</td>
                                    <td>${amountText}</td>
                                    <td>
                                        <span class="status-badge status-${status}">${getStatusText(status)}</span>
                                    </td>
                                    <td>${createdAtText}</td>
                                </tr>`;
                            }).join('')}
                        </tbody>
                    </table>
                </div>
                <div class="pagination">
                    <button onclick="changeEstimatePage(-1)" ${estimatesPage === 1 ? 'disabled' : ''}>이전</button>
                    <span>페이지 ${estimatesPage} / ${totalPages} (전체 ${sortedEstimates.length}건)</span>
                    <button onclick="changeEstimatePage(1)" ${estimatesPage >= totalPages ? 'disabled' : ''}>다음</button>
                </div>
            `;
            
            container.innerHTML = table;
            
            // 정렬 표시 업데이트
            if (estimatesSortColumn) {
                const headers = container.querySelectorAll('th');
                headers.forEach(th => {
                    const col = th.getAttribute('data-column');
                    if (col === estimatesSortColumn) {
                        th.classList.add(estimatesSortDirection === 'asc' ? 'sort-asc' : 'sort-desc');
                    }
                });
            }
            
            // 컬럼 헤더 클릭 이벤트 리스너
            const headers = container.querySelectorAll('th.sortable');
            headers.forEach(th => {
                th.addEventListener('click', () => {
                    const column = th.getAttribute('data-column');
                    if (estimatesSortColumn === column) {
                        estimatesSortDirection = estimatesSortDirection === 'asc' ? 'desc' : 'asc';
                    } else {
                        estimatesSortColumn = column;
                        estimatesSortDirection = 'asc';
                    }
                    displayEstimates();
                });
            });
            
            // 견적 제목 클릭 이벤트 리스너 설정
            const clickableTitles = container.querySelectorAll('.clickable-title');
            clickableTitles.forEach(title => {
                title.addEventListener('click', () => {
                    const estimateId = title.getAttribute('data-estimate-id');
                    showEstimateDetail(estimateId);
                });
            });
        }

        // 페이지 변경
        function changeEstimatePage(delta) {
            const totalPages = Math.ceil(allEstimates.length / estimatesPerPage);
            estimatesPage = Math.max(1, Math.min(estimatesPage + delta, totalPages));
            displayEstimates();
        }

// 상태 텍스트 변환
function getStatusText(status) {
    const statusMap = {
        'pending': '대기중',
        'approved': '승인됨',
        'rejected': '거절됨',
        'completed': '완료',
        'in_progress': '진행중',
        'awarded': '입찰 완료',
        'transferred': '이전됨'
    };
    return statusMap[status] || status;
}

        // 사용자 승인
        async function approveUser(userId) {
            try {
                console.log('사용자 승인 시도:', userId);
                const response = await apiCall(`/users/${userId}/status`, {
                    method: 'PATCH',
                    body: JSON.stringify({ status: 'approved' })
                });
                console.log('승인 응답:', response);
                
                // 서버 응답이 성공하면 즉시 UI 업데이트
                if (response.success) {
                    alert('사용자가 승인되었습니다.');
                    // Promise.all로 병렬 실행
                    await Promise.all([loadUsers(), loadDashboard()]);
                } else {
                    throw new Error('승인 실패');
                }
            } catch (error) {
                console.error('승인 오류:', error);
                alert('사용자 승인에 실패했습니다: ' + error.message);
            }
        }

        // 사용자 거절
        async function rejectUser(userId) {
            try {
                console.log('사용자 거절 시도:', userId);
                const response = await apiCall(`/users/${userId}/status`, {
                    method: 'PATCH',
                    body: JSON.stringify({ status: 'rejected' })
                });
                console.log('거절 응답:', response);
                
                // 서버 응답이 성공하면 즉시 UI 업데이트
                if (response.success) {
                    alert('사용자가 거절되었습니다.');
                    // Promise.all로 병렬 실행
                    await Promise.all([loadUsers(), loadDashboard()]);
                } else {
                    throw new Error('거절 실패');
                }
            } catch (error) {
                console.error('거절 오류:', error);
                alert('사용자 거절에 실패했습니다: ' + error.message);
            }
        }

// 사용자 삭제
async function deleteUser(userId) {
    if (!confirm('정말로 이 사용자를 삭제하시겠습니까?')) {
        return;
    }

    try {
        await apiCall(`/users/${userId}`, {
            method: 'DELETE'
        });
        loadUsers();
        loadDashboard();
    } catch (error) {
        alert('사용자 삭제에 실패했습니다.');
    }
}

        // 검색 기능 및 이벤트 리스너 설정
        document.addEventListener('DOMContentLoaded', () => {
            // 로그인 체크
            if (!checkLogin()) {
                return;
            }
            
            // 검색 기능 이벤트 리스너
            document.getElementById('userSearch').addEventListener('input', debounce(async (e) => {
                const query = e.target.value;
                if (query.length > 0) {
                    try {
                        const users = await apiCall(`/users/search?q=${encodeURIComponent(query)}`);
                        displayUsers(users);
                    } catch (error) {
                        console.error('사용자 검색 오류:', error);
                    }
                } else {
                    loadUsers();
                }
            }, 300));

            document.getElementById('estimateSearch').addEventListener('input', debounce(async (e) => {
                const query = e.target.value;
                if (query.length > 0) {
                    try {
                        const base = `/estimates/search?q=${encodeURIComponent(query)}`;
                        const params = buildEstimateQueryParams({ includeText:false });
                        const qs = params ? `&${params}` : '';
                        const estimates = await apiCall(`${base}${qs}`);
                        displayEstimates(estimates);
                    } catch (error) {
                        console.error('견적 검색 오류:', error);
                    }
                } else {
                        loadEstimates();
                }
            }, 300));

            // 필터 버튼
            document.getElementById('applyEstimateFilters').addEventListener('click', loadEstimates);
            document.getElementById('resetEstimateFilters').addEventListener('click', () => {
                document.getElementById('statusFilter').value = 'all';
                document.getElementById('startDateFilter').value = '';
                document.getElementById('endDateFilter').value = '';
                document.getElementById('phoneFilter').value = '';
                document.getElementById('estimateSearch').value = '';
                loadEstimates();
            });

            // 모달 닫기 버튼 이벤트 리스너
            document.getElementById('closeEstimateModal').addEventListener('click', closeEstimateModal);
            document.getElementById('closeEstimateModalBtn').addEventListener('click', closeEstimateModal);
            document.getElementById('closeUserModal').addEventListener('click', closeUserModal);
            document.getElementById('closeUserModalBtn').addEventListener('click', closeUserModal);
            document.getElementById('closeStatsModalBtn').addEventListener('click', closeStatsModal);

            // 견적 모달 버튼 이벤트 리스너
            document.getElementById('updateEstimateStatus').addEventListener('click', updateEstimateStatus);

            // 사용자 모달 버튼 이벤트 리스너
            document.getElementById('approveUserFromModal').addEventListener('click', approveUserFromModal);
            document.getElementById('rejectUserFromModal').addEventListener('click', rejectUserFromModal);

            // 통계 숫자 클릭 이벤트 리스너
            setupStatsClickListeners();

            // 페이지 로드 시 데이터 로드
            console.log('[PAGE LOAD] DOM이 로드되었습니다. 데이터를 불러오기 시작합니다.');
            loadDashboard();
            loadUsers();
            loadEstimates();
            // Call 현황 초기 로드 및 필터 바인딩
            const applyCallFiltersBtn = document.getElementById('applyCallFilters');
            if (applyCallFiltersBtn) {
                applyCallFiltersBtn.addEventListener('click', loadCalls);
            }
            if (typeof loadCalls === 'function') {
                loadCalls();
            }
            // 광고 로드 및 버튼 바인딩
            if (typeof loadAds === 'function') {
                loadAds();
            }
            const reloadAdsBtn = document.getElementById('btnReloadAds');
            if (reloadAdsBtn) reloadAdsBtn.addEventListener('click', loadAds);
            const newAdBtn = document.getElementById('btnNewAd');
            if (newAdBtn) newAdBtn.addEventListener('click', openAdCreateModal);
            const statsAdBtn = document.getElementById('btnAdsStats');
            if (statsAdBtn) statsAdBtn.addEventListener('click', showAdsStats);
        });

        // 쿼리 파라미터 구성
        function buildEstimateQueryParams(opts = { includeText:true }) {
            const status = (document.getElementById('statusFilter')?.value || '').trim();
            const startDate = (document.getElementById('startDateFilter')?.value || '').trim();
            const endDate = (document.getElementById('endDateFilter')?.value || '').trim();
            const phone = (document.getElementById('phoneFilter')?.value || '').trim();
            const text = (document.getElementById('estimateSearch')?.value || '').trim();
            const parts = [];
            if (status && status !== 'all') parts.push(`status=${encodeURIComponent(status)}`);
            if (startDate) parts.push(`startDate=${encodeURIComponent(startDate)}`);
            if (endDate) parts.push(`endDate=${encodeURIComponent(endDate)}`);
            if (phone) parts.push(`phone=${encodeURIComponent(phone)}`);
            if (opts.includeText && text) parts.push(`q=${encodeURIComponent(text)}`);
            return parts.join('&');
        }

        // 디바운스 함수
        function debounce(func, wait) {
            let timeout;
            return function executedFunction(...args) {
                const later = () => {
                    clearTimeout(timeout);
                    func(...args);
                };
                clearTimeout(timeout);
                timeout = setTimeout(later, wait);
            };
        }

        // 전역 변수로 현재 선택된 견적/사용자 ID 저장
        let currentEstimateId = null;
        let currentUserId = null;

        // 견적 상세 보기 모달 표시
        async function showEstimateDetail(estimateId) {
            try {
                console.log('견적 상세 보기 시도:', estimateId);
                currentEstimateId = estimateId;
                const estimates = await apiCall('/estimates');
                console.log('견적 목록:', estimates);
                const estimate = estimates.find(e => e.id === estimateId);
                console.log('찾은 견적:', estimate);
                
                if (!estimate) {
                    alert('견적을 찾을 수 없습니다.');
                    return;
                }

                document.getElementById('estimateModalTitle').textContent = `견적 상세 정보 - ${estimate.title}`;
                
                const modalBody = document.getElementById('estimateModalBody');
                modalBody.innerHTML = `
                    <div class="detail-row">
                        <div class="detail-label">제목:</div>
                        <div class="detail-value">${estimate.title || '제목 없음'}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">고객명:</div>
                        <div class="detail-value">${estimate.customerName || '고객명 없음'}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">고객 연락처:</div>
                        <div class="detail-value">${estimate.customerPhone || '연락처 없음'}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">주소:</div>
                        <div class="detail-value">${estimate.address || '주소 없음'}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">설명:</div>
                        <div class="detail-value">${estimate.description || '설명 없음'}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">카테고리:</div>
                        <div class="detail-value">${estimate.category || '카테고리 없음'}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">방문 예정일:</div>
                        <div class="detail-value">${estimate.visitDate ? new Date(estimate.visitDate).toLocaleDateString() : '날짜 없음'}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">현재 상태:</div>
                        <div class="detail-value">
                            <span class="status-badge status-${estimate.status}">
                                ${getStatusText(estimate.status)}
                            </span>
                        </div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">상태 변경:</div>
                        <div class="detail-value">
                            <select id="statusSelector" class="status-selector">
                                <option value="pending" ${estimate.status === 'pending' ? 'selected' : ''}>대기중</option>
                                <option value="approved" ${estimate.status === 'approved' ? 'selected' : ''}>승인됨</option>
                                <option value="rejected" ${estimate.status === 'rejected' ? 'selected' : ''}>거절됨</option>
                                <option value="completed" ${estimate.status === 'completed' ? 'selected' : ''}>완료</option>
                                <option value="in_progress" ${estimate.status === 'in_progress' ? 'selected' : ''}>진행중</option>
                                <option value="awarded" ${estimate.status === 'awarded' ? 'selected' : ''}>입찰 완료</option>
                                <option value="transferred" ${estimate.status === 'transferred' ? 'selected' : ''}>이전됨</option>
                            </select>
                        </div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">생성일:</div>
                        <div class="detail-value">${new Date(estimate.createdAt).toLocaleString()}</div>
                    </div>
                    <div class="detail-row">
                        <div class="detail-label">수정일:</div>
                        <div class="detail-value">${new Date(estimate.updatedAt).toLocaleString()}</div>
                    </div>
                `;

                document.getElementById('estimateModal').style.display = 'block';
            } catch (error) {
                console.error('견적 상세 정보 로드 오류:', error);
                alert('견적 상세 정보를 불러오는데 실패했습니다: ' + error.message);
            }
        }

        // 견적 상태 업데이트
        async function updateEstimateStatus() {
            if (!currentEstimateId) return;
            
            const statusSelector = document.getElementById('statusSelector');
            const newStatus = statusSelector.value;
            
            try {
                console.log('견적 상태 업데이트 시도:', currentEstimateId, '->', newStatus);
                const response = await apiCall(`/estimates/${currentEstimateId}/status`, {
                    method: 'PATCH',
                    body: JSON.stringify({ status: newStatus })
                });
                console.log('상태 업데이트 응답:', response);
                
                alert('견적 상태가 업데이트되었습니다.');
                closeEstimateModal();
                loadEstimates();
                loadDashboard();
            } catch (error) {
                console.error('상태 업데이트 오류:', error);
                alert('견적 상태 업데이트에 실패했습니다: ' + error.message);
            }
        }

        // 견적 모달 닫기
        function closeEstimateModal() {
            document.getElementById('estimateModal').style.display = 'none';
            currentEstimateId = null;
        }

        // 사용자 상세 보기 모달 표시
        async function showUserDetail(userId) {
            try {
                currentUserId = userId;
                const users = await apiCall('/users');
                const user = users.find(u => u.id === userId);
                
                if (!user) {
                    alert('사용자를 찾을 수 없습니다.');
                    return;
                }

                document.getElementById('userModalTitle').textContent = `사용자 상세 정보 - ${user.name || '이름 없음'}`;
                
                const modalBody = document.getElementById('userModalBody');
                const userStatus = user.businessStatus || user.businessstatus || 'pending';
                modalBody.innerHTML = `
                    <div style="margin-bottom: 1rem;">
                        <strong>이름:</strong> ${user.name || '이름 없음'}
                    </div>
                    <div style="margin-bottom: 1rem;">
                        <strong>이메일:</strong> ${user.email || '이메일 없음'}
                    </div>
                    <div style="margin-bottom: 1rem;">
                        <strong>역할:</strong> ${user.role === 'business' ? '사업자' : '고객'}
                    </div>
                    <div style="margin-bottom: 1rem;">
                        <strong>연락처:</strong> ${user.phoneNumber || user.phonenumber || '연락처 없음'}
                    </div>
                    ${user.role === 'business' ? `
                        <div style="margin-bottom: 1rem;">
                            <strong>사업자명:</strong> ${user.businessName || user.businessname || '사업자명 없음'}
                        </div>
                        <div style="margin-bottom: 1rem;">
                            <strong>사업자등록번호:</strong> ${user.businessNumber || user.businessnumber || '등록번호 없음'}
                        </div>
                        <div style="margin-bottom: 1rem;">
                            <strong>주소:</strong> ${user.address || '주소 없음'}
                        </div>
                        <div style="margin-bottom: 1rem;">
                            <strong>서비스 지역:</strong> ${user.serviceAreas || user.serviceareas ? (user.serviceAreas || user.serviceareas).join(', ') : '지역 없음'}
                        </div>
                        <div style="margin-bottom: 1rem;">
                            <strong>전문 분야:</strong> ${user.specialties ? user.specialties.join(', ') : '전문 분야 없음'}
                        </div>
                    ` : ''}
                    <div style="margin-bottom: 1rem;">
                        <strong>현재 상태:</strong> 
                        <span class="status-badge status-${userStatus}">
                            ${getStatusText(userStatus)}
                        </span>
                    </div>
                    <div style="margin-bottom: 1rem;">
                        <strong>가입일:</strong> ${new Date(user.createdAt || user.createdat).toLocaleString()}
                    </div>
                    <div style="margin-bottom: 1rem;">
                        <strong>수정일:</strong> ${new Date(user.updatedAt || user.updatedat).toLocaleString()}
                    </div>
                `;
                
                // 모달 footer 버튼 조건부 표시
                const modalFooter = document.querySelector('#userModal .modal-footer');
                if (userStatus === 'approved') {
                    // 승인된 사용자: 삭제 버튼만
                    modalFooter.innerHTML = `
                        <button class="btn btn-secondary" onclick="closeUserModal()">닫기</button>
                        <button class="btn btn-danger btn-sm" onclick="deleteUserFromModal()">삭제</button>
                    `;
                } else {
                    // 승인 대기 중: 승인, 거절 버튼
                    modalFooter.innerHTML = `
                        <button class="btn btn-secondary" onclick="closeUserModal()">닫기</button>
                        <button class="btn btn-danger btn-sm" onclick="rejectUserFromModal()">거절</button>
                        <button class="btn btn-success btn-sm" onclick="approveUserFromModal()">승인</button>
                    `;
                }

                document.getElementById('userModal').style.display = 'block';
            } catch (error) {
                console.error('사용자 상세 정보 로드 오류:', error);
                alert('사용자 상세 정보를 불러오는데 실패했습니다.');
            }
        }

        // 사용자 모달에서 승인
        async function approveUserFromModal() {
            if (!currentUserId) return;
            await approveUser(currentUserId);
            closeUserModal();
        }

        // 사용자 모달에서 거절
        async function rejectUserFromModal() {
            if (!currentUserId) return;
            await rejectUser(currentUserId);
            closeUserModal();
        }

        // 사용자 모달에서 삭제
        async function deleteUserFromModal() {
            if (!currentUserId) return;
            await deleteUser(currentUserId);
            closeUserModal();
        }

        // 사용자 모달 닫기
        function closeUserModal() {
            document.getElementById('userModal').style.display = 'none';
            currentUserId = null;
        }

        // 모달 외부 클릭 시 닫기
        window.onclick = function(event) {
            const estimateModal = document.getElementById('estimateModal');
            const userModal = document.getElementById('userModal');
            const statsModal = document.getElementById('statsModal');
            
            if (event.target === estimateModal) {
                closeEstimateModal();
            }
            if (event.target === userModal) {
                closeUserModal();
            }
            if (event.target === statsModal) {
                closeStatsModal();
            }
        }

        // 사용자 타입별 상세 정보 표시
        async function showUsersByType(type) {
            try {
                const users = await apiCall('/users');
                let filteredUsers = [];
                let title = '';

                switch(type) {
                    case 'all':
                        filteredUsers = users;
                        title = '전체 사용자 목록';
                        break;
                    case 'business':
                        filteredUsers = users.filter(u => u.role === 'business');
                        title = '사업자 사용자 목록';
                        break;
                    case 'customer':
                        filteredUsers = users.filter(u => u.role === 'customer');
                        title = '고객 사용자 목록';
                        break;
                    case 'pending':
                        filteredUsers = users.filter(u => u.role === 'business' && (u.businessStatus || u.businessstatus) === 'pending');
                        title = '승인 대기 사업자 목록';
                        break;
                }

                document.getElementById('statsModalTitle').textContent = title;
                const modalBody = document.getElementById('statsModalBody');
                
                if (filteredUsers.length === 0) {
                    modalBody.innerHTML = '<div class="loading">해당 조건의 사용자가 없습니다.</div>';
                } else {
                    const table = `
                        <table class="table">
                            <thead>
                                <tr>
                                    <th>이름</th>
                                    <th>이메일</th>
                                    <th>역할</th>
                                    <th>상태</th>
                                    <th>가입일</th>
                                    <th>작업</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${filteredUsers.map(user => `
                                    <tr>
                                        <td class="clickable-cell" onclick="showUserDetail('${user.id}')" style="cursor: pointer; color: #1a73e8; text-decoration: underline;">${user.name || '이름 없음'}</td>
                                        <td>${user.email}</td>
                                        <td>${user.role === 'business' ? '사업자' : '고객'}</td>
                                        <td>
                                            <span class="status-badge status-${user.businessStatus || user.businessstatus || 'pending'}">
                                                ${getStatusText(user.businessStatus || user.businessstatus)}
                                            </span>
                                        </td>
                                        <td>${new Date(user.createdAt || user.createdat).toLocaleDateString()}</td>
                                        <td>
                                            ${user.role === 'business' && (user.businessStatus || user.businessstatus) === 'pending' ? `
                                                <button class="btn btn-success" onclick="approveUser('${user.id}')">승인</button>
                                                <button class="btn btn-danger" onclick="rejectUser('${user.id}')">거절</button>
                                            ` : ''}
                                            <button class="btn btn-danger" onclick="deleteUser('${user.id}')">삭제</button>
                                        </td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    `;
                    modalBody.innerHTML = table;
                }

                document.getElementById('statsModal').style.display = 'block';
            } catch (error) {
                console.error('사용자 상세 정보 로드 오류:', error);
                alert('사용자 상세 정보를 불러오는데 실패했습니다.');
            }
        }

        // 견적 상태별 상세 정보 표시
        async function showEstimatesByStatus(status) {
            try {
                const endpoint = status === 'all' ? '/estimates' : `/estimates?status=${encodeURIComponent(status)}`;
                const estimates = await apiCall(endpoint);
                const filteredEstimates = estimates;
                const titleMap = {
                    all: '전체 견적 목록',
                    pending: '대기중인 견적 목록',
                    approved: '승인된 견적 목록',
                    completed: '완료된 견적 목록',
                    in_progress: '진행중인 견적 목록',
                    awarded: '입찰 완료된 견적 목록',
                    transferred: '이전된 견적 목록',
                };
                const title = titleMap[status] || '견적 목록';

                document.getElementById('statsModalTitle').textContent = title;
                const modalBody = document.getElementById('statsModalBody');
                
                if (filteredEstimates.length === 0) {
                    modalBody.innerHTML = '<div class="loading">해당 조건의 견적이 없습니다.</div>';
                } else {
                    const table = `
                        <table class="table">
                            <thead>
                                <tr>
                                    <th>제목</th>
                                    <th>고객</th>
                                    <th>사업자</th>
                                    <th>금액</th>
                                    <th>상태</th>
                                    <th>생성일</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${filteredEstimates.map(estimate => `
                                    <tr>
                                        <td class="clickable-title" onclick="showEstimateDetail('${estimate.id}')" style="cursor: pointer; color: #1a73e8; text-decoration: underline;">${estimate.title || '제목 없음'}</td>
                                        <td>${estimate.customerName || '고객명 없음'}</td>
                                        <td>${estimate.businessName || '사업자명 없음'}</td>
                                        <td>${estimate.estimatedPrice ? estimate.estimatedPrice.toLocaleString() + '원' : '금액 없음'}</td>
                                        <td>
                                            <span class="status-badge status-${estimate.status}">
                                                ${getStatusText(estimate.status)}
                                            </span>
                                        </td>
                                        <td>${new Date(estimate.createdAt).toLocaleDateString()}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    `;
                    modalBody.innerHTML = table;
                }

                document.getElementById('statsModal').style.display = 'block';
            } catch (error) {
                console.error('견적 상세 정보 로드 오류:', error);
                alert('견적 상세 정보를 불러오는데 실패했습니다.');
            }
        }

        // 수익 상세 정보 표시
        async function showRevenueDetails() {
            try {
                const estimates = await apiCall('/estimates');
                const completedEstimates = estimates.filter(e => e.status === 'completed');
                
                document.getElementById('statsModalTitle').textContent = '수익 상세 정보';
                const modalBody = document.getElementById('statsModalBody');
                
                if (completedEstimates.length === 0) {
                    modalBody.innerHTML = '<div class="loading">완료된 견적이 없어 수익 정보를 계산할 수 없습니다.</div>';
                } else {
                    const totalRevenue = completedEstimates.reduce((sum, e) => sum + ((e.estimatedPrice || 0) * 0.05), 0);
                    const averageRevenue = totalRevenue / completedEstimates.length;
                    
                    const table = `
                        <div class="detail-row">
                            <div class="detail-label">총 완료 견적:</div>
                            <div class="detail-value">${completedEstimates.length}건</div>
                        </div>
                        <div class="detail-row">
                            <div class="detail-label">총 수익:</div>
                            <div class="detail-value">${totalRevenue.toLocaleString()}원</div>
                        </div>
                        <div class="detail-row">
                            <div class="detail-label">평균 수익:</div>
                            <div class="detail-value">${averageRevenue.toLocaleString()}원</div>
                        </div>
                        <div class="detail-row">
                            <div class="detail-label">수수료율:</div>
                            <div class="detail-value">5%</div>
                        </div>
                        <hr style="margin: 1rem 0;">
                        <h4>완료된 견적 목록</h4>
                        <table class="table">
                            <thead>
                                <tr>
                                    <th>제목</th>
                                    <th>고객</th>
                                    <th>금액</th>
                                    <th>수익</th>
                                    <th>완료일</th>
                                </tr>
                            </thead>
                            <tbody>
                                ${completedEstimates.map(estimate => `
                                    <tr>
                                        <td class="clickable-title" onclick="showEstimateDetail('${estimate.id}')" style="cursor: pointer; color: #1a73e8; text-decoration: underline;">${estimate.title || '제목 없음'}</td>
                                        <td>${estimate.customerName || '고객명 없음'}</td>
                                        <td>${estimate.estimatedPrice ? estimate.estimatedPrice.toLocaleString() + '원' : '금액 없음'}</td>
                                        <td>${((estimate.estimatedPrice || 0) * 0.05).toLocaleString()}원</td>
                                        <td>${new Date(estimate.updatedAt).toLocaleDateString()}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    `;
                    modalBody.innerHTML = table;
                }

                document.getElementById('statsModal').style.display = 'block';
            } catch (error) {
                console.error('수익 상세 정보 로드 오류:', error);
                alert('수익 상세 정보를 불러오는데 실패했습니다.');
            }
        }

        // 통계 모달 닫기
        function closeStatsModal() {
            document.getElementById('statsModal').style.display = 'none';
        }

        // 통계 숫자 클릭 이벤트 리스너 설정
        function setupStatsClickListeners() {
            // 사용자 통계 클릭 리스너
            const userStats = document.querySelectorAll('[data-type]');
            userStats.forEach(stat => {
                stat.addEventListener('click', () => {
                    const type = stat.getAttribute('data-type');
                    showUsersByType(type);
                });
            });

            // 견적 통계 클릭 리스너
            const estimateStats = document.querySelectorAll('[data-status]');
            estimateStats.forEach(stat => {
                stat.addEventListener('click', () => {
                    const status = stat.getAttribute('data-status');
                    showEstimatesByStatus(status);
                });
            });

            // 수익 통계 클릭 리스너
            const revenueStat = document.getElementById('totalRevenue');
            if (revenueStat) {
                revenueStat.addEventListener('click', showRevenueDetails);
            }
        }

// ===== Call 현황 (마켓플레이스) =====
async function loadCalls() {
    try {
        const status = document.getElementById('callStatusFilter')?.value || 'all';
        const qs = status && status !== 'all' ? `?status=${encodeURIComponent(status)}` : '';
        const res = await fetch(`${MARKET_API_BASE}/listings${qs}`, {
            headers: {
                'admin-token': ADMIN_TOKEN,
            }
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const calls = await res.json();
        displayCalls(calls);
    } catch (e) {
        console.error('Call 로드 오류:', e);
        const container = document.getElementById('callTableContainer');
        if (container) container.innerHTML = '<div class="error">Call 목록을 불러오는데 실패했습니다: ' + e.message + '</div>';
    }
}

function displayCalls(calls) {
    const container = document.getElementById('callTableContainer');
    if (!container) return;
    if (!calls || calls.length === 0) {
        container.innerHTML = '<div class="loading">등록된 Call이 없습니다.</div>';
        return;
    }
    
    // 상태 매핑 함수
    const getCallStatusText = (status) => {
        if (status === 'open') return '대기';
        if (status === 'assigned' || status === 'completed') return '완료';
        return status || '-';
    };
    
    // 날짜 포맷 함수 (yyyy-MM-dd)
    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try {
            const date = new Date(dateStr);
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}-${month}-${day}`;
        } catch (e) {
            return '-';
        }
    };
    
    const table = `
        <table class="table">
            <thead>
                <tr>
                    <th>제목</th>
                    <th>지역</th>
                    <th>카테고리</th>
                    <th>견적 금액</th>
                    <th>상태</th>
                    <th>게시한 사업자</th>
                    <th>가져간 사업자</th>
                    <th>생성일</th>
                </tr>
            </thead>
            <tbody>
                ${calls.map(item => `
                    <tr>
                        <td>${item.title || '-'}</td>
                        <td>${item.region || '-'}</td>
                        <td>${item.category || '-'}</td>
                        <td>${typeof item.budget_amount === 'number' ? item.budget_amount.toLocaleString() + '원' : '-'}</td>
                        <td>
                            <span class="status-badge status-${item.status || 'pending'}">
                                ${getCallStatusText(item.status)}
                            </span>
                        </td>
                        <td>${item.posted_by || item.posted_by_name || '-'}</td>
                        <td>${item.assigned_to || item.assigned_to_name || item.accepted_by || item.accepted_by_name || '-'}</td>
                        <td>${formatDate(item.createdat || item.created_at)}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
    `;
    container.innerHTML = table;
}

// ===== 광고 관리 =====
async function loadAds() {
    try {
        const ads = await apiCall('/ads');
        displayAds(ads);
    } catch (e) {
        console.error('광고 로드 오류:', e);
        const c = document.getElementById('adsTableContainer');
        if (c) c.innerHTML = '<div class="error">광고 목록을 불러오는데 실패했습니다: ' + e.message + '</div>';
    }
}

function displayAds(items) {
    const c = document.getElementById('adsTableContainer');
    if (!c) return;
    if (!items || items.length === 0) {
        c.innerHTML = '<div class="loading">등록된 광고가 없습니다.</div>';
        return;
    }
    const table = `
      <table class="table">
        <thead>
          <tr>
            <th>제목</th>
            <th>슬러그</th>
            <th>HTML 경로</th>
            <th>상태</th>
            <th>우선순위</th>
            <th>작업</th>
          </tr>
        </thead>
        <tbody>
          ${items.map(ad => `
            <tr>
              <td>${ad.title || '-'}</td>
              <td>${ad.slug || '-'}</td>
              <td>${ad.html_path || '-'}</td>
              <td>${ad.status || '-'}</td>
              <td>${ad.priority ?? 0}</td>
              <td>
                <button class="btn btn-primary" onclick='openAdEditModal(${JSON.stringify(ad)})'>수정</button>
                <button class="btn btn-danger" onclick='deleteAd("${ad.id}")'>삭제</button>
              </td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    `;
    c.innerHTML = table;
}

function openAdCreateModal() {
    const title = prompt('광고 제목');
    if (title == null) return;
    const slug = prompt('슬러그(영문 소문자, 식별자)');
    if (slug == null) return;
    const html_path = prompt('HTML 파일 경로(/ads/경로.html)');
    if (html_path == null) return;
    const priority = parseInt(prompt('우선순위(숫자, 높을수록 먼저)') || '0', 10);
    const status = prompt('상태(active/inactive)', 'active');
    createAd({ title, slug, html_path, priority, status });
}

function openAdEditModal(ad) {
    try { ad = (typeof ad === 'string') ? JSON.parse(ad) : ad; } catch(_) {}
    const title = prompt('광고 제목', ad.title || '');
    if (title == null) return;
    const slug = prompt('슬러그', ad.slug || '');
    if (slug == null) return;
    const html_path = prompt('HTML 파일 경로', ad.html_path || '');
    if (html_path == null) return;
    const priority = parseInt(prompt('우선순위', String(ad.priority ?? 0)) || '0', 10);
    const status = prompt('상태(active/inactive)', ad.status || 'active');
    updateAd(ad.id, { title, slug, html_path, priority, status });
}

async function createAd(payload) {
    try {
        const res = await apiCall('/ads', { method: 'POST', body: JSON.stringify(payload) });
        alert('광고가 생성되었습니다.');
        loadAds();
    } catch (e) {
        alert('광고 생성 실패');
    }
}

async function updateAd(id, payload) {
    try {
        const res = await apiCall(`/ads/${id}`, { method: 'PUT', body: JSON.stringify(payload) });
        alert('광고가 업데이트되었습니다.');
        loadAds();
    } catch (e) {
        alert('광고 업데이트 실패');
    }
}

async function deleteAd(id) {
    if (!confirm('정말로 이 광고를 삭제하시겠습니까?')) return;
    try {
        await apiCall(`/ads/${id}`, { method: 'DELETE' });
        loadAds();
    } catch (e) {
        alert('광고 삭제 실패');
    }
}

async function showAdsStats() {
    try {
        const stats = await apiCall('/ads/stats');
        const byAd = {};
        for (const row of stats) {
            const id = row.ad_id;
            if (!byAd[id]) byAd[id] = { impressions: 0, clicks: 0 };
            if (row.type === 'impression') byAd[id].impressions = row.count || 0;
            if (row.type === 'click') byAd[id].clicks = row.count || 0;
        }
        let html = '<h3>광고 통계</h3><table class="table"><thead><tr><th>Ad ID</th><th>노출</th><th>클릭</th><th>CTR</th></tr></thead><tbody>';
        for (const [id, m] of Object.entries(byAd)) {
            const ctr = m.impressions > 0 ? ((m.clicks / m.impressions) * 100).toFixed(2) + '%' : '-';
            html += `<tr><td>${id}</td><td>${m.impressions}</td><td>${m.clicks}</td><td>${ctr}</td></tr>`;
        }
        html += '</tbody></table>';
        const modal = document.getElementById('statsModal');
        document.getElementById('statsModalTitle').textContent = '광고 통계';
        document.getElementById('statsModalBody').innerHTML = html;
        modal.style.display = 'block';
    } catch (e) {
        alert('광고 통계 조회 실패');
    }
}
