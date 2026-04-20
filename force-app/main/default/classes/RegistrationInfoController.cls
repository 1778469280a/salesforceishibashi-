/**
 * 登録情報管理コントローラ（Person Account版）
 * 現在のログインユーザーに関連するAccountの基本情報を取得・更新します。
 */
public with sharing class RegistrationInfoController {

    // 登録情報を画面とやり取りするためのラッパークラス
    public class RegistrationInfoWrapper {
        @AuraEnabled public String recordId { get; set; }
        @AuraEnabled public String lastName { get; set; }
        @AuraEnabled public String firstName { get; set; }
        @AuraEnabled public String kanaSei { get; set; }
        @AuraEnabled public String kanaMei { get; set; }
        @AuraEnabled public String birthdate { get; set; }
        @AuraEnabled public String gender { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        @AuraEnabled public String prefecture { get; set; }
        @AuraEnabled public String address { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String education { get; set; }
        @AuraEnabled public String school { get; set; }
        @AuraEnabled public String companyCount { get; set; }
        @AuraEnabled public String employmentStatus { get; set; }
        @AuraEnabled public String license { get; set; }
        @AuraEnabled public String managementExperience { get; set; }
        @AuraEnabled public String remarks { get; set; }
    }

    /**
     * 現在のユーザーに関連付けられたPerson Accountの情報を取得する
     * @return RegistrationInfoWrapper 取得した情報を格納したラッパー（Accountが無い場合は空のラッパー）
     */
    @AuraEnabled
    public static RegistrationInfoWrapper getRegistrationInfo() {
        try {
            User currentUser = [SELECT Id, AccountId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            if (currentUser.AccountId == null) {
                return new RegistrationInfoWrapper();
            }

            // Person Account の各項目を取得（__pc は Person Account のカスタム項目）
            Account acc = [
                SELECT Id, LastName, FirstName, NameKanaSei__pc, NameKanaMei__pc,
                       PersonBirthdate, Gender__pc, PostalCode1__c, City__c, CityAndAddress__c,
                       PersonMobilePhone, FinalEducationLevel__pc, SchoolFacultyDepartment__c,
                       NumberOfCompaniesWorked__c, EmploymentStatus__pc, LicensesAndCertifications1__c,
                       ManagementExperience__c, MyPageOtherRequests__c
                FROM Account
                WHERE Id = :currentUser.AccountId
                LIMIT 1
            ];

            return buildWrapper(acc);
        } catch (Exception e) {
            throw new AuraHandledException('情報取得エラー: ' + e.getMessage());
        }
    }

    /**
     * ユーザーが編集した登録情報を更新する
     * @param wrapper 画面から送信された更新データ
     */
    @AuraEnabled(cacheable=false)
    public static void updateRegistrationInfo(RegistrationInfoWrapper wrapper) {
        if (wrapper == null || String.isBlank(wrapper.recordId)) {
            throw new AuraHandledException('有効なレコードIDが指定されていません。');
        }

        try {
            Account acc = [SELECT Id FROM Account WHERE Id = :wrapper.recordId LIMIT 1];

            // 基本情報のマッピング
            acc.LastName = wrapper.lastName;
            acc.FirstName = wrapper.firstName;
            acc.NameKanaSei__pc = wrapper.kanaSei;
            acc.NameKanaMei__pc = wrapper.kanaMei;

            if (String.isNotBlank(wrapper.birthdate)) {
                acc.PersonBirthdate = Date.valueOf(wrapper.birthdate);
            }
            acc.Gender__pc = wrapper.gender;
            acc.PostalCode1__c = wrapper.postalCode;
            acc.City__c = wrapper.prefecture;      // 都道府県フィールド
            acc.CityAndAddress__c = wrapper.address; // 市区町村以降の住所
            acc.PersonMobilePhone = wrapper.phone;
            acc.FinalEducationLevel__pc = wrapper.education;
            acc.SchoolFacultyDepartment__c = wrapper.school;

            // 経験社数：数値変換、空の場合はnull
            if (String.isNotBlank(wrapper.companyCount)) {
                acc.NumberOfCompaniesWorked__c = Integer.valueOf(wrapper.companyCount);
            } else {
                acc.NumberOfCompaniesWorked__c = null;
            }

            acc.EmploymentStatus__pc = wrapper.employmentStatus;
            acc.LicensesAndCertifications1__c = wrapper.license;
            acc.ManagementExperience__c = convertManagementStringToBoolean(wrapper.managementExperience);
            acc.MyPageOtherRequests__c = wrapper.remarks;

            update acc;
        } catch (Exception e) {
            throw new AuraHandledException('更新エラー: ' + e.getMessage());
        }
    }

    // --- ピックリスト取得メソッド（キャッシュ可能） ---

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getPrefecturePicklistValues() {
        // 都道府県ピックリスト → 先頭に「都道府県を選択」の空オプションを追加
        return getPicklistValuesWithEmpty(Account.City__c, '都道府県を選択');
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEducationPicklistValues() {
        // 最終学歴ピックリスト → 空オプションなし
        return getPicklistValuesWithoutEmpty(Account.FinalEducationLevel__pc);
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getEmploymentPicklistValues() {
        // 就業状況ピックリスト → 空オプションなし
        return getPicklistValuesWithoutEmpty(Account.EmploymentStatus__pc);
    }

    // 空オプション（選択してください）付きでピックリスト値を取得
    private static List<Map<String, String>> getPicklistValuesWithEmpty(Schema.SObjectField field, String emptyLabel) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        Map<String, String> emptyOption = new Map<String, String>();
        emptyOption.put('label', emptyLabel);
        emptyOption.put('value', '');
        options.add(emptyOption);

        try {
            Schema.DescribeFieldResult fieldResult = field.getDescribe();
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', entry.getLabel());
                option.put('value', entry.getValue());
                options.add(option);
            }
        } catch (Exception e) {
            System.debug('ピックリスト取得エラー: ' + e.getMessage());
        }
        return options;
    }

    // 空オプションなしでピックリスト値を取得
    private static List<Map<String, String>> getPicklistValuesWithoutEmpty(Schema.SObjectField field) {
        List<Map<String, String>> options = new List<Map<String, String>>();
        try {
            Schema.DescribeFieldResult fieldResult = field.getDescribe();
            for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
                Map<String, String> option = new Map<String, String>();
                option.put('label', entry.getLabel());
                option.put('value', entry.getValue());
                options.add(option);
            }
        } catch (Exception e) {
            System.debug('ピックリスト取得エラー: ' + e.getMessage());
        }
        return options;
    }

    // マネジメント経験の文字列（"true"/"false"）をBooleanに変換
    private static Boolean convertManagementStringToBoolean(String mgmtStr) {
        if (mgmtStr == 'true') return true;
        if (mgmtStr == 'false') return false;
        return null;
    }

    // マネジメント経験のBooleanを文字列（"true"/"false"）に変換（画面表示用）
    private static String convertManagementBooleanToString(Boolean mgmtBool) {
        if (mgmtBool == true) return 'true';
        if (mgmtBool == false) return 'false';
        return '';
    }

    // Accountオブジェクトからラッパーを作成
    private static RegistrationInfoWrapper buildWrapper(Account acc) {
        RegistrationInfoWrapper w = new RegistrationInfoWrapper();
        w.recordId = acc.Id;
        w.lastName = acc.LastName;
        w.firstName = acc.FirstName;
        w.kanaSei = acc.NameKanaSei__pc;
        w.kanaMei = acc.NameKanaMei__pc;
        // 生年月日は yyyy-MM-dd 形式で文字列化（日本フォーマットではなくISOに合わせる）
        w.birthdate = acc.PersonBirthdate != null ? acc.PersonBirthdate.format() : '';
        w.gender = acc.Gender__pc;
        w.postalCode = acc.PostalCode1__c;
        w.prefecture = acc.City__c;
        w.address = acc.CityAndAddress__c;
        w.phone = acc.PersonMobilePhone;
        w.education = acc.FinalEducationLevel__pc;
        w.school = acc.SchoolFacultyDepartment__c;
        w.companyCount = acc.NumberOfCompaniesWorked__c != null ? String.valueOf(acc.NumberOfCompaniesWorked__c) : '';
        w.employmentStatus = acc.EmploymentStatus__pc;
        w.license = acc.LicensesAndCertifications1__c;
        w.managementExperience = convertManagementBooleanToString(acc.ManagementExperience__c);
        w.remarks = acc.MyPageOtherRequests__c;
        return w;
    }
}