import { LightningElement, track, api } from 'lwc';

/**
 * ステップ5：就業状況入力コンポーネント
 * 経験社数と就業状況（就業中/離職中/就業経験なし）を入力する
 * 就業経験なしの場合は総ステップ数が5に変更される（親コンポーネントへ通知）
 */
export default class Step5EmploymentStatus extends LightningElement {
    // 経験社数（例：1社、2社...10社以上）
    @track companyCount = '';
    // 就業状況（就業中 / 離職中 / 就業経験なし）
    @track employmentStatus = '';

    // ---- テンプレート用ゲッター（ラジオボタンのチェック状態）----
    get statusWorking() {
        return this.employmentStatus === '就業中';
    }
    get statusSeparated() {
        return this.employmentStatus === '離職中';
    }
    get statusNoExperience() {
        return this.employmentStatus === '就業経験なし';
    }

    /**
     * 経験社数セレクトボックス変更時のハンドラ
     * @param {Event} event
     */
    handleCompanyCountChange(event) {
        this.companyCount = event.target.value;
        this.checkValidity();
        this.notifyTotalSteps();  // 就業状況によって総ステップ数が変わるため通知
    }

    /**
     * 就業状況ラジオボタン変更時のハンドラ
     * @param {Event} event
     */
    handleStatusChange(event) {
        this.employmentStatus = event.target.value;
        this.checkValidity();
        this.notifyTotalSteps();  // 就業状況によって総ステップ数が変わるため通知
    }

    /**
     * 親コンポーネント（RegistrationForm）に総ステップ数を通知する
     * 就業状況が「就業経験なし」の場合は5、それ以外は6
     */
    notifyTotalSteps() {
        const totalSteps = this.employmentStatus === '就業経験なし' ? 5 : 6;
        this.dispatchEvent(new CustomEvent('totalstepschanged', {
            detail: { totalSteps }
        }));
    }

    // ---- バリデーション ----
    /**
     * 必須項目が全て入力されているかチェック
     * @returns {boolean}
     */
    isValid() {
        if (!this.companyCount || this.companyCount.trim() === '') return false;
        if (!this.employmentStatus) return false;
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

    // ---- ライフサイクル ----
    connectedCallback() {
        this.checkValidity();
        this.notifyTotalSteps();  // 初期状態の総ステップ数を通知
    }

    // ---- API for parent ----
    /**
     * 親コンポーネントから現在のデータを取得するためのメソッド
     * @returns {Object} 就業状況データ
     */
    @api
    getData() {
        return {
            companyCount: this.companyCount,
            employmentStatus: this.employmentStatus
        };
    }

    /**
     * 親コンポーネントからフォームデータを復元するためのメソッド
     * @param {Object} data - 復元するデータ
     */
    @api
    setFormData(data) {
        if (!data) return;
        if (data.companyCount !== undefined) this.companyCount = data.companyCount;
        if (data.employmentStatus !== undefined) this.employmentStatus = data.employmentStatus;
        this.checkValidity();
        this.notifyTotalSteps();
    }
}