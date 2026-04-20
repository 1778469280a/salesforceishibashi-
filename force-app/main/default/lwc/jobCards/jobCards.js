import { LightningElement, track } from 'lwc';
import getJobs from '@salesforce/apex/JobCardsController.getJobs';
import toggleFavoriteJob from '@salesforce/apex/JobCardsController.toggleFavoriteJob';

export default class JobCards extends LightningElement {
    @track jobsData = [];
    @track error;

    connectedCallback() {
        this.loadJobs();
    }

    loadJobs() {
        getJobs()
            .then(data => {
                this.jobsData = data;
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.jobsData = [];
            });
    }

    handleFavoriteButtonClick(event) {
        event.stopPropagation();
        event.preventDefault();
        this.handleFavoriteClick(event);
    }

    handleFavoriteClick(event) {
        const jobId = event.currentTarget.dataset.jobId;
        const isCurrentlyFavorite = event.currentTarget.dataset.isFavorite === 'true';
        const newFavoriteState = !isCurrentlyFavorite;

        this.jobsData = this.jobsData.map(job => {
            if (job.Id === jobId) {
                return { ...job, IsFavorite: newFavoriteState };
            }
            return job;
        });

        toggleFavoriteJob({ jobId, isFavorite: newFavoriteState })
            .then(result => {
                if (!result) {
                    this.loadJobs();
                }
            })
            .catch(error => {
                this.loadJobs();
            });
    }

    get jobWithUrls() {
        return this.jobsData.map(job => {
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
        return `${year}年${month}月${day}日`;
    }
}