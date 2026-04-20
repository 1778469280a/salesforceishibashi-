@isTest
private class PORTERSIncrementalSyncBatchTest {
    
    @testSetup
    static void setup() {
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            Access_Token__c = 'mock_token',
            Token_Expires_At__c = System.now().addHours(1),
            Is_Development_Mode__c = false,
            API_Call_Count__c = 0
        );
        upsert settings;
    }
    
    @isTest
    static void testSyncWithData() {
        Test.setMock(HttpCalloutMock.class, new MultiPageMock(2, 150));
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.LastSyncTime__c = null;
        upsert settings;
        
        Test.startTest();
        Database.executeBatch(new PORTERSIncrementalSyncBatch(), 1);
        Test.stopTest();
        
        List<IF_pts_Can__c> inserted = [SELECT Id FROM IF_pts_Can__c];
        System.assertEquals(150, inserted.size(), '全件が同期されていること');
        
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.LastSyncTime__c, '最終同期日時が更新されていること');
    }
    
    @isTest
    static void testSyncWithEmptyData() {
        Test.setMock(HttpCalloutMock.class, new EmptyResponseMock());
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.LastSyncTime__c = null;
        upsert settings;
        
        Test.startTest();
        Database.executeBatch(new PORTERSIncrementalSyncBatch(), 1);
        Test.stopTest();
        
        List<IF_pts_Can__c> inserted = [SELECT Id FROM IF_pts_Can__c];
        System.assertEquals(0, inserted.size());
        
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(null, settings.LastSyncTime__c, '空データでは同期日時が更新されないこと');
    }
    
    @isTest
    static void testSyncWithPartialFailure() {
        Test.setMock(HttpCalloutMock.class, new PartialFailureMock());
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.LastSyncTime__c = null;
        upsert settings;
        
        Test.startTest();
        Database.executeBatch(new PORTERSIncrementalSyncBatch(), 1);
        Test.stopTest();
        
        List<IF_pts_Can__c> inserted = [SELECT Id FROM IF_pts_Can__c];
        System.assertEquals(1, inserted.size());
        
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertNotEquals(null, settings.LastSyncTime__c, '部分成功時は同期日時が更新されること');
    }
    
    @isTest
    static void testSyncWithException() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.LastSyncTime__c = null;
        upsert settings;
        
        Test.startTest();
        try {
            Database.executeBatch(new PORTERSIncrementalSyncBatch(), 1);
        } catch (Exception e) {
            // 期待される例外（start 内でスローされる）
            System.assert(e.getMessage().contains('APIエラー: 999'), '想定された例外');
        }
        Test.stopTest();
    
        // レコードが作成されていないこと
        List<IF_pts_Can__c> inserted = [SELECT Id FROM IF_pts_Can__c];
        System.assertEquals(0, inserted.size());
    
        // 最終同期日時は更新されない
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(null, settings.LastSyncTime__c, '例外発生時は同期日時が更新されないこと');
        }
    
    // ========== Mock クラス ==========
    
    private class MultiPageMock implements HttpCalloutMock {
        private Integer totalPages;
        private Integer totalRecords;
        private Integer callCount = 0;
        
        public MultiPageMock(Integer totalPages, Integer totalRecords) {
            this.totalPages = totalPages;
            this.totalRecords = totalRecords;
        }
        
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            
            // 現在のページ番号を callCount から直接決定（1-indexed）
            Integer page = callCount;
            if (page > totalPages) {
                page = totalPages; // 念のため上限を超えないように
            }
            Integer start = (page - 1) * 200;
            Integer count = Math.min(200, totalRecords - start);
            
            String xml = '<?xml version="1.0" encoding="UTF-8"?>';
            xml += '<Candidate Total="' + totalRecords + '" Count="' + count + '" Start="' + start + '">';
            xml += '<Code>0</Code>';
            
            for (Integer i = 0; i < count; i++) {
                String id = String.valueOf(start + i + 1);
                xml += '<Item>';
                xml += '<Person.P_Id>' + id + '</Person.P_Id>';
                xml += '<Person.P_Name>候補者 ' + id + '</Person.P_Name>';
                xml += '<Person.P_Telephone>090-0000-0000</Person.P_Telephone>';
                xml += '<Person.P_Mail>test' + id + '@example.com</Person.P_Mail>';
                xml += '</Item>';
            }
            xml += '</Candidate>';
            res.setBody(xml);
            return res;
        }
    }
    
    private class EmptyResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><Candidate Total="0" Count="0" Start="0"><Code>0</Code></Candidate>');
            return res;
        }
    }
    
    private class PartialFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String xml = '<?xml version="1.0" encoding="UTF-8"?>';
            xml += '<Candidate Total="2" Count="2" Start="0">';
            xml += '<Code>0</Code>';
            xml += '<Item><Person.P_Id>111</Person.P_Id><Person.P_Name>成功 一郎</Person.P_Name></Item>';
            xml += '<Item><Person.P_Name>失敗 花子</Person.P_Name></Item>';
            xml += '</Candidate>';
            res.setBody(xml);
            return res;
        }
    }
    
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            String xml = '<?xml version="1.0" encoding="UTF-8"?>';
            xml += '<Candidate><Code>999</Code><Message>Test error</Message></Candidate>';
            res.setBody(xml);
            return res;
        }
    }
}