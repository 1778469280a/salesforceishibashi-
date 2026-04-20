import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
// Apexメソッドのインポート
import getRegistrationInfo from '@salesforce/apex/RegistrationInfoController.getRegistrationInfo';
import updateRegistrationInfo from '@salesforce/apex/RegistrationInfoController.updateRegistrationInfo';
import getPrefecturePicklistValues from '@salesforce/apex/RegistrationInfoController.getPrefecturePicklistValues';
import getEducationPicklistValues from '@salesforce/apex/RegistrationInfoController.getEducationPicklistValues';
import getEmploymentPicklistValues from '@salesforce/apex/RegistrationInfoController.getEmploymentPicklistValues';

export default class RegistrationInfoForm extends LightningElement {
    @track isEditing = false;      // 編集モードフラグ
    @track userInfo = {            // 画面表示/編集用データ
        recordId: '',
        lastName: '',
        firstName: '',
        kanaSei: '',
        kanaMei: '',
        birthdate: '',
        gender: '',
        postalCode: '',
        prefecture: '',
        address: '',
        phone: '',
        education: '',
        school: '',
        companyCount: '',
        employmentStatus: '',
        license: '',
        managementExperience: '',
        remarks: ''
    };

    @track birthYear = '';
    @track birthMonth = '';
    @track birthDay = '';

    // ピックリスト選択肢（サーバから取得）
    @track prefectureOptions = [];
    @track educationOptions = [];
    @track employmentOptions = [];

    // マネジメント経験の選択肢（固定）
    managementOptions = [
        { label: 'なし', value: 'false' },
        { label: 'あり', value: 'true' }
    ];

    // 性別選択肢（固定）
    genderOptions = [
        { label: '男性', value: '男性' },
        { label: '女性', value: '女性' }
    ];

    // 経験社数の選択肢（固定）
    baseCompanyCountOptions = [
        { label: '1社', value: '1' },
        { label: '2社', value: '2' },
        { label: '3社', value: '3' },
        { label: '4社', value: '4' },
        { label: '5社', value: '5' },
        { label: '6社', value: '6' },
        { label: '7社', value: '7' },
        { label: '8社', value: '8' },
        { label: '9社', value: '9' },
        { label: '10社以上', value: '10' }
    ];

    // ---- Getter（表示用に値を整形） ----
    get managementText() {
        const val = this.userInfo.managementExperience;
        if (val === 'true' || val === true) return 'あり';
        if (val === 'false' || val === false) return 'なし';
        return '';
    }

    get genderText() {
        const val = this.userInfo.gender;
        if (val === '男性') return '男性';
        if (val === '女性') return '女性';
        return '';
    }

    get fullName() {
        return `${this.userInfo.lastName} ${this.userInfo.firstName}`.trim();
    }

    get fullKana() {
        return `${this.userInfo.kanaSei} ${this.userInfo.kanaMei}`.trim();
    }

    get titleText() {
        return this.isEditing ? '登録情報の変更' : '登録情報';
    }

    get subTitleText() {
        return this.isEditing ? '基本情報の編集' : '基本情報';
    }

    get yearOptions() {
        const options = [];
        const currentYear = new Date().getFullYear();
        for (let i = currentYear; i >= 1930; i--) {
            options.push({ label: `${i}年`, value: String(i) });
        }
        return options;
    }

    get monthOptions() {
        const options = [];
        for (let i = 1; i <= 12; i++) {
            const val = String(i).padStart(2, '0');
            options.push({ label: `${i}月`, value: val });
        }
        return options;
    }

    get dayOptions() {
        const options = [];
        for (let i = 1; i <= 31; i++) {
            const val = String(i).padStart(2, '0');
            options.push({ label: `${i}日`, value: val });
        }
        return options;
    }

    // ラジオボタンのチェック状態を判定するGetter（最終学歴）
    get educationOptionsWithCheck() {
        return this.educationOptions.map(option => ({
            ...option,
            isChecked: option.value === this.userInfo.education
        }));
    }

    // 経験社数のラジオボタン用
    get companyCountOptionsWithCheck() {
        return this.baseCompanyCountOptions.map(option => ({
            ...option,
            isChecked: option.value === this.userInfo.companyCount
        }));
    }

    // 就業状況のラジオボタン用
    get employmentOptionsWithCheck() {
        return this.employmentOptions.map(option => ({
            ...option,
            isChecked: option.value === this.userInfo.employmentStatus
        }));
    }

    // ---- ライフサイクルフック ----
    connectedCallback() {
        this.loadData();                // ユーザー情報を読み込み
        this.loadPicklistOptions();     // ピックリスト選択肢を読み込み
    }

    renderedCallback() {
        // 編集モード時に、lwc:dom="manual" のテキストエリアとセレクトボックスに値を同期
        this.syncManualFields();
    }

    // ---- サーバからのデータ取得 ----
    loadData() {
        getRegistrationInfo()
            .then(data => {
                if (data) {
                    this.userInfo = { ...this.userInfo, ...data };

                    // 生年月日を分割してプルダウン用の変数にセット
                    if (data.birthdate) {
                        const parts = data.birthdate.split(/[-/]/);
                        if (parts.length === 3) {
                            this.birthYear = parts[0];
                            this.birthMonth = parts[1].padStart(2, '0');
                            this.birthDay = parts[2].padStart(2, '0');
                            this.userInfo.birthdate = `${this.birthYear}/${this.birthMonth}/${this.birthDay}`;
                        }
                    }

                    // マネジメント経験を文字列型に統一（Boolean → "true"/"false"）
                    if (data.managementExperience === true) {
                        this.userInfo.managementExperience = 'true';
                    } else if (data.managementExperience === false) {
                        this.userInfo.managementExperience = 'false';
                    }
                }
            })
            .catch(error => {
                this.dispatchEvent(new ShowToastEvent({ title: 'エラー', message: '読込失敗', variant: 'error' }));
            });
    }

    // ピックリスト選択肢を並行取得
    loadPicklistOptions() {
        Promise.all([
            getPrefecturePicklistValues(),
            getEducationPicklistValues(),
            getEmploymentPicklistValues()
        ])
        .then(([prefectures, educations, employments]) => {
            this.prefectureOptions = prefectures;
            this.educationOptions = educations;
            this.employmentOptions = employments;
        });
    }

    // ---- 手動同期（lwc:dom="manual" 項目およびセレクトボックスに対して） ----
    syncManualFields() {
        if (!this.isEditing) return;

        const lic = this.template.querySelector('[data-field="license"]');
        const rem = this.template.querySelector('[data-field="remarks"]');
        const pre = this.template.querySelector('[data-field="prefecture"]');
        const mgmt = this.template.querySelector('[data-field="managementExperience"]');
        const gender = this.template.querySelector('[data-field="gender"]');
        
        // 生年月日のセレクトボックスを取得
        const year = this.template.querySelector('[data-id="birthYear"]');
        const month = this.template.querySelector('[data-id="birthMonth"]');
        const day = this.template.querySelector('[data-id="birthDay"]');

        if (lic) lic.value = this.userInfo.license || '';
        if (rem) rem.value = this.userInfo.remarks || '';
        if (pre) pre.value = this.userInfo.prefecture || '';
        if (mgmt) mgmt.value = this.userInfo.managementExperience || 'false';
        if (gender) gender.value = this.userInfo.gender || '';

        // 生年月日の値を強制同期
        if (year) year.value = this.birthYear || '';
        if (month) month.value = this.birthMonth || '';
        if (day) day.value = this.birthDay || '';
    }

    // 保存時に、手動同期フィールドの値を最新化
    syncAllInputs() {
        const lic = this.template.querySelector('[data-field="license"]');
        const rem = this.template.querySelector('[data-field="remarks"]');
        const mgmt = this.template.querySelector('[data-field="managementExperience"]');
        const gender = this.template.querySelector('[data-field="gender"]');
        const year = this.template.querySelector('[data-id="birthYear"]');
        const month = this.template.querySelector('[data-id="birthMonth"]');
        const day = this.template.querySelector('[data-id="birthDay"]');

        this.userInfo.license = lic?.value || '';
        this.userInfo.remarks = rem?.value || '';
        this.userInfo.managementExperience = mgmt?.value || 'false';
        this.userInfo.gender = gender?.value || '';
        
        // プルダウンの状態をプロパティに書き戻す
        this.birthYear = year?.value || '';
        this.birthMonth = month?.value || '';
        this.birthDay = day?.value || '';
    }

    // ---- イベントハンドラ ----
    handleEditClick() {
        this.isEditing = true;
        // レンダリング後に手動同期を実行
        setTimeout(() => this.syncManualFields(), 0);
    }

    handleCancel() {
        this.isEditing = false;
        this.loadData();
    }

    handleInputChange(e) {
        const field = e.target.dataset.field;
        this.userInfo = { ...this.userInfo, [field]: e.target.value };
    }

    handleSelectChange(e) {
        const fieldId = e.target.dataset.id;
        if (fieldId === 'birthYear') this.birthYear = e.target.value;
        if (fieldId === 'birthMonth') this.birthMonth = e.target.value;
        if (fieldId === 'birthDay') this.birthDay = e.target.value;
    }

    handleRadioChange(e) {
        const field = e.target.dataset.field;
        this.userInfo = { ...this.userInfo, [field]: e.target.value };
    }

    // 保存処理
    handleSave() {
        this.syncAllInputs();

        if (!this.userInfo.lastName || !this.userInfo.firstName) {
            this.dispatchEvent(new ShowToastEvent({ title: '入力エラー', message: '姓・名は必須です', variant: 'error' }));
            return;
        }

        // 年月日をAPI形式 (YYYY-MM-DD) に結合
        if (this.birthYear && this.birthMonth && this.birthDay) {
            this.userInfo.birthdate = `${this.birthYear}-${this.birthMonth}-${this.birthDay}`;
        } else {
            this.userInfo.birthdate = null;
        }

        updateRegistrationInfo({ wrapper: this.userInfo })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title: '成功', message: '更新されました', variant: 'success' }));
                this.isEditing = false;
                this.loadData();
            })
            .catch(err => {
                this.dispatchEvent(new ShowToastEvent({ title: 'エラー', message: err.body?.message || '更新失敗', variant: 'error' }));
            });
    }
}