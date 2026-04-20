import { LightningElement, wire } from 'lwc';
import getOffers from '@salesforce/apex/OfferComponentController.getOffers';

/**
 * 特別オファーを表示するコンポーネント
 */
export default class OfferComponent extends LightningElement {
    // オファー求人の配列（表示用）
    jobInfos = [];
    // 総オファー件数
    totalCount = 0;

    // Apex からオファーデータを取得
    @wire(getOffers)
    wiredOffers({ error, data }) {
        if (data) {
            // データを加工：リンク生成、閲覧状態のラベル/クラスを追加
            this.jobInfos = data.jobInfos.map(job => ({
                ...job,
                jobLink: `/portal/job/${job.jobId}`,
                viewStatus: job.lastViewedDate == null ? 'new' : 'viewed',
                viewStatusLabel: job.lastViewedDate == null ? 'NEW' : '閲覧済',
                viewStatusClass: job.lastViewedDate == null ? 'view-status-new' : 'view-status-viewed',
            }));
            this.totalCount = data.totalCount;
        } else if (error) {
            console.error('データの取得に失敗しました:', error);
        }
    }
    // オファーが1件以上ある場合にセクション全体を表示
    get hasOffers() {return this.totalCount > 0;}
    // バッジ（件数表示）を表示するか
    get showBadge() {return this.totalCount > 0;}
    // バッジに表示する件数
    get displayCount() {return this.totalCount;}
}