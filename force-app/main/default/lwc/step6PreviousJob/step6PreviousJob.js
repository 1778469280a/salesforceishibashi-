import { LightningElement, track, api } from 'lwc';
import getPicklistOptions from '@salesforce/apex/PicklistController.getPicklistOptions';

/**
 * ステップ6：前職・経験職種入力コンポーネント
 * 直近の勤務先、勤務期間、年収、職務内容、経験職種（複数選択）を入力する
 * このステップは就業状況が「就業経験なし」の場合は非表示となる
 */
export default class Step6PreviousJob extends LightningElement {
    // ---- 直近の勤務先情報 ----
    @track companyName = '';      // 会社名
    @track startYear = '';        // 開始年
    @track startMonth = '';       // 開始月
    @track endYear = '';          // 終了年
    @track endMonth = '';         // 終了月
    @track currentSalary = '';    // 現在の年収（選択値）
    @track jobDescription = '';   // 直近の業務・職務内容

    // ---- 年収プルダウン用 ----
    @track salaryOptions = [];     // 年収の選択肢（Picklist）
    @track isSalaryLoading = true; // 年収オプション読み込み中フラグ

    @track _endTouched = false;

    // ---- 経験職種（チェックボックス階層構造） ----
    // 職種のグループ定義（固定データ）
    @track jobGroups = [
        {
            key: 'sales',
            label: '営業系',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '営業(法人)', label: '営業(法人)', isSelected: false },
                { value: '営業(個人)', label: '営業(個人)', isSelected: false },
                { value: '代理店営業', label: '代理店営業', isSelected: false },
                { value: '海外営業', label: '海外営業', isSelected: false },
                { value: 'プリセールス・営業支援', label: 'プリセールス・営業支援', isSelected: false },
                { value: 'その他営業', label: 'その他営業', isSelected: false }
            ]
        },
        {
            key: 'admin',
            label: '管理部門/事務系',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '人事/総務', label: '人事/総務', isSelected: false },
                { value: '法務/特許/知財', label: '法務/特許/知財', isSelected: false },
                { value: '経理/財務/株式公開', label: '経理/財務/株式公開', isSelected: false },
                { value: '広報/IR', label: '広報/IR', isSelected: false },
                { value: '秘書/事務アシスタント/その他', label: '秘書/事務アシスタント/その他', isSelected: false }
            ]
        },
        {
            key: 'exec',
            label: '経営幹部/企画/マーケティング系',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '経営管理/エグゼクティブ/事業開発', label: '経営管理/エグゼクティブ/事業開発', isSelected: false },
                { value: 'マーケティング/広告宣伝/営業企画', label: 'マーケティング/広告宣伝/営業企画', isSelected: false },
                { value: 'その他(専門コンサルタント)', label: 'その他(専門コンサルタント)', isSelected: false },
                { value: '購買/物流', label: '購買/物流', isSelected: false }
            ]
        },
        {
            key: 'tech_electric',
            label: '技術系（電気/電子/機械）',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '基礎研究/製品企画/その他', label: '基礎研究/製品企画/その他', isSelected: false },
                { value: '光学設計他', label: '光学設計他', isSelected: false },
                { value: '回路/システム設計', label: '回路/システム設計', isSelected: false },
                { value: '機械/機構/金型設計', label: '機械/機構/金型設計', isSelected: false },
                { value: '組み込み/制御設計', label: '組み込み/制御設計', isSelected: false },
                { value: '生産管理/品質管理/品質保証', label: '生産管理/品質管理/品質保証', isSelected: false },
                { value: '生産技術', label: '生産技術', isSelected: false },
                { value: 'サービスエンジニア', label: 'サービスエンジニア', isSelected: false },
                { value: 'セールスエンジニア/FAE', label: 'セールスエンジニア/FAE', isSelected: false },
                { value: 'プロセスエンジニア', label: 'プロセスエンジニア', isSelected: false },
                { value: 'その他技術職', label: 'その他技術職', isSelected: false },
                { value: 'ワーカー（電気/電子/機械）', label: 'ワーカー（電気/電子/機械）', isSelected: false }
            ]
        },
        {
            key: 'tech_arch',
            label: '技術系（建築/土木）',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '建築/土木設計', label: '建築/土木設計', isSelected: false },
                { value: '建築/土木施工管理', label: '建築/土木施工管理', isSelected: false },
                { value: 'その他(建築・土木)', label: 'その他(建築・土木)', isSelected: false },
                { value: 'ワーカー（建築/土木）', label: 'ワーカー（建築/土木）', isSelected: false }
            ]
        },
        {
            key: 'tech_medical',
            label: '技術系（メディカル/化学/食品）',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '医療/福祉サービス', label: '医療/福祉サービス', isSelected: false },
                { value: '素材/化成品', label: '素材/化成品', isSelected: false },
                { value: '医薬品/医療機器', label: '医薬品/医療機器', isSelected: false },
                { value: '化粧品', label: '化粧品', isSelected: false },
                { value: '食品', label: '食品', isSelected: false }
            ]
        },
        {
            key: 'prof_finance',
            label: '専門職系（コンサルタント/金融/不動産）',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '金融', label: '金融', isSelected: false },
                { value: 'コンサルタント/シンクタンク研究員', label: 'コンサルタント/シンクタンク研究員', isSelected: false },
                { value: '不動産/プロパティマネジメント', label: '不動産/プロパティマネジメント', isSelected: false }
            ]
        },
        {
            key: 'it',
            label: 'IT系（ソフトウェア/ネットワーク）',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: 'システム開発(Web/オープン系)', label: 'システム開発(Web/オープン系)', isSelected: false },
                { value: 'システム開発(汎用機系)', label: 'システム開発(汎用機系)', isSelected: false },
                { value: 'システム開発(組み込み/制御系)', label: 'システム開発(組み込み/制御系)', isSelected: false },
                { value: 'プロジェクトマネージャー', label: 'プロジェクトマネージャー', isSelected: false },
                { value: '研究開発/その他', label: '研究開発/その他', isSelected: false },
                { value: 'データベースエンジニア', label: 'データベースエンジニア', isSelected: false },
                { value: '通信インフラ/ネットワーク', label: '通信インフラ/ネットワーク', isSelected: false },
                { value: '社内情報システム', label: '社内情報システム', isSelected: false },
                { value: 'テクニカルサポート', label: 'テクニカルサポート', isSelected: false },
                { value: 'コンサルティング・プリセールス（IT・ネットワーク）', label: 'コンサルティング・プリセールス（IT・ネットワーク）', isSelected: false }
            ]
        },
        {
            key: 'web',
            label: 'Web/クリエイティブ系',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: 'Webプロデューサー/ディレクター', label: 'Webプロデューサー/ディレクター', isSelected: false },
                { value: 'Webデザイナー/Webマスター', label: 'Webデザイナー/Webマスター', isSelected: false },
                { value: 'Web編集/コンテンツ企画', label: 'Web編集/コンテンツ企画', isSelected: false },
                { value: '広告/メディア/ゲーム/その他', label: '広告/メディア/ゲーム/その他', isSelected: false },
                { value: '工業デザイン', label: '工業デザイン', isSelected: false }
            ]
        },
        {
            key: 'service',
            label: 'サービス系（人材/小売/フードetc）',
            isExpanded: false,
            toggleIconName: '+',
            allSelected: false,
            indeterminate: false,
            options: [
                { value: '店舗設計/内装', label: '店舗設計/内装', isSelected: false },
                { value: 'MD/バイヤー', label: 'MD/バイヤー', isSelected: false },
                { value: '店舗開発/FC開発', label: '店舗開発/FC開発', isSelected: false },
                { value: 'スーパーバイザー/その他サービス', label: 'スーパーバイザー/その他サービス', isSelected: false },
                { value: 'コールセンタースーパーバイザー/カスタマーサポート', label: 'コールセンタースーパーバイザー/カスタマーサポート', isSelected: false },
                { value: '人材サービス/キャリアコンサルタント', label: '人材サービス/キャリアコンサルタント', isSelected: false },
                { value: '教育/講師/インストラクター', label: '教育/講師/インストラクター', isSelected: false },
                { value: '店長/販売/店舗管理', label: '店長/販売/店舗管理', isSelected: false }
            ]
        }
    ];

    // 選択された経験職種の値（value）を保持するSet
    @track selectedExperienceOptions = new Set();

    // ---- 年月プルダウン用の選択肢生成 ----
    // 年（1900〜今年）
    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [];
        for (let y = 1900; y <= currentYear; y++) {
            years.push({ label: `${y}年`, value: y.toString() });
        }
        return years;
    }

    // 月（1〜12）
    get monthOptions() {
        return Array.from({ length: 12 }, (_, i) => {
            const month = i + 1;
            return { label: `${month}月`, value: month.toString() };
        });
    }

    get showDateRangeError() {
        return this.isEndDateBeforeStartDate && this._endTouched;
    }


    get isEndDateBeforeStartDate() {
        if (!this.startYear || !this.startMonth || !this.endYear || !this.endMonth) {
            return false;
        }
        const startYearNum = parseInt(this.startYear, 10);
        const startMonthNum = parseInt(this.startMonth, 10);
        const endYearNum = parseInt(this.endYear, 10);
        const endMonthNum = parseInt(this.endMonth, 10);
        if (endYearNum < startYearNum) return true;
        if (endYearNum === startYearNum && endMonthNum < startMonthNum) return true;
        return false;
    }

    // ---- ライフサイクル ----
    connectedCallback() {
        this.loadSalaryOptions();        // 年収のPicklistを読み込み
        this.initJobGroupsSelection();   // 職種グループの選択状態を初期化
        this.checkValidity();            // 初期バリデーション
    }

    /**
     * 現在の年収のPicklistオプションを非同期で読み込む
     */
    async loadSalaryOptions() {
        try {
            const options = await getPicklistOptions({
                objectName: 'Account',
                fieldName: 'CurrentAnnualIncome1__c'
            });
            this.salaryOptions = options;
        } catch (error) {
            this.salaryOptions = [];
        } finally {
            this.isSalaryLoading = false;
            // データ読み込み前に溜まっていた保留データがあれば反映
            if (this._pendingData) {
                const data = this._pendingData;
                this._pendingData = null;
                this.applySetData(data);
            }
            this.checkValidity();
        }
    }

    /**
     * 職種グループの選択状態を初期化（selectedExperienceOptionsに基づく）
     */
    initJobGroupsSelection() {
        this.jobGroups = this.jobGroups.map(group => {
            const updatedOptions = group.options.map(opt => ({
                ...opt,
                isSelected: this.selectedExperienceOptions.has(opt.value)
            }));
            const selectedCount = updatedOptions.filter(opt => opt.isSelected).length;
            const allSelected = selectedCount === updatedOptions.length && updatedOptions.length > 0;
            const indeterminate = selectedCount > 0 && selectedCount < updatedOptions.length;
            return {
                ...group,
                options: updatedOptions,
                allSelected,
                indeterminate
            };
        });
    }

    /**
     * selectedExperienceOptionsの変更に応じてjobGroupsの選択状態を更新する
     */
    updateJobGroups() {
        this.jobGroups = this.jobGroups.map(group => {
            const updatedOptions = group.options.map(opt => ({
                ...opt,
                isSelected: this.selectedExperienceOptions.has(opt.value)
            }));
            const selectedCount = updatedOptions.filter(opt => opt.isSelected).length;
            const allSelected = selectedCount === updatedOptions.length && updatedOptions.length > 0;
            const indeterminate = selectedCount > 0 && selectedCount < updatedOptions.length;
            return {
                ...group,
                options: updatedOptions,
                allSelected,
                indeterminate
            };
        });
    }

    /**
     * グループの開閉トグル（+ / -）
     * @param {Event} event
     */
    toggleGroup(event) {
        const groupKey = event.currentTarget.dataset.groupKey;
        const group = this.jobGroups.find(g => g.key === groupKey);
        if (group) {
            group.isExpanded = !group.isExpanded;
            group.toggleIconName = group.isExpanded ? '−' : '+';
            this.jobGroups = [...this.jobGroups]; // リアクティビティを確保
        }
    }

    /**
     * イベント伝播を停止（グループ内のチェックボックス操作で開閉が起きないように）
     * @param {Event} event
     */
    stopPropagation(event) {
        event.stopPropagation();
    }

    /**
     * 個別の職種オプションのチェックボックス変更時
     * @param {Event} event
     */
    handleOptionChange(event) {
        const value = event.target.value;
        const checked = event.target.checked;
        if (checked) {
            this.selectedExperienceOptions.add(value);
        } else {
            this.selectedExperienceOptions.delete(value);
        }
        this.updateJobGroups();
        this.checkValidity();
    }

    /**
     * グループ単位の「全選択」チェックボックス変更時
     * @param {Event} event
     */
    handleGroupSelect(event) {
        const groupKey = event.target.dataset.groupKey;
        const checked = event.target.checked;
        const group = this.jobGroups.find(g => g.key === groupKey);
        if (!group) return;

        if (checked) {
            group.options.forEach(opt => this.selectedExperienceOptions.add(opt.value));
        } else {
            group.options.forEach(opt => this.selectedExperienceOptions.delete(opt.value));
        }
        this.updateJobGroups();
        this.checkValidity();
    }

    /**
     * 会社名入力変更時
     * @param {Event} event
     */
    handleCompanyInput(event) {
        this.companyName = event.target.value;
        this.checkValidity();
    }

    // 開始年月・終了年月の各セレクトボックス変更ハンドラ
    handleStartYearChange(event) {
        this.startYear = event.target.value;
        this.checkValidity();
    }
    handleStartMonthChange(event) {
        this.startMonth = event.target.value;
        this.checkValidity();
    }
    handleEndYearChange(event) {
        this.endYear = event.target.value;
        this._endTouched = true;
        this.checkValidity();
    }
    handleEndMonthChange(event) {
        this.endMonth = event.target.value;
        this._endTouched = true;
        this.checkValidity();
    }

    /**
     * 年収セレクトボックス変更時
     * @param {Event} event
     */
    handleSalaryChange(event) {
        this.currentSalary = event.target.value;
        this.checkValidity();
    }

    /**
     * 職務内容テキストエリア変更時
     * @param {Event} event
     */
    handleJobDescriptionInput(event) {
        this.jobDescription = event.target.value;
        this.checkValidity();
    }

    // ---- バリデーション ----
    /**
     * 必須項目が全て入力されているかチェック
     * @returns {boolean}
     */
    isValid() {
        if (!this.companyName || this.companyName.trim() === '') return false;
        if (!this.startYear || !this.startMonth) return false;
        if (!this.endYear || !this.endMonth) return false;
        if (this.isEndDateBeforeStartDate) return false;
        if (!this.currentSalary) return false;
        if (!this.jobDescription || this.jobDescription.trim() === '') return false;
        if (this.selectedExperienceOptions.size === 0) return false;
        return true;
    }

    /**
     * バリデーション結果を親コンポーネントに通知
     */
    checkValidity() {
        const valid = this.isValid();
        this.dispatchEvent(new CustomEvent('stepvaliditychange', {
            detail: { isValid: valid }
        }));
    }

    /**
     * 保留データを実際に反映する（setFormDataの遅延適用）
     * @param {Object} data
     */
    applySetData(data) {
        if (data.companyName !== undefined) this.companyName = data.companyName;
        if (data.startDate) {
            const [year, month] = data.startDate.split('-');
            this.startYear = year;
            this.startMonth = month;
        }
        if (data.endDate) {
            const [year, month] = data.endDate.split('-');
            this.endYear = year;
            this.endMonth = month;
        }
        if (data.currentSalary !== undefined) this.currentSalary = data.currentSalary;
        if (data.jobDescription !== undefined) this.jobDescription = data.jobDescription;
        if (data.selectedExperienceOptions) {
            const selectedValues = data.selectedExperienceOptions.split(';').filter(v => v);
            this.selectedExperienceOptions = new Set(selectedValues);
            this.updateJobGroups();
        }
        this.checkValidity();
    }

    // ---- API for parent ----
    /**
     * 親コンポーネントから現在のデータを取得するためのメソッド
     * @returns {Object} 前職情報と選択された経験職種（値とカテゴリ名）
     */
    @api
    getData() {
        const startDate = this.startYear && this.startMonth
            ? `${this.startYear}-${this.startMonth.padStart(2, '0')}`
            : null;
        const endDate = this.endYear && this.endMonth
            ? `${this.endYear}-${this.endMonth.padStart(2, '0')}`
            : null;
        const selectedExperienceValues = Array.from(this.selectedExperienceOptions).join(';');
        // 選択された値からカテゴリ名を取得（重複排除してセミコロン区切り）
        const selectedCategories = Array.from(new Set(
            Array.from(this.selectedExperienceOptions).map(value => {
                const group = this.jobGroups.find(g =>
                    g.options.some(opt => opt.value === value)
                );
                return group ? group.label : null;
            }).filter(cat => cat)
        )).join(';');

        return {
            companyName: this.companyName,
            startDate: startDate,
            endDate: endDate,
            currentSalary: this.currentSalary,
            jobDescription: this.jobDescription,
            selectedExperienceOptions: selectedExperienceValues,
            selectedExperienceCategories: selectedCategories
        };
    }

    /**
     * 親コンポーネントからフォームデータを復元するためのメソッド
     * 非同期読み込み中の場合、データを保留する
     * @param {Object} data - 復元するデータ
     */
    @api
    setFormData(data) {
        if (!data) return;
        const apply = () => {
            this.applySetData(data);
        };
        if (this.isSalaryLoading) {
            this._pendingData = data;
        } else {
            apply();
        }
    }
}