@isTest
private class PORTERSResumeServiceTest {
    
    // テスト用のサンプルXML（1件のItem、簡易フィールド）
    private static final String SINGLE_ITEM_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Resume Total="1" Count="1" Start="0">' +
        '  <Code>0</Code>' +
        '  <Item>' +
        '    <Resume.P_Id>R12345</Resume.P_Id>' +
        '    <Resume.P_Candidate>テスト 太郎</Resume.P_Candidate>' +
        '    <Resume.P_Mail>taro@example.com</Resume.P_Mail>' +
        '  </Item>' +
        '</Resume>';
    
    // 2ページ分のデータ（2件）を返すXML（最初の1ページ目）
    private static final String PAGE1_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Resume Total="2" Count="1" Start="0">' +
        '  <Code>0</Code>' +
        '  <Item>' +
        '    <Resume.P_Id>R111</Resume.P_Id>' +
        '    <Resume.P_Candidate>山田 一郎</Resume.P_Candidate>' +
        '  </Item>' +
        '</Resume>';
    
    private static final String PAGE2_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Resume Total="2" Count="1" Start="1">' +
        '  <Code>0</Code>' +
        '  <Item>' +
        '    <Resume.P_Id>R222</Resume.P_Id>' +
        '    <Resume.P_Candidate>佐藤 花子</Resume.P_Candidate>' +
        '  </Item>' +
        '</Resume>';
    
    // APIエラー応答（Code=101）
    private static final String API_ERROR_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Resume>' +
        '  <Code>101</Code>' +
        '  <Message>Invalid scope</Message>' +
        '</Resume>';
    
    @testSetup
    static void setup() {
        // 有効なトークンをカスタム設定に設定（認証モックが不要になる）
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            Access_Token__c = 'mock_token',
            Token_Expires_At__c = System.now().addHours(1),
            Is_Development_Mode__c = false,
            API_Call_Count__c = 0
        );
        upsert settings;
    }
    
    // ========== 正常系テスト ==========
    
    @isTest
    static void testGetAllResumes_SinglePage() {
        Test.setMock(HttpCalloutMock.class, new SinglePageMock());
        
        Test.startTest();
        List<PORTERSResumeService.Resume> resumes = PORTERSResumeService.getAllResumes(null);
        Test.stopTest();
        
        System.assertEquals(1, resumes.size());
        System.assertEquals('R12345', resumes[0].getResumeId());
        System.assertEquals('テスト 太郎', resumes[0].getCandidateName());
    }
    
    @isTest
    static void testGetAllResumes_MultiPage() {
        Test.setMock(HttpCalloutMock.class, new MultiPageMock());
        
        Test.startTest();
        List<PORTERSResumeService.Resume> resumes = PORTERSResumeService.getAllResumes(null);
        Test.stopTest();
        
        System.assertEquals(2, resumes.size());
        System.assertEquals('R111', resumes[0].getResumeId());
        System.assertEquals('山田 一郎', resumes[0].getCandidateName());
        System.assertEquals('R222', resumes[1].getResumeId());
        System.assertEquals('佐藤 花子', resumes[1].getCandidateName());
    }
    
    @isTest
    static void testGetAllResumes_WithMaxRecords() {
        Test.setMock(HttpCalloutMock.class, new MultiPageMock());
        
        Test.startTest();
        List<PORTERSResumeService.Resume> resumes = PORTERSResumeService.getAllResumes(1);
        Test.stopTest();
        
        System.assertEquals(1, resumes.size());
        System.assertEquals('R111', resumes[0].getResumeId());
    }
    
    @isTest
    static void testGetResumesSince_WithCondition() {
        Test.setMock(HttpCalloutMock.class, new ConditionMock());
        
        Datetime lastSync = Datetime.newInstance(2023, 1, 1, 0, 0, 0);
        Test.startTest();
        List<PORTERSResumeService.Resume> resumes = PORTERSResumeService.getResumesSince(null, lastSync);
        Test.stopTest();
        
        System.assertEquals(1, resumes.size());
        // 条件の検証は Mock 内で実施済み
    }
    
    @isTest
    static void testGetResumesSince_NoCondition() {
        Test.setMock(HttpCalloutMock.class, new NoConditionMock());
        
        Test.startTest();
        List<PORTERSResumeService.Resume> resumes = PORTERSResumeService.getResumesSince(null, null);
        Test.stopTest();
        
        System.assertEquals(1, resumes.size());
    }
    
    // ========== エラー系テスト ==========
    
    @isTest
    static void testGetAllResumes_ApiErrorCode() {
        Test.setMock(HttpCalloutMock.class, new ApiErrorMock());
        
        Test.startTest();
        try {
            PORTERSResumeService.getAllResumes(null);
            System.assert(false, '例外が発生しなかった');
        } catch (PORTERSResumeService.PORTERSException e) {
            System.assert(e.getMessage().contains('APIエラー: 101'), '適切なエラーメッセージ');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAllResumes_HttpError() {
        Test.setMock(HttpCalloutMock.class, new HttpErrorMock());
        
        Test.startTest();
        try {
            PORTERSResumeService.getAllResumes(null);
            System.assert(false, '例外が発生しなかった');
        } catch (PORTERSResumeService.PORTERSException e) {
            System.assert(e.getMessage().contains('キャンディデイトデータの取得に失敗しました'), '適切なエラーメッセージ');
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetResumesSince_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new EmptyResponseMock());
        
        Test.startTest();
        List<PORTERSResumeService.Resume> resumes = PORTERSResumeService.getResumesSince(null, null);
        Test.stopTest();
        
        System.assertEquals(0, resumes.size());
    }
    
    // ========== Mock クラス ==========
    
    private class SinglePageMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(SINGLE_ITEM_XML);
            return res;
        }
    }
    
    private class MultiPageMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (callCount == 1) {
                res.setBody(PAGE1_XML);
            } else {
                res.setBody(PAGE2_XML);
            }
            return res;
        }
    }
    
    private class ConditionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String url = req.getEndpoint();
            System.assert(url.contains('condition='), 'conditionパラメータが含まれていること');
            String encodedCondition = EncodingUtil.urlEncode('Resume.P_UpdateDate>', 'UTF-8');
            System.assert(url.contains(encodedCondition), '条件が正しくエンコードされていること');
            
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(SINGLE_ITEM_XML);
            return res;
        }
    }
    
    private class NoConditionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String url = req.getEndpoint();
            System.assert(!url.contains('condition='), 'conditionパラメータが含まれていないこと');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(SINGLE_ITEM_XML);
            return res;
        }
    }
    
    private class ApiErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(API_ERROR_XML);
            return res;
        }
    }
    
    private class HttpErrorMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    private class EmptyResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><Resume Total="0" Count="0" Start="0"><Code>0</Code></Resume>');
            return res;
        }
    }
}