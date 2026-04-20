import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getJobs from '@salesforce/apex/JobSearchController.getJobs';
import toggleFavoriteJob from '@salesforce/apex/JobSearchController.toggleFavoriteJob';

export default class JobSearchResults1 extends LightningElement {
    @track jobs = [];
    @track jobWithUrls = [];
    @track isLoading = false;
    @track totalCount = 0;
    @track filterTags = [];
    @track currentFilters = {};
    @track showModifyModal = false;
    @track selectedSort = 'newest';
    @track error = undefined;
    @track currentPage = 1;
    @track pageSize = 20;
    @track totalPages = 0;
    @track visiblePages = [];

    // 固定表示およびフッター付近の非表示管理
    @track isButtonFixed = false;
    @track isButtonHidden = false;
    _scrollListener;

    @wire(CurrentPageReference)
    handlePageReferenceChange(pageRef) {
        if (pageRef?.state) {
            const newFilters = {
                categories: pageRef.state.categories?.split(',') || [],
                prefectures: pageRef.state.prefectures?.split(',') || [],
                minSalary: pageRef.state.minSalary || '',
                transfer: pageRef.state.transfer || '',
                conditions: pageRef.state.conditions?.split(',') || [],
                keyword: pageRef.state.keyword || '',
                sortBy: pageRef.state.sort || this.selectedSort,
                page: pageRef.state.page ? Number(pageRef.state.page) : 1
            };
            if (JSON.stringify(newFilters) !== JSON.stringify(this.currentFilters)) {
                this.currentFilters = newFilters;
                this.currentPage = newFilters.page || 1;
                this.generateFilterTags(this.currentFilters);
                this.searchJobs(this.currentFilters);
            }
        }
    }

    get sortOptions() {
        return [
            { label: '新着順', value: 'newest' },
            { label: '年収高い順', value: 'highestSalary' },
            { label: '年収低い順', value: 'lowestSalary' },
            { label: 'おすすめ順', value: 'recommended' }
        ];
    }

    connectedCallback() {
        this.loadFromUrl();
        window.addEventListener('popstate', () => {
            this.loadFromUrl();
        });

        // スクロールイベントの登録
        this._scrollListener = this.handleScroll.bind(this);
        window.addEventListener('scroll', this._scrollListener);
    }

    disconnectedCallback() {
        window.removeEventListener('popstate', () => {
            this.loadFromUrl();
        });
        // イベントの解除
        window.removeEventListener('scroll', this._scrollListener);
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

    // ▼ 修正：固定バーのクラスを制御 ▼
    get fixedBarClass() {
        // 条件クリア（上スクロール基準クリア ＆ フッター未到達）の場合のみ表示
        if (this.isButtonFixed && !this.isButtonHidden) {
            return 'fixed-bottom-bar show-bar';
        }
        return 'fixed-bottom-bar hide-bar';
    }

    loadFromUrl() {
        const urlParams = new URLSearchParams(window.location.search);
        this.currentFilters = {
            categories: urlParams.get('categories')?.split(',') || [],
            prefectures: urlParams.get('prefectures')?.split(',') || [],
            minSalary: urlParams.get('minSalary') || '',
            transfer: urlParams.get('transfer') || '',
            conditions: urlParams.get('conditions')?.split(',') || [],
            keyword: urlParams.get('keyword') || '',
            sortBy: urlParams.get('sort') || this.selectedSort,
            page: urlParams.get('page') ? Number(urlParams.get('page')) : 1
        };
        this.currentPage = this.currentFilters.page || 1;
        this.generateFilterTags(this.currentFilters);
        this.searchJobs(this.currentFilters);
    }

    generateFilterTags(filters) {
        const tags = [];
        if (filters.categories && filters.categories.length > 0) {
            filters.categories.forEach(category => {
                tags.push({ id: `cat-${category}`, label: `職種: ${category}` });
            });
        }
        if (filters.prefectures && filters.prefectures.length > 0) {
            filters.prefectures.forEach(location => {
                tags.push({ id: `loc-${location}`, label: `勤務地: ${location}` });
            });
        }
        if (filters.minSalary) {
            tags.push({ id: 'minSalary', label: `最低年収: ${filters.minSalary}万円以上` });
        }
        if (filters.transfer) {
            const label = filters.transfer === '有り' ? '転勤あり' : '転勤なし';
            tags.push({ id: 'transfer', label: `転勤: ${label}` });
        }
        if (filters.conditions && filters.conditions.length > 0) {
            filters.conditions.forEach(condition => {
                tags.push({ id: `condition-${condition}`, label: `こだわり: ${condition}` });
            });
        }
        if (filters.keyword) {
            tags.push({ id: 'keyword', label: `キーワード: ${filters.keyword}` });
        }
        this.filterTags = tags;
    }

    async searchJobs(filters) {
        this.isLoading = true;
        this.error = undefined;
        try {
            const searchFilters = {
                ...filters,
                sortBy: filters.sortBy || this.selectedSort
            };
            const result = await getJobs({ filters: searchFilters });
            this.jobs = result || [];
            this.totalCount = this.jobs.length;
            this.totalPages = Math.ceil(this.totalCount / this.pageSize);
            this.currentPage = Math.min(this.currentPage, this.totalPages);
            this.currentPage = Math.max(this.currentPage, 1);
            this.generateVisiblePages();
            this.processJobData();
        } catch (error) {
            console.error('検索エラー:', error);
            this.error = error;
            this.jobs = [];
            this.totalCount = 0;
            this.totalPages = 0;
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
            const jobTitlePart = jobTitleMain ? jobTitleMain.trim() : '';
            const jobBenefitPart = jobBenefitParts.join('／').trim();

            return {
                ...job,
                url: `/portal/job/${job.Id}`,
                FormattedLastModifiedDate: this.formatDateToJapanese(job.LastModifiedDate),
                viewStatus: job.LastViewedDate == null ? 'new' : 'viewed',
                viewStatusLabel: job.LastViewedDate == null ? 'NEW' : '閲覧済',
                viewStatusClass: job.LastViewedDate == null ? 'view-status-new' : 'view-status-viewed',
                favoriteButtonClass: job.IsFavorite ? 'favorite-button-active' : 'favorite-button',
                favoriteButtonText: job.IsFavorite ? '追加済' : '気になる',
                jobTitlePart: jobTitlePart,
                jobBenefitPart: jobBenefitPart
            };
        });
    }

    formatDateToJapanese(datetime) {
        if (!datetime) return '';
        const date = new Date(datetime);
        const year = date.getFullYear();
        const month = date.getMonth() + 1;
        const day = date.getDate();
        return `${year}/${month}/${day}`;
    }

    handleSortChange(event) {
        this.selectedSort = event.detail.value;
        this.currentFilters.sortBy = this.selectedSort;
        this.currentPage = 1;
        this.currentFilters.page = this.currentPage;
        this.searchJobs(this.currentFilters);
        this.updateUrlParams(this.currentFilters);
    }

    openModifyModal() {
        this.showModifyModal = true;
        document.body.style.overflow = 'hidden';
    }

    closeModifyModal() {
        this.showModifyModal = false;
        document.body.style.overflow = '';
    }

    handleModalSearch(event) {
        const newFilters = event.detail;
        this.currentFilters = {
            ...newFilters,
            sortBy: this.currentFilters.sortBy || this.selectedSort,
            page: 1
        };
        this.currentPage = 1;
        this.generateFilterTags(this.currentFilters);
        this.searchJobs(this.currentFilters);
        this.closeModifyModal();
        this.updateUrlParams(this.currentFilters);
    }

    updateUrlParams(filters) {
        const urlParams = new URLSearchParams();
        if (filters.categories?.length) urlParams.set('categories', filters.categories.join(','));
        if (filters.prefectures?.length) urlParams.set('prefectures', filters.prefectures.join(','));
        if (filters.minSalary) urlParams.set('minSalary', filters.minSalary);
        if (filters.transfer) urlParams.set('transfer', filters.transfer);
        if (filters.conditions?.length) urlParams.set('conditions', filters.conditions.join(','));
        if (filters.keyword) urlParams.set('keyword', filters.keyword);
        if (filters.sortBy) urlParams.set('sort', filters.sortBy);
        if (filters.page) urlParams.set('page', filters.page.toString());
        window.history.pushState({}, '', `${window.location.pathname}?${urlParams.toString()}`);
    }

    handleFavoriteClick(event) {
        event.stopPropagation();
        event.preventDefault();
        const jobId = event.currentTarget.dataset.jobId;
        const isCurrentlyFavorite = event.currentTarget.dataset.isFavorite === 'true';
        const newFavoriteState = !isCurrentlyFavorite;

        this.jobs = this.jobs.map(job => {
            if (job.Id === jobId) {
                return { ...job, IsFavorite: newFavoriteState };
            }
            return job;
        });
        this.processJobData();
        toggleFavoriteJob({ jobId, isFavorite: newFavoriteState })
            .then(result => {
                if (!result) {
                    this.searchJobs(this.currentFilters);
                }
            })
            .catch(error => {
                console.error('お気に入り更新エラー:', error);
                this.searchJobs(this.currentFilters);
            });
    }

    handleCardClick(event) {
        // 詳細遷移などの処理
    }

    handlePageClick(event) {
        const page = Number(event.currentTarget.dataset.page);
        if (page === this.currentPage || page < 1 || page > this.totalPages) return;
        this.currentPage = page;
        this.currentFilters.page = this.currentPage;
        this.generateVisiblePages();
        this.processJobData();
        this.updateUrlParams(this.currentFilters);
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.currentFilters.page = this.currentPage;
            this.generateVisiblePages();
            this.processJobData();
            this.updateUrlParams(this.currentFilters);
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.currentFilters.page = this.currentPage;
            this.generateVisiblePages();
            this.processJobData();
            this.updateUrlParams(this.currentFilters);
        }
    }

    generateVisiblePages() {
        const pages = [];
        const total = this.totalPages;
        const current = this.currentPage;
        let keyCounter = 0;

        if (total <= 4) {
            for (let i = 1; i <= total; i++) {
                pages.push({
                    key: `page-${keyCounter++}`,
                    value: i,
                    isNumber: true,
                    isEllipsis: false,
                    isCurrent: i === current
                });
            }
        } else if (current <= 2) {
            pages.push(
                { key: `page-${keyCounter++}`, value: 1, isNumber: true, isEllipsis: false, isCurrent: 1 === current },
                { key: `page-${keyCounter++}`, value: 2, isNumber: true, isEllipsis: false, isCurrent: 2 === current },
                { key: `page-${keyCounter++}`, value: 3, isNumber: true, isEllipsis: false, isCurrent: 3 === current },
                { key: `page-${keyCounter++}`, value: '...', isNumber: false, isEllipsis: true, isCurrent: false },
                { key: `page-${keyCounter++}`, value: total, isNumber: true, isEllipsis: false, isCurrent: total === current }
            );
        } else if (current >= total - 1) {
            pages.push(
                { key: `page-${keyCounter++}`, value: 1, isNumber: true, isEllipsis: false, isCurrent: 1 === current },
                { key: `page-${keyCounter++}`, value: '...', isNumber: false, isEllipsis: true, isCurrent: false },
                { key: `page-${keyCounter++}`, value: total - 2, isNumber: true, isEllipsis: false, isCurrent: (total - 2) === current },
                { key: `page-${keyCounter++}`, value: total - 1, isNumber: true, isEllipsis: false, isCurrent: (total - 1) === current },
                { key: `page-${keyCounter++}`, value: total, isNumber: true, isEllipsis: false, isCurrent: total === current }
            );
        } else {
            pages.push(
                { key: `page-${keyCounter++}`, value: 1, isNumber: true, isEllipsis: false, isCurrent: 1 === current },
                { key: `page-${keyCounter++}`, value: '...', isNumber: false, isEllipsis: true, isCurrent: false },
                { key: `page-${keyCounter++}`, value: current - 1, isNumber: true, isEllipsis: false, isCurrent: (current - 1) === current },
                { key: `page-${keyCounter++}`, value: current, isNumber: true, isEllipsis: false, isCurrent: true },
                { key: `page-${keyCounter++}`, value: current + 1, isNumber: true, isEllipsis: false, isCurrent: (current + 1) === current },
                { key: `page-${keyCounter++}`, value: '...', isNumber: false, isEllipsis: true, isCurrent: false },
                { key: `page-${keyCounter++}`, value: total, isNumber: true, isEllipsis: false, isCurrent: total === current }
            );
        }

        this.visiblePages = pages;
    }

    get showPagination() {
        return this.totalPages > 1;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages;
    }

    get paginationRangeText() {
        if (this.totalCount === 0) return '';
        const start = (this.currentPage - 1) * this.pageSize + 1;
        const end = Math.min(this.currentPage * this.pageSize, this.totalCount);
        return `${start}〜${end}件を表示中`;
    }
}