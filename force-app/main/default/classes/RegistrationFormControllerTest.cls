@isTest
public with sharing class RegistrationFormControllerTest {
    private static final String RT_NAME = '求職者';
    private static final String PROFILE_NAME = '求職者';
    private static final String TEST_EMAIL = 'test.jobseeker@example.com';

    @testSetup
    static void setUpTestData() {
    }

    /**
     * 正常系テスト：有効なデータで登録処理を実行し、正常に完了することを検証
     */
    @isTest
    static void testSaveRegistrationWithValidData() {
        Map<String, Object> testData = new Map<String, Object>{
            'lastName' => '田中',
            'firstName' => '太郎',
            'lastNameKana' => 'タナカ',
            'firstNameKana' => 'タロウ',
            'email' => TEST_EMAIL,
            'birthDate' => '1990-01-15',
            'phone' => '09012345678',
            'gender' => '男性',
            'zipcode' => '1000001',
            'prefecture' => '東京都',
            'cityAddress' => '千代田区',
            'desiredDate' => '2025-04-01',
            'location1' => '東京都',
            'location2' => '神奈川県',
            'location3' => '千葉県',
            'selectedSalary' => '201万円～300万円',
            'selectedCategories' => '営業系',
            'transfer' => '不可',
            'selectedEducation' => '大学卒',
            'schoolDetail' => 'テスト大学',
            'employmentStatus' => '就業中',
            'companyCount' => '2社',
            'companyName' => 'テスト株式会社',
            'startDate' => '2020-04',
            'endDate' => '2024-03',
            'currentSalary' => '301万円～400万円',
            'jobDescription' => '開発業務',
            'selectedExperienceCategories' => '営業系',
            'selectedExperienceOptions' => '営業(法人);営業(個人);代理店営業;海外営業;プリセールス・営業支援;その他営業'
        };

        Test.startTest();
        Id accountId = RegistrationFormController.saveRegistration(testData);
        Test.stopTest();

        Account acc = [SELECT Id, PersonContactId FROM Account WHERE Id = :accountId];
        User usr = [SELECT Id FROM User WHERE ContactId = :acc.PersonContactId];

        // 標準Assertで書き換え
        System.assert(accountId != null, 'Account IDが取得できません');
        System.assert(acc.PersonContactId != null, '担当者が作成されていません');
        System.assert(usr.Id != null, 'ユーザーが作成されていません');
    }

    /**
     * 異常系テスト：データがNullの場合、エラーが発生することを検証
     */
    @isTest
    static void testSaveRegistrationWithNullData() {
        Test.startTest();
        try {
            RegistrationFormController.saveRegistration(null);
            System.assert(false, '例外が発生しませんでした');
        } catch (AuraHandledException e) {
            System.assertEquals('登録データがありません。', e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * 異常系テスト：無効な日付形式の場合、日付が設定されないことを検証
     */
    @isTest
    static void testSaveRegistrationWithInvalidDate() {
        Map<String, Object> testData = new Map<String, Object>{
            'lastName' => '佐藤',
            'firstName' => '花子',
            'email' => 'test2@example.com',
            'birthDate' => '1990/01/01'
        };

        Test.startTest();
        Id accountId = RegistrationFormController.saveRegistration(testData);
        Test.stopTest();

        Account acc = [SELECT PersonBirthdate FROM Account WHERE Id = :accountId];
        System.assert(acc.PersonBirthdate == null, '不正な日付が設定されています');
    }

    /**
     * 境界テスト：前職情報が存在しない場合、正常に登録されることを検証
     */
    @isTest
    static void testSaveRegistrationWithoutPreviousJob() {
        Map<String, Object> testData = new Map<String, Object>{
            'lastName' => '高橋',
            'firstName' => '健',
            'email' => 'test3@example.com',
            'birthDate' => '1995-05-05',
            'employmentStatus' => '未経験',
            'companyCount' => '0社'
        };

        Test.startTest();
        Id accountId = RegistrationFormController.saveRegistration(testData);
        Test.stopTest();

        Account acc = [SELECT EmployerName1__c FROM Account WHERE Id = :accountId];
        System.assert(acc.EmployerName1__c == null, '前職情報が不要なのに設定されています');
    }
}