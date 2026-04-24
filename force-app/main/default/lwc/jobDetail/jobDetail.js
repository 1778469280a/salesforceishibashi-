import { LightningElement, track, wire } from 'lwc';
import getJobDetail from '@salesforce/apex/JobDetailController.getJobDetail';
import toggleFavoriteJob from '@salesforce/apex/JobCardsController.toggleFavoriteJob';
import getJobFavoriteStatus from '@salesforce/apex/JobDetailController.getJobFavoriteStatus';
import createInquiryProcess from '@salesforce/apex/JobDetailController.createInquiryProcess';
import getSelectionProcessStatus from '@salesforce/apex/JobDetailController.getSelectionProcessStatus';

export default class JobDetail extends LightningElement {
    @track jobId;
    @track job;
    @track error;
    @track isFavorite = false;
    @track processStatus = null;

    @track isButtonFixed = false;
    @track isButtonHidden = false;
    _scrollListener;

    connectedCallback() {
        this.parseJobIdFromUrl();

        // スクロールイベントの登録
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
        const topThreshold = 500;    // 上から250px
        const bottomThreshold = 600; // 下から400px以内
        
        const isPastTop = scrollY > topThreshold;
        const isNearBottom = scrollBottom >= (documentHeight - bottomThreshold);

        this.isButtonFixed = isPastTop;
        this.isButtonHidden = isPastTop && isNearBottom;
    }

    parseJobIdFromUrl() {
        try {
            const pathname = window.location.pathname;
            const pathSegments = pathname.split('/').filter(segment => segment.trim());
            const jobIdSegment = pathSegments[2];
            const sfIdPattern = /^[a-zA-Z0-9]{18}$/;
            
            if (jobIdSegment && sfIdPattern.test(jobIdSegment)) {
                this.jobId = jobIdSegment;
                this.loadFavoriteStatus(); 
                this.loadProcessStatus(); 
            } else {
                this.error = { message: 'URL内の求人ID形式が不正です' };
            }
        } catch (e) {
            this.error = { message: `URL解析エラー：${e.message}` };
        }
    }

    loadProcessStatus() {
        getSelectionProcessStatus({ jobId: this.jobId })
            .then(result => {
                this.processStatus = result;
                console.log("取得");
                console.log(JSON.stringify(this.processStatus, null, 2));
            })
            .catch(error => {
                console.error('ステータス取得エラー:', error);
                console.log("no取得");
            });
    }

    loadFavoriteStatus() {
        getJobFavoriteStatus({ jobId: this.jobId })
            .then(result => {
                this.isFavorite = result;
            })
            .catch(error => {
                this.isFavorite = false;
            });
    }

    @wire(getJobDetail, { jobId: '$jobId' })
    wiredJobDetail({ data, error }) {
        if (data) {
            this.job = data;
            this.error = null;
        } else if (error) {
            this.error = error;
            this.job = null;
        }
    }

    handleFavoriteClick(event) {
        event.stopPropagation();
        if (!this.jobId) return;
        const newFavoriteState = !this.isFavorite;
        this.isFavorite = newFavoriteState;
        toggleFavoriteJob({ jobId: this.jobId, isFavorite: newFavoriteState })
            .then(result => {
                if (!result) {
                    this.isFavorite = !newFavoriteState;
                    this.loadFavoriteStatus();
                }
            })
            .catch(() => {
                this.isFavorite = !newFavoriteState;
                this.loadFavoriteStatus();
            });
    }

    handleInquiryClick() {
        const result = window.confirm('お問い合わせいただき、ありがとうございます。求人の詳細については、確認次第、順次ご回答いたします。');

        if (result) {
            createInquiryProcess({ jobId: this.jobId })
                .then(() => {
                    window.location.reload();
                })
                .catch(error => {
                    console.error('問い合わせ処理エラー:', error);
                    alert('エラーが発生しました。時間をおいて再度お試しください。');
                });
        }
    }

    // バーおよびボタンに表示するメッセージ
    get bannerMessage() {
        if (!this.processStatus) return '';

        const status = this.processStatus;
        if (status === '求人詳細問合せ') {
            return 'この求人は現在【問い合わせ中】です';
        } else if (status === 'JOB打診') {
            return 'この求人は現在【オファー】です';
        } else if (['応募承諾', '書類推薦'].includes(status)) {
            return 'この求人は現在【応募中】です';
        } else if (['面接（一次）', '面接（二次）', '面接（三次）', '面接（最終）'].includes(status)) {
            return 'この求人は現在【面接】です';
        } else if (status === '内定' || status === '入社') {
            return 'この求人は現在【内定】です';
        } else if (status === 'クローズ') {
            return 'この求人は現在【募集終了】です';
        }
        return '';
    }

    // ボタンのラベル制御
    get contactButtonLabel() {
        return this.bannerMessage ? this.bannerMessage : 'この求人に問い合わせる';
    }

    // ボタンの非活性制御
    get isContactButtonDisabled() {
        return !!this.processStatus;
    }

    get jobIdGetter() {
        return this.job && this.job.Id ? this.job.Id : '';
    }

    get favoriteButtonFullClass() {
        let baseClasses = 'favorite-button standalone-favorite-button';
        if (this.isFavorite) {
            baseClasses += ' standalone-favorite-button-active';
        }
        return baseClasses;
    }

    get favoriteButtonText() {
        return this.isFavorite ? '追加済' : '気になる';
    }

    get errorMessage() {
        if (!this.error) return '';
        return this.error.body?.message || this.error.message || '求人データの読み込みに失敗しました';
    }

    get jobTitlePart() {
        if (!this.job) return '';
        const fullTitle = this.job.JobPosition__c || '';
        const [titlePart] = fullTitle.split('／');
        return titlePart ? titlePart.trim() : '';
    }

    get jobBenefitPart() {
        if (!this.job) return '';
        const fullTitle = this.job.JobPosition__c || '';
        const [, ...benefitParts] = fullTitle.split('／');
        return benefitParts.join('／').trim() || '';
    }

    get companyName() {
        if (!this.job) return '';
        if (!this.processStatus || this.processStatus === '求人詳細問合せ') {
            return '***********';
        }
        return this.job.Company__r?.Name || '';
    }

    get hiringBackground() { return this.job?.HiringBackground__c || ''; }
    get jobDescription() { return this.job?.JobDescription__c || ''; }
    get applicationQualification() { return this.job?.ApplicationQualification__c || ''; }
    get employmentType() { return this.job?.EmploymentType__c || ''; }

    get formattedAnnualSalary() {
        if (!this.job) return '';
        const min = this.job.MinAnnualSalary__c;
        const max = this.job.MaxAnnualSalary__c;
        if (!min && !max) return '';
        if (!min) return `${max}万円`;
        if (!max) return `${min}万円～`;
        return `${min}万円～${max}万円`;
    }

    get formattedWorkLocation() {
        if (!this.job) return '';
        const workLocation = this.job.WorkLocation2__c || '';
        const workLocationCity = this.job.WorkLocationRegion__c || '';
        const WorkLocationPrefecture = this.job.WorkLocationPrefecture__c || '';
        const firstPart = [workLocation, workLocationCity].filter(part => part).join(' ');
        return [firstPart, WorkLocationPrefecture].filter(part => part).join('');
    }

    get WorkLocation2() { return this.job?.WorkLocation2__c || ''; }

    get workLocationDetail() {
        if (!this.job) return '';
        const transfer = this.job.TransferRequired__c || '';
        const transferSupplement = this.job.TransferRemarks__c || '';
        let detail = transfer ? `転勤${transfer}` : '';
        if (transferSupplement) detail += `\n${transferSupplement}`;
        return detail;
    }

    get benefits() { return this.job?.BenefitsAndWelfare__c || ''; }
    get holidays() { return this.job?.HolidaysAndLeave__c || ''; }
    get workingHours() { return this.job?.WorkingHours__c || ''; }
    get specificConditions() { return this.job?.SpecificConditions__c || ''; }

    get formattedIndustry() {
        if (!this.job?.Company__r?.Industry__c) return '';
        return this.job.Company__r.Industry__c.replace(/;/g, '\n');
    }

    get formattedBusinessSummary() {
        if (!this.job?.Company__r?.BusinessSummary__c) return '';
        const summary = this.job.Company__r.BusinessSummary__c;
        return summary.length > 30 ? summary.substring(0, 30) + '…' : summary;
    }

    get formattedEmployeeCount() {
        if (!this.job?.Company__r?.NumberOfEmployees__c) return '';
        return `${this.job.Company__r.NumberOfEmployees__c}名`;
    }

    get formattedLastModifiedDate() {
        if (!this.job?.LastModifiedDate) return '';
        const date = new Date(this.job.LastModifiedDate);
        return `${date.getFullYear()}年${date.getMonth() + 1}月${date.getDate()}日`;
    }

    get jobHighlights() {
        if (!this.job) return [];
        const highlights = [];
        if (this.job.JobHighlight1__c) highlights.push({ id: '1', value: this.job.JobHighlight1__c });
        if (this.job.JobHighlight2__c) highlights.push({ id: '2', value: this.job.JobHighlight2__c });
        if (this.job.JobHighlight3__c) highlights.push({ id: '3', value: this.job.JobHighlight3__c });
        return highlights;
    }

    get hasHighlights() { return this.jobHighlights.length > 0; }
    get viewStatusLabel() { return this.job?.LastViewedDate == null ? 'NEW' : '閲覧済'; }
    get viewStatusClass() { return this.job?.LastViewedDate == null ? 'view-status-new' : 'view-status-viewed'; }

    get fixedBarClass() {
        // 条件クリア（上スクロール基準クリア ＆ フッター未到達）の場合のみ表示
        if (this.isButtonFixed && !this.isButtonHidden) {
            return 'fixed-bottom-bar show-bar';
        }
        return 'fixed-bottom-bar hide-bar';
    }
}