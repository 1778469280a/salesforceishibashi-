import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getAllMetadataTypes from '@salesforce/apex/CustomMetadataManagerController.getAllMetadataTypes';
import getMetadataRecordsAndColumns from '@salesforce/apex/CustomMetadataManagerController.getMetadataRecordsAndColumns';
import deployMetadata from '@salesforce/apex/CustomMetadataManagerController.deployMetadata';
import checkDeployStatus from '@salesforce/apex/CustomMetadataManagerController.checkDeployStatus';

const VIEW_LIST = 'LIST';
const VIEW_RECORD_LIST = 'RECORD';
const VIEW_UPLOAD = 'UPLOAD';
const VIEW_PREVIEW = 'PREVIEW';

// メタデータ型一覧のカラム
const LIST_COLUMNS = [
    { 
        label: 'ラベル', fieldName: 'Label',
        type: 'button', 
        typeAttributes: { label: { fieldName: 'Label' }, name: 'view_records', variant: 'base' },
        initialWidth: 300
    },
    { label: 'API参照名', fieldName: 'DeveloperName' },
    {
        type: 'button',
        typeAttributes: { label: '一括登録', name: 'direct_upload', variant: 'brand-outline', iconName: 'utility:upload' },
        initialWidth: 150
    }
];

export default class CustomMetadataManager extends LightningElement {
    
    @track viewState = VIEW_LIST;
    @track isLoading = false;
    
    // 一覧用
    @track allTypes = [];
    @track filteredData = [];
    listColumns = LIST_COLUMNS;

    // 選択中メタデータ情報
    @track selectedMetadataType = '';
    @track selectedMetadataLabel = '';

    // レコード一覧用 (動的取得)
    @track recordListData = [];
    @track recordListColumns = [];

    // アップロード/プレビュー用
    @track dataToDeploy = [];
    @track previewColumns = [];

    // モード判定Getter
    get isListMode() { return this.viewState === VIEW_LIST; }
    get isRecordListMode() { return this.viewState === VIEW_RECORD_LIST; }
    get isUploadMode() { return this.viewState === VIEW_UPLOAD; }
    get isPreviewMode() { return this.viewState === VIEW_PREVIEW; }
    
    get cardTitle() {
        if (this.isListMode) return 'カスタムメタデータ管理マネージャー';
        if (this.isRecordListMode) return 'レコード一覧';
        return 'CSV一括登録';
    }

    // --- 1. 型一覧取得 ---
    @wire(getAllMetadataTypes)
    wiredTypes({ error, data }) {
        if (data) {
            this.allTypes = data;
            this.filteredData = data;
        } else if (error) {
            this.showToast('Error', '一覧取得エラー', 'error');
        }
    }

    handleSearch(event) {
        const key = event.target.value.toLowerCase();
        this.filteredData = this.allTypes.filter(row => 
            row.Label.toLowerCase().includes(key) || 
            row.DeveloperName.toLowerCase().includes(key)
        );
    }

    // --- 2. リスト選択時のアクション ---
    handleRowAction(event) {
        const actionName = event.detail.action.name;
        const row = event.detail.row;

        this.selectedMetadataType = row.DeveloperName;
        this.selectedMetadataLabel = row.Label;

        if (actionName === 'view_records') {
            // Apexからレコードと列定義を取得して表示
            this.fetchRecords(this.selectedMetadataType);
        } else if (actionName === 'direct_upload') {
            this.viewState = VIEW_UPLOAD;
        }
    }

    // Apex呼び出し: レコード取得
    fetchRecords(metadataName) {
        this.isLoading = true;
        this.recordListData = [];
        this.recordListColumns = [];

        getMetadataRecordsAndColumns({ metadataName: metadataName })
            .then(result => {
                this.recordListColumns = result.columns;
                this.recordListData = result.data;
                this.viewState = VIEW_RECORD_LIST; // 画面切り替え
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'データ取得エラー: ' + (error.body ? error.body.message : error.message), 'error');
                this.isLoading = false;
            });
    }

    // --- 画面遷移用メソッド ---
    goBackToTypeList() {
        this.viewState = VIEW_LIST;
        this.selectedMetadataType = '';
        this.recordListData = [];
    }

    goToUploadMode() {
        this.viewState = VIEW_UPLOAD;
    }

    goBackToRecordList() {
        // アップロード画面から戻る際はデータを再取得（更新確認のため）
        if (this.selectedMetadataType) {
            this.fetchRecords(this.selectedMetadataType);
        } else {
            this.viewState = VIEW_LIST;
        }
        this.dataToDeploy = [];
    }

    // --- 3. CSV処理 ---
    handleFileUpload(event) {
        const file = event.target.files[0];
        if (file) {
            this.isLoading = true;
            const reader = new FileReader();
            reader.onload = () => {
                this.processCsv(reader.result);
                this.isLoading = false;
                this.viewState = VIEW_PREVIEW;
            };
            reader.readAsText(file);
        }
    }

    processCsv(csvContent) {
        const lines = csvContent.split(/\r\n|\n/);
        if (lines.length < 2) {
            this.showToast('Error', 'Header not found', 'error');
            this.isLoading = false;
            return;
        }
        const headers = lines[0].split(',').map(h => h.trim().replace(/^"|"$/g, ''));
        this.previewColumns = headers.map(header => ({ label: header, fieldName: header }));

        const resultData = [];

        // ★自動採番用タイムスタンプ (YYYYMMDDHHMMSS)
        const now = new Date();
        const timestamp = String(now.getFullYear()) +
                          String(now.getMonth() + 1).padStart(2, '0') +
                          String(now.getDate()).padStart(2, '0') +
                          String(now.getHours()).padStart(2, '0') +
                          String(now.getMinutes()).padStart(2, '0') +
                          String(now.getSeconds()).padStart(2, '0');

        for (let i = 1; i < lines.length; i++) {
            if (!lines[i].trim()) continue;
            const obj = {};
            const currentLine = lines[i].split(',');
            headers.forEach((header, index) => {
                let val = currentLine[index] ? currentLine[index].trim() : '';
                val = val.replace(/^"|"$/g, '');
                obj[header] = val;
            });

            // ★DeveloperNameがない場合、秒単位のタイムスタンプで自動採番
            // 例: Auto_20240205123045_001
            if (!obj.DeveloperName) {
                obj.DeveloperName = `Auto_${timestamp}_${String(i).padStart(3, '0')}`;
            }
            resultData.push(obj);
        }
        this.dataToDeploy = resultData;
    }

    handleCancelPreview() {
        this.dataToDeploy = [];
        this.viewState = VIEW_UPLOAD;
    }

    // --- 4. デプロイ処理 ---
    handleDeploy() {
        this.isLoading = true;
        const jsonRecords = JSON.stringify(this.dataToDeploy);

        deployMetadata({ metadataType: this.selectedMetadataType, jsonRecords: jsonRecords })
            .then(jobId => {
                this.pollStatus(jobId);
            })
            .catch(error => {
                this.showToast('Error', error.body ? error.body.message : error.message, 'error');
                this.isLoading = false;
            });
    }

    pollStatus(jobId) {
        const intervalId = setInterval(() => {
            checkDeployStatus({ jobId: jobId })
                .then(status => {
                    if (status === 'Succeeded') {
                        clearInterval(intervalId);
                        this.handleSuccess();
                    } else if (['Failed', 'Aborted', 'Unknown'].includes(status)) {
                        clearInterval(intervalId);
                        this.showToast('Error', 'Failed', 'error');
                        this.isLoading = false;
                    }
                })
                .catch(() => {
                    clearInterval(intervalId);
                    this.isLoading = false;
                });
        }, 2000);
    }

    handleSuccess() {
        this.isLoading = false;
        this.showToast('Success', '登録完了しました', 'success');
        this.dataToDeploy = [];
        
        // 登録が終わったらレコード一覧に戻り、最新データを再取得して表示
        this.fetchRecords(this.selectedMetadataType);
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}