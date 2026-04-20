import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
// インポートするApexメソッド名を変更
import getSelectionProcesses from '@salesforce/apex/UserProfileHeaderController.getSelectionProcesses';

export default class UserProfileHeader extends NavigationMixin(LightningElement) {
    userId = USER_ID;
    userName;

    // 各ステータスの件数（初期値0）
    inquiryCount = 0;
    applyingCount = 0;
    interviewCount = 0;
    offerCount = 0;

    // ログインユーザーのレコード情報を取得
    @wire(getRecord, { recordId: '$userId', fields: [NAME_FIELD] })
    wiredUser({ error, data }) {
        if (data) {
            this.userName = getFieldValue(data, NAME_FIELD);
        } else if (error) {
            console.error('ユーザー情報の取得に失敗しました', error);
            this.userName = 'ゲスト';
        }
    }

    // Apexから応募状況のレコード一覧を取得し、JS側で集計
    @wire(getSelectionProcesses)
    wiredProcesses({ error, data }) {
        if (data) {
            // カウントを初期化（再レンダリング時の蓄積防止）
            this.inquiryCount = 0;
            this.applyingCount = 0;
            this.interviewCount = 0;
            this.offerCount = 0;

            // レコードを1件ずつループして集計
            data.forEach(record => {
                const status = record.LatestProcessStatus__c;

                if (status === '求人詳細問合せ') {
                    this.inquiryCount++;//問合せ中
                } else if (status === '応募承諾' || status === '書類推薦') {
                    this.applyingCount++;//応募中
                } else if (status === '面接（一次）' || status === '面接（二次）' || status === '面接（三次）' || status === '面接（最終）') {
                    this.interviewCount++;//面接
                } else if (status === '内定' || status === '入社') {
                    this.offerCount++;//内定
                }
            });
        } else if (error) {
            console.error('応募状況の取得に失敗しました', error);
        }
    }

    // --- 以下、0件ならグレー、1件以上ならプライマリー色にするためのCSSクラス制御 ---

    get inquiryNumClass() { return this.inquiryCount > 0 ? 'status-number text-primary' : 'status-number text-gray'; }
    get inquiryTextClass() { return this.inquiryCount > 0 ? 'status-text text-primary' : 'status-text text-gray'; }

    get applyingNumClass() { return this.applyingCount > 0 ? 'status-number text-primary' : 'status-number text-gray'; }
    get applyingTextClass() { return this.applyingCount > 0 ? 'status-text text-primary' : 'status-text text-gray'; }

    get interviewNumClass() { return this.interviewCount > 0 ? 'status-number text-primary' : 'status-number text-gray'; }
    get interviewTextClass() { return this.interviewCount > 0 ? 'status-text text-primary' : 'status-text text-gray'; }

    get offerNumClass() { return this.offerCount > 0 ? 'status-number text-primary' : 'status-number text-gray'; }
    get offerTextClass() { return this.offerCount > 0 ? 'status-text text-primary' : 'status-text text-gray'; }
}