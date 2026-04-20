@isTest
public with sharing class InterestedJobControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // 企業（Account）を作成
        Account acc = new Account(Name = 'テスト企業');
        insert acc;
        
        // JOB__c を作成（有効な選択リスト値を使用）
        Job__c job1 = new Job__c(
            Company__c = acc.Id,
            Name = '求人1',
            JobPosition__c = 'エンジニア／福利厚生充実',
            JobDescription__c = 'ソフトウェア開発業務',
            MinAnnualSalary__c = 500,
            MaxAnnualSalary__c = 700,
            WorkLocation2__c = '東京都渋谷区',
            JobCategory1__c = 'IT系（ソフトウェア/ネットワーク）',  // 修正：正しい選択リスト値
            LatestPhase__c = 'オープン',                           // 必須項目
            JobUrgencyLevel__c = '緊急度S（積極採用）',            // 必須項目
            TargetGender__c = '不問',                              // 必須項目
            EmploymentType__c = '正社員',                          // 必須項目
            CompanyNamePublic__c = '可',                           // 必須項目
            InputLanguage__c = '日本語',                           // 必須項目
            WorkLocationRegion__c = '関東'                         // 必須項目
        );
        Job__c job2 = new Job__c(
            Company__c = acc.Id,
            Name = '求人2',
            JobPosition__c = '営業／未経験歓迎',
            JobDescription__c = '法人営業',
            MinAnnualSalary__c = 400,
            MaxAnnualSalary__c = 600,
            WorkLocation2__c = '大阪府大阪市',
            JobCategory1__c = '営業系',                            // 営業系は有効
            LatestPhase__c = 'オープン',
            JobUrgencyLevel__c = '緊急度S（積極採用）',
            TargetGender__c = '不問',
            EmploymentType__c = '正社員',
            CompanyNamePublic__c = '可',
            InputLanguage__c = '日本語',
            WorkLocationRegion__c = '関西'
        );
        insert new List<Job__c>{job1, job2};
        
        // InterestedJob__c を作成（IsArchive__c = false のもの）
        List<InterestedJob__c> interestedList = new List<InterestedJob__c>();
        interestedList.add(new InterestedJob__c(Job__c = job1.Id, IsArchive__c = false));
        interestedList.add(new InterestedJob__c(Job__c = job2.Id, IsArchive__c = false));
        // アーカイブ済みのレコードも作成（検索結果から除外されることを確認するため）
        interestedList.add(new InterestedJob__c(Job__c = job1.Id, IsArchive__c = true));
        insert interestedList;
    }
    
    @isTest
    static void testGetInterestedJobs() {
        Test.startTest();
        List<InterestedJob__c> results = InterestedJobController.getInterestedJobs();
        Test.stopTest();
        
        // IsArchive__c = false のレコードのみ返却される（2件）
        Assert.areEqual(2, results.size(), '未アーカイブのレコードのみ返却されるべき');
        
        // ソート順の確認（LastModifiedDate DESC）
        Assert.isTrue(results[0].LastModifiedDate >= results[1].LastModifiedDate,
            'LastModifiedDate が降順で並んでいること');
        
        // リレーション項目が正しく取得されているか確認
        Assert.isNotNull(results[0].Job__r, 'Job__r が null ではない');
        Assert.isNotNull(results[0].Job__r.JobPosition__c, 'JobPosition__c が取得できている');
        Assert.isNotNull(results[0].Job__r.MinAnnualSalary__c, 'MinAnnualSalary__c が取得できている');
    }
    
    @isTest
    static void testArchiveSingleJob() {
        // 事前に未アーカイブのレコードを1件取得
        InterestedJob__c target = [SELECT Id, IsArchive__c FROM InterestedJob__c WHERE IsArchive__c = false LIMIT 1];
        Assert.isFalse(target.IsArchive__c, '初期状態はアーカイブされていない');
        
        Test.startTest();
        InterestedJobController.archiveSingleJob(target.Id);
        Test.stopTest();
        
        // 更新後、アーカイブフラグが true になっていることを確認
        InterestedJob__c updated = [SELECT Id, IsArchive__c FROM InterestedJob__c WHERE Id = :target.Id];
        Assert.isTrue(updated.IsArchive__c, 'archiveSingleJob によりアーカイブフラグが true になるべき');
    }
    
    @isTest
    static void testArchiveBulkJobs() {
        // 未アーカイブのレコードを2件取得
        List<InterestedJob__c> targets = [SELECT Id, IsArchive__c FROM InterestedJob__c WHERE IsArchive__c = false];
        Assert.areEqual(2, targets.size(), '事前に2件の未アーカイブレコードが存在');
        
        List<Id> jobIds = new List<Id>();
        for (InterestedJob__c rec : targets) {
            jobIds.add(rec.Id);
        }
        
        Test.startTest();
        InterestedJobController.archiveBulkJobs(jobIds);
        Test.stopTest();
        
        // すべての対象レコードがアーカイブされたか確認
        List<InterestedJob__c> updatedList = [SELECT Id, IsArchive__c FROM InterestedJob__c WHERE Id IN :jobIds];
        for (InterestedJob__c rec : updatedList) {
            Assert.isTrue(rec.IsArchive__c, '一括アーカイブによりフラグが true になるべき');
        }
        
        // 再度 getInterestedJobs を呼び出し、結果が0件であることを確認
        List<InterestedJob__c> remaining = InterestedJobController.getInterestedJobs();
        Assert.areEqual(0, remaining.size(), 'すべてアーカイブされたため、未アーカイブは0件');
    }
    
    @isTest
    static void testGetInterestedJobsEmpty() {
        // すべての InterestedJob__c をアーカイブ
        List<InterestedJob__c> all = [SELECT Id FROM InterestedJob__c];
        for (InterestedJob__c rec : all) {
            rec.IsArchive__c = true;
        }
        update all;
        
        Test.startTest();
        List<InterestedJob__c> results = InterestedJobController.getInterestedJobs();
        Test.stopTest();
        
        Assert.areEqual(0, results.size(), '未アーカイブが0件の場合は空リストを返す');
    }
}