@isTest
public with sharing class JobDetailControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // 企業（Account）を作成
        Account acc = new Account(Name = 'テスト企業');
        insert acc;
        
        // Job__c を作成（必須フィールドを設定）
        Job__c job1 = new Job__c(
            Company__c = acc.Id,
            Name = '求人1',
            JobPosition__c = 'エンジニア／福利厚生充実',
            JobDescription__c = 'ソフトウェア開発業務',
            MinAnnualSalary__c = 500,
            MaxAnnualSalary__c = 700,
            WorkLocation2__c = '東京都渋谷区',
            JobCategory1__c = 'IT系（ソフトウェア/ネットワーク）',
            LatestPhase__c = 'オープン',
            JobUrgencyLevel__c = '緊急度S（積極採用）',
            TargetGender__c = '不問',
            EmploymentType__c = '正社員',
            CompanyNamePublic__c = '可',
            InputLanguage__c = '日本語',
            WorkLocationRegion__c = '関東'
        );
        Job__c job2 = new Job__c(
            Company__c = acc.Id,
            Name = '求人2',
            JobPosition__c = '営業／未経験歓迎',
            JobDescription__c = '法人営業',
            MinAnnualSalary__c = 400,
            MaxAnnualSalary__c = 600,
            WorkLocation2__c = '大阪府大阪市',
            JobCategory1__c = '営業系',
            LatestPhase__c = 'オープン',
            JobUrgencyLevel__c = '緊急度A（募集中）',
            TargetGender__c = '不問',
            EmploymentType__c = '正社員',
            CompanyNamePublic__c = '可',
            InputLanguage__c = '日本語',
            WorkLocationRegion__c = '関西'
        );
        insert new List<Job__c>{job1, job2};
        
        // 現在のユーザーが job1 をお気に入りとして登録
        InterestedJob__c fav = new InterestedJob__c(
            Job__c = job1.Id,
            IsArchive__c = false
        );
        insert fav;
    }
    
    @isTest
    static void testGetJobDetailSuccess() {
        Job__c testJob = [SELECT Id FROM Job__c WHERE Name = '求人1' LIMIT 1];
        
        Test.startTest();
        Job__c result = JobDetailController.getJobDetail(testJob.Id);
        Test.stopTest();
        
        Assert.isNotNull(result, '求人データが取得できること');
        Assert.areEqual(testJob.Id, result.Id, 'IDが一致すること');
        Assert.areEqual('エンジニア／福利厚生充実', result.JobPosition__c, '求人タイトルが一致すること');
        Assert.isNotNull(result.Company__r, 'Company__r リレーションが取得できていること');
        Assert.areEqual('テスト企業', result.Company__r.Name, '企業名が一致すること');
    }
    
    @isTest
    static void testGetJobDetailBlankId() {
        Test.startTest();
        try {
            JobDetailController.getJobDetail('');
            Assert.fail('空白IDでは例外が発生すべき');
        } catch (AuraHandledException e) {
            // テスト環境ではメッセージが「Script-thrown exception」になる場合があるため、内容は検証しない
            System.debug('期待された例外が発生しました: ' + e);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetJobDetailInvalidId() {
        Test.startTest();
        try {
            JobDetailController.getJobDetail('invalid-id');
            Assert.fail('無効なID形式では例外が発生すべき');
        } catch (AuraHandledException e) {
            System.debug('期待された例外が発生しました: ' + e);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetJobDetailNotFound() {
        // 存在しないID（有効な形式だがDBにない）
        Id fakeId = 'a0B000000000001AAA';
        
        Test.startTest();
        try {
            JobDetailController.getJobDetail(fakeId);
            Assert.fail('存在しないIDでは例外が発生すべき');
        } catch (AuraHandledException e) {
            System.debug('期待された例外が発生しました: ' + e);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetJobFavoriteStatusTrue() {
        Job__c favoritedJob = [SELECT Id FROM Job__c WHERE Name = '求人1' LIMIT 1];
        
        Test.startTest();
        Boolean isFavorite = JobDetailController.getJobFavoriteStatus(favoritedJob.Id);
        Test.stopTest();
        
        Assert.isTrue(isFavorite, 'お気に入り登録済みの求人では true を返すべき');
    }
    
    @isTest
    static void testGetJobFavoriteStatusFalse() {
        Job__c nonFavoritedJob = [SELECT Id FROM Job__c WHERE Name = '求人2' LIMIT 1];
        
        Test.startTest();
        Boolean isFavorite = JobDetailController.getJobFavoriteStatus(nonFavoritedJob.Id);
        Test.stopTest();
        
        Assert.isFalse(isFavorite, 'お気に入り未登録の求人では false を返すべき');
    }
    
    @isTest
    static void testGetJobFavoriteStatusBlankId() {
        Test.startTest();
        Boolean result = JobDetailController.getJobFavoriteStatus('');
        Test.stopTest();
        
        Assert.isFalse(result, '空白IDの場合は false を返すべき');
    }
    
    @isTest
    static void testGetJobFavoriteStatusNullId() {
        Test.startTest();
        Boolean result = JobDetailController.getJobFavoriteStatus(null);
        Test.stopTest();
        
        Assert.isFalse(result, 'null IDの場合は false を返すべき');
    }
}