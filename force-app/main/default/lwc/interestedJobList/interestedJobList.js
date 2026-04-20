import { LightningElement, track } from 'lwc';
import getInterestedJobs from '@salesforce/apex/InterestedJobController.getInterestedJobs';
import archiveSingleJob from '@salesforce/apex/InterestedJobController.archiveSingleJob';
import archiveBulkJobs from '@salesforce/apex/InterestedJobController.archiveBulkJobs';

export default class InterestedJobList extends LightningElement {
    @track jobs = [];           // 取得した気になる求人の生データ
    @track selectedJobIds = new Set();  // 削除対象として選択された求人のIDセット

    // コンポーネント初期化時にデータを読み込む
    connectedCallback() {
        this.loadJobs();
    }

    /**
     * 気になる求人一覧をサーバーから取得する
     */
    loadJobs() {
        getInterestedJobs()
            .then(data => {
                this.jobs = data;               // データを保存
                this.selectedJobIds.clear();    // 選択状態をリセット
                this.error = undefined;
            })
            .catch(error => {
                this.error = error;
                this.jobs = [];
            });
    }

    /**
     * チェックボックスの変更時ハンドラ
     * @param {Event} event - チェックボックスのchangeイベント
     */
    handleCheckboxChange(event) {
        const jobId = event.target.getAttribute('data-job-id');
        const isChecked = event.target.checked;
        if (jobId) {
            if (isChecked) {
                this.selectedJobIds.add(jobId);   // 選択セットに追加
            } else {
                this.selectedJobIds.delete(jobId); // 選択セットから削除
            }
            // リアクティビティを確保するため配列を再代入
            this.jobs = [...this.jobs];
        }
    }

    /**
     * 単一削除ボタンのクリックハンドラ
     * @param {Event} event - ボタンのクリックイベント
     */
    async handleSingleDelete(event) {
        event.stopPropagation();
        const jobId = event.currentTarget.dataset.jobId;
        if (window.confirm('この求人を削除してもよろしいですか？')) {
            archiveSingleJob({ jobId })
                .then(() => {
                    this.loadJobs();   // 削除後にリストを再読み込み
                })
                .catch(error => console.error('削除に失敗しました', error));
        }
    }

    /**
     * 一括削除ボタンのクリックハンドラ
     */
    async handleBulkDelete() {
        const jobIds = Array.from(this.selectedJobIds);
        if (jobIds.length === 0) {
            alert('削除する求人を選択してください');
            return;
        }
        if (window.confirm(`選択した ${jobIds.length} 件の求人を削除してもよろしいですか？`)) {
            archiveBulkJobs({ jobIds })
                .then(() => {
                    this.loadJobs();   // 削除後にリストを再読み込み
                })
                .catch(error => console.error('一括削除に失敗しました', error));
        }
    }

    /**
     * ヘッダー（選択件数表示＋一括削除ボタン）を表示するかどうか
     * @returns {boolean}
     */
    get showHeader() {
        return this.jobsWithMeta.length > 0 && this.selectedJobIds.size > 0;
    }

    /**
     * 画面表示用に加工した求人データの配列
     * @returns {Array} 各求人オブジェクト（Id, タイトル, 給与, 勤務地, 表示状態など）
     */
    get jobsWithMeta() {
        return this.jobs.map(job => {
            const r = job.Job__r || {};
            const lastViewed = r.LastViewedDate;
            const originalJobTitle = r.JobPosition__c || '（求人タイトルなし）';
            // タイトルを「／」で分割 → 前半をタイトル、後半をベネフィットとして扱う
            const [jobTitlePart, ...jobBenefitParts] = originalJobTitle.split('／');
            const finalJobTitle = jobTitlePart ? jobTitlePart.trim() : '（求人タイトルなし）';
            const jobBenefitPart = jobBenefitParts.join('／').trim();

            return {
                Id: job.Id,
                jobDetailUrl: `/portal/job/${job.Job__c}`,
                jobTitlePart: finalJobTitle,
                jobBenefitPart: jobBenefitPart,
                jobDescription: r.JobDescription__c || '',
                minAnnualSalary: r.MinAnnualSalary__c ?? '0',
                maxAnnualSalary: r.MaxAnnualSalary__c ?? '0',
                jobCategory: r.JobCategory1__c || '',
                workLocation: r.WorkLocation2__c || '',
                MainIndustry: r.Company__r?.MainIndustry__c || '',
                formattedLastModified: this.formatDateToJapanese(r.LastModifiedDate),
                viewStatus: lastViewed == null ? 'new' : 'viewed',        // 内部判定用
                viewStatusLabel: lastViewed == null ? 'NEW' : '閲覧済',    // 表示テキスト
                viewStatusClass: lastViewed == null ? 'view-status-new' : 'view-status-viewed', // CSSクラス
                checked: this.selectedJobIds.has(job.Id)                  // チェックボックス状態
            };
        });
    }

    /**
     * 日付を「YYYY年MM月DD日」形式の日本語表記に変換
     * @param {string} datetime - ISO日付文字列など
     * @returns {string} 整形された日付文字列
     */
    formatDateToJapanese(datetime) {
        if (!datetime) return '';
        const date = new Date(datetime);
        const year = date.getFullYear();
        const month = date.getMonth() + 1;
        const day = date.getDate();
        return `${year}年${month}月${day}日`;
    }

    handleCardClick(event){
        // aタグ（タイトル）を押した時はブラウザの標準遷移に任せるため無視
        if (event.target.tagName === 'A' || event.target.closest('a')) {
            return; 
        }
        const url = event.currentTarget.dataset.url;
        window.location.href = url;
    }
}