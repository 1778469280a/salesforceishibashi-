import { LightningElement, track } from 'lwc';
import getPreferences from '@salesforce/apex/JobSearchController.getPreferences';

export default class PreferredCriteriaCard extends LightningElement {
    @track preferredCriteria = {};


    connectedCallback() {
        this.loadPreferences();
    }

    async loadPreferences() {
        this.isLoading = true;
        try {
            const result = await getPreferences();
            if (result) {
                this.preferredCriteria = {
                    categories: result.categories || [],
                    pref1: result.pref1 || '',
                    pref2: result.pref2 || '',
                    pref3: result.pref3 || '',
                    minSalary: result.minSalary || '',
                    transfer: result.transfer || [],
                    page: 1
                };
            }
        } catch (e) {
            console.error('設定取得エラー:', e);
        }
    }
}