import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getFilterOptions from '@salesforce/apex/JobSearchController.getFilterOptions';
import savePreferences from '@salesforce/apex/JobSearchController.savePreferences';
import getPreferences from '@salesforce/apex/JobSearchController.getPreferences';

export default class PreferredCriteriaSearch extends LightningElement {
    @api initialFilters;

    @track filters = {
        categories: [],
        pref1: '',
        pref2: '',
        pref3: '',
        minSalary: '',
        transfer: []
    };

    @track tempFilters = {
        categories: []
    };

    @track jobCategories = [];
    @track regionsData = []; 
    @track showJobTypeModal = false;

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

    connectedCallback() {
        // 親から条件が渡されているか、中身が実質的に存在するかを判定
        let hasActiveFilters = false;
        if (this.initialFilters) {
            hasActiveFilters = (this.initialFilters.categories && this.initialFilters.categories.length > 0) ||
                               this.initialFilters.pref1 ||
                               this.initialFilters.pref2 ||
                               this.initialFilters.pref3 ||
                               this.initialFilters.minSalary ||
                               (this.initialFilters.transfer && this.initialFilters.transfer.length > 0);
        }

        if (hasActiveFilters) {
            // 検索画面などから具体的な条件が渡された場合はそれを優先
            this.filters = {
                categories: this.initialFilters.categories || [],
                pref1: this.initialFilters.pref1 || '',
                pref2: this.initialFilters.pref2 || '',
                pref3: this.initialFilters.pref3 || '',
                minSalary: this.initialFilters.minSalary || '',
                transfer: Array.isArray(this.initialFilters.transfer) ? this.initialFilters.transfer : []
            };
            this.tempFilters = { categories: [...this.filters.categories] };
        } else {
            // 条件が空っぽ（初期表示）の場合はAccountから取得
            this.loadUserPreferences();
        }
    }

    // Accountから現在の希望条件を取得する処理
    async loadUserPreferences() {
        try {
            const data = await getPreferences();
            if (data) {
                this.filters = {
                    categories: data.categories || [],
                    pref1: data.pref1 || '',
                    pref2: data.pref2 || '',
                    pref3: data.pref3 || '',
                    minSalary: data.minSalary || '',
                    transfer: data.transfer || []
                };
                this.tempFilters = { categories: [...this.filters.categories] };
                this.updateSelectedFlags();
            }
        } catch (error) {
            console.error('希望条件の取得エラー:', error);
        }
    }

    @wire(getFilterOptions)
    wiredFilterOptions({ error, data }) {
        if (data) {
            this.processFilterData(data);
            this.updateSelectedFlags();
        } else if (error) {
            console.error('オプション取得エラー:', error);
        }
    }

    processFilterData(data) {
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

    getRegionLabel(prefName) {
        if (!prefName) return '';
        const region = this.REGION_MAPPINGS.find(r => r.values.includes(prefName));
        if (region && region.label === 'その他') {
            return '';
        }
        return region ? region.label : '';
    }

    get isTransferNo() { return this.filters.transfer.includes('不可'); }
    get isTransferSingle() { return this.filters.transfer.includes('可（単身）'); }
    get isTransferFamily() { return this.filters.transfer.includes('可（家族同伴）'); }
    get isTransferConditional() { return this.filters.transfer.includes('条件付き可'); }

    handleTransferChange(event) {
        const { value, checked } = event.target;
        let transfer = [...this.filters.transfer];
        if (checked) transfer.push(value);
        else transfer = transfer.filter(item => item !== value);
        this.filters = { ...this.filters, transfer };
    }

    handleSelectLocationChange(event) {
        this.filters = { ...this.filters, [event.target.name]: event.target.value };
    }

    handleSelectChange(event) {
        if (event.target.dataset.type === 'salary') {
            this.filters = { ...this.filters, minSalary: event.target.value };
        }
    }

    async handleRegister() {
        const payload = {
            ...this.filters,
            pref1Category: this.getRegionLabel(this.filters.pref1),
            pref2Category: this.getRegionLabel(this.filters.pref2),
            pref3Category: this.getRegionLabel(this.filters.pref3)
        };

        try {
            await savePreferences({ filters: payload });
            
            this.dispatchEvent(new ShowToastEvent({
                title: '完了',
                message: '希望条件を登録しました',
                variant: 'success'
            }));

            // ★【追加】親コンポーネント（一覧画面）に最新の条件を渡し、親の currentFilters を更新させる
            this.dispatchEvent(new CustomEvent('search', { detail: this.filters }));

            this.dispatchEvent(new CustomEvent('searchcompleted'));

        } catch (error) {
            console.error('登録エラー:', error);
            this.dispatchEvent(new ShowToastEvent({
                title: 'エラー',
                message: error.body ? error.body.message : error.message,
                variant: 'error'
            }));
        }
    }

    handleJobTypeClick() {
        this.showJobTypeModal = true;
        this.tempFilters.categories = [...this.filters.categories];
        this.updateSelectedFlags(true);
    }

    closeJobTypeModal() { this.showJobTypeModal = false; }
    
    handleJobTypeSubmit() {
        this.filters = { ...this.filters, categories: [...this.tempFilters.categories] };
        this.showJobTypeModal = false;
    }

    handleCheckboxChange(event) {
        const { value, checked } = event.target;
        if (checked) this.tempFilters.categories = [...new Set([...this.tempFilters.categories, value])];
        else this.tempFilters.categories = this.tempFilters.categories.filter(i => i !== value);
        this.updateSelectedFlags(true);
    }

    updateSelectedFlags(useTemp = false) {
        const target = useTemp ? this.tempFilters : this.filters;
        this.jobCategories = this.jobCategories.map(c => ({ ...c, isSelected: target.categories.includes(c.value) }));
    }

    get selectedJobCategories() {
        return this.jobCategories.filter(c => this.filters.categories.includes(c.value)).map(c => c.label);
    }

    get jobTypeSelectedText() { return this.filters.categories.length > 0 ? `${this.filters.categories.length}件選択中` : '選択する'; }

    // 画面がレンダリングされるたびに、確実に入力値をDOM（select等）と同期する
    renderedCallback() {
        this.updateSalarySelect();
        this.updateLocationSelects();
    }

    updateLocationSelects() {
        this.template.querySelectorAll('.location-select').forEach(s => { 
            if (s.value !== (this.filters[s.name] || '')) {
                s.value = this.filters[s.name] || ''; 
            }
        });
    }

    updateSalarySelect() {
        const s = this.template.querySelector('.salary-select');
        if (s && s.value !== (this.filters.minSalary || '')) {
            s.value = this.filters.minSalary || '';
        }
    }

    handleReset() {
        this.filters = { categories: [], pref1: '', pref2: '', pref3: '', minSalary: '', transfer: [] };
        this.updateSelectedFlags();
        this.updateSalarySelect();
        this.updateLocationSelects();
    }

    stopPropagation(event) { event.stopPropagation(); }
    handleModalOutsideClick() { this.closeJobTypeModal(); }
    handleJobTypeReset() { this.tempFilters.categories = []; this.updateSelectedFlags(true); }
}