@isTest
public with sharing class OfferComponentControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // 企業（Account）を作成
        Account acc = new Account(Name = 'テスト企業');
        insert acc;
        
        // Job__c を作成（必須フィールドを設定）
        List<Job__c> jobs = new List<Job__c>();
        for (Integer i = 1; i <= 3; i++) {
            Job__c job = new Job__c(
                Company__c = acc.Id,
                Name = '求人' + i,
                JobPosition__c = 'ポジション' + i,
                JobDescription__c = '仕事内容' + i,
                MinAnnualSalary__c = 400 + i * 50,
                MaxAnnualSalary__c = 600 + i * 50,
                WorkLocation2__c = '勤務地' + i,
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
        
        // SelectionProcess__c を作成（LatestProcessStatus__c = 'JOB打診' のもの）
        List<SelectionProcess__c> processes = new List<SelectionProcess__c>();
        for (Integer i = 0; i < 2; i++) {
            processes.add(new SelectionProcess__c(
                JobPosition__c = jobs[i].Id,
                LatestProcessStatus__c = 'JOB打診'
            ));
        }
        // ステータスが異なるレコード（カウントに含まれない）
        processes.add(new SelectionProcess__c(
            JobPosition__c = jobs[2].Id,
            LatestProcessStatus__c = '応募承諾'
        ));
        insert processes;
    }
    
    // 正常系：オファーが存在する場合
    @isTest
    static void testGetOffersWithData() {
        Test.startTest();
        Map<String, Object> result = OfferComponentController.getOffers();
        Test.stopTest();
        
        Assert.isNotNull(result, '結果がnullではない');
        Assert.isTrue(result.containsKey('totalCount'), 'totalCountキーが存在する');
        Assert.isTrue(result.containsKey('jobInfos'), 'jobInfosキーが存在する');
        
        Integer totalCount = (Integer)result.get('totalCount');
        List<Object> jobInfos = (List<Object>)result.get('jobInfos');
        
        Assert.areEqual(2, totalCount, 'JOB打診のレコード数は2件');
        Assert.areEqual(2, jobInfos.size(), '取得される求人情報は最大2件');
        
        // 各ジョブ情報のフィールドを検証
        for (Object obj : jobInfos) {
            Map<String, Object> jobInfo = (Map<String, Object>)obj;
            Assert.isTrue(jobInfo.containsKey('jobId'), 'jobIdが含まれる');
            Assert.isTrue(jobInfo.containsKey('JobPosition'), 'JobPositionが含まれる');
            Assert.isTrue(jobInfo.containsKey('companyName'), 'companyNameが含まれる');
            Assert.isTrue(jobInfo.containsKey('lastUpdate'), 'lastUpdateが含まれる');
            Assert.isNotNull(jobInfo.get('jobId'), 'jobIdはnullではない');
        }
    }
    
    // オファーが0件の場合
    @isTest
    static void testGetOffersEmpty() {
        // すべての SelectionProcess__c を削除
        delete [SELECT Id FROM SelectionProcess__c];
        
        Test.startTest();
        Map<String, Object> result = OfferComponentController.getOffers();
        Test.stopTest();
        
        Integer totalCount = (Integer)result.get('totalCount');
        List<Object> jobInfos = (List<Object>)result.get('jobInfos');
        
        Assert.areEqual(0, totalCount, 'レコードがない場合は0');
        Assert.areEqual(0, jobInfos.size(), '空リストが返る');
    }
    
    // リレーション先が null の場合のハンドリング
    @isTest
    static void testGetOffersWithNullRelations() {
        // JobPosition__c が null の SelectionProcess__c を作成
        SelectionProcess__c nullJobProc = new SelectionProcess__c(
            JobPosition__c = null,
            LatestProcessStatus__c = 'JOB打診'
        );
        insert nullJobProc;
        
        Test.startTest();
        Map<String, Object> result = OfferComponentController.getOffers();
        Test.stopTest();
        
        Integer totalCount = (Integer)result.get('totalCount');
        List<Object> jobInfos = (List<Object>)result.get('jobInfos');
        
        // カウント：初期2件 + nullJobProc 1件 = 3件（'応募承諾'は除外）
        Assert.areEqual(3, totalCount, 'nullJobProc もカウントに含まれる');
        // LIMIT 2 により jobInfos は最大2件
        Assert.areEqual(2, jobInfos.size(), 'LIMIT 2 により最大2件が返る');
        
        for (Object obj : jobInfos) {
            Map<String, Object> jobInfo = (Map<String, Object>)obj;
            // 関連フィールドが null の場合でもエラーにならないことを確認
            Assert.isTrue(jobInfo.containsKey('JobPosition'));
        }
    }
    
    // 日付フォーマットのテスト（最終更新日が正しく文字列変換されるか）
    @isTest
    static void testGetOffersDateFormat() {
        Test.startTest();
        Map<String, Object> result = OfferComponentController.getOffers();
        Test.stopTest();
        
        List<Object> jobInfos = (List<Object>)result.get('jobInfos');
        for (Object obj : jobInfos) {
            Map<String, Object> jobInfo = (Map<String, Object>)obj;
            String lastUpdate = (String)jobInfo.get('lastUpdate');
            System.assert(String.isNotBlank(lastUpdate), '最終更新日が文字列として取得できる');
            // 形式が「yyyy/M/d HH:mm」であることを簡易チェック
            System.assert(lastUpdate.contains('/'), '日付形式が正しい');
            System.assert(lastUpdate.contains(':'), '時刻が含まれている');
        }
    }
}