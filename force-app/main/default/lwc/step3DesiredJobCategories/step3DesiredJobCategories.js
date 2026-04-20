import { LightningElement, track, api } from 'lwc';
import getPicklistOptions from '@salesforce/apex/PicklistController.getPicklistOptions';

/**
 * ステップ3：希望職種・年収・転勤可否入力コンポーネント
 * 希望年収、転勤可否、希望職種（複数選択可）を入力する
 */
export default class Step3DesiredJobCategories extends LightningElement {
    // 選択された希望年収
    @track selectedSalary = '';
    // 年収の選択肢（Picklistから取得）
    @track salaryOptions = [];
    // 年収オプション読み込み中フラグ
    @track isSalaryLoading = true;

    // 転勤可否の選択値（不可 / 可（单身） / 可（家族同伴） / 条件付き可）
    @track transfer = '';

    // 希望職種のカテゴリ一覧（チェックボックス）
    @track jobCategories = [];
    // 職種オプション読み込み中フラグ
    @track isJobLoading = true;
    // 選択された職種の値のSet（valueを保持）
    @track selectedCategories = new Set();

    // ---- ライフサイクル ----
    connectedCallback() {
        this.loadSalaryOptions();  // 年収のPicklistを読み込み
        this.loadJobOptions();     // 職種のPicklistを読み込み
        this.checkValidity();      // 初期バリデーション
    }

    /**
     * 希望年収のPicklistオプションを非同期で読み込む
     */
    async loadSalaryOptions() {
        try {
            const options = await getPicklistOptions({
                objectName: 'Account',
                fieldName: 'PreferredSalary__c'
            });
            this.salaryOptions = options;
        } catch (error) {
            this.salaryOptions = [];
        } finally {
            this.isSalaryLoading = false;
            this.tryApplyPendingData(); // 保留データがあれば反映
            this.checkValidity();
        }
    }

    /**
     * 希望職種のPicklistオプションを非同期で読み込む
     */
    async loadJobOptions() {
        try {
            const options = await getPicklistOptions({
                objectName: 'Account',
                fieldName: 'CandidateSelectedOccupation__c'
            });
            if (options && options.length > 0) {
                this.jobCategories = options.map(opt => ({
                    value: opt.value,
                    label: opt.label,
                    isSelected: this.selectedCategories.has(opt.value)
                }));
            }
        } catch (error) {
            console.error('職種オプションの読み込みに失敗しました', error);
        } finally {
            this.isJobLoading = false;
            this.tryApplyPendingData(); // 保留データがあれば反映
            this.checkValidity();
        }
    }

    /**
     * 両方のPicklist読み込み完了後に保留データを適用する
     */
    tryApplyPendingData() {
        if (!this._pendingData) return;
        if (!this.isSalaryLoading && !this.isJobLoading) {
            const data = this._pendingData;
            this._pendingData = null;
            this.applySetData(data);
        }
    }

    /**
     * 保留されていたデータを実際に反映する（setFormDataの遅延適用）
     * @param {Object} data - 設定するデータ
     */
    applySetData(data) {
        if (data.selectedSalary !== undefined) this.selectedSalary = data.selectedSalary;
        if (data.transfer !== undefined) this.transfer = data.transfer;
        if (data.selectedCategories) {
            const categoryArray = data.selectedCategories.split(';').filter(c => c);
            this.selectedCategories = new Set(categoryArray);
            this.jobCategories = this.jobCategories.map(cat => ({
                ...cat,
                isSelected: this.selectedCategories.has(cat.value)
            }));
        }
        this.checkValidity();
    }

    // ---- 入力イベントハンドラ ----
    /**
     * 年収セレクトボックス変更時のハンドラ
     * @param {Event} event
     */
    handleSalaryChange(event) {
        this.selectedSalary = event.target.value;
        this.checkValidity();
    }

    /**
     * 転勤可否ラジオボタン変更時のハンドラ
     * @param {Event} event
     */
    handleTransferChange(event) {
        this.transfer = event.target.value;
        this.checkValidity();
    }

    // 転勤可否の各ラジオボタンのチェック状態（テンプレート用）
    get transferNone() {
        return this.transfer === '不可';
    }
    get transferSingle() {
        return this.transfer === '可（单身）';
    }
    get transferFamily() {
        return this.transfer === '可（家族同伴）';
    }
    get transferConditional() {
        return this.transfer === '条件付き可';
    }

    /**
     * 希望職種のチェックボックス変更時のハンドラ
     * @param {Event} event
     */
    handleCategoryChange(event) {
        const value = event.target.value;
        const checked = event.target.checked;
        if (checked) {
            this.selectedCategories.add(value);
        } else {
            this.selectedCategories.delete(value);
        }
        // 職種リストの選択状態を更新
        this.jobCategories = this.jobCategories.map(cat => ({
            ...cat,
            isSelected: this.selectedCategories.has(cat.value)
        }));
        this.checkValidity();
    }

    // ---- バリデーション ----
    /**
     * 必須項目が全て選択されているかチェック
     * @returns {boolean}
     */
    isValid() {
        if (!this.selectedSalary) return false;
        if (!this.transfer) return false;
        if (this.selectedCategories.size === 0) return false;
        return true;
    }

    /**
     * バリデーション結果を親コンポーネントに通知
     */
    checkValidity() {
        const valid = this.isValid();
        this.dispatchEvent(new CustomEvent('stepvaliditychange', {
            detail: { isValid: valid }
        }));
    }

    // ---- API for parent ----
    /**
     * 親コンポーネントから現在のデータを取得するためのメソッド
     * @returns {Object} 希望職種データ（選択されたラベルをセミコロン区切りで返す）
     */
    @api
    getData() {
        const selectedLabels = this.jobCategories
            .filter(cat => cat.isSelected)
            .map(cat => cat.label)
            .join(';');
        return {
            selectedSalary: this.selectedSalary,
            transfer: this.transfer,
            selectedCategories: selectedLabels
        };
    }

    /**
     * 親コンポーネントからフォームデータを復元するためのメソッド
     * 非同期読み込み中の場合、データを保留する
     * @param {Object} data - 復元するデータ
     */
    @api
    setFormData(data) {
        if (!data) return;
        this._pendingData = data;
        this.tryApplyPendingData();
    }
}