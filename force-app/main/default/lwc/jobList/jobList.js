import { LightningElement, wire, track } from 'lwc';
import getJobList from '@salesforce/apex/JobListController.getJobList';

export default class JobList extends LightningElement {
    @track jobs = [];
    @track error;

    @wire(getJobList)
    wiredJobs({ error, data }) {
        if (data) {
            this.jobs = data.map(job => ({
                ...job,
                url: `/portal/job/${job.Id}`,
                salaryRange: this.formatSalary(job.MinAnnualSalary__c, job.MaxAnnualSalary__c),
                isNew: job.LastViewedDate == null
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.jobs = [];
        }
    }

    formatSalary(min, max) {
        if (!min && !max) return '非公開';
        return `${min || 0} 〜 ${max || 0} 万円`;
    }
}