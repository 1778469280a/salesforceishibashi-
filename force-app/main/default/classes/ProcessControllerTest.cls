@isTest
public with sharing class ProcessControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // クライアント（企業）の作成
        Account account1 = new Account(Name = 'テスト会社1');
        Account account2 = new Account(Name = 'テスト会社2');
        insert new List<Account>{account1, account2};
        
        // Job__c（求人）の作成
        Job__c job1 = new Job__c(
            Company__c = account1.Id,
            Name = 'エンジニア',
            JobPosition__c = 'エンジニア',
            JobCategory1__c = 'IT系（ソフトウェア/ネットワーク）',
            WorkLocation2__c = '東京都千代田区'
        );
        Job__c job2 = new Job__c(
            Company__c = account1.Id,
            Name = '営業',
            JobPosition__c = '営業',
            JobCategory1__c = '営業系',
            WorkLocation2__c = '大阪府大阪市'
        );
        Job__c job3 = new Job__c(
            Company__c = account2.Id,
            Name = 'デザイナー',
            JobPosition__c = 'デザイナー',
            JobCategory1__c = null,
            WorkLocation2__c = null
        );
        insert new List<Job__c>{job1, job2, job3};
        
        // SelectionProcess__c レコードの作成（有効な選択リスト値のみ使用）
        List<SelectionProcess__c> processes = new List<SelectionProcess__c>();
        
        processes.add(new SelectionProcess__c(
            JobPosition__c = job1.Id,
            LatestProcessStatus__c = 'JOB打診'
        ));
        processes.add(new SelectionProcess__c(
            JobPosition__c = job1.Id,
            LatestProcessStatus__c = '求人詳細問合せ'
        ));
        processes.add(new SelectionProcess__c(
            JobPosition__c = job2.Id,
            LatestProcessStatus__c = '応募承諾'
        ));
        processes.add(new SelectionProcess__c(
            JobPosition__c = job2.Id,
            LatestProcessStatus__c = '面接（一次）'
        ));
        processes.add(new SelectionProcess__c(
            JobPosition__c = job3.Id,
            LatestProcessStatus__c = '内定'
        ));
        // 無効な '辞退済み' を有効な 'クローズ' に変更
        processes.add(new SelectionProcess__c(
            JobPosition__c = job3.Id,
            LatestProcessStatus__c = 'クローズ'
        ));
        
        // JobPosition__c が null のレコード（有効なステータスを使用）
        processes.add(new SelectionProcess__c(
            JobPosition__c = null,
            LatestProcessStatus__c = 'JOB打診'
        ));
        
        // LatestProcessStatus__c が null のレコード
        processes.add(new SelectionProcess__c(
            JobPosition__c = job1.Id,
            LatestProcessStatus__c = null
        ));
        
        insert processes;
    }
    
    @isTest
    static void testGetProcessesBasic() {
        Test.startTest();
        List<SelectionProcess__c> results = ProcessController.getProcesses();
        Test.stopTest();
        
        // 有効なレコードは6件（JobPosition__c null の1件 + LatestProcessStatus__c null の1件を除外）
        Assert.areEqual(6, results.size(), '有効なステータスを持つレコードは6件であるべき');
        
        for (SelectionProcess__c proc : results) {
            Assert.isNotNull(proc.JobPosition__r, 'JobPosition__r は null ではありません');
            Assert.isNotNull(proc.JobPosition__r.Company__r, 'Company__r は null ではありません');
        }
    }
    
    @isTest
    static void testGetProcessesExcludesNullStatus() {
        Test.startTest();
        List<SelectionProcess__c> results = ProcessController.getProcesses();
        Test.stopTest();
        
        for (SelectionProcess__c proc : results) {
            Assert.isNotNull(proc.LatestProcessStatus__c, 
                'LatestProcessStatus__c が null のレコードは含まれていません');
        }
    }
    
    @isTest
    static void testGetProcessesExcludesNullJobPosition() {
        // JobPosition__c = null でステータスが非空のレコードを追加作成
        SelectionProcess__c nullJobProc = new SelectionProcess__c(
            JobPosition__c = null,
            LatestProcessStatus__c = 'JOB打診'   // 有効な値
        );
        insert nullJobProc;
        
        Test.startTest();
        List<SelectionProcess__c> results = ProcessController.getProcesses();
        Test.stopTest();
        
        Boolean found = false;
        for (SelectionProcess__c proc : results) {
            if (proc.Id == nullJobProc.Id) found = true;
        }
        Assert.isFalse(found, 'JobPosition__c が null のレコードは返却されるべきではありません');
    }
    
    @isTest
    static void testGetProcessesLargeDataVolume() {
        List<Job__c> jobs = [SELECT Id FROM Job__c LIMIT 1];
        if (jobs.isEmpty()) {
            Account tempClient = new Account(Name = 'TempCompany');
            insert tempClient;
            Job__c tempJob = new Job__c(Company__c = tempClient.Id, Name = 'TempJob');
            insert tempJob;
            jobs = new List<Job__c>{tempJob};
        }
        Id jobId = jobs[0].Id;
        
        List<SelectionProcess__c> largeList = new List<SelectionProcess__c>();
        for (Integer i = 0; i < 200; i++) {
            largeList.add(new SelectionProcess__c(
                JobPosition__c = jobId,
                LatestProcessStatus__c = '応募承諾'
            ));
        }
        insert largeList;
        
        Test.startTest();
        List<SelectionProcess__c> results = ProcessController.getProcesses();
        Test.stopTest();
        
        Assert.isTrue(results.size() >= 200, '大量データでも全件返却されるべき');
    }
    
    @isTest
    static void testGetProcessesCacheBehavior() {
        Test.startTest();
        List<SelectionProcess__c> firstCall = ProcessController.getProcesses();
        List<SelectionProcess__c> secondCall = ProcessController.getProcesses();
        Test.stopTest();
        
        Assert.areEqual(firstCall.size(), secondCall.size(), 
            'cacheable=true により同じクエリ結果が返るべき');
        Set<Id> firstIds = new Map<Id, SelectionProcess__c>(firstCall).keySet();
        Set<Id> secondIds = new Map<Id, SelectionProcess__c>(secondCall).keySet();
        Assert.areEqual(firstIds, secondIds, '返却されたレコードIDのセットが一致する');
    }
    
    @isTest
    static void testGetProcessesEmptyResult() {
        delete [SELECT Id FROM SelectionProcess__c];
        
        Test.startTest();
        List<SelectionProcess__c> results = ProcessController.getProcesses();
        Test.stopTest();
        
        Assert.areEqual(0, results.size(), 'データが存在しない場合は空リストを返す');
    }
    
    @isTest
    static void testGetProcessesWithVariousStatusValues() {
        Set<String> expectedStatuses = new Set<String>{
            'JOB打診', '求人詳細問合せ', '応募承諾', '面接（一次）', '内定', 'クローズ'
        };
        
        Test.startTest();
        List<SelectionProcess__c> results = ProcessController.getProcesses();
        Test.stopTest();
        
        Set<String> actualStatuses = new Set<String>();
        for (SelectionProcess__c proc : results) {
            actualStatuses.add(proc.LatestProcessStatus__c);
        }
        
        for (String status : expectedStatuses) {
            Assert.isTrue(actualStatuses.contains(status), 
                '期待するステータス「' + status + '」が結果に含まれていません');
        }
    }
    
    @isTest
    static void testGetProcessesHandlesNullChildFields() {
        Account newClient = new Account(Name = 'NullFieldCo');
        insert newClient;
        Job__c jobWithNulls = new Job__c(
            Company__c = newClient.Id,
            Name = 'NullJob',
            JobCategory1__c = null,
            WorkLocation2__c = null
        );
        insert jobWithNulls;
        
        SelectionProcess__c nullFieldProc = new SelectionProcess__c(
            JobPosition__c = jobWithNulls.Id,
            LatestProcessStatus__c = '応募承諾'
        );
        insert nullFieldProc;
        
        Test.startTest();
        List<SelectionProcess__c> results = ProcessController.getProcesses();
        Test.stopTest();
        
        SelectionProcess__c found = null;
        for (SelectionProcess__c proc : results) {
            if (proc.Id == nullFieldProc.Id) {
                found = proc;
                break;
            }
        }
        Assert.isNotNull(found, '新規レコードが返却されていません');
        Assert.isNull(found.JobPosition__r.JobCategory1__c, 'JobCategory1__c は null のまま');
        Assert.isNull(found.JobPosition__r.WorkLocation2__c, 'WorkLocation2__c は null のまま');
    }
}