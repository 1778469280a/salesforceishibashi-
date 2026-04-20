import { LightningElement, wire, track, api } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getFilterOptions from '@salesforce/apex/JobSearchController.getFilterOptions';

/**
 * 求人検索コンポーネント
 * 職種、勤務地、年収、転勤の有無、こだわり条件、キーワードによるフィルタリング機能を提供します。
 * モーダルを使用して詳細な選択が可能で、検索条件を親コンポーネントに通知したり、検索結果ページへ遷移します。
 */
export default class JobSearch extends NavigationMixin(LightningElement) {
    // 外部から初期検索条件を受け取るためのAPIプロパティ
    @api initialFilters;

    // 現在のフィルター状態（画面表示に使用）
    @track filters = {
        categories: [],      // 選択された職種（詳細）
        prefectures: [],     // 選択された都道府県
        minSalary: '',       // 最低年収（万円）
        transfer: '',        // 転勤の有無（"無し" / "有り"）
        conditions: [],      // 選択されたこだわり条件
        keyword: ''          // フリーワード検索
    };

    // モーダル内で一時的に保持するフィルター状態（確定前にユーザーの変更を保持）
    @track tempFilters = {
        categories: [],
        prefectures: [],
        conditions: []
    };

    // 職種の階層構造（カテゴリー → 詳細オプション）を保持
    @track jobCategories = [];

    // 勤務地の地域グループと都道府県リスト
    @track regions = [];

    // こだわり条件のリスト
    @track specificConditions = [];

    // 各モーダルの表示フラグ
    @track showJobTypeModal = false;   // 職種選択モーダル
    @track showLocationModal = false;  // 勤務地選択モーダル
    @track showConditionModal = false; // こだわり条件選択モーダル

    // 各グループ（職種カテゴリ／地域／都道府県）の開閉状態を管理
    @track expandedGroups = {};

    // 初回レンダリング済みフラグ（DOM操作の初期化制御用）
    @track _hasRendered = false;

    // 地域と都道府県のマッピング（固定データ）
    REGION_MAPPINGS = [
        { label: '北海道 / 東北', key: 'hokkaido-tohoku', values: ['北海道', '青森県', '岩手県', '宮城県', '秋田県', '山形県', '福島県'] },
        { label: '関東', key: 'kanto', values: ['茨城県', '栃木県', '群馬県', '埼玉県', '千葉県', '東京都', '神奈川県'] },
        { label: '上信越 / 北陸', key: 'shinetsu-hokuriku', values: ['新潟県', '富山県', '石川県', '福井県', '山梨県', '長野県'] },
        { label: '東海', key: 'tokai', values: ['岐阜県', '静岡県', '愛知県', '三重県'] },
        { label: '関西', key: 'kansai', values: ['滋賀県', '京都府', '大阪府', '兵庫県', '奈良県', '和歌山県'] },
        { label: '中国', key: 'chugoku', values: ['鳥取県', '島根県', '岡山県', '広島県', '山口県'] },
        { label: '四国', key: 'shikoku', values: ['徳島県', '香川県', '愛媛県', '高知県'] },
        { label: '九州 / 沖縄 / その他', key: 'kyushu-okinawa', values: ['福岡県', '佐賀県', '長崎県', '熊本県', '大分県', '宮崎県', '鹿児島県', '沖縄県', '海外'] }
    ];

    /**
     * コンポーネントがDOMに追加された際の処理
     * initialFilters が指定されていれば、フィルターの初期値を設定する
     */
    connectedCallback() {
        if (this.initialFilters) {
            this.filters = {
                categories: this.initialFilters.categories || [],
                prefectures: this.initialFilters.prefectures || [],
                minSalary: this.initialFilters.minSalary || '',
                transfer: this.initialFilters.transfer || '',
                conditions: this.initialFilters.conditions || [],
                keyword: this.initialFilters.keyword || ''
            };
            this.tempFilters = {
                categories: [...this.filters.categories],
                prefectures: [...this.filters.prefectures],
                conditions: [...this.filters.conditions]
            };
            this.keyword = this.initialFilters.keyword || '';
        }
    }

    /**
     * サーバーからフィルターオプション（職種・勤務地・こだわり条件）を取得するWire
     * @param {Object} error, data
     */
    @wire(getFilterOptions)
    wiredFilterOptions({ error, data }) {
        if (data) {
            this.processFilterData(data);
            this.updateSelectedFlags();
        } else if (error) {
            console.error('フィルターオプションの読み込みエラー:', error);
        }
    }

    /**
     * 取得したフィルターオプションを加工し、jobCategories, regions, specificConditions に格納する
     * @param {Object} data - Apexから返されるデータ
     */
    processFilterData(data) {
        // 職種カテゴリ（JobCategory1__c）ごとに詳細（JobCategoryDetail1__c）をグループ化
        const categoryMap = new Map();
        data.jobCategories.forEach(item => {
            if (item.JobCategoryDetail1__c) {
                const category = item.JobCategory1__c;
                if (!categoryMap.has(category)) categoryMap.set(category, []);
                categoryMap.get(category).push(item.JobCategoryDetail1__c);
            }
        });

        this.jobCategories = Array.from(categoryMap.entries()).map(([label, options], idx) => ({
            key: `cat-${idx}`,
            label,
            toggleIconName: 'add',      // 開閉アイコン（初期は閉じている）
            isExpanded: false,
            options: options.map(opt => ({
                value: opt,
                label: opt,
                isSelected: false
            }))
        }));

        const cityMap = new Map();
        if (data.cities) {
            data.cities.forEach(c => {
                if (!cityMap.has(c.MasterLabel)) cityMap.set(c.MasterLabel, []);
                cityMap.get(c.MasterLabel).push({ value: c.CityName__c, label: c.CityName__c, isSelected: false });
            });
        }

        // 勤務地：利用可能な都道府県のみを地域マッピングからフィルタリング
        const availableOptions = this.getAllAvailableOptions(data);
        this.regions = this.REGION_MAPPINGS.map(mapping => ({
            key: mapping.key, 
            label: mapping.label, 
            toggleIconName: 'add', 
            isExpanded: false,
            prefectures: mapping.values.filter(v => availableOptions.includes(v)).map(v => ({
                value: v, 
                label: v, 
                isSelected: false, 
                isExpanded: false,       // 修正：都道府県ごとの開閉状態
                toggleIconName: 'add',   // 修正：都道府県ごとのアイコン
                cities: cityMap.get(v) || []
            }))
        })).filter(g => g.prefectures.length > 0);

        // こだわり条件
        this.specificConditions = (data.specificConditions || []).map(condition => ({
            value: condition,
            label: condition,
            isSelected: false
        }));
    }

    /**
     * 利用可能な都道府県のセットを取得（データソースから）
     * @param {Object} data
     * @returns {Array} ユニークな都道府県名の配列
     */
    getAllAvailableOptions(data) {
        const allValues = [
            ...(data.regions || []),
            ...(data.prefectures || [])
        ];
        return [...new Set(allValues.filter(Boolean).map(v => v.trim()))];
    }

    /**
     * 現在のフィルター（filters または tempFilters）に基づいて、
     * jobCategories, regions, specificConditions の各選択状態を更新する
     * @param {boolean} useTemp - true の場合は tempFilters を参照、false の場合は filters を参照
     */
    updateSelectedFlags(useTemp = false) {
        const targetFilters = useTemp ? this.tempFilters : this.filters;

        // 職種カテゴリの選択状態を更新
        this.jobCategories = this.jobCategories.map(category => {
            const options = category.options.map(option => ({
                ...option,
                isSelected: targetFilters.categories.includes(option.value)
            }));

            const selectedCount = options.filter(opt => opt.isSelected).length;
            const allSelected = selectedCount === options.length && options.length > 0;
            const indeterminate = selectedCount > 0 && selectedCount < options.length;

            return {
                ...category,
                options,
                allSelected,
                indeterminate,
                isExpanded: this.expandedGroups[category.key] || false
            };
        });

        // 勤務地の選択状態を更新
        this.regions = this.regions.map(region => {
            const prefectures = region.prefectures.map(pref => ({
                ...pref,
                isSelected: targetFilters.prefectures.includes(pref.value),
                isExpanded: this.expandedGroups[pref.value] || false,              // 修正
                toggleIconName: this.expandedGroups[pref.value] ? 'remove' : 'add' // 修正
            }));

            const selectedCount = prefectures.filter(p => p.isSelected).length;
            const allSelected = selectedCount === prefectures.length && prefectures.length > 0;
            const indeterminate = selectedCount > 0 && selectedCount < prefectures.length;

            return {
                ...region,
                prefectures,
                allSelected,
                indeterminate,
                isExpanded: this.expandedGroups[region.key] || false
            };
        });

        // こだわり条件の選択状態を更新
        this.specificConditions = this.specificConditions.map(condition => ({
            ...condition,
            isSelected: targetFilters.conditions.includes(condition.value)
        }));
    }

    /**
     * グループ（職種カテゴリ or 地域）の「すべて選択」チェックボックスが変更された時のハンドラ
     * @param {Event} event
     */
    handleGroupSelectAll(event) {
        event.stopPropagation();
        const groupKey = event.target.dataset.groupKey;
        const type = event.target.dataset.type;
        const checked = event.target.checked;
        
        const detailsElement = event.target.closest('details');
        if (detailsElement) {
            detailsElement.open = true;
        }

        let group, options, filterKey;

        if (type === 'category') {
            group = this.jobCategories.find(g => g.key === groupKey);
            options = group?.options || [];
            filterKey = 'categories';
        } else if (type === 'location') {
            group = this.regions.find(g => g.key === groupKey);
            options = group?.prefectures || [];
            filterKey = 'prefectures';
        } else {
            return;
        }

        if (!group || options.length === 0) return;

        const values = options.map(opt => opt.value);
        const newTempFilters = { ...this.tempFilters };

        if (checked) {
            newTempFilters[filterKey] = [...new Set([...newTempFilters[filterKey], ...values])];
        } else {
            newTempFilters[filterKey] = newTempFilters[filterKey].filter(v => !values.includes(v));
        }

        this.tempFilters = newTempFilters;
        this.updateSelectedFlags(true);
    }

    /**
     * details 要素の開閉トグル時のハンドラ（アイコン切り替えと expandedGroups の更新）
     * @param {Event} event
     */
    handleDetailsToggle(event) {
        event.stopPropagation();
        const groupKey = event.currentTarget.dataset.groupKey;
        if (!groupKey) return;

        this.expandedGroups = {
            ...this.expandedGroups,
            [groupKey]: !this.expandedGroups[groupKey]
        };

        // 職種カテゴリの更新
        this.jobCategories = this.jobCategories.map(category => {
            if (category.key === groupKey) {
                return {
                    ...category,
                    isExpanded: this.expandedGroups[groupKey],
                    toggleIconName: this.expandedGroups[groupKey] ? 'remove' : 'add'
                };
            }
            return category;
        });

        // 勤務地・都道府県の更新（修正箇所）
        this.regions = this.regions.map(region => {
            let updatedRegion = { ...region };
            
            // 1. 地域グループ自身がトグルされた場合
            if (region.key === groupKey) {
                updatedRegion.isExpanded = this.expandedGroups[groupKey];
                updatedRegion.toggleIconName = this.expandedGroups[groupKey] ? 'remove' : 'add';
            }

            // 2. 地域の配下にある「都道府県」がトグルされた場合
            updatedRegion.prefectures = region.prefectures.map(pref => {
                if (pref.value === groupKey) {
                    return {
                        ...pref,
                        isExpanded: this.expandedGroups[groupKey],
                        toggleIconName: this.expandedGroups[groupKey] ? 'remove' : 'add'
                    };
                }
                return pref;
            });

            return updatedRegion;
        });
    }

    // ---- Getters (テンプレート表示用) ----

    /**
     * 職種オプションに「すべての選択肢」テキストを追加したものを返す
     */
    get jobCategoriesWithSelected() {
        return this.jobCategories.map(category => ({
            ...category,
            allOptionsText: category.options.map(opt => opt.label).join('、')
        }));
    }

    /**
     * 勤務地オプションに「すべての選択肢」テキストを追加したものを返す
     */
    get regionsWithSelected() {
        return this.regions.map(region => ({
            ...region,
            allOptionsText: region.prefectures.map(pref => pref.label).join('、')
        }));
    }

    /**
     * こだわり条件のリストをそのまま返す
     */
    get conditionsWithSelected() {
        return this.specificConditions;
    }

    /**
     * 現在選択されている職種のラベル一覧を返す（選択タグ表示用）
     */
    get selectedJobCategories() {
        const selected = [];
        this.jobCategories.forEach(category => {
            category.options.forEach(option => {
                if (this.filters.categories.includes(option.value)) {
                    selected.push(option.label);
                }
            });
        });
        return selected;
    }

    /**
     * 現在選択されている勤務地のラベル一覧を返す（選択タグ表示用）
     */
    get selectedLocations() {
        const selected = [];
        this.regions.forEach(region => {
            region.prefectures.forEach(pref => {
                if (this.filters.prefectures.includes(pref.value)) {
                    selected.push(pref.label);
                }
            });
        });
        return selected;
    }

    /**
     * 現在選択されているこだわり条件のラベル一覧を返す（選択タグ表示用）
     */
    get selectedConditions() {
        return this.specificConditions
            .filter(condition => this.filters.conditions.includes(condition.value))
            .map(condition => condition.label);
    }

    /**
     * 職種フィルターの選択状態を表すテキスト（例：「3件選択中」）
     */
    get jobTypeSelectedText() {
        return this.filters.categories.length > 0
            ? `${this.filters.categories.length}件選択中`
            : '選択する';
    }

    /**
     * 勤務地フィルターの選択状態を表すテキスト
     */
    get locationSelectedText() {
        return this.filters.prefectures.length > 0
            ? `${this.filters.prefectures.length}件選択中`
            : '選択する';
    }

    /**
     * こだわり条件フィルターの選択状態を表すテキスト
     */
    get conditionSelectedText() {
        return this.filters.conditions.length > 0
            ? `${this.filters.conditions.length}件選択中`
            : '選択する';
    }

    /**
     * 転勤なしラジオボタンのチェック状態
     */
    get isTransferNone() {
        return this.filters.transfer === '無し';
    }

    /**
     * 転勤ありラジオボタンのチェック状態
     */
    get isTransferYes() {
        return this.filters.transfer === '有り';
    }

    // ---- モーダル制御 ----

    handleJobTypeClick() {
        this.showJobTypeModal = true;
        this.tempFilters.categories = [...this.filters.categories];
        this.updateSelectedFlags(true);
    }

    handleLocationClick() {
        this.showLocationModal = true;
        this.tempFilters.prefectures = [...this.filters.prefectures];
        this.updateSelectedFlags(true);
    }

    handleConditionClick() {
        this.showConditionModal = true;
        this.tempFilters.conditions = [...this.filters.conditions];
        this.updateSelectedFlags(true);
    }

    /**
     * モーダルの背景クリックで全てのモーダルを閉じる
     */
    handleModalOutsideClick() {
        this.closeJobTypeModal();
        this.closeLocationModal();
        this.closeConditionModal();
        this.resetToggleIcons();
    }

    closeJobTypeModal() {
        this.showJobTypeModal = false;
        document.body.style.overflow = '';
        this.tempFilters.categories = [...this.filters.categories];
        this.resetToggleIcons();
    }

    closeLocationModal() {
        this.showLocationModal = false;
        document.body.style.overflow = '';
        this.tempFilters.prefectures = [...this.filters.prefectures];
        this.resetToggleIcons();
    }

    closeConditionModal() {
        this.showConditionModal = false;
        document.body.style.overflow = '';
        this.tempFilters.conditions = [...this.filters.conditions];
        this.resetToggleIcons();
    }

    /**
     * 全てのグループ（職種カテゴリ／地域／都道府県）を閉じた状態にリセット
     */
    resetToggleIcons() {
        this.expandedGroups = {};
        
        this.jobCategories = this.jobCategories.map(category => ({
            ...category,
            isExpanded: false,
            toggleIconName: 'add'
        }));

        // 修正：地域と都道府県の両方のアイコンをリセット
        this.regions = this.regions.map(region => ({
            ...region,
            isExpanded: false,
            toggleIconName: 'add',
            prefectures: region.prefectures.map(pref => ({
                ...pref,
                isExpanded: false,
                toggleIconName: 'add'
            }))
        }));
    }

    /**
     * イベントの伝播を停止（モーダル内クリックで背景の閉じ処理を防ぐ）
     * @param {Event} event
     */
    stopPropagation(event) {
        event.stopPropagation();
    }

    /**
     * モーダル内のチェックボックス変更ハンドラ（職種・勤務地・こだわり条件共通）
     * @param {Event} event
     */
    handleCheckboxChange(event) {
        event.stopPropagation();
        const { value, checked, dataset } = event.target;
        const type = dataset.type;
        const filterKey = type === 'category' ? 'categories' :
            type === 'location' ? 'prefectures' : 'conditions';

        const newTempFilters = { ...this.tempFilters };

        if (checked) {
            newTempFilters[filterKey] = [...new Set([...newTempFilters[filterKey], value])];
        } else {
            newTempFilters[filterKey] = newTempFilters[filterKey].filter(item => item !== value);
        }

        this.tempFilters = newTempFilters;
        this.updateSelectedFlags(true);
    }

    /**
     * セレクトボックス（年収）の変更ハンドラ
     * @param {Event} event
     */
    handleSelectChange(event) {
        const { value, dataset } = event.target;
        const newFilters = { ...this.filters };
        if (dataset.type === 'salary') newFilters.minSalary = value;

        this.filters = newFilters;
        this.updateSalarySelect();
    }

    /**
     * ラジオボタン（転勤の有無）の変更ハンドラ
     * @param {Event} event
     */
    handleRadioChange(event) {
        const { value, dataset } = event.target;
        const newFilters = { ...this.filters };
        if (dataset.type === 'transfer') newFilters.transfer = value;

        this.filters = newFilters;
    }

    /**
     * キーワード入力フィールドの入力ハンドラ
     * @param {Event} event
     */
    handleKeywordInput(event) {
        this.filters.keyword = event.target.value;
    }

    // ---- モーダル内の「この条件を選ぶ」ボタン ----

    handleJobTypeSubmit() {
        this.filters = {
            ...this.filters,
            categories: [...this.tempFilters.categories]
        };
        this.showJobTypeModal = false;
        this.resetToggleIcons();
    }

    handleLocationSubmit() {
        this.filters = {
            ...this.filters,
            prefectures: [...this.tempFilters.prefectures]
        };
        this.showLocationModal = false;
        this.resetToggleIcons();
    }

    handleConditionSubmit() {
        this.filters = {
            ...this.filters,
            conditions: [...this.tempFilters.conditions]
        };
        this.showConditionModal = false;
        this.resetToggleIcons();
    }

    // ---- モーダル内の「リセット」ボタン ----

    handleJobTypeReset() {
        this.tempFilters.categories = [];
        this.updateSelectedFlags(true);
    }

    handleLocationReset() {
        this.tempFilters.prefectures = [];
        this.updateSelectedFlags(true);
    }

    handleConditionReset() {
        this.tempFilters.conditions = [];
        this.updateSelectedFlags(true);
    }

    /**
     * 年収セレクトボックスの値をフィルターの値に同期させる
     */
    updateSalarySelect() {
        const select = this.template.querySelector('select[data-type="salary"]');
        if (!select) return;

        const value = this.filters.minSalary || '';
        const options = Array.from(select.options);
        const index = options.findIndex(opt => opt.value === value);

        select.selectedIndex = index >= 0 ? index : 0;
    }

    /**
     * キーワード入力フィールドの値をフィルターの値に同期させる
     */
    updateKeywordInput() {
        const input = this.template.querySelector('.keyword-input');
        if (input) {
            input.value = this.filters.keyword || '';
        }
    }

    /**
     * レンダリング完了後のフック（初回のみDOM同期を行う）
     */
    renderedCallback() {
        if (!this._hasRendered) {
            this.updateSalarySelect();
            this.updateKeywordInput();
            this._hasRendered = true;
        }
    }

    /**
     * 全てのフィルターをリセットする
     */
    handleReset() {
        this.filters = {
            categories: [],
            prefectures: [],
            minSalary: '',
            transfer: '',
            conditions: []
        };

        this.tempFilters = {
            categories: [],
            prefectures: [],
            conditions: []
        };
        this.keyword = '';
        
        this.updateSelectedFlags();
        this.expandedGroups = {};

        this.jobCategories = this.jobCategories.map(category => ({
            ...category,
            isExpanded: false,
            toggleIconName: 'add'
        }));

        // 修正：地域と都道府県の両方のアイコンをリセット
        this.regions = this.regions.map(region => ({
            ...region,
            isExpanded: false,
            toggleIconName: 'add',
            prefectures: region.prefectures.map(pref => ({
                ...pref,
                isExpanded: false,
                toggleIconName: 'add'
            }))
        }));

        this.updateSalarySelect();
        const keywordInput = this.template.querySelector('.keyword-input');
        if (keywordInput) keywordInput.value = '';
    }

    /**
     * 検索実行：現在のフィルター条件をURLパラメータに変換して検索結果ページへ遷移する
     */
    handleSearch() {
        const params = new URLSearchParams();
        const { categories, prefectures, minSalary, transfer, conditions } = this.filters;

        if (categories.length) params.append('categories', categories.join(','));
        if (prefectures.length) params.append('prefectures', prefectures.join(','));
        if (minSalary) params.append('minSalary', minSalary);
        if (transfer) params.append('transfer', transfer);
        if (conditions.length) params.append('conditions', conditions.join(','));
        if (this.filters.keyword) params.append('keyword', this.filters.keyword);

        this.dispatchEvent(new CustomEvent('searchcompleted', {
            bubbles: true,
            cancelable: true
        }));

        this[NavigationMixin.Navigate]({
            type: 'standard__webPage',
            attributes: {
                url: `/search/result?${params.toString()}`
            }
        });
    }
}