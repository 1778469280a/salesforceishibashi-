@isTest
public with sharing class JobSearchControllerTest {
    
    @TestSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'テスト企業');
        insert acc;
        
        List<Job__c> jobs = new List<Job__c>();
        
        Job__c job1 = new Job__c(
            Company__c = acc.Id,
            Name = '求人1',
            JobPosition__c = 'エンジニア／福利厚生充実',
            JobDescription__c = 'ソフトウェア開発',
            MinAnnualSalary__c = 500,
            MaxAnnualSalary__c = 700,
            WorkLocation2__c = '東京都千代田区',
            WorkLocationRegion__c = '関東',
            WorkLocationPrefecture__c = '東京都',
            JobCategory1__c = 'IT系（ソフトウェア/ネットワーク）',
            JobCategoryDetail1__c = 'システム開発(Web/オープン系)',
            TransferRequired__c = '無し',
            SpecificConditions__c = '土日祝休み',
            LatestPhase__c = 'オープン',
            JobUrgencyLevel__c = '緊急度S（積極採用）',
            TargetGender__c = '不問',
            EmploymentType__c = '正社員',
            CompanyNamePublic__c = '可',
            InputLanguage__c = '日本語'
        );
        jobs.add(job1);
        
        Job__c job2 = new Job__c(
            Company__c = acc.Id,
            Name = '求人2',
            JobPosition__c = '営業／未経験歓迎',
            JobDescription__c = '法人営業',
            MinAnnualSalary__c = 400,
            MaxAnnualSalary__c = 600,
            WorkLocation2__c = '大阪府大阪市',
            WorkLocationRegion__c = '関西',
            WorkLocationPrefecture__c = '大阪府',
            JobCategory1__c = '営業系',
            JobCategoryDetail1__c = '営業(法人)',
            TransferRequired__c = '有り',
            SpecificConditions__c = '残業少なめ(20時間未満)',
            LatestPhase__c = 'オープン',
            JobUrgencyLevel__c = '緊急度A（募集中）',
            TargetGender__c = '不問',
            EmploymentType__c = '正社員',
            CompanyNamePublic__c = '可',
            InputLanguage__c = '日本語'
        );
        jobs.add(job2);
        
        Job__c job3 = new Job__c(
            Company__c = acc.Id,
            Name = '求人3',
            JobPosition__c = 'データサイエンティスト／最先端技術',
            JobDescription__c = 'データ分析',
            MinAnnualSalary__c = 600,
            MaxAnnualSalary__c = 800,
            WorkLocation2__c = '福岡市博多区',
            WorkLocationRegion__c = '九州/沖縄',
            WorkLocationPrefecture__c = '福岡県',
            JobCategory1__c = 'IT系（ソフトウェア/ネットワーク）',
            JobCategoryDetail1__c = 'データベースエンジニア',
            TransferRequired__c = '無し',
            SpecificConditions__c = 'リモートワーク・在宅勤務制度あり',
            LatestPhase__c = 'オープン',
            JobUrgencyLevel__c = '緊急度B（良い人がいたら）',
            TargetGender__c = '不問',
            EmploymentType__c = '正社員',
            CompanyNamePublic__c = '可',
            InputLanguage__c = '日本語',
            SearchKeywords__c = 'AI, 機械学習, データサイエンス'
        );
        jobs.add(job3);
        
        insert jobs;
        
        InterestedJob__c fav = new InterestedJob__c(
            Job__c = job1.Id,
            IsArchive__c = false
        );
        insert fav;
    }
    
    @isTest
    static void testGetJobsNoFilters() {
        Test.startTest();
        Map<String, Object> emptyFilters = new Map<String, Object>();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(emptyFilters);
        Test.stopTest();
        
        Assert.areEqual(3, results.size());
        Job__c job1 = [SELECT Id FROM Job__c WHERE Name = '求人1' LIMIT 1];
        Boolean foundFavorite = false;
        for (JobSearchController.JobWrapper j : results) {
            if (j.Id == job1.Id) {
                Assert.isTrue(j.IsFavorite);
                foundFavorite = true;
                break;
            }
        }
        Assert.isTrue(foundFavorite);
    }
    
    @isTest
    static void testGetJobsWithCategoryFilter() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('categories', new List<String>{'システム開発(Web/オープン系)'});
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('エンジニア'));
    }
    
    @isTest
    static void testGetJobsWithPrefectureFilter() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('prefectures', new List<String>{'大阪府'});
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('営業'));
    }
    
    @isTest
    static void testGetJobsWithMinSalaryFilter() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('minSalary', '550');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('データサイエンティスト'));
    }
    
    @isTest
    static void testGetJobsWithTransferFilter() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('transfer', '無し');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(2, results.size());
        Set<String> expectedPrefixes = new Set<String>{'エンジニア', 'データサイエンティスト'};
        for (JobSearchController.JobWrapper j : results) {
            String prefix = j.JobPosition.split('／')[0];
            Assert.isTrue(expectedPrefixes.contains(prefix), '想定外の求人: ' + prefix);
        }
    }
    
    @isTest
    static void testGetJobsWithConditionsFilter() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('conditions', new List<String>{'土日祝休み'});
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('エンジニア'));
    }
    
    @isTest
    static void testGetJobsWithMultipleFilters() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('categories', new List<String>{'システム開発(Web/オープン系)'});
        filters.put('prefectures', new List<String>{'東京都'});
        filters.put('minSalary', '450');
        filters.put('transfer', '無し');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('エンジニア'));
    }
    
    @isTest
    static void testGetJobsWithKeyword() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('keyword', 'AI');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('データサイエンティスト'));
    }
    
    @isTest
    static void testGetJobsWithKeywordAndFilters() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('keyword', 'AI');
        filters.put('minSalary', '550');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(1, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('データサイエンティスト'));
    }
    
    @isTest
    static void testGetJobsSortNewest() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('sortBy', 'newest');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(3, results.size());
    }
    
    @isTest
    static void testGetJobsSortHighestSalary() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('sortBy', 'highestSalary');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(3, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('データサイエンティスト'));
        Assert.isTrue(results[1].JobPosition.startsWith('エンジニア'));
        Assert.isTrue(results[2].JobPosition.startsWith('営業'));
    }
    
    @isTest
    static void testGetJobsSortLowestSalary() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('sortBy', 'lowestSalary');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(3, results.size());
        Assert.isTrue(results[0].JobPosition.startsWith('営業'));
        Assert.isTrue(results[1].JobPosition.startsWith('エンジニア'));
        Assert.isTrue(results[2].JobPosition.startsWith('データサイエンティスト'));
    }
    
    @isTest
    static void testGetJobsSortRecommended() {
        Map<String, Object> filters = new Map<String, Object>();
        filters.put('sortBy', 'recommended');
        
        Test.startTest();
        List<JobSearchController.JobWrapper> results = JobSearchController.getJobs(filters);
        Test.stopTest();
        
        Assert.areEqual(3, results.size());
    }
    
    @isTest
    static void testGetFilterOptions() {
        Test.startTest();
        Map<String, Object> options = JobSearchController.getFilterOptions();
        Test.stopTest();
        
        Assert.isTrue(options.containsKey('jobCategories'));
        Assert.isTrue(options.containsKey('regions'));
        Assert.isTrue(options.containsKey('prefectures'));
        Assert.isTrue(options.containsKey('specificConditions'));
        
        List<Object> prefectures = (List<Object>)options.get('prefectures');
        Assert.isTrue(prefectures.contains('東京都'));
        
        List<Object> conditions = (List<Object>)options.get('specificConditions');
        Assert.isTrue(conditions.contains('土日祝休み'));
    }
    
    @isTest
    static void testToggleFavoriteJob() {
        Job__c targetJob = [SELECT Id FROM Job__c WHERE Name = '求人2' LIMIT 1];
        
        List<InterestedJob__c> before = [SELECT Id FROM InterestedJob__c WHERE Job__c = :targetJob.Id AND IsArchive__c = false];
        Assert.areEqual(0, before.size());
        
        Test.startTest();
        Boolean resultAdd = JobSearchController.toggleFavoriteJob(targetJob.Id, true);
        // 追加操作の結果検証は startTest/stopTest 内で行う（stopTest はテスト終了時に自動的に呼ばれるが、ここでは明示せずに続ける）
        
        Assert.isTrue(resultAdd);
        
        List<InterestedJob__c> afterAdd = [SELECT Id, IsArchive__c FROM InterestedJob__c WHERE Job__c = :targetJob.Id];
        Assert.areEqual(1, afterAdd.size());
        Assert.isFalse(afterAdd[0].IsArchive__c);
        
        // 削除操作（同じテストメソッド内、追加の startTest は不要）
        Boolean resultRemove = JobSearchController.toggleFavoriteJob(targetJob.Id, false);
        Assert.isTrue(resultRemove);
        
        InterestedJob__c updated = [SELECT Id, IsArchive__c FROM InterestedJob__c WHERE Id = :afterAdd[0].Id];
        Assert.isTrue(updated.IsArchive__c);
        Test.stopTest();
    }
    
    @isTest
    static void testToggleFavoriteJobInvalidId() {
        Test.startTest();
        Boolean result = JobSearchController.toggleFavoriteJob('invalid-id', true);
        Test.stopTest();
        Assert.isFalse(result);
    }
    
    @isTest
    static void testToggleFavoriteJobBlankId() {
        Test.startTest();
        Boolean result = JobSearchController.toggleFavoriteJob('', true);
        Test.stopTest();
        Assert.isFalse(result);
    }
}