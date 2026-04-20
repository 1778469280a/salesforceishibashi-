import { LightningElement,wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import getRecentViewedJobs from '@salesforce/apex/RecentJobViewedController.getRecentViewedJobs';

export default class recentJobViewed extends LightningElement {

    @track jobs = [];
    @track isLoading = true;
    @track error;

    @wire(getRecentViewedJobs)
    wiredJobs(result) {
        this.isLoading = false;
        
        if (result.data) {
            this.jobs = result.data.map(job => ({
                id: job.Id,
                name: job.Name,
                position: job.JobPosition__c || 'タイトルなし',
                lastViewedDate: job.LastViewedDate,
                formattedDate: this.formatDate(job.LastViewedDate),
                url: `/portal/job/${job.Id}`
            }));
            this.error = undefined;
        } else if (result.error) {
            this.error = result.error;
            this.jobs = [];
            this.showToast('エラー', 'データの取得に失敗しました', 'error');
        }
    }

    formatDate(dateTime) {
        if (!dateTime) return '';
        const date = new Date(dateTime);
        return date.toLocaleDateString('ja-JP', {
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    }

    showToast(title, message, variant) {
        const toastEvent = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(toastEvent);
    }

    handleLinkClick(event) {
        const jobId = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/portal/job/${jobId}`
            }
        });
    }

    get hasJobs() {
        return this.jobs && this.jobs.length > 0;
    }

    get isEmpty() {
        return !this.isLoading && (!this.jobs || this.jobs.length === 0);
    }
}