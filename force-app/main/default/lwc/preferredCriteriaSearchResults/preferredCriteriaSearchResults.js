import { LightningElement, track, wire } from 'lwc';
import getRecommendedJobs from '@salesforce/apex/JobSearchController.getRecommendedJobs';
import toggleFavoriteJob from '@salesforce/apex/JobSearchController.toggleFavoriteJob';
import getFilterOptions from '@salesforce/apex/JobSearchController.getFilterOptions';
import savePreferences from '@salesforce/apex/JobSearchController.savePreferences';
import getPreferences from '@salesforce/apex/JobSearchController.getPreferences';

export default class PreferredCriteriaSearchResults extends LightningElement {
    // --- トースト管理 ---
    @track toastConfig = { show: false, message: '', isError: false };

    // --- 検索結果用 State ---
    @track jobs = [];               // 全ヒットデータ
    @track jobWithUrls = [];        // 現在のページに表示する加工済みデータ
    @track isLoading = false;
    @track totalCount = 0;
    @track currentConditionsText = ''; 
    @track selectedSort = 'newest';
    @track currentPage = 1;
    @track pageSize = 20;
    @track totalPages = 0;
    @track visiblePages = [];
    @track isButtonFixed = false;
    @track isButtonHidden = false;
    _scrollListener;

    // --- フィルター用 State ---
    @track currentFilters = {
        categories: [], pref1: '', pref2: '', pref3: '', minSalary: '', transfer: [], sortBy: 'newest', page: 1
    };
    @track editFilters = {
        categories: [], pref1: '', pref2: '', pref3: '', minSalary: '', transfer: []
    };
    @track tempFilters = { categories: [] };

    // --- マスタデータ・モーダル制御用 ---
    @track jobCategories = [];
    @track regionsData = []; 
    @track showModifyModal = false;
    @track showJobTypeModal = false;
    @track isModalLoading = false; 

    REGION_MAPPINGS = [
        { label: '北海道/東北', key: 'hokkaido-tohoku', values: ['北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'] },
        { label: '関東', key: 'kanto', values: ['茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県'] },
        { label: '上信越/北陸', key: 'shinetsu-hokuriku', values: ['新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県'] },
        { label: '東海', key: 'tokai', values: ['岐阜県', '静岡県', '愛知県', '三重県'] },
        { label: '関西', key: 'kansai', values: ['滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県'] },
        { label: '中国', key: 'chugoku', values: ['鳥取県', '島根県', '岡山県', '広島県', '山口県'] },
        { label: '四国', key: 'shikoku', values: ['徳島県', '香川県', '愛媛県', '高知県'] },
        { label: '九州/沖縄', key: 'kyushu-okinawa', values: ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県', '海外'] },
        { label: 'その他', key: 'else', values: ['海外'] }
    ];

    get sortOptions() {
        return [
            { label: '新着順', value: 'newest' },
            { label: '年収高い順', value: 'highestSalary' },
            { label: '年収低い順', value: 'lowestSalary' },
            { label: 'おすすめ順', value: 'recommended' }
        ];
    }

    // ==========================================
    // 初期化・データ取得
    // ==========================================
    connectedCallback() {
        // URLパラメータは見ず、無条件でDBから希望条件を取得
        this.loadPreferencesAndSearch();

        this._scrollListener = this.handleScroll.bind(this);
        window.addEventListener('scroll', this._scrollListener);
    }

    handleScroll() {
        const scrollY = window.scrollY || window.pageYOffset;
        const windowHeight = window.innerHeight;
        const documentHeight = Math.max(
            document.body.scrollHeight, 
            document.documentElement.scrollHeight
        );
        const scrollBottom = scrollY + windowHeight;

        // ▼ 表示範囲の調整（適宜変更してください） ▼
        const topThreshold = 250;    // 上から250px
        const bottomThreshold = 400; // 下から400px以内
        
        const isPastTop = scrollY > topThreshold;
        const isNearBottom = scrollBottom >= (documentHeight - bottomThreshold);

        this.isButtonFixed = isPastTop;
        this.isButtonHidden = isPastTop && isNearBottom;
    }


    async loadPreferencesAndSearch() {
        this.isLoading = true;
        try {
            const dbPrefs = await getPreferences();
            if (dbPrefs) {
                this.currentFilters = {
                    ...this.currentFilters,
                    categories: dbPrefs.categories || [],
                    pref1: dbPrefs.pref1 || '',
                    pref2: dbPrefs.pref2 || '',
                    pref3: dbPrefs.pref3 || '',
                    minSalary: dbPrefs.minSalary || '',
                    transfer: dbPrefs.transfer || [],
                    page: 1
                };
            }
            this.updateCurrentConditionsText();
            this.searchJobs();
        } catch (e) {
            console.error('設定取得エラー:', e);
            // エラー時でも空の条件で検索をかける
            this.searchJobs();
        }
    }

    @wire(getFilterOptions)
    wiredFilterOptions({ error, data }) {
        if (data) {
            const categorySet = new Set();
            data.jobCategories.forEach(item => { if (item.JobCategory1__c) categorySet.add(item.JobCategory1__c); });
            this.jobCategories = Array.from(categorySet).map((label, idx) => ({
                key: `cat-${idx}`, value: label, label: label, isSelected: false
            }));

            const available = [...new Set([...(data.regions || []), ...(data.prefectures || [])].filter(Boolean).map(v => v.trim()))];
            this.regionsData = this.REGION_MAPPINGS
                .map(mapping => ({
                    key: mapping.key, label: mapping.label,
                    prefectures: mapping.values.filter(v => available.includes(v))
                }))
                .filter(group => group.prefectures.length > 0);
        }
    }

    // ==========================================
    // 検索ロジック
    // ==========================================
    async searchJobs() {
        this.isLoading = true;
        try {
            const result = await getRecommendedJobs({ filters: this.currentFilters });
            this.jobs = result || [];
            this.totalCount = this.jobs.length;
            this.totalPages = Math.ceil(this.totalCount / this.pageSize);
            this.currentPage = Math.max(1, Math.min(this.currentPage, this.totalPages || 1));
            
            this.generateVisiblePages();
            this.processJobData();
        } catch (error) {
            console.error('検索エラー:', error);
            this.jobs = [];
            this.jobWithUrls = [];
        } finally {
            this.isLoading = false;
        }
    }

    processJobData() {
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const paginatedJobs = this.jobs.slice(start, end);

        this.jobWithUrls = paginatedJobs.map(job => {
            const [jobTitleMain, ...jobBenefitParts] = job.JobPosition ? job.JobPosition.split('／') : ['', ''];
            
            return {
                ...job,
                url: `/portal/job/${job.Id}`,
                FormattedLastModifiedDate: this.formatDateToJapanese(job.LastModifiedDate),
                viewStatusLabel: job.LastViewedDate == null ? 'NEW' : '閲覧済',
                viewStatusClass: job.LastViewedDate == null ? 'view-status-new' : 'view-status-viewed',
                favoriteButtonClass: job.IsFavorite ? 'favorite-button-active' : 'favorite-button',
                favoriteButtonText: job.IsFavorite ? '追加済' : '気になる',
                jobTitlePart: jobTitleMain ? jobTitleMain.trim() : '',
                jobBenefitPart: jobBenefitParts.join('／').trim(),
                JobCategory1: job.JobCategory1,
                WorkLocation2: job.WorkLocation2,
                JobDescription: job.JobDescription,
                MinAnnualSalary: job.MinAnnualSalary,
                MaxAnnualSalary: job.MaxAnnualSalary
            };
        });
    }

    updateCurrentConditionsText() {
        const parts = [];
        if (this.currentFilters.categories?.length) parts.push(...this.currentFilters.categories);
        if (this.currentFilters.pref1) parts.push(this.currentFilters.pref1);
        if (this.currentFilters.pref2) parts.push(this.currentFilters.pref2);
        if (this.currentFilters.pref3) parts.push(this.currentFilters.pref3);
        if (this.currentFilters.minSalary) parts.push(this.currentFilters.minSalary);
        if (this.currentFilters.transfer?.length) parts.push(...this.currentFilters.transfer);
        this.currentConditionsText = parts.length > 0 ? parts.join('、') : '指定なし';
    }

    formatDateToJapanese(datetime) {
        if (!datetime) return '';
        const date = new Date(datetime);
        return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`;
    }

    // ==========================================
    // イベントハンドラ
    // ==========================================
    handleSortChange(event) {
        this.selectedSort = event.detail.value;
        this.currentFilters.sortBy = this.selectedSort;
        this.currentPage = 1;
        this.currentFilters.page = 1;
        this.searchJobs();
    }

    handleFavoriteClick(event) {
        event.stopPropagation();
        event.preventDefault();
        const jobId = event.currentTarget.dataset.jobId;
        const isFavorite = event.currentTarget.dataset.isFavorite === 'true';
        const newState = !isFavorite;

        this.jobs = this.jobs.map(j => j.Id === jobId ? { ...j, IsFavorite: newState } : j);
        this.processJobData();

        toggleFavoriteJob({ jobId, isFavorite: newState }).catch(err => {
            console.error('お気に入りエラー:', err);
            this.searchJobs();
        });
    }

    // ==========================================
    // ページネーション
    // ==========================================
    handlePageClick(event) {
        const page = Number(event.currentTarget.dataset.page);
        if (page === this.currentPage) return;
        this.currentPage = page;
        this.currentFilters.page = page;
        this.generateVisiblePages();
        this.processJobData();
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.currentFilters.page = this.currentPage;
            this.generateVisiblePages();
            this.processJobData();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.currentFilters.page = this.currentPage;
            this.generateVisiblePages();
            this.processJobData();
        }
    }

    generateVisiblePages() {
        const pages = [];
        const total = this.totalPages;
        const current = this.currentPage;
        let key = 0;

        if (total <= 4) {
            for (let i = 1; i <= total; i++) {
                pages.push({ key: key++, value: i, isNumber: true, isEllipsis: false, isCurrent: i === current, className: `pagination-btn pagination-page ${i === current ? 'active' : ''}` });
            }
        } else if (current <= 2) {
            for (let i = 1; i <= 3; i++) pages.push({ key: key++, value: i, isNumber: true, isEllipsis: false, isCurrent: i === current, className: `pagination-btn pagination-page ${i === current ? 'active' : ''}` });
            pages.push({ key: key++, value: '...', isNumber: false, isEllipsis: true });
            pages.push({ key: key++, value: total, isNumber: true, isEllipsis: false, isCurrent: total === current, className: `pagination-btn pagination-page` });
        } else if (current >= total - 1) {
            pages.push({ key: key++, value: 1, isNumber: true, isEllipsis: false, isCurrent: false, className: `pagination-btn pagination-page` });
            pages.push({ key: key++, value: '...', isNumber: false, isEllipsis: true });
            for (let i = total - 2; i <= total; i++) pages.push({ key: key++, value: i, isNumber: true, isEllipsis: false, isCurrent: i === current, className: `pagination-btn pagination-page ${i === current ? 'active' : ''}` });
        } else {
            pages.push({ key: key++, value: 1, isNumber: true, isEllipsis: false, isCurrent: false, className: `pagination-btn pagination-page` });
            pages.push({ key: key++, value: '...', isNumber: false, isEllipsis: true });
            pages.push({ key: key++, value: current, isNumber: true, isEllipsis: false, isCurrent: true, className: `pagination-btn pagination-page active` });
            pages.push({ key: key++, value: current + 1, isNumber: true, isEllipsis: false, isCurrent: false, className: `pagination-btn pagination-page` });
            pages.push({ key: key++, value: '...', isNumber: false, isEllipsis: true });
            pages.push({ key: key++, value: total, isNumber: true, isEllipsis: false, isCurrent: false, className: `pagination-btn pagination-page` });
        }
        this.visiblePages = pages;
    }

    // ==========================================
    // モーダル操作
    // ==========================================
    openModifyModal() {
        this.editFilters = JSON.parse(JSON.stringify(this.currentFilters));
        this.showModifyModal = true;
        document.body.style.overflow = 'hidden';
        
        setTimeout(() => {
            this.template.querySelectorAll('.location-select').forEach(s => { s.value = this.editFilters[s.name] || ''; });
            const ss = this.template.querySelector('.salary-select');
            if (ss) ss.value = this.editFilters.minSalary || '';
        }, 0);
    }

    closeModifyModal() {
        this.showModifyModal = false;
        document.body.style.overflow = '';
    }

    handleSelectLocationChange(e) { this.editFilters = { ...this.editFilters, [e.target.name]: e.target.value }; }
    handleSelectChange(e) { if (e.target.dataset.type === 'salary') this.editFilters.minSalary = e.target.value; }
    
    handleTransferChange(e) {
        const { value, checked } = e.target;
        let t = [...(this.editFilters.transfer || [])];
        if (checked) t.push(value); else t = t.filter(v => v !== value);
        this.editFilters.transfer = t;
    }

    async handleRegister() {
        this.isModalLoading = true;
        const getReg = (p) => {
            if (!p) return '';
            const r = this.REGION_MAPPINGS.find(m => m.values.includes(p));
            return (r && r.label !== 'その他') ? r.label : '';
        };

        const payload = {
            ...this.editFilters,
            pref1Category: getReg(this.editFilters.pref1),
            pref2Category: getReg(this.editFilters.pref2),
            pref3Category: getReg(this.editFilters.pref3)
        };

        try {
            await savePreferences({ filters: payload });
            this.displayToast('希望条件を登録しました', false);
            this.currentFilters = { ...this.editFilters, page: 1 };
            this.currentPage = 1;
            this.closeModifyModal();
            this.updateCurrentConditionsText();
            this.searchJobs();
        } catch (error) {
            this.displayToast(error.body?.message || error.message, true);
        } finally {
            this.isModalLoading = false;
        }
    }

    // --- 職種サブモーダル ---
    handleJobTypeClick() {
        this.showJobTypeModal = true;
        this.tempFilters.categories = [...(this.editFilters.categories || [])];
        this.updateJobCategoryFlags();
    }
    closeJobTypeModal() { this.showJobTypeModal = false; }
    handleJobTypeSubmit() {
        this.editFilters.categories = [...this.tempFilters.categories];
        this.showJobTypeModal = false;
    }
    handleJobTypeReset() { this.tempFilters.categories = []; this.updateJobCategoryFlags(); }
    handleCheckboxChange(e) {
        const { value, checked } = e.target;
        if (checked) this.tempFilters.categories = [...new Set([...this.tempFilters.categories, value])];
        else this.tempFilters.categories = this.tempFilters.categories.filter(v => v !== value);
        this.updateJobCategoryFlags();
    }
    updateJobCategoryFlags() {
        this.jobCategories = this.jobCategories.map(c => ({ ...c, isSelected: this.tempFilters.categories.includes(c.value) }));
    }

    // --- 共通 ---
    displayToast(msg, isErr) {
        this.toastConfig = { show: true, message: msg, isError: isErr };
        setTimeout(() => { this.toastConfig.show = false; }, 3000);
    }
    get isTransferNo() { return this.editFilters.transfer?.includes('不可'); }
    get isTransferSingle() { return this.editFilters.transfer?.includes('可（単身）'); }
    get isTransferFamily() { return this.editFilters.transfer?.includes('可（家族同伴）'); }
    get isTransferConditional() { return this.editFilters.transfer?.includes('条件付き可'); }
    get selectedJobCategories() { return this.jobCategories.filter(c => this.editFilters.categories?.includes(c.value)).map(c => c.label); }
    get jobTypeSelectedText() { return this.editFilters.categories?.length > 0 ? `${this.editFilters.categories.length}件選択中` : '選択する'; }
    get showPagination() { return this.totalPages > 1; }
    get isFirstPage() { return this.currentPage === 1; }
    get isLastPage() { return this.currentPage === this.totalPages; }
    get paginationRangeText() {
        if (this.totalCount === 0) return '';
        const s = (this.currentPage - 1) * this.pageSize + 1;
        const e = Math.min(this.currentPage * this.pageSize, this.totalCount);
        return `${s}〜${e}件を表示中`;
    }
    stopPropagation(e) { e.stopPropagation(); }
    handleModalOutsideClick() { this.closeJobTypeModal(); }
    get fixedBarClass() {
        // 条件クリア（上スクロール基準クリア ＆ フッター未到達）の場合のみ表示
        if (this.isButtonFixed && !this.isButtonHidden) {
            return 'fixed-bottom-bar show-bar';
        }
        return 'fixed-bottom-bar hide-bar';
    }
}