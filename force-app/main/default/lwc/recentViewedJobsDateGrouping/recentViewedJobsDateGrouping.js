import { LightningElement, track, wire } from 'lwc';
import getRecentViewedDetailJobs from '@salesforce/apex/RecentJobViewedController.getRecentViewedDetailJobs';
import toggleFavoriteJob from '@salesforce/apex/JobSearchController.toggleFavoriteJob';

export default class RecentViewedJobsDateGrouping extends LightningElement {
    @track groupedJobs = [];
    @track isLoading = true;
    
    // データ保持用
    allJobs = []; 

    // ページネーション用変数
    @track currentPage = 1;
    @track pageSize = 20; // 1ページあたりの件数（必要に応じて変更してください）
    @track totalCount = 0;
    @track totalPages = 0;
    @track visiblePages = [];

    @wire(getRecentViewedDetailJobs)
    wiredJobs({ error, data }) {
        this.isLoading = true;
        if (data) {
            // Apexから取得した全件を保持
            this.allJobs = JSON.parse(JSON.stringify(data));
            this.totalCount = this.allJobs.length;
            this.totalPages = Math.ceil(this.totalCount / this.pageSize) || 1;
            
            // 1ページ目を表示
            this.updatePageData(1);
            this.isLoading = false;
        } else if (error) {
            console.error('求人情報の取得に失敗しました:', error);
            this.allJobs = [];
            this.groupedJobs = [];
            this.totalCount = 0;
            this.totalPages = 0;
            this.isLoading = false;
        }
    }

    // ページ切り替えに伴うデータの更新
    updatePageData(pageNumber) {
        this.currentPage = pageNumber;
        
        // 全件リストから現在のページ分を切り出し
        const start = (this.currentPage - 1) * this.pageSize;
        const end = start + this.pageSize;
        const paginatedRawJobs = this.allJobs.slice(start, end);

        // 切り出したリストでグループ化と画面用プロパティ付与を実行
        this.processGroupedData(paginatedRawJobs);
        this.generateVisiblePages();
    }

    processGroupedData(jobsToProcess) {
        const groups = {};

        jobsToProcess.forEach(job => {
            const lastViewed = job.LastViewedDate;
            const lastModified = job.LastModifiedDate;
            const jobPosition = job.JobPosition || job.JobPosition__c || '';
            const jobCategory = job.JobCategory1 || job.JobCategory1__c || '';
            const mainIndustry = job.MainIndustry || (job.Company__r ? job.Company__r.MainIndustry__c : '') || '';
            const jobDesc = job.JobDescription || job.JobDescription__c || '';
            const minSalary = job.MinAnnualSalary || job.MinAnnualSalary__c || '';
            const maxSalary = job.MaxAnnualSalary || job.MaxAnnualSalary__c || '';
            const workLoc = job.WorkLocation2 || job.WorkLocation2__c || '';

            let dateKey = '閲覧日不明';
            if (lastViewed) {
                dateKey = this.formatDateToJapanese(lastViewed);
            }

            if (!groups[dateKey]) {
                groups[dateKey] = {
                    dateString: dateKey,
                    jobs: []
                };
            }

            const [jobTitleMain, ...jobBenefitParts] = jobPosition ? jobPosition.split('／') : ['', ''];
            const jobTitlePart = jobTitleMain ? jobTitleMain.trim() : '';
            const jobBenefitPart = jobBenefitParts.join('／').trim();

            groups[dateKey].jobs.push({
                Id: job.Id,
                url: `/portal/job/${job.Id}`,
                FormattedLastModifiedDate: this.formatDateToJapanese(lastModified),
                viewStatusClass: lastViewed ? 'view-status-viewed' : 'view-status-new',
                viewStatusLabel: lastViewed ? '閲覧済' : 'NEW',
                favoriteButtonClass: job.IsFavorite ? 'favorite-button-active' : 'favorite-button',
                favoriteButtonText: job.IsFavorite ? '追加済' : '気になる',
                IsFavorite: job.IsFavorite || false,
                jobTitlePart: jobTitlePart,
                jobBenefitPart: jobBenefitPart,
                DisplayCategory: jobCategory,
                DisplayIndustry: mainIndustry,
                DisplayDescription: jobDesc,
                DisplayMinSalary: minSalary,
                DisplayMaxSalary: maxSalary,
                DisplayLocation: workLoc
            });
        });

        this.groupedJobs = Object.values(groups).sort((a, b) => {
            return new Date(b.dateString) - new Date(a.dateString);
        });
    }

    formatDateToJapanese(datetime) {
        if (!datetime) return '';
        const date = new Date(datetime);
        const year = date.getFullYear();
        const month = String(date.getMonth() + 1).padStart(2, '0');
        const day = String(date.getDate()).padStart(2, '0');
        return `${year}/${month}/${day}`;
    }

    // --- お気に入り処理 ---
    handleFavoriteClick(event) {
        event.preventDefault();
        event.stopPropagation();
        
        const jobId = event.currentTarget.dataset.jobId;
        const isCurrentlyFavorite = event.currentTarget.dataset.isFavorite === 'true';
        const newFavoriteState = !isCurrentlyFavorite;

        // 全件リスト（allJobs）のお気に入り状態を更新
        this.allJobs = this.allJobs.map(job => {
            if (job.Id === jobId) {
                return { ...job, IsFavorite: newFavoriteState };
            }
            return job;
        });

        // 状態を更新した後、現在のページを再描画（色やテキストを反映）
        this.updatePageData(this.currentPage);

        toggleFavoriteJob({ jobId: jobId, isFavorite: newFavoriteState })
            .catch(error => {
                console.error('お気に入り更新エラー:', error);
            });
    }

    // --- ページネーション処理 ---
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

    handlePageClick(event) {
        const page = Number(event.currentTarget.dataset.page);
        if (page === this.currentPage || page < 1 || page > this.totalPages) return;
        this.updatePageData(page);
    }

    handlePrevPage() {
        if (this.currentPage > 1) {
            this.updatePageData(this.currentPage - 1);
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.updatePageData(this.currentPage + 1);
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
                    key: `page-${keyCounter++}`, value: i, isNumber: true, isEllipsis: false, isCurrent: i === current
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
}