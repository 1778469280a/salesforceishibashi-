import { LightningElement, track } from 'lwc';
import doLogin from '@salesforce/apex/CustomLoginController.doLogin';
import isGuest from '@salesforce/user/isGuest';

export default class CustomLoginForm extends LightningElement {
    @track email = '';
    @track password = '';
    @track errorMessage = '';
    @track isLoading = false;

    // パスワード忘れ時の遷移先URL
    forgotPasswordUrl = '/secur/forgotpassword.jsp';

    constructor() {
        super();
        
        // ① 初回アクセス時のチェック（hrefではなくreplaceを使う）
        if (!isGuest) {
            window.location.replace('/');
        }

        // ② ブラウザの「戻る」ボタン等でキャッシュから復元された時の検知（bfcache対策）
        window.addEventListener('pageshow', (event) => {
            if (event.persisted) {
                // ★ isGuestの判定を消し、キャッシュ復元時は無条件で画面をリフレッシュする！
                // リフレッシュすることでサーバーと通信し、isGuestが正しい値(false)に更新され、①が発動します。
                window.location.reload();
            }
        });
    }

    // connectedCallback() {

    // }

    handleEmailChange(event) {
        this.email = event.target.value;
    }

    handlePasswordChange(event) {
        this.password = event.target.value;
    }

    handleLogin() {
        this.errorMessage = '';

        if (!this.email || !this.password) {
            this.errorMessage = 'メールアドレスとパスワードを入力してください。';
            return;
        }

        this.isLoading = true;

        // ★ Apexを呼び出し
        doLogin({
            email: this.email,
            password: this.password,
            startUrl: null // 特定のページに飛ばしたい場合はここにパスを指定（例: '/s/'）
        })
            .then(result => {
                if (result.startsWith('ERROR:')) {
                    // Apexからエラー文字列が返ってきた場合
                    this.errorMessage = result.replace('ERROR:', '').trim();
                    this.isLoading = false;
                } else {
                    // 成功時は、返ってきたURL（トップページ等）にリダイレクト
                    window.location.href = result;
                }
            })
            .catch(error => {
                // Apexの通信自体のエラー
                this.errorMessage = '通信エラーが発生しました。しばらく経ってから再度お試しください。';
                console.error('Login error:', error);
                this.isLoading = false;
            });
    }
}