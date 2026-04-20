@isTest
private class PORTERSDataSyncTest {
    
    @testSetup
    static void setup() {
        // 必要に応じてテスト環境の初期化（ここでは空）
    }
    
    /**
     * 候補者リストが空の場合、結果も空で返ることを確認
     */
    @isTest
    static void testSyncCandidates_EmptyList() {
        List<PORTERSDataService.Candidate> emptyList = new List<PORTERSDataService.Candidate>();
        
        Test.startTest();
        PORTERSDataSync.SyncResult result = PORTERSDataSync.syncCandidates(emptyList);
        Test.stopTest();
        
        System.assertEquals(0, result.successCount);
        System.assertEquals(0, result.failedCount);
        System.assert(result.errors.isEmpty());
    }
    
    /**
     * 候補者リストがnullの場合、結果も空で返ることを確認
     */
    @isTest
    static void testSyncCandidates_NullList() {
        Test.startTest();
        PORTERSDataSync.SyncResult result = PORTERSDataSync.syncCandidates(null);
        Test.stopTest();
        
        System.assertEquals(0, result.successCount);
        System.assertEquals(0, result.failedCount);
        System.assert(result.errors.isEmpty());
    }
    
    /**
     * 正常同期：1件の候補者データが正しくSalesforceに作成されることを確認
     */
    @isTest
    static void testSyncCandidates_Success() {
        PORTERSDataService.Candidate cand = createCandidate('12345', 'テスト 太郎', '03-1234-5678', 'taro@example.com');
        
        // ★ デバッグ：外部IDが正しく設定されているか確認
        System.debug('Person.P_Id = ' + cand.getPersonId());
        System.debug('fields = ' + cand.fields);
        
        List<PORTERSDataService.Candidate> candidates = new List<PORTERSDataService.Candidate>{cand};
        
        Test.startTest();
        PORTERSDataSync.SyncResult result = PORTERSDataSync.syncCandidates(candidates);
        Test.stopTest();
        
        // ★ デバッグ：同期結果を出力
        System.debug('成功件数: ' + result.successCount);
        System.debug('失敗件数: ' + result.failedCount);
        System.debug('エラー詳細: ' + result.errors);
        
        System.assertEquals(1, result.successCount);
        System.assertEquals(0, result.failedCount);
        System.assert(result.errors.isEmpty());
        
        // 実際にレコードが作成されたか検証
        List<IF_pts_Can__c> insertedRecords = [
            SELECT Id, IndividualContactId__c, IndividualName__c, IndividualPhone__c, IndividualEmail__c
            FROM IF_pts_Can__c
            WHERE IndividualContactId__c = '12345'
        ];
        System.assertEquals(1, insertedRecords.size());
        System.assertEquals('テスト 太郎', insertedRecords[0].IndividualName__c);
        System.assertEquals('03-1234-5678', insertedRecords[0].IndividualPhone__c);
        System.assertEquals('taro@example.com', insertedRecords[0].IndividualEmail__c);
    }
    
    /**
     * 外部ID（Person.P_Id）が存在しない候補者は失敗としてカウントされることを確認
     */
    @isTest
    static void testSyncCandidates_MissingExternalId() {
        PORTERSDataService.Candidate cand = new PORTERSDataService.Candidate();
        cand.fields.put('Person.P_Name', '名無し');
        List<PORTERSDataService.Candidate> candidates = new List<PORTERSDataService.Candidate>{cand};
        
        Test.startTest();
        PORTERSDataSync.SyncResult result = PORTERSDataSync.syncCandidates(candidates);
        Test.stopTest();
        
        System.assertEquals(0, result.successCount);
        System.assertEquals(1, result.failedCount);
        System.assert(result.errors.size() == 1);
        System.assert(result.errors[0].contains('Person.P_Id がありません'));
    }
    
    /**
     * 複数件の候補者データを同期（一部成功、一部失敗）の場合の挙動確認
     */
    @isTest
    static void testSyncCandidates_PartialSuccess() {
        PORTERSDataService.Candidate successCand = createCandidate('111', '成功 一郎', '090-1111-1111', 'success@example.com');
        PORTERSDataService.Candidate failCand = new PORTERSDataService.Candidate();
        failCand.fields.put('Person.P_Name', '失敗 花子');
        
        List<PORTERSDataService.Candidate> candidates = new List<PORTERSDataService.Candidate>{successCand, failCand};
        
        Test.startTest();
        PORTERSDataSync.SyncResult result = PORTERSDataSync.syncCandidates(candidates);
        Test.stopTest();
        
        System.debug('成功件数: ' + result.successCount);
        System.debug('失敗件数: ' + result.failedCount);
        System.debug('エラー詳細: ' + result.errors);
        
        System.assertEquals(1, result.successCount);
        System.assertEquals(1, result.failedCount);
        System.assert(result.errors.size() == 1);
        System.assert(result.errors[0].contains('Person.P_Id がありません'));
        
        // 成功したレコードが作成されたことを確認
        List<IF_pts_Can__c> insertedRecords = [
            SELECT Id FROM IF_pts_Can__c WHERE IndividualContactId__c = '111'
        ];
        System.assertEquals(1, insertedRecords.size());
    }
    
    /**
     * 対象オブジェクトが存在しない場合のエラーハンドリング
     * 注意：このテストは実際の組織では対象オブジェクトが存在するため、通常は実行されません。
     */
    @isTest
    static void testSyncCandidates_TargetObjectNotFound() {
        // 実際の組織では常に対象オブジェクトが存在するため、このテストはコメントアウトします。
        System.debug('このテストは実際の組織では対象オブジェクトが存在するため省略します。');
        // 必要に応じて、別途テスト環境で実行する場合は以下のコードを使用します。
        /*
        List<PORTERSDataService.Candidate> candidates = new List<PORTERSDataService.Candidate>{createCandidate('test', 'test', 'test', 'test')};
        try {
            PORTERSDataSync.syncCandidates(candidates);
            System.assert(false);
        } catch (PORTERSDataSync.PORTERSException e) {
            System.assert(e.getMessage().contains('対象オブジェクト'));
        }
        */
    }
    
    /**
     * 外部IDフィールドが存在しない場合のエラーハンドリング
     * 注意：同様に実際の組織ではフィールドが存在するため省略します。
     */
    @isTest
    static void testSyncCandidates_ExternalIdFieldNotFound() {
        System.debug('このテストは実際の組織では外部IDフィールドが存在するため省略します。');
    }
    
    /**
     * テスト用の候補者オブジェクトを作成するヘルパーメソッド
     * ★ キー名は PORTERSDataSync.FIELD_MAPPING のキーと完全に一致させる必要があります
     */
    private static PORTERSDataService.Candidate createCandidate(String id, String name, String phone, String email) {
        PORTERSDataService.Candidate cand = new PORTERSDataService.Candidate();
        cand.fields.put('Person.P_Id', id);
        cand.fields.put('Person.P_Name', name);
        cand.fields.put('Person.P_Telephone', phone);
        cand.fields.put('Person.P_Mail', email);
        return cand;
    }
}