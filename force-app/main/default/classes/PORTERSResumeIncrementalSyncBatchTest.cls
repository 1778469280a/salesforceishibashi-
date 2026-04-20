@isTest
private class PORTERSResumeIncrementalSyncBatchTest {
    
    @testSetup
    static void setup() {
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            Access_Token__c = 'mock_token',
            Token_Expires_At__c = System.now().addHours(1),
            Is_Development_Mode__c = false,
            API_Call_Count__c = 0,
            LastResumeSyncTime__c = null
        );
        upsert settings;
    }
    
    // 正常同期：1件のデータを取得し、Salesforceにupsertされることを確認
    @isTest
    static void testSyncWithData() {
        Test.setMock(HttpCalloutMock.class, new ResumeDataMock(1));
        
        Test.startTest();
        Database.executeBatch(new PORTERSResumeIncrementalSyncBatch(), 1);
        Test.stopTest();
        
        List<IF_pts_resume__c> inserted = [SELECT Id, ResumeId__c FROM IF_pts_resume__c];
        System.assertEquals(1, inserted.size());
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.LastResumeSyncTime__c);
    }
    
    // 空データの場合、同期は行われず、最終同期日時も更新されない
    @isTest
    static void testSyncWithEmptyData() {
        Test.setMock(HttpCalloutMock.class, new EmptyResumeMock());
        
        Test.startTest();
        Database.executeBatch(new PORTERSResumeIncrementalSyncBatch(), 1);
        Test.stopTest();
        
        List<IF_pts_resume__c> inserted = [SELECT Id FROM IF_pts_resume__c];
        System.assertEquals(0, inserted.size());
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(null, settings.LastResumeSyncTime__c);
    }
    
    // 部分失敗：外部IDがないレコードを含む場合、成功した分のみ同期され、最終同期日時は更新される
    @isTest
    static void testSyncWithPartialFailure() {
        Test.setMock(HttpCalloutMock.class, new PartialFailureMock());
        
        Test.startTest();
        Database.executeBatch(new PORTERSResumeIncrementalSyncBatch(), 1);
        Test.stopTest();
        
        List<IF_pts_resume__c> inserted = [SELECT Id, ResumeId__c FROM IF_pts_resume__c];
        System.assertEquals(1, inserted.size());
        System.assertEquals('R111', inserted[0].ResumeId__c);
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.LastResumeSyncTime__c);
    }
    
    // execute内で例外が発生した場合、最終同期日時は更新されない
    @isTest
    static void testSyncWithException() {
        Test.setMock(HttpCalloutMock.class, new ApiErrorMock());
        
        Test.startTest();
        Database.executeBatch(new PORTERSResumeIncrementalSyncBatch(), 1);
        Test.stopTest();
        
        List<IF_pts_resume__c> inserted = [SELECT Id FROM IF_pts_resume__c];
        System.assertEquals(0, inserted.size());
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(null, settings.LastResumeSyncTime__c);
    }
    
    // ========== Mock クラス ==========
    
    private class ResumeDataMock implements HttpCalloutMock {
        private Integer count;
        public ResumeDataMock(Integer count) {
            this.count = count;
        }
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String xml = '<?xml version="1.0" encoding="UTF-8"?>';
            xml += '<Resume Total="' + count + '" Count="' + count + '" Start="0">';
            xml += '<Code>0</Code>';
            for (Integer i = 1; i <= count; i++) {
                String id = 'R' + i;
                xml += '<Item>';
                xml += '<Resume.P_Id>' + id + '</Resume.P_Id>';
                xml += '<Resume.P_Candidate>テスト 太郎' + i + '</Resume.P_Candidate>';
                xml += '</Item>';
            }
            xml += '</Resume>';
            res.setBody(xml);
            return res;
        }
    }
    
    private class EmptyResumeMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><Resume Total="0" Count="0" Start="0"><Code>0</Code></Resume>');
            return res;
        }
    }
    
    private class PartialFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String xml = '<?xml version="1.0" encoding="UTF-8"?>';
            xml += '<Resume Total="2" Count="2" Start="0">';
            xml += '<Code>0</Code>';
            xml += '<Item><Resume.P_Id>R111</Resume.P_Id><Resume.P_Candidate>成功 一郎</Resume.P_Candidate></Item>';
            xml += '<Item><Resume.P_Candidate>失敗 花子</Resume.P_Candidate></Item>';
            xml += '</Resume>';
            res.setBody(xml);
            return res;
        }
    }
    
    private class ApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String xml = '<?xml version="1.0" encoding="UTF-8"?>';
            xml += '<Resume><Code>999</Code><Message>Test error</Message></Resume>';
            res.setBody(xml);
            return res;
        }
    }
}