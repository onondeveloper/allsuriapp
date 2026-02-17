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

// 오더 현황 페이지네이션 및 정렬 상태
let callsPage = 1;
const callsPerPage = 15;
let callsSortColumn = null;
let callsSortDirection = 'asc';
let allCalls = [];

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

// API 호출 헬퍼 함수 테스트
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
            let errorMessage = `HTTP error! status: ${response.status}`;
            try {
                const errorData = await response.json();
                console.error('[API CALL] Error response:', errorData);
                if (errorData.error) {
                    errorMessage += `\n에러: ${errorData.error}`;
                }
                if (errorData.details) {
                    errorMessage += `\n상세: ${errorData.details}`;
                }
                if (errorData.message) {
                    errorMessage += `\n메시지: ${errorData.message}`;
                }
            } catch (e) {
                console.error('[API CALL] Could not parse error response');
            }
            if (response.status === 401) {
                throw new Error('관리자 권한이 필요합니다. ADMIN_TOKEN을 확인해주세요.');
            }
            throw new Error(errorMessage);
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
                
                console.log('[DASHBOARD] ===== 받은 데이터 상세 =====');
                console.log('[DASHBOARD] 전체 데이터:', JSON.stringify(data, null, 2));
                console.log('[DASHBOARD] totalOrders:', data.totalOrders);
                console.log('[DASHBOARD] pendingOrders:', data.pendingOrders);
                console.log('[DASHBOARD] completedOrders:', data.completedOrders);
                console.log('[DASHBOARD] totalEstimates:', data.totalEstimates);
                console.log('[DASHBOARD] ================================');
                
                // 사용자 통계
                const totalBusinessUsers = data.totalBusinessUsers || 0;
                const totalCustomers = data.totalCustomers || 0;
                
                const totalBusinessUsersEl = document.getElementById('totalBusinessUsers');
                if (totalBusinessUsersEl) totalBusinessUsersEl.textContent = totalBusinessUsers;
                
                const totalCustomersEl = document.getElementById('totalCustomers');
                if (totalCustomersEl) totalCustomersEl.textContent = totalCustomers;
                
                const pendingUsersEl = document.getElementById('pendingUsers');
                if (pendingUsersEl) pendingUsersEl.textContent = 0;
                
                console.log('[DASHBOARD] 사업자:', totalBusinessUsers, '고객:', totalCustomers);
                
                // 오더 통계
                const totalOrders = data.totalOrders || 0;
                const pendingOrders = data.pendingOrders || 0;
                const completedOrders = data.completedOrders || 0;
                
                const totalOrdersEl = document.getElementById('totalOrders');
                if (totalOrdersEl) totalOrdersEl.textContent = totalOrders;
                
                const pendingOrdersEl = document.getElementById('pendingOrders');
                if (pendingOrdersEl) pendingOrdersEl.textContent = pendingOrders;
                
                const completedOrdersEl = document.getElementById('completedOrders');
                if (completedOrdersEl) completedOrdersEl.textContent = completedOrders;
                
                console.log('[DASHBOARD] 오더 - 전체:', totalOrders, '입찰중:', pendingOrders, '완료:', completedOrders);
                
                // 견적 통계
                const totalEstimates = data.totalEstimates || 0;
                const pendingEstimates = data.pendingEstimates || 0;
                const completedEstimates = data.completedEstimates || 0;
                const inProgressEstimates = data.inProgressEstimates || 0;
                
                const totalEstimatesEl = document.getElementById('totalEstimates');
                if (totalEstimatesEl) totalEstimatesEl.textContent = totalEstimates;
                
                const pendingEstimatesEl = document.getElementById('pendingEstimates');
                if (pendingEstimatesEl) pendingEstimatesEl.textContent = pendingEstimates;
                
                const approvedEstimatesEl = document.getElementById('approvedEstimates');
                if (approvedEstimatesEl) approvedEstimatesEl.textContent = data.approvedEstimates || 0;
                
                const completedEstimatesEl = document.getElementById('completedEstimates');
                if (completedEstimatesEl) completedEstimatesEl.textContent = completedEstimates;
                
                const inProgressEstimatesEl = document.getElementById('inProgressEstimates');
                if (inProgressEstimatesEl) inProgressEstimatesEl.textContent = inProgressEstimates;
                
                const awardedEstimatesEl = document.getElementById('awardedEstimates');
                if (awardedEstimatesEl) awardedEstimatesEl.textContent = data.awardedEstimates || 0;
                
                const transferredEstimatesEl = document.getElementById('transferredEstimates');
                if (transferredEstimatesEl) transferredEstimatesEl.textContent = data.transferredEstimates || 0;
                
                console.log('[DASHBOARD] 견적 - 전체:', totalEstimates, '대기:', pendingEstimates, '완료:', completedEstimates, '진행중:', inProgressEstimates);
                
                // 금액 통계
                const totalOrderAmount = data.totalOrderAmount || 0;
                const totalEstimateAmount = data.totalEstimateAmount || 0;
                const totalRevenue = data.totalRevenue || 0;
                
                const totalOrderAmountEl = document.getElementById('totalOrderAmount');
                if (totalOrderAmountEl) totalOrderAmountEl.textContent = '₩' + totalOrderAmount.toLocaleString('ko-KR');
                
                const totalEstimateAmountEl = document.getElementById('totalEstimateAmount');
                if (totalEstimateAmountEl) totalEstimateAmountEl.textContent = '₩' + totalEstimateAmount.toLocaleString('ko-KR');
                
                const totalRevenueEl = document.getElementById('totalRevenue');
                if (totalRevenueEl) totalRevenueEl.textContent = '₩' + totalRevenue.toLocaleString('ko-KR');
                
                console.log('[DASHBOARD] 금액 - 오더:', totalOrderAmount, '견적:', totalEstimateAmount, '수익:', totalRevenue);
            } catch (error) {
                console.error('대시보드 로드 오류:', error);
                alert('대시보드 데이터를 불러오는데 실패했습니다: ' + error.message);
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
                                <th>관리자</th>
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
                                        ${user.is_admin ? 
                                            '<span class="status-badge approved" style="background: #e6f4ea; color: #15803d;">관리자</span>' : 
                                            '<span style="color: #999;">-</span>'
                                        }
                                    </td>
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
                                    <td class="clickable-title" data-estimate-id="${e.id}" style="cursor: pointer; color: #1a73e8; text-decoration: underline;" onclick="showEstimateDetail('${e.id}')">${title}</td>
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
    if (!confirm('정말로 이 사용자를 삭제하시겠습니까?\n\n⚠️ 관련된 모든 데이터도 함께 삭제됩니다:\n- 견적 및 입찰\n- 오더 및 작업\n- 채팅 메시지\n- 알림\n- 커뮤니티 게시글/댓글')) {
        return;
    }

    try {
        // 모든 사용자에 대해 CASCADE 삭제 사용
        const response = await apiCall(`/users/${userId}`, {
            method: 'DELETE'
        });
        
        // 삭제된 데이터 통계 표시
        if (response.deleted_counts) {
            const counts = response.deleted_counts;
            let message = '사용자가 삭제되었습니다.\n\n삭제된 데이터:\n';
            if (counts.estimates > 0) message += `- 견적: ${counts.estimates}개\n`;
            if (counts.bids > 0) message += `- 입찰: ${counts.bids}개\n`;
            if (counts.listings > 0) message += `- 오더: ${counts.listings}개\n`;
            if (counts.jobs > 0) message += `- 작업: ${counts.jobs}개\n`;
            if (counts.chats > 0) message += `- 채팅방: ${counts.chats}개\n`;
            if (counts.notifications > 0) message += `- 알림: ${counts.notifications}개\n`;
            alert(message);
        } else {
            alert('사용자가 삭제되었습니다.');
        }
        
        loadUsers();
        loadDashboard();
    } catch (error) {
        console.error('사용자 삭제 오류:', error);
        alert('사용자 삭제에 실패했습니다: ' + error.message);
    }
}

// 관리자 권한 토글
async function toggleAdmin(userId) {
    try {
        const user = allUsers.find(u => u.id === userId);
        if (!user) {
            alert('사용자를 찾을 수 없습니다.');
            return;
        }
        
        const newAdminStatus = !user.is_admin;
        const confirmMsg = newAdminStatus 
            ? '이 사용자를 관리자로 지정하시겠습니까?' 
            : '이 사용자의 관리자 권한을 해제하시겠습니까?';
        
        if (!confirm(confirmMsg)) {
            return;
        }
        
        const response = await apiCall(`/users/${userId}/admin`, {
            method: 'PATCH',
            body: JSON.stringify({ is_admin: newAdminStatus })
        });
        
        if (response.success) {
            alert(response.message);
            loadUsers();
        }
    } catch (error) {
        alert('관리자 권한 변경에 실패했습니다: ' + error.message);
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
            if (newAdBtn) newAdBtn.addEventListener('click', showAdModal);
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
                    <div style="margin-bottom: 1rem;">
                        <strong>관리자 권한:</strong> 
                        <span class="status-badge ${user.is_admin ? 'approved' : 'pending'}">
                            ${user.is_admin ? '관리자' : '일반 사용자'}
                        </span>
                    </div>
                `;
                
                // 모달 footer 버튼 조건부 표시
                const modalFooter = document.querySelector('#userModal .modal-footer');
                if (userStatus === 'approved') {
                    // 승인된 사용자: 관리자 권한 토글 버튼, 삭제 버튼
                    modalFooter.innerHTML = `
                        <button class="btn btn-secondary" onclick="closeUserModal()">닫기</button>
                        <button class="btn ${user.is_admin ? 'btn-warning' : 'btn-primary'} btn-sm" onclick="toggleAdminFromModal()" style="margin-right: auto;">
                            <span class="material-icons" style="font-size: 1rem;">${user.is_admin ? 'remove_moderator' : 'admin_panel_settings'}</span>
                            ${user.is_admin ? '관리자 해제' : '관리자 지정'}
                        </button>
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

        // 사용자 모달에서 관리자 권한 토글
        async function toggleAdminFromModal() {
            if (!currentUserId) return;
            await toggleAdmin(currentUserId);
            // 모달 다시 열어서 업데이트된 정보 보여주기
            setTimeout(() => showUserDetail(currentUserId), 100);
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
            const adModal = document.getElementById('adModal');
            
            if (event.target === estimateModal) {
                closeEstimateModal();
            }
            if (event.target === userModal) {
                closeUserModal();
            }
            if (event.target === statsModal) {
                closeStatsModal();
            }
            if (event.target === adModal) {
                closeAdModal();
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

// ===== 오더 현황 (마켓플레이스) =====
async function loadCalls() {
    try {
        console.log('[LOAD ORDERS] Fetching marketplace listings data...');
        allCalls = await apiCall('/calls');
        console.log('[LOAD ORDERS] Received:', allCalls.length, 'orders');
        callsPage = 1; // Reset to first page
        displayCalls();
    } catch (e) {
        console.error('오더 로드 오류:', e);
        const container = document.getElementById('callTableContainer');
        if (container) container.innerHTML = '<div class="error">오더 목록을 불러오는데 실패했습니다: ' + e.message + '</div>';
    }
}

function displayCalls() {
    const container = document.getElementById('callTableContainer');
    if (!container) return;
    if (!allCalls || allCalls.length === 0) {
        container.innerHTML = '<div class="loading">등록된 오더가 없습니다.</div>';
        return;
    }
    
    // 정렬 적용
    let sortedCalls = [...allCalls];
    if (callsSortColumn) {
        sortedCalls.sort((a, b) => {
            let aVal = a[callsSortColumn];
            let bVal = b[callsSortColumn];
            
            // 날짜 처리
            if (callsSortColumn === 'created_at' || callsSortColumn === 'claimed_at') {
                aVal = new Date(a[callsSortColumn] || 0).getTime();
                bVal = new Date(b[callsSortColumn] || 0).getTime();
            }
            
            // 금액 처리
            if (callsSortColumn === 'budget_amount') {
                aVal = a.budget_amount || 0;
                bVal = b.budget_amount || 0;
            }
            
            // 문자열 비교
            if (typeof aVal === 'string') {
                aVal = (aVal || '').toLowerCase();
                bVal = (bVal || '').toLowerCase();
            }
            
            if (aVal < bVal) return callsSortDirection === 'asc' ? -1 : 1;
            if (aVal > bVal) return callsSortDirection === 'asc' ? 1 : -1;
            return 0;
        });
    }
    
    // 페이지네이션 적용
    const totalPages = Math.ceil(sortedCalls.length / callsPerPage);
    const startIdx = (callsPage - 1) * callsPerPage;
    const endIdx = startIdx + callsPerPage;
    const paginatedCalls = sortedCalls.slice(startIdx, endIdx);
    
    // 상태 매핑 함수
    const getCallStatusText = (status, claimedBy) => {
        if (claimedBy) return '완료';
        if (status === 'assigned') return '완료';
        if (status === 'completed') return '종료됨';
        if (status === 'cancelled') return '취소됨';
        if (status === 'created' || status === 'open') return '대기 중';
        return status || '대기 중';
    };
    
    const getStatusClass = (status, claimedBy) => {
        if (claimedBy || status === 'assigned') return 'success';
        if (status === 'completed') return 'completed';
        if (status === 'cancelled') return 'cancelled';
        return 'warning';
    };
    
    // 날짜 포맷 함수 (yyyy-MM-dd HH:mm)
    const formatDate = (dateStr) => {
        if (!dateStr) return '-';
        try {
            const date = new Date(dateStr);
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            const hours = String(date.getHours()).padStart(2, '0');
            const minutes = String(date.getMinutes()).padStart(2, '0');
            return `${year}-${month}-${day} ${hours}:${minutes}`;
        } catch (e) {
            return '-';
        }
    };
    
    // 통계 계산
    const total = sortedCalls.length;
    const pending = sortedCalls.filter(c => !c.claimed_by && c.status !== 'completed' && c.status !== 'cancelled' && c.status !== 'assigned').length;
    const completed = sortedCalls.filter(c => c.claimed_by || c.status === 'assigned').length;
    
    const table = `
        <table class="table">
            <thead>
                <tr>
                    <th class="sortable" data-column="title">제목</th>
                    <th class="sortable" data-column="location">위치</th>
                    <th class="sortable" data-column="category">카테고리</th>
                    <th class="sortable" data-column="budget_amount">예산</th>
                    <th class="sortable" data-column="status">상태</th>
                    <th>등록한 사업자</th>
                    <th>가져간 사업자</th>
                    <th class="sortable" data-column="claimed_at">입찰받은 날짜</th>
                    <th class="sortable" data-column="created_at">생성일</th>
                </tr>
            </thead>
            <tbody>
                ${paginatedCalls.map(item => `
                    <tr style="cursor: pointer;" onclick="showCallDetail('${item.id}')">
                        <td><strong>${item.title || '-'}</strong></td>
                        <td>${item.location || item.region || '-'}</td>
                        <td>${item.category || '-'}</td>
                        <td>${typeof item.budget_amount === 'number' ? '₩' + item.budget_amount.toLocaleString('ko-KR') : '-'}</td>
                        <td>
                            <span class="status-badge status-${getStatusClass(item.status, item.claimed_by)}">
                                ${getCallStatusText(item.status, item.claimed_by)}
                            </span>
                        </td>
                        <td>${item.owner_business_name || '-'}</td>
                        <td>${item.claimed_business_name || item.assigned_business_name || '<span style="color: #999;">-</span>'}</td>
                        <td>${item.claimed_at ? formatDate(item.claimed_at) : '<span style="color: #999;">-</span>'}</td>
                        <td>${formatDate(item.created_at)}</td>
                    </tr>
                `).join('')}
            </tbody>
        </table>
        <div class="pagination">
            <button onclick="changeCallsPage(-1)" ${callsPage === 1 ? 'disabled' : ''}>이전</button>
            <span>페이지 ${callsPage} / ${totalPages} (전체 ${sortedCalls.length}건)</span>
            <button onclick="changeCallsPage(1)" ${callsPage >= totalPages ? 'disabled' : ''}>다음</button>
        </div>
    `;
    
    container.innerHTML = table;
    
    // 정렬 표시 업데이트
    if (callsSortColumn) {
        const headers = container.querySelectorAll('th');
        headers.forEach(th => {
            const col = th.getAttribute('data-column');
            if (col === callsSortColumn) {
                th.classList.add(callsSortDirection === 'asc' ? 'sort-asc' : 'sort-desc');
            }
        });
    }
    
    // 컬럼 헤더 클릭 이벤트 리스너
    const headers = container.querySelectorAll('th.sortable');
    headers.forEach(th => {
        th.addEventListener('click', () => {
            const column = th.getAttribute('data-column');
            if (callsSortColumn === column) {
                callsSortDirection = callsSortDirection === 'asc' ? 'desc' : 'asc';
            } else {
                callsSortColumn = column;
                callsSortDirection = 'asc';
            }
            displayCalls();
        });
    });
}

// 오더 페이지 변경
function changeCallsPage(delta) {
    const totalPages = Math.ceil(allCalls.length / callsPerPage);
    callsPage = Math.max(1, Math.min(callsPage + delta, totalPages));
    displayCalls();
}

// Call 상세 보기 함수
async function showCallDetail(jobId) {
    try {
        const calls = await apiCall('/calls');
        const job = calls.find(c => c.id === jobId);
        
        if (!job) {
            alert('Call 정보를 찾을 수 없습니다.');
            return;
        }
        
        // 상태 매핑 함수 (displayCalls에서 사용하는 것과 동일)
        const getCallStatusText = (status, claimedBy) => {
            if (claimedBy) return '완료';
            if (status === 'assigned') return '완료';
            if (status === 'completed') return '종료됨';
            if (status === 'cancelled') return '취소됨';
            if (status === 'created' || status === 'open') return '대기 중';
            return status || '대기 중';
        };
        
        const getStatusClass = (status, claimedBy) => {
            if (claimedBy || status === 'assigned') return 'success';
            if (status === 'completed') return 'completed';
            if (status === 'cancelled') return 'cancelled';
            return 'warning';
        };
        
        // 날짜 포맷 함수
        const formatDate = (dateStr) => {
            if (!dateStr) return '-';
            try {
                const date = new Date(dateStr);
                const year = date.getFullYear();
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const day = String(date.getDate()).padStart(2, '0');
                const hours = String(date.getHours()).padStart(2, '0');
                const minutes = String(date.getMinutes()).padStart(2, '0');
                return `${year}-${month}-${day} ${hours}:${minutes}`;
            } catch (e) {
                return '-';
            }
        };
        
        const modalBody = document.getElementById('callModalBody');
        const statusText = getCallStatusText(job.status, job.claimed_by);
        const statusClass = getStatusClass(job.status, job.claimed_by);
        
        let detailHtml = `
            <div class="detail-group">
                <div class="detail-item">
                    <span class="detail-label">제목:</span>
                    <span class="detail-value">${job.title || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">지역:</span>
                    <span class="detail-value">${job.location || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">카테고리:</span>
                    <span class="detail-value">${job.category || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">예산 금액:</span>
                    <span class="detail-value">${typeof job.budget_amount === 'number' ? '₩' + job.budget_amount.toLocaleString('ko-KR') : '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">상태:</span>
                    <span class="detail-value"><span class="status-badge status-${statusClass}">${statusText}</span></span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">등록 사업자:</span>
                    <span class="detail-value">${job.owner_business_name || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">가져간 사업자:</span>
                    <span class="detail-value">${job.assigned_business_name || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">생성일:</span>
                    <span class="detail-value">${formatDate(job.created_at)}</span>
                </div>
        `;
        
        // 상세 설명이 있으면 추가
        if (job.description) {
            detailHtml += `
                <div class="detail-item" style="grid-column: 1 / -1;">
                    <span class="detail-label">설명:</span>
                    <span class="detail-value">${job.description}</span>
                </div>
            `;
        }
        
        // 미디어 URL이 있으면 추가
        if (job.media_urls && Array.isArray(job.media_urls) && job.media_urls.length > 0) {
            detailHtml += `
                <div class="detail-item" style="grid-column: 1 / -1;">
                    <span class="detail-label">첨부 이미지:</span>
                    <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.5rem;">
                        ${job.media_urls.map(url => `
                            <img src="${url}" alt="첨부 이미지" style="width: 120px; height: 120px; object-fit: cover; border-radius: 8px; cursor: pointer;" onclick="window.open('${url}', '_blank')">
                        `).join('')}
                    </div>
                </div>
            `;
        }
        
        detailHtml += `</div>`;
        
        modalBody.innerHTML = detailHtml;
        
        // 모달 footer에 버튼들 추가
        const modalFooter = document.querySelector('#callModal .modal-footer');
        if (modalFooter) {
            modalFooter.innerHTML = `
                <button class="btn btn-secondary" onclick="closeCallModal()">닫기</button>
                <button class="btn btn-primary" onclick="copyOrderShareLink('${jobId}')">
                    <span class="material-icons" style="font-size: 1rem;">content_copy</span>
                    카카오톡 공유 링크 복사
                </button>
                <button class="btn btn-success" onclick="sendOrderNotification('${jobId}')">
                    <span class="material-icons" style="font-size: 1rem;">send</span>
                    사업자들에게 알림 발송
                </button>
                <button class="btn btn-danger" onclick="deleteCall('${jobId}')">
                    <span class="material-icons" style="font-size: 1rem;">delete</span>
                    오더 삭제
                </button>
            `;
        }
        
        document.getElementById('callModal').style.display = 'flex';
    } catch (error) {
        console.error('Call 상세 정보 로드 오류:', error);
        alert('Call 상세 정보를 불러오는데 실패했습니다.');
    }
}

// 오더 삭제 함수
async function deleteCall(listingId) {
    if (!confirm('정말로 이 오더를 삭제하시겠습니까?\n\n⚠️ 관련된 입찰 정보도 함께 삭제됩니다.')) {
        return;
    }
    
    try {
        console.log('[deleteCall] 오더 삭제 시작:', listingId);
        
        // marketplace_listings 삭제 (CASCADE로 order_bids도 함께 삭제됨)
        const response = await apiCall(`/listings/${listingId}`, {
            method: 'DELETE'
        });
        
        if (response.success) {
            alert('오더가 삭제되었습니다.');
            closeCallModal();
            loadCalls();
            loadDashboard();
        } else {
            throw new Error(response.message || '삭제 실패');
        }
    } catch (error) {
        console.error('[deleteCall] 에러:', error);
        alert('오더 삭제에 실패했습니다: ' + error.message);
    }
}

// Call 모달 닫기
function closeCallModal() {
    document.getElementById('callModal').style.display = 'none';
}

// 오더에 대해 사업자들에게 알림 발송
async function sendOrderNotification(orderId) {
    const customMessage = prompt(
        '사업자들에게 보낼 메시지를 입력하세요:\n\n' +
        '(비워두면 기본 메시지가 전송됩니다)'
    );
    
    // 취소 버튼을 누른 경우
    if (customMessage === null) {
        return;
    }
    
    try {
        console.log('[sendOrderNotification] 알림 발송 시작:', orderId);
        
        // 로딩 표시
        const loadingDiv = document.createElement('div');
        loadingDiv.id = 'notification-loading';
        loadingDiv.innerHTML = `
            <div style="position: fixed; top: 0; left: 0; width: 100%; height: 100%; 
                        background: rgba(0,0,0,0.5); display: flex; align-items: center; 
                        justify-content: center; z-index: 10000;">
                <div style="background: white; padding: 2rem; border-radius: 12px; text-align: center;">
                    <div class="spinner" style="margin: 0 auto 1rem;"></div>
                    <div>사업자들에게 알림을 발송하는 중...</div>
                </div>
            </div>
        `;
        document.body.appendChild(loadingDiv);
        
        const response = await apiCall(`/orders/${orderId}/notify`, {
            method: 'POST',
            body: JSON.stringify({
                message: customMessage?.trim() || null,
                targetRegion: true,  // 오더의 지역에 해당하는 사업자
                targetCategory: true, // 오더의 카테고리에 해당하는 사업자
            })
        });
        
        // 로딩 제거
        document.getElementById('notification-loading')?.remove();
        
        if (response.success) {
            alert(`✅ 성공!\n\n${response.message}\n\n성공: ${response.sent}명\n실패: ${response.failed}명\n전체: ${response.total}명`);
        } else {
            alert('❌ 알림 발송에 실패했습니다');
        }
    } catch (error) {
        console.error('[sendOrderNotification] 에러:', error);
        document.getElementById('notification-loading')?.remove();
        alert('알림 발송에 실패했습니다: ' + error.message);
    }
}

// 오더를 카카오톡으로 공유
async function shareOrderToKakao(orderId) {
    try {
        const calls = await apiCall('/calls');
        const order = calls.find(c => c.id === orderId);
        
        if (!order) {
            alert('오더 정보를 찾을 수 없습니다.');
            return;
        }
        
        console.log('[shareOrderToKakao] 오더 정보:', order);
        
        // 예산 포맷팅
        const budgetText = order.budget_amount 
            ? `\n💰 예산: ${order.budget_amount.toLocaleString('ko-KR')}원`
            : '';
        
        // 카카오톡 공유 템플릿
        const template = {
            objectType: 'feed',
            content: {
                title: `🔧 ${order.title || '오더'}`,
                description: `📍 지역: ${order.location || order.region || '지역 미지정'}\n🏷️ 카테고리: ${order.category || '일반'}${budgetText}\n\n${order.description || '상세 설명이 없습니다.'}`,
                imageUrl: order.media_urls && order.media_urls.length > 0 
                    ? order.media_urls[0]
                    : 'https://allsuri.app/assets/images/logo.png',
                link: {
                    mobileWebUrl: 'https://play.google.com/store/apps/details?id=com.ononcompany.allsuri',
                    webUrl: 'https://play.google.com/store/apps/details?id=com.ononcompany.allsuri',
                },
            },
            buttons: [
                {
                    title: '앱에서 보기',
                    link: {
                        mobileWebUrl: 'https://play.google.com/store/apps/details?id=com.ononcompany.allsuri',
                        webUrl: 'https://play.google.com/store/apps/details?id=com.ononcompany.allsuri',
                    },
                },
            ],
        };
        
        // Kakao SDK 확인
        if (!window.Kakao || !Kakao.isInitialized()) {
            alert('Kakao SDK가 초기화되지 않았습니다.\n\n관리자에게 문의하세요.');
            return;
        }
        
        // 카카오톡 공유 실행
        Kakao.Share.sendDefault(template);
        
        console.log('[shareOrderToKakao] 카카오톡 공유 완료');
    } catch (error) {
        console.error('[shareOrderToKakao] 에러:', error);
        alert('카카오톡 공유에 실패했습니다: ' + error.message);
    }
}

// 오더 공유 URL 생성 및 복사
async function copyOrderShareLink(orderId) {
    try {
        const calls = await apiCall('/calls');
        const order = calls.find(c => c.id === orderId);
        
        if (!order) {
            alert('오더 정보를 찾을 수 없습니다.');
            return;
        }
        
        // 예산 포맷팅
        const budgetText = order.budget_amount 
            ? `\n💰 예산: ${order.budget_amount.toLocaleString('ko-KR')}원`
            : '';
        
        // 공유 텍스트 생성
        const shareText = `🔧 새로운 오더 등록!\n\n` +
            `📌 ${order.title || '오더'}\n` +
            `📍 지역: ${order.location || order.region || '지역 미지정'}\n` +
            `🏷️ 카테고리: ${order.category || '일반'}${budgetText}\n\n` +
            `${order.description || ''}\n\n` +
            `👉 앱에서 확인하기:\n` +
            `https://play.google.com/store/apps/details?id=com.ononcompany.allsuri`;
        
        // 클립보드에 복사
        await navigator.clipboard.writeText(shareText);
        
        alert('✅ 공유 텍스트가 클립보드에 복사되었습니다!\n\n카카오톡에 붙여넣기 하세요.');
    } catch (error) {
        console.error('[copyOrderShareLink] 에러:', error);
        alert('링크 복사에 실패했습니다: ' + error.message);
    }
}

module.exports = router;

// 견적 상세 보기 함수
async function showEstimateDetail(estimateId) {
    try {
        // allEstimates에서 해당 견적을 찾거나 API로 다시 가져오기
        let estimate = allEstimates.find(e => e.id === estimateId);
        
        if (!estimate) {
            alert('견적 정보를 찾을 수 없습니다.');
            return;
        }
        
        const modalBody = document.getElementById('estimateModalBody');
        
        let detailHtml = `
            <div class="detail-group">
                <div class="detail-item">
                    <span class="detail-label">제목:</span>
                    <span class="detail-value">${estimate.title || estimate.description || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">고객명:</span>
                    <span class="detail-value">${estimate.customerName || estimate.customername || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">사업자명:</span>
                    <span class="detail-value">${estimate.businessName || estimate.businessname || '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">견적 금액:</span>
                    <span class="detail-value">${typeof (estimate.amount || estimate.estimatedPrice) === 'number' ? '₩' + (estimate.amount || estimate.estimatedPrice).toLocaleString('ko-KR') : '-'}</span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">상태:</span>
                    <span class="detail-value"><span class="status-badge status-${estimate.status}">${getStatusText(estimate.status)}</span></span>
                </div>
                <div class="detail-item">
                    <span class="detail-label">생성일:</span>
                    <span class="detail-value">${formatDate(estimate.createdAt || estimate.createdat)}</span>
                </div>
        `;
        
        // 추가 정보가 있으면 표시
        if (estimate.orderid) {
            detailHtml += `
                <div class="detail-item">
                    <span class="detail-label">주문 ID:</span>
                    <span class="detail-value">${estimate.orderid}</span>
                </div>
            `;
        }
        
        if (estimate.customerid) {
            detailHtml += `
                <div class="detail-item">
                    <span class="detail-label">고객 ID:</span>
                    <span class="detail-value">${estimate.customerid}</span>
                </div>
            `;
        }
        
        if (estimate.businessid) {
            detailHtml += `
                <div class="detail-item">
                    <span class="detail-label">사업자 ID:</span>
                    <span class="detail-value">${estimate.businessid}</span>
                </div>
            `;
        }
        
        // 상세 설명이 있으면 추가
        if (estimate.details || estimate.description) {
            detailHtml += `
                <div class="detail-item" style="grid-column: 1 / -1;">
                    <span class="detail-label">상세 설명:</span>
                    <span class="detail-value">${estimate.details || estimate.description}</span>
                </div>
            `;
        }
        
        // 미디어 URL이 있으면 추가
        if (estimate.mediaurls && Array.isArray(estimate.mediaurls) && estimate.mediaurls.length > 0) {
            detailHtml += `
                <div class="detail-item" style="grid-column: 1 / -1;">
                    <span class="detail-label">첨부 이미지:</span>
                    <div style="display: flex; gap: 0.5rem; flex-wrap: wrap; margin-top: 0.5rem;">
                        ${estimate.mediaurls.map(url => `
                            <img src="${url}" alt="견적 이미지" style="width: 120px; height: 120px; object-fit: cover; border-radius: 8px; cursor: pointer;" onclick="window.open('${url}', '_blank')">
                        `).join('')}
                    </div>
                </div>
            `;
        }
        
        detailHtml += `</div>`;
        
        modalBody.innerHTML = detailHtml;
        document.getElementById('estimateModal').style.display = 'flex';
    } catch (error) {
        console.error('견적 상세 정보 로드 오류:', error);
        alert('견적 상세 정보를 불러오는데 실패했습니다.');
    }
}

// 견적 모달 닫기
function closeEstimateModal() {
    document.getElementById('estimateModal').style.display = 'none';
}

// ===== 광고 관리 =====
let currentEditingAd = null;

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

function getLocationLabel(location) {
    const labels = {
        'home_banner': '📱 홈 화면 배너',
        'dashboard_ad_1': '🎯 대시보드 광고 1',
        'dashboard_ad_2': '🎯 대시보드 광고 2',
    };
    return labels[location] || location;
}

function displayAds(items) {
    const c = document.getElementById('adsTableContainer');
    if (!c) return;
    if (!items || items.length === 0) {
        c.innerHTML = `
            <div class="empty-state">
                <span class="material-icons">campaign</span>
                <p>등록된 광고가 없습니다</p>
                <button class="btn btn-primary" id="firstAdBtn">
                    <span class="material-icons">add</span>
                    첫 광고 추가하기
                </button>
            </div>
        `;
        // 이벤트 리스너 추가
        const firstAdBtn = document.getElementById('firstAdBtn');
        if (firstAdBtn) {
            firstAdBtn.addEventListener('click', () => showAdModal());
        }
        return;
    }
    
    // 위치별로 그룹화
    const byLocation = {
        'home_banner': [],
        'dashboard_ad_1': [],
        'dashboard_ad_2': []
    };
    
    items.forEach(ad => {
        if (byLocation[ad.location]) {
            byLocation[ad.location].push(ad);
        }
    });
    
    let html = '';
    
    // 각 위치별로 표시
    Object.entries(byLocation).forEach(([location, ads]) => {
        html += `
            <div style="margin-bottom: 2rem;">
                <h3 style="margin-bottom: 1rem; color: var(--gray-700); display: flex; align-items: center; gap: 0.5rem;">
                    ${getLocationLabel(location)}
                    ${ads.length === 0 ? '<span style="font-size: 0.875rem; color: var(--gray-500);">(광고 없음)</span>' : ''}
                </h3>
                ${ads.length > 0 ? `
                    <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 1rem;">
                        ${ads.map(ad => `
                            <div style="border: 1px solid var(--gray-200); border-radius: 12px; padding: 1rem; background: white;">
                                ${ad.image_url ? `
                                    <img src="${ad.image_url}" alt="${ad.title}" 
                                        style="width: 100%; height: 120px; object-fit: cover; border-radius: 8px; margin-bottom: 0.75rem;"
                                        onerror="this.src='data:image/svg+xml,%3Csvg xmlns=%22http://www.w3.org/2000/svg%22 width=%22100%22 height=%22100%22%3E%3Crect fill=%22%23ddd%22 width=%22100%22 height=%22100%22/%3E%3Ctext x=%2250%25%22 y=%2250%25%22 text-anchor=%22middle%22 dy=%22.3em%22 fill=%22%23999%22%3E이미지 없음%3C/text%3E%3C/svg%3E'">
                                ` : `
                                    <div style="width: 100%; height: 120px; background: var(--gray-100); border-radius: 8px; display: flex; align-items: center; justify-content: center; margin-bottom: 0.75rem; color: var(--gray-400);">
                                        <span class="material-icons" style="font-size: 3rem;">image</span>
                                    </div>
                                `}
                                <h4 style="font-size: 1rem; margin-bottom: 0.5rem; color: var(--gray-900);">${ad.title || '제목 없음'}</h4>
                                ${ad.link_url ? `
                                    <p style="font-size: 0.75rem; color: var(--info); margin-bottom: 0.5rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;">
                                        🔗 ${ad.link_url}
                                    </p>
                                ` : ''}
                                <div style="display: flex; justify-content: space-between; align-items: center; margin-top: 0.75rem;">
                                    <span class="status-badge ${ad.is_active ? 'approved' : 'rejected'}">
                                        ${ad.is_active ? '✅ 활성' : '❌ 비활성'}
                                    </span>
                                    <div style="display: flex; gap: 0.5rem;">
                                        <button class="btn btn-secondary btn-sm edit-ad-btn" data-ad='${JSON.stringify(ad).replace(/'/g, "&apos;")}'>
                                            <span class="material-icons" style="font-size: 1rem;">edit</span>
                                        </button>
                                        <button class="btn btn-danger btn-sm delete-ad-btn" data-ad-id="${ad.id}">
                                            <span class="material-icons" style="font-size: 1rem;">delete</span>
                                        </button>
                                    </div>
                                </div>
                            </div>
                        `).join('')}
                    </div>
                ` : `
                    <div style="padding: 2rem; text-align: center; background: var(--gray-50); border-radius: 8px; color: var(--gray-500);">
                        이 위치에 광고가 없습니다. 
                        <button class="btn btn-primary btn-sm add-ad-btn" data-location="${location}" style="margin-left: 0.5rem;">
                            추가하기
                        </button>
                    </div>
                `}
            </div>
        `;
    });
    
    c.innerHTML = html;
    
    // "추가하기" 버튼들에 이벤트 리스너 추가
    const addBtns = c.querySelectorAll('.add-ad-btn');
    addBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const location = this.getAttribute('data-location');
            showAdModal(location);
        });
    });
    
    // "수정" 버튼들에 이벤트 리스너 추가
    const editBtns = c.querySelectorAll('.edit-ad-btn');
    editBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const adData = this.getAttribute('data-ad');
            try {
                const ad = JSON.parse(adData.replace(/&apos;/g, "'"));
                editAd(ad);
            } catch (e) {
                console.error('광고 데이터 파싱 실패:', e);
                alert('광고 정보를 불러올 수 없습니다.');
            }
        });
    });
    
    // "삭제" 버튼들에 이벤트 리스너 추가
    const deleteBtns = c.querySelectorAll('.delete-ad-btn');
    deleteBtns.forEach(btn => {
        btn.addEventListener('click', function() {
            const adId = this.getAttribute('data-ad-id');
            deleteAd(adId);
        });
    });
}

function showAdModal(defaultLocation = 'home_banner') {
    currentEditingAd = null;
    document.getElementById('adModalTitle').textContent = '새 광고 추가';
    document.getElementById('adId').value = '';
    document.getElementById('adTitle').value = '';
    document.getElementById('adLink').value = '';
    document.getElementById('adLocation').value = defaultLocation;
    document.getElementById('adActive').value = 'true';
    document.getElementById('adImageUrl').value = '';
    document.getElementById('adImagePreview').innerHTML = '';
    updateLocationGuide(defaultLocation);
    document.getElementById('adModal').style.display = 'block';
}

function editAd(ad) {
    try { 
        ad = (typeof ad === 'string') ? JSON.parse(ad) : ad; 
    } catch(_) {}
    
    currentEditingAd = ad;
    document.getElementById('adModalTitle').textContent = '광고 수정';
    document.getElementById('adId').value = ad.id || '';
    document.getElementById('adTitle').value = ad.title || '';
    document.getElementById('adLink').value = ad.link_url || '';
    document.getElementById('adLocation').value = ad.location || 'home_banner';
    document.getElementById('adActive').value = ad.is_active ? 'true' : 'false';
    document.getElementById('adImageUrl').value = ad.image_url || '';
    
    // 이미지 미리보기
    if (ad.image_url) {
        document.getElementById('adImagePreview').innerHTML = `
            <img src="${ad.image_url}" style="width: 100%; max-height: 200px; object-fit: cover; border-radius: 8px; margin-top: 0.5rem;">
        `;
    }
    
    updateLocationGuide(ad.location || 'home_banner');
    document.getElementById('adModal').style.display = 'block';
}

function updateLocationGuide(location) {
    const guides = {
        'home_banner': '📱 홈 화면 상단 배너 (권장: 1200×400px, 3:1 비율)',
        'dashboard_ad_1': '🎯 대시보드 광고 슬라이드 1번 (권장: 800×200px, 4:1 비율)',
        'dashboard_ad_2': '🎯 대시보드 광고 슬라이드 2번 (권장: 800×200px, 4:1 비율)'
    };
    const guideEl = document.getElementById('locationGuide');
    if (guideEl) {
        guideEl.textContent = guides[location] || '';
    }
}

function previewAdImage() {
    const url = document.getElementById('adImageUrl').value;
    const preview = document.getElementById('adImagePreview');
    
    if (url) {
        preview.innerHTML = `
            <img src="${url}" 
                style="width: 100%; max-height: 200px; object-fit: cover; border-radius: 8px; margin-top: 0.5rem;"
                onerror="this.parentElement.innerHTML='<p style=\\'color: var(--danger);\\'>이미지를 불러올 수 없습니다</p>'">
        `;
    } else {
        preview.innerHTML = '';
    }
}

async function saveAd() {
    const id = document.getElementById('adId').value;
    const title = document.getElementById('adTitle').value.trim();
    const link = document.getElementById('adLink').value.trim();
    const location = document.getElementById('adLocation').value;
    const isActive = document.getElementById('adActive').value === 'true';
    const imageUrl = document.getElementById('adImageUrl').value.trim();
    
    if (!title) {
        alert('제목을 입력해주세요');
        return;
    }
    
    const payload = {
        title,
        link_url: link || null,
        location,
        is_active: isActive,
        image_url: imageUrl || '',
    };
    
    try {
        if (id) {
            // 수정
            await apiCall(`/ads/${id}`, { 
                method: 'PUT', 
                body: JSON.stringify(payload) 
            });
            alert('광고가 수정되었습니다');
        } else {
            // 신규 생성 - 서버에서 createdat을 자동으로 추가하므로 제거
            await apiCall('/ads', { 
                method: 'POST', 
                body: JSON.stringify(payload) 
            });
            alert('광고가 추가되었습니다');
        }
        closeAdModal();
        loadAds();
    } catch (e) {
        console.error('광고 저장 실패:', e);
        alert('광고 저장에 실패했습니다: ' + e.message);
    }
}

async function deleteAd(id) {
    if (!confirm('정말로 이 광고를 삭제하시겠습니까?')) return;
    try {
        await apiCall(`/ads/${id}`, { method: 'DELETE' });
        alert('광고가 삭제되었습니다');
        loadAds();
    } catch (e) {
        console.error('광고 삭제 실패:', e);
        alert('광고 삭제에 실패했습니다');
    }
}

function closeAdModal() {
    document.getElementById('adModal').style.display = 'none';
    currentEditingAd = null;
}

// ===== 초기화 및 전체 로드 =====
async function loadAll() {
    try {
        await loadDashboard();
        console.log('✅ Dashboard loaded successfully');
    } catch (error) {
        console.error('❌ Error loading dashboard:', error);
    }
}

// 페이지 로드 시 초기화
document.addEventListener('DOMContentLoaded', () => {
    console.log('🚀 Admin page initializing...');
    checkLogin();
    loadAll();
});
