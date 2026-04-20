@isTest
public with sharing class RegistrationInfoControllerTest {

    // 有効な選択リスト値を動的に取得するヘルパー
    private static String getValidPicklistValue(Schema.SObjectField field, String defaultValue) {
        List<String> validValues = new List<String>();
        Schema.DescribeFieldResult fieldDesc = field.getDescribe();
        for (Schema.PicklistEntry entry : fieldDesc.getPicklistValues()) {
            if (entry.isActive()) {
                validValues.add(entry.getValue());
            }
        }
        return validValues.isEmpty() ? defaultValue : validValues[0];
    }

    // 完全な Person Account を作成（テストデータ用）
    private static Account createFullPersonAccount() {
        String genderValue = getValidPicklistValue(Account.Gender__pc, '男性');
        String educationValue = getValidPicklistValue(Account.FinalEducationLevel__pc, '大学卒');
        String employmentValue = getValidPicklistValue(Account.EmploymentStatus__pc, '就業中');

        Account acc = new Account(
            LastName = '山田',
            FirstName = '太郎',
            NameKanaSei__pc = 'ヤマダ',
            NameKanaMei__pc = 'タロウ',
            PersonBirthdate = Date.newInstance(1990, 1, 1),
            Gender__pc = genderValue,
            PostalCode1__c = '123-4567',
            City__c = '東京都',
            CityAndAddress__c = '千代田区1-1',
            PersonMobilePhone = '09012345678',
            FinalEducationLevel__pc = educationValue,
            SchoolFacultyDepartment__c = '工学部',
            NumberOfCompaniesWorked__c = 3,
            EmploymentStatus__pc = employmentValue,
            LicensesAndCertifications1__c = '普通自動車免許',
            ManagementExperience__c = true,
            MyPageOtherRequests__c = '特記事項なし'
        );
        insert acc;
        return acc;
    }

    // Account に紐づく Community ユーザーを作成（ContactId 経由）
    private static User createTestUserWithAccount(Id accountId) {
        Account acc = [SELECT PersonContactId FROM Account WHERE Id = :accountId];
        Id contactId = acc.PersonContactId;

        Profile communityProfile;
        try {
            communityProfile = [SELECT Id FROM Profile WHERE Name LIKE '%Customer Community%' OR Name LIKE '%Community%' LIMIT 1];
        } catch (Exception e) {
            return null;
        }

        User communityUser = new User(
            Username = 'comm_user_' + System.currentTimeMillis() + '@example.com',
            Email = 'comm@example.com',
            LastName = 'Community',
            FirstName = 'User',
            Alias = 'commu',
            TimeZoneSidKey = 'Asia/Tokyo',
            LocaleSidKey = 'ja_JP',
            EmailEncodingKey = 'UTF-8',
            ProfileId = communityProfile.Id,
            LanguageLocaleKey = 'ja',
            ContactId = contactId
        );

        try {
            insert communityUser;
            return communityUser;
        } catch (DmlException e) {
            return null;
        }
    }

    // AccountId なしの通常ユーザーを作成
    private static User createTestUserWithoutAccount() {
        Profile currentProfile = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId()];
        User testUser = new User(
            Username = 'testuser_noacc_' + System.currentTimeMillis() + '@example.com',
            Email = 'test@example.com',
            LastName = 'NoAccount',
            FirstName = 'User',
            Alias = 'noacc',
            TimeZoneSidKey = 'Asia/Tokyo',
            LocaleSidKey = 'ja_JP',
            EmailEncodingKey = 'UTF-8',
            ProfileId = currentProfile.Id,
            LanguageLocaleKey = 'ja'
        );
        insert testUser;
        return testUser;
    }

    // ========= テストメソッド =========

    @isTest
    static void testGetRegistrationInfo_WithAccount() {
        Account personAcc = createFullPersonAccount();
        User testUser = createTestUserWithAccount(personAcc.Id);
        if (testUser == null) return;

        System.runAs(testUser) {
            RegistrationInfoController.RegistrationInfoWrapper result = RegistrationInfoController.getRegistrationInfo();
            Assert.isNotNull(result);
            Assert.areEqual(personAcc.Id, result.recordId);
            Assert.areEqual('山田', result.lastName);
            Assert.areEqual('太郎', result.firstName);
        }
    }

    @isTest
    static void testGetRegistrationInfo_NoAccount() {
        User testUser = createTestUserWithoutAccount();
        System.runAs(testUser) {
            RegistrationInfoController.RegistrationInfoWrapper result = RegistrationInfoController.getRegistrationInfo();
            Assert.isNotNull(result);
            Assert.isNull(result.recordId);
        }
    }

    @isTest
    static void testGetRegistrationInfo_NullBirthdate() {
        Account personAcc = createFullPersonAccount();
        personAcc.PersonBirthdate = null;
        update personAcc;
        
        User testUser = createTestUserWithAccount(personAcc.Id);
        if (testUser == null) return;

        System.runAs(testUser) {
            RegistrationInfoController.RegistrationInfoWrapper result = RegistrationInfoController.getRegistrationInfo();
            Assert.areEqual('', result.birthdate);
        }
    }

    @isTest
    static void testGetRegistrationInfo_NullCompanyCount() {
        Account personAcc = createFullPersonAccount();
        personAcc.NumberOfCompaniesWorked__c = null;
        update personAcc;
        
        User testUser = createTestUserWithAccount(personAcc.Id);
        if (testUser == null) return;

        System.runAs(testUser) {
            RegistrationInfoController.RegistrationInfoWrapper result = RegistrationInfoController.getRegistrationInfo();
            Assert.areEqual('', result.companyCount);
        }
    }

    @isTest
    static void testUpdateRegistrationInfo_Success() {
        Account personAcc = createFullPersonAccount();

        RegistrationInfoController.RegistrationInfoWrapper updateWrapper = new RegistrationInfoController.RegistrationInfoWrapper();
        updateWrapper.recordId = personAcc.Id;
        updateWrapper.lastName = '鈴木';
        updateWrapper.firstName = '一郎';
        updateWrapper.kanaSei = 'スズキ';
        updateWrapper.kanaMei = 'イチロウ';
        updateWrapper.birthdate = '1995-05-05';
        updateWrapper.gender = getValidPicklistValue(Account.Gender__pc, '女性');
        updateWrapper.postalCode = '987-6543';
        updateWrapper.prefecture = '大阪府';
        updateWrapper.address = '大阪市北区2-3';
        updateWrapper.phone = '08098765432';
        updateWrapper.education = getValidPicklistValue(Account.FinalEducationLevel__pc, '高校卒');
        updateWrapper.school = '法学研究科';
        updateWrapper.companyCount = '5';
        updateWrapper.employmentStatus = getValidPicklistValue(Account.EmploymentStatus__pc, '就業中');
        updateWrapper.license = 'TOEIC 900';
        updateWrapper.managementExperience = 'false';
        updateWrapper.remarks = '更新後の備考';

        Test.startTest();
        RegistrationInfoController.updateRegistrationInfo(updateWrapper);
        Test.stopTest();

        Account updatedAcc = [SELECT LastName, FirstName, ManagementExperience__c, NumberOfCompaniesWorked__c
                              FROM Account WHERE Id = :personAcc.Id];
        Assert.areEqual('鈴木', updatedAcc.LastName);
        Assert.areEqual('一郎', updatedAcc.FirstName);
        Assert.areEqual(false, updatedAcc.ManagementExperience__c);
        Assert.areEqual(5, updatedAcc.NumberOfCompaniesWorked__c);
    }

    @isTest
    static void testUpdateRegistrationInfo_NullCompanyCount() {
        Account personAcc = createFullPersonAccount();

        RegistrationInfoController.RegistrationInfoWrapper updateWrapper = new RegistrationInfoController.RegistrationInfoWrapper();
        updateWrapper.recordId = personAcc.Id;
        updateWrapper.lastName = '鈴木';
        updateWrapper.firstName = '一郎';
        updateWrapper.kanaSei = 'スズキ';
        updateWrapper.kanaMei = 'イチロウ';
        updateWrapper.birthdate = '1995-05-05';
        updateWrapper.gender = getValidPicklistValue(Account.Gender__pc, '女性');
        updateWrapper.postalCode = '987-6543';
        updateWrapper.prefecture = '大阪府';
        updateWrapper.address = '大阪市北区2-3';
        updateWrapper.phone = '08098765432';
        updateWrapper.education = getValidPicklistValue(Account.FinalEducationLevel__pc, '高校卒');
        updateWrapper.school = '法学研究科';
        updateWrapper.companyCount = '';
        updateWrapper.employmentStatus = getValidPicklistValue(Account.EmploymentStatus__pc, '就業中');
        updateWrapper.license = 'TOEIC 900';
        updateWrapper.managementExperience = 'false';
        updateWrapper.remarks = '更新後の備考';

        Test.startTest();
        RegistrationInfoController.updateRegistrationInfo(updateWrapper);
        Test.stopTest();

        Account updatedAcc = [SELECT NumberOfCompaniesWorked__c FROM Account WHERE Id = :personAcc.Id];
        Assert.isNull(updatedAcc.NumberOfCompaniesWorked__c);
    }

    // companyCount が null の場合のテスト
    @isTest
    static void testUpdateRegistrationInfo_CompanyCountNull() {
        Account personAcc = createFullPersonAccount();

        RegistrationInfoController.RegistrationInfoWrapper updateWrapper = new RegistrationInfoController.RegistrationInfoWrapper();
        updateWrapper.recordId = personAcc.Id;
        updateWrapper.lastName = personAcc.LastName;
        updateWrapper.firstName = personAcc.FirstName;
        updateWrapper.kanaSei = personAcc.NameKanaSei__pc;
        updateWrapper.kanaMei = personAcc.NameKanaMei__pc;
        // 生年月日を yyyy-MM-dd 形式で設定
        updateWrapper.birthdate = '1990-01-01';
        updateWrapper.gender = personAcc.Gender__pc;
        updateWrapper.postalCode = personAcc.PostalCode1__c;
        updateWrapper.prefecture = personAcc.City__c;
        updateWrapper.address = personAcc.CityAndAddress__c;
        updateWrapper.phone = personAcc.PersonMobilePhone;
        updateWrapper.education = personAcc.FinalEducationLevel__pc;
        updateWrapper.school = personAcc.SchoolFacultyDepartment__c;
        updateWrapper.employmentStatus = personAcc.EmploymentStatus__pc;
        updateWrapper.license = personAcc.LicensesAndCertifications1__c;
        updateWrapper.managementExperience = 'true';
        updateWrapper.remarks = personAcc.MyPageOtherRequests__c;
        updateWrapper.companyCount = null;  // テスト対象

        Test.startTest();
        RegistrationInfoController.updateRegistrationInfo(updateWrapper);
        Test.stopTest();

        Account updatedAcc = [SELECT NumberOfCompaniesWorked__c FROM Account WHERE Id = :personAcc.Id];
        Assert.isNull(updatedAcc.NumberOfCompaniesWorked__c);
    }

    // 生年月日が空文字の場合のテスト
    @isTest
    static void testUpdateRegistrationInfo_BirthdateEmpty() {
        Account personAcc = createFullPersonAccount();
        Date originalBirthdate = personAcc.PersonBirthdate;
        
        RegistrationInfoController.RegistrationInfoWrapper updateWrapper = new RegistrationInfoController.RegistrationInfoWrapper();
        updateWrapper.recordId = personAcc.Id;
        updateWrapper.lastName = personAcc.LastName;
        updateWrapper.firstName = personAcc.FirstName;
        updateWrapper.kanaSei = personAcc.NameKanaSei__pc;
        updateWrapper.kanaMei = personAcc.NameKanaMei__pc;
        updateWrapper.birthdate = '';  // テスト対象
        updateWrapper.gender = personAcc.Gender__pc;
        updateWrapper.postalCode = personAcc.PostalCode1__c;
        updateWrapper.prefecture = personAcc.City__c;
        updateWrapper.address = personAcc.CityAndAddress__c;
        updateWrapper.phone = personAcc.PersonMobilePhone;
        updateWrapper.education = personAcc.FinalEducationLevel__pc;
        updateWrapper.school = personAcc.SchoolFacultyDepartment__c;
        updateWrapper.companyCount = String.valueOf(personAcc.NumberOfCompaniesWorked__c);
        updateWrapper.employmentStatus = personAcc.EmploymentStatus__pc;
        updateWrapper.license = personAcc.LicensesAndCertifications1__c;
        updateWrapper.managementExperience = 'true';
        updateWrapper.remarks = personAcc.MyPageOtherRequests__c;

        Test.startTest();
        RegistrationInfoController.updateRegistrationInfo(updateWrapper);
        Test.stopTest();

        Account updatedAcc = [SELECT PersonBirthdate FROM Account WHERE Id = :personAcc.Id];
        Assert.areEqual(originalBirthdate, updatedAcc.PersonBirthdate);
    }

    // 無効な管理経験値のテスト
    @isTest
    static void testUpdateRegistrationInfo_InvalidManagementExperience() {
        Account personAcc = createFullPersonAccount();

        RegistrationInfoController.RegistrationInfoWrapper updateWrapper = new RegistrationInfoController.RegistrationInfoWrapper();
        updateWrapper.recordId = personAcc.Id;
        updateWrapper.lastName = personAcc.LastName;
        updateWrapper.firstName = personAcc.FirstName;
        updateWrapper.kanaSei = personAcc.NameKanaSei__pc;
        updateWrapper.kanaMei = personAcc.NameKanaMei__pc;
        updateWrapper.birthdate = '1990-01-01';
        updateWrapper.gender = personAcc.Gender__pc;
        updateWrapper.postalCode = personAcc.PostalCode1__c;
        updateWrapper.prefecture = personAcc.City__c;
        updateWrapper.address = personAcc.CityAndAddress__c;
        updateWrapper.phone = personAcc.PersonMobilePhone;
        updateWrapper.education = personAcc.FinalEducationLevel__pc;
        updateWrapper.school = personAcc.SchoolFacultyDepartment__c;
        updateWrapper.companyCount = String.valueOf(personAcc.NumberOfCompaniesWorked__c);
        updateWrapper.employmentStatus = personAcc.EmploymentStatus__pc;
        updateWrapper.license = personAcc.LicensesAndCertifications1__c;
        updateWrapper.remarks = personAcc.MyPageOtherRequests__c;
        updateWrapper.managementExperience = 'maybe';  // 無効な値

        Test.startTest();
        RegistrationInfoController.updateRegistrationInfo(updateWrapper);
        Test.stopTest();

        Account updatedAcc = [SELECT ManagementExperience__c FROM Account WHERE Id = :personAcc.Id];
        Assert.isNull(updatedAcc.ManagementExperience__c);
    }

    @isTest
    static void testUpdateRegistrationInfo_InvalidRecordId() {
        RegistrationInfoController.RegistrationInfoWrapper invalidWrapper = new RegistrationInfoController.RegistrationInfoWrapper();
        invalidWrapper.recordId = '001000000000000AAA';
        invalidWrapper.lastName = '存在しない';

        Exception caughtException = null;
        try {
            RegistrationInfoController.updateRegistrationInfo(invalidWrapper);
        } catch (Exception e) {
            caughtException = e;
        }
        Assert.isNotNull(caughtException);
    }

    @isTest
    static void testUpdateRegistrationInfo_NullWrapper() {
        Exception caughtException = null;
        try {
            RegistrationInfoController.updateRegistrationInfo(null);
        } catch (Exception e) {
            caughtException = e;
        }
        Assert.isNotNull(caughtException);
    }

    @isTest
    static void testGetPicklistValues() {
        Test.startTest();
        List<Map<String, String>> prefectures = RegistrationInfoController.getPrefecturePicklistValues();
        List<Map<String, String>> educations = RegistrationInfoController.getEducationPicklistValues();
        List<Map<String, String>> employments = RegistrationInfoController.getEmploymentPicklistValues();
        Test.stopTest();

        Assert.isTrue(prefectures.size() > 0);
        Assert.areEqual('都道府県を選択', prefectures[0].get('label'));
        Assert.areEqual('', prefectures[0].get('value'));

        for (Map<String, String> opt : educations) {
            Assert.isTrue(String.isNotBlank(opt.get('value')));
        }
        for (Map<String, String> opt : employments) {
            Assert.isTrue(String.isNotBlank(opt.get('value')));
        }
    }
}