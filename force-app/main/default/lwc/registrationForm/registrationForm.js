import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import saveRegistration from '@salesforce/apex/RegistrationFormController.saveRegistration';

/**
 * 会員登録フォーム（ステップ入力）のメインコンポーネント
 * 複数の子ステップコンポーネントを管理し、ステップの切り替え、バリデーション、
 * データの一時保存、最終送信を行います。
 */
export default class RegistrationForm extends LightningElement {
    // 現在のステップ番号（1～totalSteps）
    currentStepNumber = 1;
    // 総ステップ数（通常6だが、就業経験なしの場合は5に変更される）
    totalSteps = 6;
    // 登録完了フラグ（trueで完了画面を表示）
    isComplete = false;
    // 各ステップのバリデーション状態（index: 0～5）
    @track stepValidities = [false, false, false, false, false, false];
    // URLパラメータから取得したメールアドレス
    @track emailFromUrl = '';
    // エラーメッセージ（登録失敗時など）
    @track errorMessage = '';

    /**
     * 現在のページ参照（URLのstate）を取得するWire
     * メールアドレスをURLから受け取る
     * @param {Object} pageRef
     */
    @wire(CurrentPageReference)
    getPageReference(pageRef) {
        if (pageRef && pageRef.state && pageRef.state.email) {
            this.emailFromUrl = pageRef.state.email;
        }
    }

    // ---- 表示用ゲッター ----
    // 現在ステップ（2桁ゼロ埋め）
    get currentStepDisplay() {
        return this.currentStepNumber.toString().padStart(2, '0');
    }
    // 総ステップ数（2桁ゼロ埋め）
    get totalStepsDisplay() {
        return this.totalSteps.toString().padStart(2, '0');
    }
    // プログレスバーの幅（パーセント）
    get progressStyle() {
        if (this.isComplete) return 'width: 0%;';
        const percentage = (this.currentStepNumber / this.totalSteps) * 100;
        return `width: ${percentage}%;`;
    }
    // 各ステップの表示判定
    get isStep1() { return this.currentStepNumber === 1; }
    get isStep2() { return this.currentStepNumber === 2; }
    get isStep3() { return this.currentStepNumber === 3; }
    get isStep4() { return this.currentStepNumber === 4; }
    get isStep5() { return this.currentStepNumber === 5; }
    get isStep6() { return this.currentStepNumber === 6; }
    // 最終ステップか
    get isLastStep() {
        return this.currentStepNumber === this.totalSteps;
    }
    // 次へボタンが無効か（現在のステップが未入力ならtrue）
    get isNextDisabled() {
        return !this.stepValidities[this.currentStepNumber - 1];
    }
    // 各ステップの表示スタイル（block/none）
    get step1Style() { return `display: ${this.isStep1 ? 'block' : 'none'};`; }
    get step2Style() { return `display: ${this.isStep2 ? 'block' : 'none'};`; }
    get step3Style() { return `display: ${this.isStep3 ? 'block' : 'none'};`; }
    get step4Style() { return `display: ${this.isStep4 ? 'block' : 'none'};`; }
    get step5Style() { return `display: ${this.isStep5 ? 'block' : 'none'};`; }
    get step6Style() { return `display: ${this.isStep6 ? 'block' : 'none'};`; }

    // ---- セッション保存・復元 ----
    /**
     * 現在のステップ番号と総ステップ数をsessionStorageに保存
     */
    saveState() {
        sessionStorage.setItem('registrationStep', JSON.stringify({
            step: this.currentStepNumber,
            total: this.totalSteps
        }));
    }

    /**
     * sessionStorageからステップ情報を復元する
     */
    restoreState() {
        const saved = sessionStorage.getItem('registrationStep');
        if (saved) {
            try {
                const { step, total } = JSON.parse(saved);
                if (total >= 1 && total <= 6 && step >= 1 && step <= total) {
                    this.totalSteps = total;
                    this.currentStepNumber = step;
                    if (total === 5) {
                        this.stepValidities = this.stepValidities.slice(0, 5);
                    } else if (total === 6 && this.stepValidities.length < 6) {
                        this.stepValidities = [...this.stepValidities, false];
                    }
                }
            } catch (e) {
                console.error('復旧手順が失敗しました', e);
            }
        }
    }

    /**
     * 全ステップの子コンポーネントからデータを収集しsessionStorageに保存
     */
    saveFormData() {
        const steps = [
            this.template.querySelector('c-step-1-personal-info'),
            this.template.querySelector('c-step-2-desired-conditions'),
            this.template.querySelector('c-step-3-desired-job-categories'),
            this.template.querySelector('c-step-4-education'),
            this.template.querySelector('c-step-5-employment-status'),
            this.template.querySelector('c-step-6-previous-job')
        ];
        const stepData = steps.map(comp => (comp ? comp.getData() : null));
        const storageData = {
            totalSteps: this.totalSteps,
            currentStep: this.currentStepNumber,
            stepData: stepData,
            version: '1.0'
        };
        sessionStorage.setItem('registrationFormData', JSON.stringify(storageData));
    }

    /**
     * sessionStorageからフォームデータを復元し、各子コンポーネントに設定する
     */
    restoreFormData() {
        const raw = sessionStorage.getItem('registrationFormData');
        if (!raw) return;
        try {
            const saved = JSON.parse(raw);
            if (saved.version !== '1.0') return;
            this.totalSteps = saved.totalSteps;
            this.currentStepNumber = saved.currentStep;
            if (this.totalSteps === 5 && this.stepValidities.length > 5) {
                this.stepValidities = this.stepValidities.slice(0, 5);
            } else if (this.totalSteps === 6 && this.stepValidities.length < 6) {
                this.stepValidities = [...this.stepValidities, false];
            }
            // 子コンポーネントの読み込み完了を待つため遅延実行
            setTimeout(() => {
                const steps = [
                    this.template.querySelector('c-step-1-personal-info'),
                    this.template.querySelector('c-step-2-desired-conditions'),
                    this.template.querySelector('c-step-3-desired-job-categories'),
                    this.template.querySelector('c-step-4-education'),
                    this.template.querySelector('c-step-5-employment-status'),
                    this.template.querySelector('c-step-6-previous-job')
                ];
                saved.stepData.forEach((data, idx) => {
                    if (steps[idx] && data) {
                        steps[idx].setFormData(data);
                    }
                });
                // 復元後に各ステップのバリデーションを再実行
                steps.forEach((comp, idx) => {
                    if (comp && comp.checkValidity) {
                        comp.checkValidity();
                    }
                });
            }, 100);
        } catch (e) {
            console.error('フォームデータの復元に失敗しました', e);
        }
    }

    // ---- ライフサイクル ----
    connectedCallback() {
        this.restoreState();
        this.restoreFormData();
        if (this.totalSteps === 5 && this.stepValidities.length > 5) {
            this.stepValidities = this.stepValidities.slice(0, 5);
        } else if (this.totalSteps === 6 && this.stepValidities.length < 6) {
            this.stepValidities = [...this.stepValidities, false];
        }
    }

    // ---- イベントハンドラ ----
    /**
     * 子ステップからのバリデーション変更イベントを受信
     * @param {CustomEvent} event - detail.isValid を含む
     */
    handleStepValidityChange(event) {
        const step = parseInt(event.target.dataset.step, 10);
        const isValid = event.detail.isValid;
        if (step >= 1 && step <= this.totalSteps) {
            this.stepValidities[step - 1] = isValid;
        }
        this.saveFormData();
    }

    /**
     * 子ステップ（step5）からの総ステップ数変更イベントを受信
     * 就業経験なしの場合は総ステップ数を5に変更
     * @param {CustomEvent} event - detail.totalSteps を含む
     */
    handleTotalStepsChange(event) {
        const newTotal = event.detail.totalSteps;
        if (newTotal === this.totalSteps) return;
        this.totalSteps = newTotal;
        if (newTotal === 5) {
            this.stepValidities = this.stepValidities.slice(0, 5);
        } else if (newTotal === 6) {
            this.stepValidities = [...this.stepValidities, false];
        }
        if (this.currentStepNumber > this.totalSteps) {
            this.currentStepNumber = this.totalSteps;
        }
        this.saveState();
        this.saveFormData();
    }

    /**
     * 「次へ」ボタンのクリックハンドラ
     * 最終ステップの場合は登録処理を実行、それ以外は次のステップへ進む
     */
    async handleNext() {
        if (this.isLastStep) {
            // 最終ステップ：各子コンポーネントからデータを収集
            const step1Comp = this.template.querySelector('c-step-1-personal-info');
            const step2Comp = this.template.querySelector('c-step-2-desired-conditions');
            const step3Comp = this.template.querySelector('c-step-3-desired-job-categories');
            const step4Comp = this.template.querySelector('c-step-4-education');
            const step5Comp = this.template.querySelector('c-step-5-employment-status');
            const step6Comp = this.totalSteps === 6 ? this.template.querySelector('c-step-6-previous-job') : null;
            let step1Data, step2Data, step3Data, step4Data, step5Data, step6Data;
            try {
                step1Data = step1Comp?.getData();
                step2Data = step2Comp?.getData();
                step3Data = step3Comp?.getData();
                step4Data = step4Comp?.getData();
                step5Data = step5Comp?.getData();
                step6Data = step6Comp?.getData();
            } catch (error) {
                this.errorMessage = 'データの取得に失敗しました。';
                return;
            }
            // 全データをマージし、メールアドレスを追加
            const accountData = {
                ...step1Data,
                ...step2Data,
                ...step3Data,
                ...step4Data,
                ...step5Data,
                ...step6Data,
                email: this.emailFromUrl
            };
            try {
                const result = await saveRegistration({ accountData });
                this.isComplete = true;
                // 登録完了後はセッションストレージをクリア
                sessionStorage.removeItem('registrationFormData');
                sessionStorage.removeItem('registrationStep');
            } catch (error) {
                let errorMsg = '登録に失敗しました。';
                if (error.body && error.body.message) {
                    errorMsg = error.body.message;
                } else if (error.message) {
                    errorMsg = error.message;
                }
                this.errorMessage = errorMsg;
            }
        } else {
            // 次のステップへ
            this.currentStepNumber++;
            this.saveState();
            this.saveFormData();
        }
        // 画面をトップへスクロール
        window.scrollTo({ top: 0, behavior: 'smooth' });
    }
}