import { LightningElement, api, wire, track } from 'lwc';
import { getRecord, updateRecord } from 'lightning/uiRecordApi';
import { getObjectInfo, getPicklistValuesByRecordType } from 'lightning/uiObjectInfoApi';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { FlowNavigationFinishEvent, FlowNavigationNextEvent } from 'lightning/flowSupport';

export default class CheckboxMultiSelect extends LightningElement {
    @api recordId;
    @api objectApiName;
    @api fieldApiName;
    @api availableActions = []; 

    @track options = [];
    selectedValues = []; 
    rawPicklistValues = []; 
    
    fieldLabel;
    fieldHelpText;
    
    isLoading = true;
    defaultRecordTypeId;

    // デバッグ用：何が届いているか確認
    connectedCallback() {
        console.log('--- LWC Initialized ---');
        console.log('recordId:', this.recordId);
        console.log('objectApiName:', this.objectApiName);
        console.log('fieldApiName:', this.fieldApiName);

        // 値が全く届いていない場合のセーフティ
        if (!this.objectApiName || !this.fieldApiName) {
            console.warn('Required parameters (objectApiName or fieldApiName) are missing.');
            // 3秒待っても何も来なければロードを解除してエラーを出す
            setTimeout(() => {
                if (this.isLoading) this.isLoading = false;
            }, 3000);
        }
    }

    get fieldArray() {
        return (this.objectApiName && this.fieldApiName) ? [`${this.objectApiName}.${this.fieldApiName}`] : null;
    }

    get displayLabel() {
        return this.fieldLabel ? this.fieldLabel : this.fieldApiName;
    }

    @wire(getObjectInfo, { objectApiName: '$objectApiName' })
    wiredObjectInfo({ error, data }) {
        if (data) {
            this.defaultRecordTypeId = data.defaultRecordTypeId;
            const fieldInfo = data.fields[this.fieldApiName];
            if (fieldInfo) {
                this.fieldLabel = fieldInfo.label;
                this.fieldHelpText = fieldInfo.inlineHelpText;
            }
        } else if (error) {
            this.handleError(error);
        }
    }

    @wire(getPicklistValuesByRecordType, { 
        objectApiName: '$objectApiName', 
        recordTypeId: '$defaultRecordTypeId' 
    })
    wiredPicklist({ error, data }) {
        if (data) {
            const picklistValues = data.picklistFieldValues[this.fieldApiName];
            if (picklistValues) {
                this.rawPicklistValues = picklistValues.values;
                this.buildOptions();
            } else {
                this.isLoading = false;
            }
        } else if (error) {
            // ここでエラーが出る場合は API名が間違っている可能性が高い
            this.handleError(error);
        }
    }

    @wire(getRecord, { recordId: '$recordId', fields: '$fieldArray' })
    wiredRecord({ error, data }) {
        if (data) {
            const fieldValue = data.fields[this.fieldApiName]?.value;
            this.selectedValues = fieldValue ? fieldValue.split(';') : [];
            this.buildOptions();
        } else if (error) {
            // recordIdがない場合はここが呼ばれないか、エラーになる
            console.warn('Record data could not be fetched. Check if recordId is valid.');
            this.buildOptions(); // recordIdがなくても選択肢だけは出す
        }
    }

    buildOptions() {
        // rawPicklistValuesさえあれば、isLoadingを落として画面を出す
        if (this.rawPicklistValues && this.rawPicklistValues.length > 0) {
            this.options = this.rawPicklistValues.map(item => ({
                label: item.label,
                value: item.value,
                checked: this.selectedValues ? this.selectedValues.includes(item.value) : false
            }));
            this.isLoading = false;
        }
    }

    // ... (以下、handleCheckboxChange, handleSave, handleFlowExit, handleError は変更なし)
    handleCheckboxChange(event) {
        const isChecked = event.target.checked;
        const clickedValue = event.target.value;
        if (isChecked) {
            if (!this.selectedValues.includes(clickedValue)) {
                this.selectedValues = [...this.selectedValues, clickedValue];
            }
        } else {
            this.selectedValues = this.selectedValues.filter(val => val !== clickedValue);
        }
        this.buildOptions();
    }

    async handleSave() {
        this.isLoading = true;
        const fields = {};
        fields['Id'] = this.recordId;
        fields[this.fieldApiName] = this.selectedValues.join(';');
        try {
            await updateRecord({ fields });
            this.dispatchEvent(new ShowToastEvent({ title: '成功', message: '保存しました。', variant: 'success' }));
            this.handleFlowExit();
        } catch (error) {
            this.handleError(error);
            this.isLoading = false;
        }
    }

    handleFlowExit() {
        if (this.availableActions.find(action => action === 'FINISH')) {
            this.dispatchEvent(new FlowNavigationFinishEvent());
        } else if (this.availableActions.find(action => action === 'NEXT')) {
            this.dispatchEvent(new FlowNavigationNextEvent());
        }
    }

    handleError(error) {
        console.error('LWC Error:', error);
        const message = error.body ? error.body.message : error.message;
        this.dispatchEvent(new ShowToastEvent({ title: 'エラー', message: message, variant: 'error' }));
        this.isLoading = false;
    }
}