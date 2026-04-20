@isTest
public with sharing class JobCardsControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // 企業（Account）を作成
        Account acc = new Account(Name = 'テスト企業');
        insert acc;
        
        // Job__c を作成（必須フィールドを設定）
        List<Job__c> jobs = new List<Job__c>();
        for (Integer i = 1; i <= 5; i++) {
            Job__c job = new Job__c(
                Company__c = acc.Id,
                Name = '求人' + i,
                JobPosition__c = 'ポジション' + i + '／福利厚生充実',
                JobDescription__c = '仕事内容' + i,
                MinAnnualSalary__c = 400 + i * 50,
                MaxAnnualSalary__c = 600 + i * 50,
                WorkLocation2__c = '東京都千代田区' + i,
                JobCategory1__c = 'IT系（ソフトウェア/ネットワーク）',
                LatestPhase__c = 'オープン',
                JobUrgencyLevel__c = '緊急度S（積極採用）',
                TargetGender__c = '不問',
                EmploymentType__c = '正社員',
                CompanyNamePublic__c = '可',
                InputLanguage__c = '日本語',
                WorkLocationRegion__c = '関東'
            );
            jobs.add(job);
        }
        insert jobs;
        
        // 現在のユーザーが「気になる」として登録したレコードを作成（最初の2件を登録）
        List<InterestedJob__c> favList = new List<InterestedJob__c>();
        for (Integer i = 0; i < 2; i++) {
            favList.add(new InterestedJob__c(
                Job__c = jobs[i].Id,
                IsArchive__c = false
            ));
        }
        insert favList;
        
        // アーカイブ済みの「気になる」レコードも作成（検証用）
        InterestedJob__c archivedFav = new InterestedJob__c(
            Job__c = jobs[2].Id,
            IsArchive__c = true
        );
        insert archivedFav;
    }
    
    @isTest
    static void testGetJobs() {
        Test.startTest();
        List<JobCardsController.JobWrapper> results = JobCardsController.getJobs();
        Test.stopTest();
        
        // 全 Job__c は5件だが、LIMIT 10 により全て返る
        Assert.areEqual(5, results.size(), '全求人が返却されるべき');
        
        // ソート順の確認（LastModifiedDate DESC）
        for (Integer i = 0; i < results.size() - 1; i++) {
            Assert.isTrue(results[i].LastModifiedDate >= results[i+1].LastModifiedDate,
                'LastModifiedDate が降順で並んでいること');
        }
        
        // お気に入りフラグの検証
        // 最初の2件はお気に入り登録済み（IsArchive__c = false）
        Assert.isTrue(results[0].IsFavorite, '最初の求人はお気に入りであるべき');
        Assert.isTrue(results[1].IsFavorite, '2番目の求人もお気に入りであるべき');
        // 3件目はアーカイブ済みのためお気に入りではない
        Assert.isFalse(results[2].IsFavorite, 'アーカイブ済みの求人はお気に入りフラグが false であるべき');
        // 4,5件目は未登録
        Assert.isFalse(results[3].IsFavorite, '未登録の求人はお気に入りフラグが false であるべき');
        Assert.isFalse(results[4].IsFavorite, '未登録の求人はお気に入りフラグが false であるべき');
        
        // フィールドのマッピングが正しいか検証
        Job__c firstJob = [SELECT Id, JobPosition__c, WorkLocation2__c, JobCategory1__c,
                                  MaxAnnualSalary__c, MinAnnualSalary__c, JobDescription__c,
                                  LastModifiedDate, LastViewedDate
                           FROM Job__c ORDER BY LastModifiedDate DESC LIMIT 1];
        JobCardsController.JobWrapper firstWrapper = results[0];
        Assert.areEqual(firstJob.Id, firstWrapper.Id, 'ID が一致すること');
        Assert.areEqual(firstJob.JobPosition__c, firstWrapper.JobPosition, 'JobPosition が一致すること');
        Assert.areEqual(firstJob.MinAnnualSalary__c, firstWrapper.MinAnnualSalary, 'MinAnnualSalary が一致すること');
        Assert.areEqual(firstJob.MaxAnnualSalary__c, firstWrapper.MaxAnnualSalary, 'MaxAnnualSalary が一致すること');
    }
    
    @isTest
    static void testToggleFavoriteJobAddNew() {
        // 未登録の求人を1件取得（setup内の4番目の求人）
        Job__c targetJob = [SELECT Id FROM Job__c WHERE Name = '求人4' LIMIT 1];
        
        // 事前確認：お気に入りレコードが存在しないこと
        List<InterestedJob__c> before = [SELECT Id FROM InterestedJob__c 
                                         WHERE Job__c = :targetJob.Id AND IsArchive__c = false];
        Assert.areEqual(0, before.size(), '初期状態では未登録');
        
        Test.startTest();
        Boolean result = JobCardsController.toggleFavoriteJob(targetJob.Id, true);
        Test.stopTest();
        
        Assert.isTrue(result, '処理が成功すること');
        
        // 確認：新規レコードが作成され、IsArchive__c = false であること
        List<InterestedJob__c> after = [SELECT Id, IsArchive__c FROM InterestedJob__c 
                                        WHERE Job__c = :targetJob.Id];
        Assert.areEqual(1, after.size(), 'レコードが1件作成されている');
        Assert.isFalse(after[0].IsArchive__c, 'IsArchive__c が false であること');
    }
    
    @isTest
    static void testToggleFavoriteJobArchive() {
        // 既にお気に入り登録されている求人（setup内の1番目）
        Job__c targetJob = [SELECT Id FROM Job__c WHERE Name = '求人1' LIMIT 1];
        
        // 事前確認：お気に入りレコードが存在し、未アーカイブであること
        InterestedJob__c existing = [SELECT Id, IsArchive__c FROM InterestedJob__c 
                                     WHERE Job__c = :targetJob.Id AND IsArchive__c = false];
        Assert.isNotNull(existing, '事前にお気に入りレコードが存在する');
        Assert.isFalse(existing.IsArchive__c, '初期状態は未アーカイブ');
        
        Test.startTest();
        // isFavorite = false を渡す → アーカイブに変更
        Boolean result = JobCardsController.toggleFavoriteJob(targetJob.Id, false);
        Test.stopTest();
        
        Assert.isTrue(result, '処理が成功すること');
        
        // 確認：既存レコードの IsArchive__c が true に更新されている
        InterestedJob__c updated = [SELECT Id, IsArchive__c FROM InterestedJob__c 
                                    WHERE Id = :existing.Id];
        Assert.isTrue(updated.IsArchive__c, 'IsArchive__c が true に更新されている');
    }
    
    @isTest
    static void testToggleFavoriteJobWhenAlreadyArchived() {
        // アーカイブ済みのお気に入りレコード（setup内の3番目の求人）
        Job__c targetJob = [SELECT Id FROM Job__c WHERE Name = '求人3' LIMIT 1];
        
        // 事前確認：アーカイブ済みのレコードが存在する
        InterestedJob__c archived = [SELECT Id, IsArchive__c FROM InterestedJob__c 
                                     WHERE Job__c = :targetJob.Id AND IsArchive__c = true];
        Assert.isNotNull(archived, 'アーカイブ済みレコードが存在する');
        
        Test.startTest();
        // isFavorite = true を渡す → アーカイブを解除（IsArchive__c = false）
        Boolean result = JobCardsController.toggleFavoriteJob(targetJob.Id, true);
        Test.stopTest();
        
        Assert.isTrue(result, '処理が成功すること');
        
        // 確認：既存レコードの IsArchive__c が false に更新されている
        InterestedJob__c updated = [SELECT Id, IsArchive__c FROM InterestedJob__c 
                                    WHERE Id = :archived.Id];
        Assert.isFalse(updated.IsArchive__c, 'アーカイブが解除されている');
    }
    
    @isTest
    static void testToggleFavoriteJobInvalidJobId() {
        Id fakeId = 'a0B000000000001'; // 存在しないID
        Test.startTest();
        Boolean result = JobCardsController.toggleFavoriteJob(fakeId, true);
        Test.stopTest();
        
        // 存在しないIDの場合、例外が発生せず false が返ることを確認
        Assert.isFalse(result, '存在しないIDの場合は false を返す');
    }
}