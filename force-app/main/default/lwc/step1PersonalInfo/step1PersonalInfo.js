import { LightningElement, track, api } from 'lwc';
import searchAddress from '@salesforce/apex/ZipCodeSearchController.searchAddress';

export default class Step1PersonalInfo extends LightningElement {
    @track password = '';
    @track passwordConfirm = '';
    @track passwordMismatch = false;
    @track lastName = '';
    @track firstName = '';
    @track lastNameKana = '';
    @track firstNameKana = '';
    @track birthYear = '';
    @track birthMonth = '';
    @track birthDay = '';
    @track phone = '';
    @track gender = '';
    @track zipcode = '';
    @track zipError = '';
    @track prefecture = '';
    @track cityAddress = '';

    @track zipSearched = false;

    @track lastNameKanaError = false;
    @track firstNameKanaError = false;
    @track phoneError = false;

    validateKana(value) {
        return /^[\u3040-\u309F]+$/.test(value);
    }

    validatePhone(value) {
        if (!value) return false;
        const digits = value.replace(/-/g, '');
        return /^\d{10,11}$/.test(digits);
    }

    get yearOptions() {
        const currentYear = new Date().getFullYear();
        const years = [];
        for (let y = 1900; y <= currentYear; y++) {
            years.push({ label: `${y.toString()}年`, value: y.toString() });
        }
        return years;
    }

    get monthOptions() {
        return Array.from({ length: 12 }, (_, i) => {
            const month = i + 1;
            return { label: `${month.toString()}月`, value: month.toString() };
        });
    }

    get dayOptions() {
        if (!this.birthYear || !this.birthMonth) {
            return [{ label: '日', value: '' }];
        }
        const year = parseInt(this.birthYear, 10);
        const month = parseInt(this.birthMonth, 10);
        const lastDay = new Date(year, month, 0).getDate();
        const days = [];
        for (let d = 1; d <= lastDay; d++) {
            days.push({ label: `${d.toString()}日`, value: d.toString() });
        }
        return days;
    }

    get genderMale() {
        return this.gender === '男性';
    }

    get genderFemale() {
        return this.gender === '女性';
    }

    handleInputChange(event) {
        const field = event.target.dataset.id;
        this[field] = event.target.value;

        if (field === 'password' && this.passwordMismatch) {
            this.passwordMismatch = false;
        }

        if (field === 'zipcode') {
            this.zipError = '';
            this.zipSearched = false;
        }

        if (field === 'lastNameKana') {
            this.lastNameKanaError = false;
        } else if (field === 'firstNameKana') {
            this.firstNameKanaError = false;
        } else if (field === 'phone') {
            this.phoneError = false;
        }

        this.checkValidity();
    }

    handleKanaBlur(event) {
        const field = event.target.dataset.id;
        const value = this[field];
        if (field === 'lastNameKana') {
            this.lastNameKanaError = value && !this.validateKana(value);
        } else if (field === 'firstNameKana') {
            this.firstNameKanaError = value && !this.validateKana(value);
        }
        this.checkValidity();
    }

    handlePhoneBlur(event) {
        const value = this.phone;
        this.phoneError = value && !this.validatePhone(value);
        this.checkValidity();
    }

    handlePasswordConfirmBlur() {
        this.passwordMismatch = (this.password !== this.passwordConfirm);
        this.checkValidity();
    }

    handleSelectChange(event) {
        const field = event.target.dataset.id;
        const newValue = event.target.value;
        const oldDay = this.birthDay;

        if (field === 'birthYear') {
            this.birthYear = newValue;
        } else if (field === 'birthMonth') {
            this.birthMonth = newValue;
        } else {
            this[field] = newValue;
            this.checkValidity();
            return;
        }

        if (oldDay && this.birthYear && this.birthMonth) {
            const year = parseInt(this.birthYear, 10);
            const month = parseInt(this.birthMonth, 10);
            const lastDay = new Date(year, month, 0).getDate();
            if (parseInt(oldDay, 10) > lastDay) {
                this.birthDay = '';
            } else {
                this.birthDay = oldDay;
            }
        }
        this.checkValidity();
    }

    handleGenderChange(event) {
        this.gender = event.target.dataset.value;
        this.checkValidity();
    }

    async handleZipSearch() {
        const rawZip = this.zipcode?.trim() || '';
        const cleanZip = rawZip.replace(/-/g, '');
        this.zipError = '';

        if (!cleanZip) {
            this.zipError = '郵便番号を入力してください';
            this.checkValidity();
            return;
        }
        if (cleanZip.length !== 7 || isNaN(Number(cleanZip))) {
            this.zipError = '郵便番号は7桁の数字で入力してください';
            this.checkValidity();
            return;
        }

        try {
            const data = await searchAddress({ zipcode: cleanZip });
            if (data.status === 200 && data.results && data.results.length > 0) {
                const result = data.results[0];
                this.prefecture = result.address1 || '';
                this.cityAddress = [result.address2, result.address3].filter(Boolean).join('');
                this.zipSearched = true;
            } else {
                this.zipError = data.message || '住所が見つかりませんでした';
            }
        } catch (error) {
            this.zipError = '住所検索に失敗しました';
        }
        this.checkValidity();
    }

    isValid() {
        const requiredFields = [
            this.password,
            this.passwordConfirm,
            this.lastName,
            this.firstName,
            this.lastNameKana,
            this.firstNameKana,
            this.birthYear,
            this.birthMonth,
            this.birthDay,
            this.phone,
            this.gender,
            this.zipcode,
            this.prefecture,
            this.cityAddress
        ];
        if (requiredFields.some(val => !val || val.trim() === '')) {
            return false;
        }
        if (this.passwordMismatch) {
            return false;
        }
        if (!this.validateKana(this.lastNameKana) || !this.validateKana(this.firstNameKana)) {
            return false;
        }
        if (!this.validatePhone(this.phone)) {
            return false;
        }
        if (this.zipError) {
            return false;
        }
        if (!this.zipSearched) {
            return false;
        }
        return true;
    }

    checkValidity() {
        this.lastNameKanaError = this.lastNameKana && !this.validateKana(this.lastNameKana);
        this.firstNameKanaError = this.firstNameKana && !this.validateKana(this.firstNameKana);
        this.phoneError = this.phone && !this.validatePhone(this.phone);

        const valid = this.isValid();
        this.dispatchEvent(new CustomEvent('stepvaliditychange', {
            detail: { isValid: valid }
        }));
    }

    connectedCallback() {
        this.checkValidity();
    }

    @api
    getData() {
        let birthDate = null;
        if (this.birthYear && this.birthMonth && this.birthDay) {
            birthDate = `${this.birthYear}-${this.birthMonth.padStart(2, '0')}-${this.birthDay.padStart(2, '0')}`;
        }
        return {
            lastName: this.lastName,
            firstName: this.firstName,
            lastNameKana: this.lastNameKana,
            firstNameKana: this.firstNameKana,
            birthDate: birthDate,
            phone: this.phone,
            gender: this.gender,
            zipcode: this.zipcode,
            prefecture: this.prefecture,
            cityAddress: this.cityAddress,
            password: this.password,
            passwordConfirm: this.passwordConfirm
        };
    }

    @api
    setFormData(data) {
        if (!data) return;
        if (data.password !== undefined) this.password = data.password;
        if (data.passwordConfirm !== undefined) this.passwordConfirm = data.passwordConfirm;
        if (data.lastName !== undefined) this.lastName = data.lastName;
        if (data.firstName !== undefined) this.firstName = data.firstName;
        if (data.lastNameKana !== undefined) this.lastNameKana = data.lastNameKana;
        if (data.firstNameKana !== undefined) this.firstNameKana = data.firstNameKana;
        if (data.phone !== undefined) this.phone = data.phone;
        if (data.gender !== undefined) this.gender = data.gender;
        if (data.zipcode !== undefined) this.zipcode = data.zipcode;
        if (data.prefecture !== undefined) this.prefecture = data.prefecture;
        if (data.cityAddress !== undefined) this.cityAddress = data.cityAddress;
        if (data.birthYear !== undefined) this.birthYear = data.birthYear;
        if (data.birthMonth !== undefined) this.birthMonth = data.birthMonth;
        if (data.birthDay !== undefined) this.birthDay = data.birthDay;
        if (data.zipcode && data.prefecture) {
            this.zipSearched = true;
        }

        this.passwordMismatch = (this.password !== this.passwordConfirm);

        this.lastNameKanaError = this.lastNameKana && !this.validateKana(this.lastNameKana);
        this.firstNameKanaError = this.firstNameKana && !this.validateKana(this.firstNameKana);
        this.phoneError = this.phone && !this.validatePhone(this.phone);
        this.checkValidity();
    }
}