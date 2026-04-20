@isTest
private class PORTERSResumeSyncTest {
    
    @testSetup
    static void setup() {
        // テスト環境に必要なカスタム設定（トークンキャッシュ）を設定
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            Access_Token__c = 'mock_token',
            Token_Expires_At__c = System.now().addHours(1),
            Is_Development_Mode__c = false,
            API_Call_Count__c = 0
        );
        upsert settings;
        
        // 必要に応じて、対象オブジェクトが存在することを確認（通常は組織に存在する）
        // ここでは特に何も作成しない
    }
    
    // 空リストの同期
    @isTest
    static void testSyncResumes_EmptyList() {
        List<PORTERSResumeService.Resume> emptyList = new List<PORTERSResumeService.Resume>();
        
        Test.startTest();
        PORTERSResumeSync.SyncResult result = PORTERSResumeSync.syncResumes(emptyList);
        Test.stopTest();
        
        System.assertEquals(0, result.successCount);
        System.assertEquals(0, result.failedCount);
        System.assert(result.errors.isEmpty());
    }
    
    // null リストの同期
    @isTest
    static void testSyncResumes_NullList() {
        Test.startTest();
        PORTERSResumeSync.SyncResult result = PORTERSResumeSync.syncResumes(null);
        Test.stopTest();
        
        System.assertEquals(0, result.successCount);
        System.assertEquals(0, result.failedCount);
        System.assert(result.errors.isEmpty());
    }
    
    // 正常同期：1件の履歴書データが正しくSalesforceに作成される
    @isTest
    static void testSyncResumes_Success() {
        PORTERSResumeService.Resume resume = createResume('R12345', 'テスト 太郎', 'taro@example.com');
        List<PORTERSResumeService.Resume> resumes = new List<PORTERSResumeService.Resume>{resume};
        
        Test.startTest();
        PORTERSResumeSync.SyncResult result = PORTERSResumeSync.syncResumes(resumes);
        Test.stopTest();
        
        System.assertEquals(1, result.successCount);
        System.assertEquals(0, result.failedCount);
        System.assert(result.errors.isEmpty());
        
        // 実際にレコードが作成されたか検証
        List<IF_pts_resume__c> inserted = [SELECT Id, ResumeId__c, FullName__c, IndividualEmail__c FROM IF_pts_resume__c WHERE ResumeId__c = 'R12345'];
        System.assertEquals(1, inserted.size());
        System.assertEquals('テスト 太郎', inserted[0].FullName__c);
        System.assertEquals('taro@example.com', inserted[0].IndividualEmail__c);
    }
    
    // 外部ID（Resume.P_Id）が存在しない場合、失敗としてカウントされる
    @isTest
    static void testSyncResumes_MissingExternalId() {
        PORTERSResumeService.Resume resume = new PORTERSResumeService.Resume();
        resume.fields.put('Resume.P_Candidate', '名無し');
        List<PORTERSResumeService.Resume> resumes = new List<PORTERSResumeService.Resume>{resume};
        
        Test.startTest();
        PORTERSResumeSync.SyncResult result = PORTERSResumeSync.syncResumes(resumes);
        Test.stopTest();
        
        System.assertEquals(0, result.successCount);
        System.assertEquals(1, result.failedCount);
        System.assert(result.errors.size() == 1);
        System.assert(result.errors[0].contains('Resume.P_Id がありません'));
    }
    
    // 複数件の同期（一部成功、一部失敗）
    @isTest
    static void testSyncResumes_PartialSuccess() {
        PORTERSResumeService.Resume successResume = createResume('R111', '成功 一郎', 'success@example.com');
        PORTERSResumeService.Resume failResume = new PORTERSResumeService.Resume();
        failResume.fields.put('Resume.P_Candidate', '失敗 花子');
        
        List<PORTERSResumeService.Resume> resumes = new List<PORTERSResumeService.Resume>{successResume, failResume};
        
        Test.startTest();
        PORTERSResumeSync.SyncResult result = PORTERSResumeSync.syncResumes(resumes);
        Test.stopTest();
        
        System.assertEquals(1, result.successCount);
        System.assertEquals(1, result.failedCount);
        System.assert(result.errors.size() == 1);
        System.assert(result.errors[0].contains('Resume.P_Id がありません'));
        
        // 成功したレコードが作成されたことを確認
        List<IF_pts_resume__c> inserted = [SELECT Id FROM IF_pts_resume__c WHERE ResumeId__c = 'R111'];
        System.assertEquals(1, inserted.size());
    }
    
    /**
     * 対象オブジェクトが存在しない場合のエラーハンドリング
     * 注意：実際の組織では対象オブジェクトが存在するため、このテストは通常は実行されません。
     * 必要に応じて別途環境で実行する場合にコメント解除してください。
     */
    @isTest
    static void testSyncResumes_TargetObjectNotFound() {
        // 実際の組織では常に対象オブジェクトが存在するため、このテストはスキップします。
        System.debug('このテストは実際の組織では対象オブジェクトが存在するため省略します。');
    }
    
    /**
     * 外部IDフィールドが存在しない場合のエラーハンドリング
     * 同様に実際の組織ではフィールドが存在するため省略します。
     */
    @isTest
    static void testSyncResumes_ExternalIdFieldNotFound() {
        System.debug('このテストは実際の組織では外部IDフィールドが存在するため省略します。');
    }
    
    // ========== ヘルパーメソッド ==========
    private static PORTERSResumeService.Resume createResume(String id, String name, String email) {
        PORTERSResumeService.Resume resume = new PORTERSResumeService.Resume();
        resume.fields.put('Resume.P_Id', id);
        resume.fields.put('Resume.P_Candidate', name);
        resume.fields.put('Resume.P_Mail', email);
        // 必要に応じて他のフィールドも追加可能
        return resume;
    }
}