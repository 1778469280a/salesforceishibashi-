import { LightningElement, track } from 'lwc';
import saveCareers from '@salesforce/apex/CareerHistoryController.saveCareers';
import getCareerHistory from '@salesforce/apex/CareerHistoryController.getCareerHistory';

// ★ 各行のひな形となるチェックボックスのマスターデータ
const MASTER_JOB_GROUPS = [
    { key: 'sales', label: '営業系', options: [{ value: '営業(法人)', label: '営業(法人)' }, { value: '営業(個人)', label: '営業(個人)' }, { value: '代理店営業', label: '代理店営業' }, { value: '海外営業', label: '海外営業' }, { value: 'プリセールス・営業支援', label: 'プリセールス・営業支援' }, { value: 'その他営業', label: 'その他営業' }] },
    { key: 'admin', label: '管理部門/事務系', options: [{ value: '人事/総務', label: '人事/総務' }, { value: '法務/特許/知財', label: '法務/特許/知財' }, { value: '経理/財務/株式公開', label: '経理/財務/株式公開' }, { value: '広報/IR', label: '広報/IR' }, { value: '秘書/事務アシスタント/その他', label: '秘書/事務アシスタント/その他' }] },
    { key: 'exec', label: '経営幹部/企画/マーケティング系', options: [{ value: '経営管理/エグゼクティブ/事業開発', label: '経営管理/エグゼクティブ/事業開発' }, { value: 'マーケティング/広告宣伝/営業企画', label: 'マーケティング/広告宣伝/営業企画' }, { value: 'その他(専門コンサルタント)', label: 'その他(専門コンサルタント)' }, { value: '購買/物流', label: '購買/物流' }] },
    { key: 'tech_electric', label: '技術系（電気/電子/機械）', options: [{ value: '基礎研究/製品企画/その他', label: '基礎研究/製品企画/その他' }, { value: '光学設計他', label: '光学設計他' }, { value: '回路/システム設計', label: '回路/システム設計' }, { value: '機械/機構/金型設計', label: '機械/機構/金型設計' }, { value: '組み込み/制御設計', label: '組み込み/制御設計' }, { value: '生産管理/品質管理/品質保証', label: '生産管理/品質管理/品質保証' }, { value: '生産技術', label: '生産技術' }, { value: 'サービスエンジニア', label: 'サービスエンジニア' }, { value: 'セールスエンジニア/FAE', label: 'セールスエンジニア/FAE' }, { value: 'プロセスエンジニア', label: 'プロセスエンジニア' }, { value: 'その他技術職', label: 'その他技術職' }, { value: 'ワーカー（電気/電子/機械）', label: 'ワーカー（電気/電子/機械）' }] },
    { key: 'tech_arch', label: '技術系（建築/土木）', options: [{ value: '建築/土木設計', label: '建築/土木設計' }, { value: '建築/土木施工管理', label: '建築/土木施工管理' }, { value: 'その他(建築・土木)', label: 'その他(建築・土木)' }, { value: 'ワーカー（建築/土木）', label: 'ワーカー（建築/土木）' }] },
    { key: 'tech_medical', label: '技術系（メディカル/化学/食品）', options: [{ value: '医療/福祉サービス', label: '医療/福祉サービス' }, { value: '素材/化成品', label: '素材/化成品' }, { value: '医薬品/医療機器', label: '医薬品/医療機器' }, { value: '化粧品', label: '化粧品' }, { value: '食品', label: '食品' }] },
    { key: 'prof_finance', label: '専門職系（コンサルタント/金融/不動産）', options: [{ value: '金融', label: '金融' }, { value: 'コンサルタント/シンクタンク研究員', label: 'コンサルタント/シンクタンク研究員' }, { value: '不動産/プロパティマネジメント', label: '不動産/プロパティマネジメント' }] },
    { key: 'it', label: 'IT系（ソフトウェア/ネットワーク）', options: [{ value: 'システム開発(Web/オープン系)', label: 'システム開発(Web/オープン系)' }, { value: 'システム開発(汎用機系)', label: 'システム開発(汎用機系)' }, { value: 'システム開発(組み込み/制御系)', label: 'システム開発(組み込み/制御系)' }, { value: 'プロジェクトマネージャー', label: 'プロジェクトマネージャー' }, { value: '研究開発/その他', label: '研究開発/その他' }, { value: 'データベースエンジニア', label: 'データベースエンジニア' }, { value: '通信インフラ/ネットワーク', label: '通信インフラ/ネットワーク' }, { value: '社内情報システム', label: '社内情報システム' }, { value: 'テクニカルサポート', label: 'テクニカルサポート' }, { value: 'コンサルティング・プリセールス（IT・ネットワーク）', label: 'コンサルティング・プリセールス（IT・ネットワーク）' }] },
    { key: 'web', label: 'Web/クリエイティブ系', options: [{ value: 'Webプロデューサー/ディレクター', label: 'Webプロデューサー/ディレクター' }, { value: 'Webデザイナー/Webマスター', label: 'Webデザイナー/Webマスター' }, { value: 'Web編集/コンテンツ企画', label: 'Web編集/コンテンツ企画' }, { value: '広告/メディア/ゲーム/その他', label: '広告/メディア/ゲーム/その他' }, { value: '工業デザイン', label: '工業デザイン' }] },
    { key: 'service', label: 'サービス系（人材/小売/フードetc）', options: [{ value: '店舗設計/内装', label: '店舗設計/内装' }, { value: 'MD/バイヤー', label: 'MD/バイヤー' }, { value: '店舗開発/FC開発', label: '店舗開発/FC開発' }, { value: 'スーパーバイザー/その他サービス', label: 'スーパーバイザー/その他サービス' }, { value: 'コールセンタースーパーバイザー/カスタマーサポート', label: 'コールセンタースーパーバイザー/カスタマーサポート' }, { value: '人材サービス/キャリアコンサルタント', label: '人材サービス/キャリアコンサルタント' }, { value: '教育/講師/インストラクター', label: '教育/講師/インストラクター' }, { value: '店長/販売/店舗管理', label: '店長/販売/店舗管理' }] }
];

export default class CareerHistory extends LightningElement {
    @track isAllEditMode = false;
    @track careerData = [];
    
    // ★ 自作トースト管理
    @track toastConfig = {
        show: false,
        message: '',
        isError: false
    };

    incomeOptions = [
        { label: '200万円以下', value: '200万円以下' },
        { label: '201万円～300万円', value: '201万円～300万円' },
        { label: '301万円～400万円', value: '301万円～400万円' },
        { label: '401万円～500万円', value: '401万円～500万円' },
        { label: '501万円～600万円', value: '501万円～600万円' },
        { label: '601万円～700万円', value: '601万円～700万円' },
        { label: '701万円～800万円', value: '701万円～800万円' },
        { label: '801万円～900万円', value: '801万円～900万円' },
        { label: '901万円～1000万円', value: '901万円～1000万円' },
        { label: '1001万円以上', value: '1001万円以上' }
    ];

    originalCareerData = [];

    // ==========================================
    // ライフサイクル・初期化処理
    // ==========================================
    async connectedCallback() {
        try {
            const result = await getCareerHistory();

            if (result && result.length === 4) {
                this.careerData = result.map(item => ({
                    ...item,
                    isEditing: false,
                    hasAnnualIncome: !!item.annualIncome,
                    startDateDisplay: this.formatDisplayDate(item.startDateInput),
                    endDateDisplay: this.formatDisplayDate(item.endDateInput),
                    selectedJobGroups: new Set(item.jobGroup ? item.jobGroup.split(';').map(s => s.trim()).filter(s => s) : []),
                    selectedJobGroupOptions: new Set(item.jobGroupOption ? item.jobGroupOption.split(';').map(s => s.trim()).filter(s => s) : []),
                    expandedGroups: new Set()
                }));
            } else {
                this.initEmptyData();
            }
        } catch (error) {
            console.error('初期データの取得に失敗しました:', error);
            this.initEmptyData();
        } finally {
            this.backupData();
        }
    }

    formatDisplayDate(dateString) {
        if (!dateString) return '';
        const [year, month] = dateString.split('-');
        return `${year}年 ${month}月`;
    }

    initEmptyData() {
        this.careerData = Array.from({ length: 4 }, (_, i) => ({
            id: String(i + 1),
            companyName: '', startDateDisplay: '', startDateInput: '',
            endDateDisplay: '', endDateInput: '', isCurrentJob: false,
            annualIncome: '', hasAnnualIncome: false, jobDescription: '', jobGroup: '', jobGroupOption: '',
            selectedJobGroups: new Set(),
            selectedJobGroupOptions: new Set(),
            expandedGroups: new Set()
        }));
    }

    // ==========================================
    // バックアップ・復元処理
    // ==========================================
    cleanDataForBackup(career) {
        const copy = { ...career };
        delete copy.selectedJobGroups;
        delete copy.selectedJobGroupOptions;
        delete copy.expandedGroups;
        delete copy.rowJobGroups;
        delete copy.rowIncomeOptions;
        delete copy.jobGroupDisplay;
        return copy;
    }

    backupData() {
        const dataToBackup = this.careerData.map(career => this.cleanDataForBackup(career));
        this.originalCareerData = JSON.parse(JSON.stringify(dataToBackup));
    }

    restoreData(targetId) {
        if (targetId) {
            this.careerData = this.careerData.map(career => {
                if (career.id === targetId) {
                    const original = this.originalCareerData.find(item => item.id === targetId);
                    return { 
                        ...original, 
                        isEditing: false,
                        selectedJobGroups: new Set(original.jobGroup ? original.jobGroup.split(';').map(s => s.trim()).filter(s => s) : []),
                        selectedJobGroupOptions: new Set(original.jobGroupOption ? original.jobGroupOption.split(';').map(s => s.trim()).filter(s => s) : []),
                        expandedGroups: new Set()
                    };
                }
                return career;
            });
        } else {
            this.careerData = this.originalCareerData.map(original => ({
                ...original,
                isEditing: false,
                selectedJobGroups: new Set(original.jobGroup ? original.jobGroup.split(';').map(s => s.trim()).filter(s => s) : []),
                selectedJobGroupOptions: new Set(original.jobGroupOption ? original.jobGroupOption.split(';').map(s => s.trim()).filter(s => s) : []),
                expandedGroups: new Set()
            }));
        }
    }

    // ==========================================
    // 経験職種（チェックボックス）の独立制御ロジック
    // ==========================================
    toggleGroup(event) {
        const careerId = event.currentTarget.dataset.id;
        const groupKey = event.currentTarget.dataset.groupKey;

        this.careerData = this.careerData.map(career => {
            if (career.id === careerId) {
                const newExpanded = new Set(career.expandedGroups);
                if (newExpanded.has(groupKey)) {
                    newExpanded.delete(groupKey);
                } else {
                    newExpanded.add(groupKey);
                }
                return { ...career, expandedGroups: newExpanded };
            }
            return career;
        });
    }

    syncGroupsAndOptions(careerId, newSelectedOptions, newExpanded) {
        this.careerData = this.careerData.map(career => {
            if (career.id === careerId) {
                const newSelectedGroups = new Set();
                
                MASTER_JOB_GROUPS.forEach(group => {
                    const hasChildSelected = group.options.some(opt => newSelectedOptions.has(opt.value));
                    if (hasChildSelected) {
                        newSelectedGroups.add(group.label); 
                    }
                });

                return { 
                    ...career, 
                    selectedJobGroups: newSelectedGroups,
                    selectedJobGroupOptions: newSelectedOptions,
                    expandedGroups: newExpanded,
                    jobGroup: Array.from(newSelectedGroups).join(';'),
                    jobGroupOption: Array.from(newSelectedOptions).join(';')
                };
            }
            return career;
        });
    }

    handleGroupSelect(event) {
        const careerId = event.target.dataset.id;
        const groupKey = event.target.dataset.groupKey;
        const checked = event.target.checked;
        const groupDef = MASTER_JOB_GROUPS.find(g => g.key === groupKey);
        if (!groupDef) return;

        const targetCareer = this.careerData.find(c => c.id === careerId);
        const newSelectedOptions = new Set(targetCareer.selectedJobGroupOptions);
        const newExpanded = new Set(targetCareer.expandedGroups);

        if (checked) {
            groupDef.options.forEach(opt => newSelectedOptions.add(opt.value));
            newExpanded.add(groupKey); 
        } else {
            groupDef.options.forEach(opt => newSelectedOptions.delete(opt.value));
        }
        
        this.syncGroupsAndOptions(careerId, newSelectedOptions, newExpanded);
    }

    handleOptionChange(event) {
        const careerId = event.target.dataset.id;
        const value = event.target.value;
        const checked = event.target.checked;

        const targetCareer = this.careerData.find(c => c.id === careerId);
        const newSelectedOptions = new Set(targetCareer.selectedJobGroupOptions);
        
        if (checked) {
            newSelectedOptions.add(value);
        } else {
            newSelectedOptions.delete(value);
        }

        this.syncGroupsAndOptions(careerId, newSelectedOptions, targetCareer.expandedGroups);
    }

    stopPropagation(event) { event.stopPropagation(); }

    // ==========================================
    // クリックイベント（全体モード）
    // ==========================================
    async handleAllEditSaveClick(event) {
        event.preventDefault();
        if (this.isAllEditMode) {
            const isSuccess = await this.saveCareerData();
            if (isSuccess) {
                this.isAllEditMode = false;
                this.careerData = this.careerData.map(career => ({ ...career, isEditing: false }));
            }
        } else {
            this.isAllEditMode = true;
            this.careerData = this.careerData.map(career => ({ ...career, isEditing: false }));
        }
    }

    handleCancel(){
        this.isAllEditMode = false;
    }

    handleAllCancelClick(event) {
        event.preventDefault();
        this.isAllEditMode = false;
        this.restoreData();
    }

    // ==========================================
    // クリックイベント（個別モード）
    // ==========================================
    handleSingleEditStart(event) {
        event.preventDefault();
        const targetId = event.currentTarget.dataset.id;
        
        this.careerData = this.careerData.map(career => {
            if (career.id === targetId) {
                return { 
                    ...career, 
                    isEditing: true,
                    selectedJobGroups: new Set(career.jobGroup ? career.jobGroup.split(';').map(s => s.trim()).filter(s => s) : []),
                    selectedJobGroupOptions: new Set(career.jobGroupOption ? career.jobGroupOption.split(';').map(s => s.trim()).filter(s => s) : [])
                };
            }
            return career; 
        });
    }

    handleSingleEditCansel(event){
        event.preventDefault();
        const targetId = event.currentTarget.dataset.id;

        this.careerData = this.careerData.map(career => {
            if (career.id === targetId) {
                return { 
                    ...career, 
                    isEditing: false
                };
            }
            return career; 
        });
    }

    async handleSingleSaveClick(event) {
        const targetId = event.target.dataset.id;
        const isSuccess = await this.saveCareerData(targetId);
        if (isSuccess) {
            this.careerData = this.careerData.map(career => {
                return career.id === targetId ? { ...career, isEditing: false } : career;
            });
        }
    }

    handleSingleCancelClick(event) {
        const targetId = event.target.dataset.id;
        this.restoreData(targetId);
    }

    // ==========================================
    // 入力イベント
    // ==========================================
    handleInputChange(event) {
        const careerId = event.target.dataset.id;
        const fieldName = event.target.dataset.field;
        const value = event.target.value;

        this.careerData = this.careerData.map(career => {
            if (career.id === careerId) {
                const newCareer = { ...career, [fieldName]: value };
                if (fieldName === 'annualIncome') {
                    newCareer.hasAnnualIncome = !!value && value.trim() !== '';
                }
                return newCareer;
            }
            return career;
        });
    }

    handleDateChange(event) {
        const careerId = event.target.dataset.id;
        const fieldName = event.target.dataset.field;
        const inputValue = event.target.value;

        this.careerData = this.careerData.map(career => {
            if (career.id === careerId) {
                const newCareer = { ...career };
                newCareer[fieldName + 'Input'] = inputValue;
                if (inputValue) {
                    const [year, month] = inputValue.split('-');
                    newCareer[fieldName + 'Display'] = `${year}年 ${month}月`;
                } else {
                    newCareer[fieldName + 'Display'] = '';
                }
                if (fieldName === 'endDate') {
                    newCareer.isCurrentJob = !inputValue;
                }
                return newCareer;
            }
            return career;
        });
    }

    // ==========================================
    // 自作トースト表示用メソッド
    // ==========================================
    displayToast(message, isError = false) {
        this.toastConfig = {
            show: true,
            message: message,
            isError: isError
        };

        setTimeout(() => {
            this.toastConfig.show = false;
        }, 3000);
    }

    // ==========================================
    // Apex通信処理（保存）
    // ==========================================
    async saveCareerData(targetId = null) {
        try {
            let pureData;
            if (targetId) {
                const targetCareer = this.careerData.find(item => item.id === targetId);
                pureData = [JSON.parse(JSON.stringify(this.cleanDataForBackup(targetCareer)))];
            } else {
                pureData = this.careerData.map(career => JSON.parse(JSON.stringify(this.cleanDataForBackup(career))));
            }

            await saveCareers({ careerList: pureData });

            this.displayToast('職務経歴を保存しました。', false);

            if (targetId) {
                const targetCareer = this.careerData.find(item => item.id === targetId);
                this.originalCareerData = this.originalCareerData.map(item => {
                    if (item.id === targetId) return JSON.parse(JSON.stringify(this.cleanDataForBackup(targetCareer)));
                    return item;
                });
            } else {
                this.backupData();
            }
            return true;
        } catch (error) {
            console.error('保存エラー:', error);
            let message = '保存中にエラーが発生しました。';
            if (error.body && error.body.message) message = error.body.message;
            
            this.displayToast(message, true);
            
            return false;
        }
    }

    // ==========================================
    // 画面描画用 Getter
    // ==========================================
    get processedCareerData() {
        return this.careerData.map((item, index) => {
            const rowIncomeOptions = this.incomeOptions.map(opt => ({
                ...opt,
                selected: opt.value === item.annualIncome 
            }));

            const rowJobGroups = MASTER_JOB_GROUPS.map(group => {
                const isExpanded = item.expandedGroups.has(group.key);
                
                const options = group.options.map(opt => ({
                    ...opt,
                    isSelected: item.selectedJobGroupOptions.has(opt.value) 
                }));

                const selectedCount = options.filter(opt => opt.isSelected).length;
                const allSelected = selectedCount > 0 && selectedCount === options.length;
                const indeterminate = selectedCount > 0 && selectedCount < options.length;

                return {
                    ...group,
                    isExpanded: isExpanded,
                    toggleIconName: isExpanded ? '−' : '+',
                    options: options,
                    allSelected: allSelected,
                    indeterminate: indeterminate
                };
            });

            let displayArr = [];
            MASTER_JOB_GROUPS.forEach(group => {
                const selectedInGroup = group.options.filter(opt => item.selectedJobGroupOptions.has(opt.value));
                if (selectedInGroup.length > 0) {
                    const childLabels = selectedInGroup.map(opt => opt.label).join('、');
                    displayArr.push(`【${group.label}】\n${childLabels}`);
                }
            });
            const jobGroupDisplay = displayArr.length > 0 ? displayArr.join('\n\n') : '未選択';

            return {
                ...item,
                isFirst: index === 0,
                isSecond: index === 1,
                isThird: index === 2,
                isFourth: index === 3,
                isFirstThree: index < 3,
                showEditFields: this.isAllEditMode || item.isEditing,
                rowIncomeOptions: rowIncomeOptions,
                rowJobGroups: rowJobGroups,
                jobGroupDisplay: jobGroupDisplay 
            };
        });
    }
}