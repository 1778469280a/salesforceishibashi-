// LWC および Apex コントローラから必要なモジュールをインポート
import { LightningElement, wire, track } from 'lwc';
import getProcesses from '@salesforce/apex/ProcessController.getProcesses';

// ステータスグループのスタイルに使用する色の定数
const COLOR_MAIN = '#042356';      // プライマリカラー（メイン）
const COLOR_ACCENT = '#FF5924';    // アクセントカラー（オファーなど重要ステータス）
const COLOR_GRAY = '#808080';      // 空のグループに使用するグレー
const COLOR_WHITE = '#FFFFFF';     // テキストのコントラスト用白

// ステータスグループのマッピング定義
const STATUS_MAPPINGS = [
    { label: 'オファー', key: 'offer', values: ['JOB打診', 'JOB打診（弱）', 'JOB打診【強！】'], iconName: 'person_heart' },
    { label: '問合せ中', key: 'inquiry', values: ['求人詳細問合せ'], iconName: 'outgoing_mail' },
    { label: '応募中', key: 'apply', values: ['応募承諾', '応募承諾（書類待ち）', '書類推薦'], iconName: 'mark_email_read' },
    { label: '面接', key: 'interview', values: ['面接（一次）', '面接（二次）', '面接（三次）', '面接（最終）', '書類OK'], iconName: 'communication' },
    { label: '内定', key: 'offeraccepted', values: ['入社', '内定'], iconName: 'handshake' },
    { label: '辞退済み', key: 'declined', values: ['本人NG', '面接辞退', '内定辞退']},
    { label: 'お見送り', key: 'rejected', values: ['社内NG', 'JM対応用 社内NG（社名非公開）', '書類NG', '面接NG']},
    { label: '募集終了', key: 'closed', values: ['クローズ']},
];

export default class ApplicationStatus extends LightningElement {
    @track processedData = [];   // Apexから取得した加工済みデータ
    @track expandedKeys = [];    // 現在展開中のグループのキーを保持

    // Apex メソッドをワイヤーで呼び出し、データを取得
    @wire(getProcesses)
    wiredProcesses({ error, data }) {
        if (data) {
            this.processedData = data.map(record => {
                // 面接日フィールドを分割代入で取得（※Apex側でも取得するようSOQLの修正が必要です）
                const { 
                    JobPosition__r: job = {}, 
                    Id, 
                    JobPosition__c: jobId, 
                    LatestProcessStatus__c: status, 
                    LastModifiedDate,
                    First_interview_date__c,
                    Second_interview_date__c,
                    Third_interview_date__c,
                    Final_interview_date__c
                } = record;
                
                const { Company__r: company = {}, JobCategory1__c: category, WorkLocation2__c: location, JobPosition__c: position, LastViewedDate } = job;

                // 面接日表示の判定ロジック
                let showInterviewDate = false;
                let interviewDateLabel = '';
                let interviewDateValue = '';

                switch (status) {
                    case '面接（一次）':
                        showInterviewDate = true;
                        interviewDateLabel = '1次面接日：';
                        interviewDateValue = First_interview_date__c ? this.formatDateOnlyToJapanese(First_interview_date__c) : '調整中';
                        break;
                    case '面接（二次）':
                        showInterviewDate = true;
                        interviewDateLabel = '2次面接日：';
                        interviewDateValue = Second_interview_date__c ? this.formatDateOnlyToJapanese(Second_interview_date__c) : '調整中';
                        break;
                    case '面接（三次）':
                        showInterviewDate = true;
                        interviewDateLabel = '3次面接日：';
                        interviewDateValue = Third_interview_date__c ? this.formatDateOnlyToJapanese(Third_interview_date__c) : '調整中';
                        break;
                    case '面接（最終）':
                        showInterviewDate = true;
                        interviewDateLabel = '最終面接日：';
                        interviewDateValue = Final_interview_date__c ? this.formatDateOnlyToJapanese(Final_interview_date__c) : '調整中';
                        break;
                }

                return {
                    id: Id,
                    jobPositionId: jobId,
                    status,
                    JobCategory1: category,
                    companyName: company.Name || '',
                    jobUrl: jobId ? `/portal/job/${jobId}` : '#',
                    WorkLocation2: location,
                    JobPosition: position,
                    lastUpdate: this.formatDateToJapanese(LastModifiedDate),
                    viewStatusLabel: LastViewedDate == null ? 'NEW' : '閲覧済',
                    viewStatusClass: LastViewedDate == null ? 'view-status-new' : 'view-status-viewed',
                    // 新しく追加したプロパティ
                    showInterviewDate,
                    interviewDateLabel,
                    interviewDateValue
                };
            });
            // 初期状態で「オファー」グループに項目がある場合は開いておく
            const offerGroup = STATUS_MAPPINGS.find(m => m.key === 'offer');
            if (this.processedData.some(r => offerGroup.values.includes(r.status))) {
                this.expandedKeys = ['offer'];
            }
        } else if (error) {
            console.error('データの取得に失敗しました:', error);
        }
    }

    // ステータスグループのリストを生成する getter
    get statusGroups() {
        return STATUS_MAPPINGS.map(mapping => {
            const items = this.processedData.filter(r => mapping.values.includes(r.status));
            const count = items.length;
            const hasItems = count > 0;
            const isExpanded = this.expandedKeys.includes(mapping.key);
            const color = !hasItems ? COLOR_GRAY : (mapping.key === 'offer' ? COLOR_ACCENT : COLOR_MAIN);
            return {
                ...mapping,
                items,
                count,
                hasItems,
                isExpanded,
                toggleIconName: isExpanded ? 'remove' : 'add',
                toggleIconAlt: isExpanded ? '閉じる' : '開く',
                summaryStyle: `background-color: ${color}; color: ${COLOR_WHITE}; cursor: ${hasItems ? 'pointer' : 'default'};`,
                itemStyle: `border-left-color: ${color}; background-color: ${COLOR_WHITE};`,
                statusTextStyle: `color: ${color}; font-weight: bold;`,
                buttonStyle: `background-color: ${color}; color: ${COLOR_WHITE} !important;`,
                groupStyle: `--group-color: ${color};`
            };
        });
    }

    handleToggle(event) {
        const { key } = event.currentTarget.dataset;
        this.expandedKeys = this.expandedKeys.includes(key)
            ? this.expandedKeys.filter(k => k !== key)
            : [...this.expandedKeys, key];
    }

    // 更新日時用（日時まで）
    formatDateToJapanese(datetime) {
        if (!datetime) return '';
        const date = new Date(datetime);
        const year = date.getFullYear();
        const month = (date.getMonth() + 1).toString().padStart(2, '0');
        const day = date.getDate().toString().padStart(2, '0');
        const hour = date.getHours().toString().padStart(2, '0');
        const minute = date.getMinutes().toString().padStart(2, '0');
        return `${year}/${month}/${day} ${hour}:${minute}`;
    }

    // 面接日用に追加（日付のみ）
    formatDateOnlyToJapanese(dateString) {
        if (!dateString) return '';
        const date = new Date(dateString);
        const year = date.getFullYear();
        const month = (date.getMonth() + 1).toString().padStart(2, '0');
        const day = date.getDate().toString().padStart(2, '0');
        return `${year}/${month}/${day}`;
    }
}