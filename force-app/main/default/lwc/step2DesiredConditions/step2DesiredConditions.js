import { LightningElement, track, api } from 'lwc';
import getPicklistOptions from '@salesforce/apex/PicklistController.getPicklistOptions';

/**
 * ステップ2：希望条件入力コンポーネント
 * 転職希望日、希望勤務地（第1〜第3希望）を入力する
 */
export default class Step2DesiredConditions extends LightningElement {
    // 転職希望日（選択値）
    @track desiredDate = '';
    // 希望勤務地 第1〜第3希望
    @track location1 = '';
    @track location2 = '';
    @track location3 = '';

    // 勤務地の選択肢（Picklistから取得）
    @track locationOptions = [];
    // 勤務地オプション読み込み中フラグ
    @track isLocationLoading = true;

    // 転職希望日の選択肢（固定値：すぐに、3ヶ月後、半年後、1年後、未定など）
    desiredOptions = [];

    // ---- ライフサイクル ----
    connectedCallback() {
        this.initDesiredOptions();   // 転職希望日の選択肢を初期化
        this.loadLocationOptions();  // 勤務地のPicklistを読み込み
        this.checkValidity();        // 初期バリデーション
    }

    /**
     * 転職希望日の選択肢を生成する
     * 基準日は今日
     */
    initDesiredOptions() {
        const today = new Date();
        const formatDate = (date) => {
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');
            return `${year}/${month}/${day}`;
        };

        const immediateDate = formatDate(today);
        const after90Days = this.addDays(today, 90);
        const after180Days = this.addDays(today, 180);
        const after365Days = this.addDays(today, 365);

        this.desiredOptions = [
            { label: 'すぐに', value: immediateDate },
            { label: '3ヶ月後', value: formatDate(after90Days) },
            { label: '半年後', value: formatDate(after180Days) },
            { label: '1年後', value: formatDate(after365Days) },
            { label: '未定（情報取集段階）', value: '情報取集段階' },
            { label: '未定（良いところがあれば転職したい）', value: '良いところがあれば' }
        ];
    }

    /**
     * 日付に指定日数を加算した新しいDateオブジェクトを返す
     * @param {Date} date - 基準日
     * @param {number} days - 加算する日数
     * @returns {Date}
     */
    addDays(date, days) {
        const result = new Date(date);
        result.setDate(result.getDate() + days);
        return result;
    }

    /**
     * 希望勤務地のPicklistオプションを非同期で読み込む
     */
    async loadLocationOptions() {
        try {
            const options = await getPicklistOptions({
                objectName: 'Account',
                fieldName: 'PreferredWorkLocation1__c'
            });
            this.locationOptions = options;
        } catch (error) {
            console.error('勤務地オプションの読み込みに失敗しました', error);
            this.locationOptions = [];
        } finally {
            this.isLocationLoading = false;
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
        if (data.desiredDate !== undefined) this.desiredDate = data.desiredDate;
        if (data.location1 !== undefined) this.location1 = data.location1;
        if (data.location2 !== undefined) this.location2 = data.location2;
        if (data.location3 !== undefined) this.location3 = data.location3;
        this.checkValidity();
    }

    /**
     * セレクトボックス変更時のハンドラ
     * @param {Event} event
     */
    handleChange(event) {
        const field = event.target.dataset.id;
        this[field] = event.target.value;
        this.checkValidity();
    }

    /**
     * 必須項目が全て入力されているかチェック
     * @returns {boolean}
     */
    isValid() {
        return this.desiredDate && this.desiredDate.trim() !== '';
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
     * @returns {Object} 希望条件データ
     */
    @api
    getData() {
        return {
            desiredDate: this.desiredDate,
            location1: this.location1,
            location2: this.location2,
            location3: this.location3
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
        if (this.isLocationLoading) {
            // オプション読み込み中は保留
            this._pendingData = data;
        } else {
            this.applySetData(data);
        }
    }
}