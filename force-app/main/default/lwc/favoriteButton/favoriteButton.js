import { LightningElement, track } from 'lwc';

export default class FavoriteButton extends LightningElement {
    @track isShowModal = false;
    SESSION_KEY = 'hasClosedNotification';

    connectedCallback() {
        // セッションストレージを確認
        const isClosed = sessionStorage.getItem('hasClosedNotification');
        
        // まだ閉じていなければ表示（テスト用にDB判定はスキップ）
        if (!isClosed) {
            this.isShowModal = true;
        }
    }

    handleClose() {
        // sessionStorageにフラグを保存（ブラウザのタブを閉じるまで保持）
        sessionStorage.setItem('hasClosedNotification', 'true');
        this.isShowModal = false;
        
        // 本番実装時はここでApexを呼び出し、DB側の既読フラグも更新する
    }
}