import { LightningElement, api, wire, track } from 'lwc';
import { updateRecord } from 'lightning/uiRecordApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowNavigationNextEvent, FlowNavigationFinishEvent } from 'lightning/flowSupport';
import getInitialData from '@salesforce/apex/LinkedMultiplePicklistController.getInitialData';

export default class LinkedMultiplePicklist extends LightningElement {
    @api metadataApiName;
    @api mParentField;
    @api mChildField;
    @api objectApiName;
    @api oParentField;
    @api oChildField;
    @api oRecordId;
    @api searchPlaceholder;
    @api columnCount;
    @api availableActions = [];

    @api selectedParentValuesString = '';
    @api selectedChildValuesString = '';

    @track allMappings = [];
    @track selectedParentValues = [];
    @track selectedChildValues = [];
    @track searchTerm = '';
    @track isLoaded = false;
    @track isSaving = false;

    @wire(getInitialData, { 
        metadataName: '$metadataApiName', mParentField: '$mParentField', mChildField: '$mChildField',
        objectName: '$objectApiName', oParentField: '$oParentField', oChildField: '$oChildField',
        recordId: '$oRecordId'
    })
    wiredInit({ error, data }) {
        if (data) {
            this.allMappings = data.mappings;
            this.selectedParentValues = data.currentParentValues ? data.currentParentValues.split(';').filter(v => v) : [];
            this.selectedChildValues = data.currentChildValues ? data.currentChildValues.split(';').filter(v => v) : [];
            this.syncToFlow();
            this.isLoaded = true;
        } else if (error) {
            this.isLoaded = true;
        }
    }

    syncToFlow() {
        this.selectedParentValuesString = this.selectedParentValues.join(';');
        this.selectedChildValuesString = this.selectedChildValues.join(';');
    }

    async handleSave() {        
        if (!this.oRecordId) {
            this.showToast('エラー', 'レコードIDが見つかりません。', 'error');
            return;
        }
        this.isSaving = true;

        const fields = {
            Id: this.oRecordId,
            [this.oParentField]: this.selectedParentValues.join(';'),
            [this.oChildField]: this.selectedChildValues.join(';')
        };

        try {
            await updateRecord({ fields });
            this.showToast('成功', 'レコードを更新しました', 'success');

            // フローナビゲーション：NEXT優先、なければFINISH
            if (this.availableActions.includes('NEXT')) {
                this.dispatchEvent(new FlowNavigationNextEvent());
            } else if (this.availableActions.includes('FINISH')) {
                this.dispatchEvent(new FlowNavigationFinishEvent());
            }
        } catch (error) {
            let message = error.body?.message || '不明なエラーが発生しました';
            this.showToast('保存エラー', message, 'error');
        } finally {
            this.isSaving = false;
        }
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get filteredGroupedData() {
        if (!this.allMappings || this.allMappings.length === 0) return [];
        const map = new Map();
        this.allMappings.forEach(m => {
            if (!map.has(m.parent)) map.set(m.parent, []);
            map.get(m.parent).push(m.child);
        });

        return Array.from(map.keys()).map(parentName => {
            const isParentMatch = parentName.toLowerCase().includes(this.searchTerm);
            const children = map.get(parentName)
                .filter(c => isParentMatch || (c && c.toLowerCase().includes(this.searchTerm)))
                .map(c => ({
                    name: c,
                    selected: this.selectedChildValues.includes(c),
                    className: this.selectedChildValues.includes(c) ? 'child-item is-selected' : 'child-item'
                }));
            return {
                name: parentName,
                selected: this.selectedParentValues.includes(parentName),
                children: children
            };
        }).filter(p => p.children.length > 0);
    }

    handleSearchChange(event) {
        this.searchTerm = event.target.value.toLowerCase();
    }

    handleParentToggle(event) {
        const val = event.currentTarget.dataset.value;
        const related = this.allMappings.filter(m => m.parent === val).map(m => m.child);
        if (!this.selectedParentValues.includes(val)) {
            this.selectedParentValues = [...this.selectedParentValues, val];
            this.selectedChildValues = [...new Set([...this.selectedChildValues, ...related])];
        } else {
            this.selectedParentValues = this.selectedParentValues.filter(v => v !== val);
            this.selectedChildValues = this.selectedChildValues.filter(v => !related.includes(v));
        }
        this.syncToFlow();
    }

    handleChildToggle(event) {
        const val = event.currentTarget.dataset.value;
        const p = event.currentTarget.dataset.parent;
        if (!this.selectedChildValues.includes(val)) {
            this.selectedChildValues = [...this.selectedChildValues, val];
        } else {
            this.selectedChildValues = this.selectedChildValues.filter(v => v !== val);
        }
        const sibs = this.allMappings.filter(m => m.parent === p).map(m => m.child);
        if (sibs.every(c => this.selectedChildValues.includes(c))) {
            if (!this.selectedParentValues.includes(p)) this.selectedParentValues = [...this.selectedParentValues, p];
        } else {
            this.selectedParentValues = this.selectedParentValues.filter(v => v !== p);
        }
        this.syncToFlow();
    }

    get computedPlaceholder() { return this.searchPlaceholder || '検索'; }
    get hasData() { return this.filteredGroupedData.length > 0; }
    get columnSizeClass() {
        const size = Math.floor(12 / (parseInt(this.columnCount, 10) || 4)); 
        return `slds-col slds-size_1-of-2 slds-medium-size_${size}-of-12 slds-p-around_xx-small`;
    }
}