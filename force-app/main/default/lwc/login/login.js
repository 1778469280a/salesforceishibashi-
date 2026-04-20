import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import checkAndSendEmail from '@salesforce/apex/RegistrationController.checkAndSendEmail';

/**
 * 会員登録（メールアドレス入力）コンポーネント
 * メールアドレスを受け取り、サーバー側で登録チェック＆確認メール送信を行う
 */
export default class Login extends NavigationMixin(LightningElement) {
    // 入力されたメールアドレス
    @track email = '';
    // エラーメッセージ（バリデーションまたはサーバーエラー）
    @track errorMessage = '';

    /**
     * メールアドレス入力欄の変更イベント
     * @param {Event} event
     */
    handleEmailChange(event) {
        this.email = event.target.value;
        this.errorMessage = ''; // 入力を変更したら古いエラーを消す
    }

    /**
     * 登録ボタンのクリックハンドラ
     * バリデーション後、Apexを呼び出してメール送信を依頼する
     */
    handleRegister() {
        const emailInput = this.template.querySelector('input[type=email]');
        // ブラウザ標準のバリデーション（required, patternなど）を実行
        if (!emailInput.checkValidity()) {
            emailInput.reportValidity();
            return;
        }
        this.errorMessage = ''; // 送信前にエラーをクリア

        // Apex呼び出し
        checkAndSendEmail({ email: this.email })
            .then(result => {
                console.log(JSON.stringify(result)); // デバッグ用（運用時は削除可）
                if (result.type === 'Error') {
                    // サーバー側でエラー（既存ユーザーなど）
                    this.errorMessage = result.message;
                } else {
                    // 成功：セッションにタイプを保存し、確認メール送信完了画面へ遷移
                    sessionStorage.setItem('type', result.type);
                    this[NavigationMixin.Navigate]({
                        type: 'standard__webPage',
                        attributes: { url: '/sendmail' }
                    });
                }
            })
            .catch(error => {
                // 通信エラーなど
                this.errorMessage = '通信エラーが発生しました。';
                console.error(error);
            });
    }
}