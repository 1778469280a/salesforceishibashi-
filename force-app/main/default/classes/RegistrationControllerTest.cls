@isTest
public with sharing class RegistrationControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // 現在のユーザーのプロファイルを使用（内部ユーザーであることを保証）
        Profile currentProfile = [SELECT Id FROM Profile WHERE Id = :UserInfo.getProfileId() LIMIT 1];
        
        // 既存ユーザーを作成（現在のプロファイルを使用）
        User existingUser = new User(
            Username = 'existing@test.com',
            Email = 'existing@test.com',
            LastName = 'Existing',
            Alias = 'exist',
            TimeZoneSidKey = 'Asia/Tokyo',
            LocaleSidKey = 'ja_JP',
            EmailEncodingKey = 'UTF-8',
            ProfileId = currentProfile.Id,
            LanguageLocaleKey = 'ja'
        );
        insert existingUser;
        
        // メールテンプレートを作成（テキスト形式、レターヘッド不要）
        EmailTemplate template = new EmailTemplate(
            DeveloperName = 'EmailTemplateetst',
            Name = 'Test Verification Template',
            Subject = 'テスト用メール',
            Body = '認証URL: {!VerificationUrl}',
            TemplateType = 'text',
            FolderId = UserInfo.getUserId()
        );
        insert template;
    }
    
    // メールアドレスが空白の場合
    @isTest
    static void testCheckAndSendEmailBlank() {
        Test.startTest();
        RegistrationController.Result result = RegistrationController.checkAndSendEmail('');
        Test.stopTest();
        
        Assert.areEqual('Error', result.type);
        Assert.areEqual('有効なメールアドレスを入力してください。', result.message);
    }
    
    // 既存ユーザーの場合
    @isTest
    static void testCheckAndSendEmailExistingUser() {
        Test.startTest();
        RegistrationController.Result result = RegistrationController.checkAndSendEmail('existing@test.com');
        Test.stopTest();
        
        Assert.areEqual('ExistingUser', result.type);
        Assert.areEqual('既に登録済みのユーザーです。', result.message);
    }
    
    // 新規ユーザーの場合
    @isTest
    static void testCheckAndSendEmailNewUser() {
        Test.startTest();
        RegistrationController.Result result = RegistrationController.checkAndSendEmail('newuser@example.com');
        Test.stopTest();
        
        Assert.areEqual('NewUser', result.type);
        Assert.areEqual('仮登録メールを送信しました。', result.message);
    }
    
    // メールテンプレートが存在しない場合のエラーハンドリング
    @isTest
    static void testSendTestVerificationEmailNoTemplate() {
        Test.startTest();
        // テンプレートを削除
        delete [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'EmailTemplateetst'];
        RegistrationController.sendTestVerificationEmail('test@example.com', 'https://test.com/portal');
        Test.stopTest();
    }
    
    // メール本文が空の場合のエラーハンドリング
    @isTest
    static void testSendTestVerificationEmailEmptyBody() {
        EmailTemplate template = [SELECT Id FROM EmailTemplate WHERE DeveloperName = 'EmailTemplateetst' LIMIT 1];
        template.Body = null;
        update template;
        
        Test.startTest();
        RegistrationController.sendTestVerificationEmail('test@example.com', 'https://test.com/portal');
        Test.stopTest();
    }
    
    // 組織全体のメールアドレスが存在しない場合のエラーハンドリング
    @isTest
    static void testSendTestVerificationEmailNoOrgWideEmail() {
        Test.startTest();
        RegistrationController.sendTestVerificationEmail('test@example.com', 'https://test.com/portal');
        Test.stopTest();
    }
}