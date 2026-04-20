import { LightningElement, track, api } from 'lwc';
import getPicklistOptions from '@salesforce/apex/PicklistController.getPicklistOptions';

/**
 * ステップ4：学歴情報入力コンポーネント
 * 最終学歴と学校名・学部・学科を入力する
 */
export default class Step4Education extends LightningElement {
    // 選択された最終学歴（Picklist値）
    @track selectedEducation = '';
    // 学校名 / 学部 / 学科の入力内容
    @track schoolDetail = '';
    // 最終学歴の選択肢（Picklistから取得）
    @track educationOptions = [];
    // オプション読み込み中フラグ
    @track isLoading = true;

    // ---- ライフサイクル ----
    connectedCallback() {
        this.loadEducationOptions(); // Picklistを読み込み
        this.checkValidity();        // 初期バリデーション
    }

    /**
     * 最終学歴のPicklistオプションを非同期で読み込む
     */
    async loadEducationOptions() {
        try {
            const options = await getPicklistOptions({
                objectName: 'Account',
                fieldName: 'FinalEducationLevel__pc'
            });
            this.educationOptions = options;
        } catch (error) {
            this.educationOptions = [];
        } finally {
            this.isLoading = false;
            // データ読み込み前に溜まっていた保留データがあれば反映
            if (this._pendingData) {
                const data = this._pendingData;
                this._pendingData = null;
                this.applySetData(data);
            }
            this.checkValidity();
        }
    }

    /**
     * 保留されていたデータを実際に反映する（setFormDataの遅延適用）
     * @param {Object} data - 設定するデータ
     */
    applySetData(data) {
        if (data.selectedEducation !== undefined) this.selectedEducation = data.selectedEducation;
        if (data.schoolDetail !== undefined) this.schoolDetail = data.schoolDetail;
        this.checkValidity();
    }

    /**
     * 最終学歴セレクトボックス変更時のハンドラ
     * @param {Event} event
     */
    handleEducationChange(event) {
        this.selectedEducation = event.target.value;
        this.checkValidity();
    }

    /**
     * 学校名入力欄の変更ハンドラ
     * @param {Event} event
     */
    handleSchoolInput(event) {
        this.schoolDetail = event.target.value;
        this.checkValidity();
    }

    // ---- バリデーション ----
    /**
     * 必須項目が全て入力されているかチェック
     * @returns {boolean}
     */
    isValid() {
        return this.selectedEducation && this.schoolDetail && this.schoolDetail.trim() !== '';
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
     * @returns {Object} 学歴データ
     */
    @api
    getData() {
        return {
            selectedEducation: this.selectedEducation,
            schoolDetail: this.schoolDetail
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
        if (this.isLoading) {
            this._pendingData = data;
        } else {
            this.applySetData(data);
        }
    }
}