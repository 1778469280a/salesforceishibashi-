import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation'; 
import getNotifications from '@salesforce/apex/CustomNotificationController.getNotifications';
import markAsRead from '@salesforce/apex/CustomNotificationController.markAsRead';
import markAllAsRead from '@salesforce/apex/CustomNotificationController.markAllAsRead';

export default class CustomNotificationBell extends NavigationMixin(LightningElement) {
    @track notifications = [];
    @track unreadCount = 0;
    @track isDropdownOpen = false;

    boundClickOutsideHandler;

    get hasUnread() {
        return this.unreadCount > 0;
    }

    get hasNotifications() {
        return this.notifications.length > 0;
    }

    connectedCallback() {
        // 初回ロード
        this.fetchNotifications(null);

        // 画面外クリック検知イベントの登録
        this.boundClickOutsideHandler = this.handleClickOutside.bind(this);
        document.addEventListener('click', this.boundClickOutsideHandler);
    }

    disconnectedCallback() {
        document.removeEventListener('click', this.boundClickOutsideHandler);
    }

    // コンポーネント外がクリックされたらドロップダウンを閉じる処理
    handleClickOutside(event) {
        if (this.isDropdownOpen) {
            const path = event.composedPath ? event.composedPath() : [];
            if (!path.includes(this.template.host)) {
                this.isDropdownOpen = false;
            }
        }
    }

    // ユーザーの邪魔をしない定期更新ロジック
    silentRefresh() {
        if (!this.isDropdownOpen) {
            this.fetchNotifications(null);
        }
    }

    // 通知を取得する共通処理
    fetchNotifications(beforeParam) {
        getNotifications({ before: beforeParam })
            .then(result => {
                const data = JSON.parse(result);
                
                if (!beforeParam) {
                    this.notifications = [];
                }

                const newNotifs = (data.notifications || []).map(notif => ({
                    id: notif.id,
                    title: notif.messageTitle,
                    body: notif.messageBody,
                    target: notif.target,
                    read: notif.read,
                    cssClass: notif.read ? 'notif-item read' : 'notif-item unread',
                    relativeTime: this.getRelativeTime(notif.lastModified),
                }));

                // 取得した通知を結合
                this.notifications = [...this.notifications, ...newNotifs];
                
                // 現在のリストから未読数を再集計
                this.unreadCount = this.notifications.filter(notif => !notif.read).length;
            })
            .catch(error => console.error('通知の取得に失敗しました', error));
    }

    // 「過去の通知をもっと見る」をクリックした時
    loadOlderNotifications() {
        if (this.notifications.length > 0) {
            const lastNotificationId = this.notifications[this.notifications.length - 1].id;
            this.fetchNotifications(lastNotificationId);
        }
    }

    // ベルアイコンクリック時の開閉トグル
    toggleDropdown(event) {
        event.stopPropagation();
        this.isDropdownOpen = !this.isDropdownOpen;
    }

    // 個別の通知をクリックした時の処理（画面遷移 ＆ 既読化）
    handleNotificationClick(event) {
        const notificationId = event.currentTarget.dataset.id;
        const clickedNotif = this.notifications.find(n => n.id === notificationId);

        // targetIdが存在すれば、/job/{id} へURL遷移を実行
        if (clickedNotif && clickedNotif.target) {
            try {
                this[NavigationMixin.Navigate]({
                    type: 'standard__webPage',
                    attributes: {
                        url: `/job/${clickedNotif.target}`
                    }
                });
                this.isDropdownOpen = false; // クリック後はメニューを閉じる
            } catch (e) {
                console.error('画面遷移エラー:', e);
            }
        } else {
            console.warn('通知に遷移先の target が含まれていませんでした。');
        }

        // 裏側で既読化のAPIを呼び出す
        markAsRead({ notificationId: notificationId })
            .then(() => {
                this.fetchNotifications(null); // 既読の見た目に更新
            })
            .catch(error => console.error('既読化に失敗しました', error));
    }

    // 「すべて既読にする」をクリックした時の処理
    handleMarkAllAsRead(event) {
        event.preventDefault(); 
        
        markAllAsRead()
            .then(() => {
                this.fetchNotifications(null);
            })
            .catch(error => console.error('すべて既読化に失敗しました', error));
    }

    // 日時から「○分前」などを計算
    getRelativeTime(dateString) {
        if (!dateString) return '';
        
        const date = new Date(dateString);
        const now = new Date();
        const diffMs = now - date;
        
        if (diffMs < 0) return '数秒前';
        
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffMins < 1) return '数秒前';
        if (diffMins < 60) return `${diffMins}分前`;
        if (diffHours < 24) return `${diffHours}時間前`;
        if (diffDays === 1) return '昨日';
        return `${diffDays}日前`;
    }
}