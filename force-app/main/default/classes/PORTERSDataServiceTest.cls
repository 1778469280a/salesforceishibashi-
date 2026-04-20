@isTest
private class PORTERSDataServiceTest {
    
    // テスト用のサンプルXML（1件のItem）
    private static final String SINGLE_ITEM_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Candidate Total="1" Count="1" Start="0">' +
        '  <Code>0</Code>' +
        '  <Item>' +
        '    <Person.P_Id>12345</Person.P_Id>' +
        '    <Person.P_Name>テスト 太郎</Person.P_Name>' +
        '    <Person.P_Telephone>03-1234-5678</Person.P_Telephone>' +
        '    <Person.P_Mail>taro@example.com</Person.P_Mail>' +
        '  </Item>' +
        '</Candidate>';
    
    // 2ページ分のデータ（2件）を返すXML（最初の1ページ目）
    private static final String PAGE1_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Candidate Total="2" Count="1" Start="0">' +
        '  <Code>0</Code>' +
        '  <Item>' +
        '    <Person.P_Id>111</Person.P_Id>' +
        '    <Person.P_Name>山田 一郎</Person.P_Name>' +
        '  </Item>' +
        '</Candidate>';
    
    private static final String PAGE2_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Candidate Total="2" Count="1" Start="1">' +
        '  <Code>0</Code>' +
        '  <Item>' +
        '    <Person.P_Id>222</Person.P_Id>' +
        '    <Person.P_Name>佐藤 花子</Person.P_Name>' +
        '  </Item>' +
        '</Candidate>';
    
    // APIエラー応答（Code=101）
    private static final String API_ERROR_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Candidate>' +
        '  <Code>101</Code>' +
        '  <Message>Invalid scope</Message>' +
        '</Candidate>';
    
    // 1ページに2件のデータを含むレスポンス
    private static final String TWO_ITEMS_IN_PAGE_XML = 
        '<?xml version="1.0" encoding="UTF-8"?>' +
        '<Candidate Total="2" Count="2" Start="0">' +
        '  <Code>0</Code>' +
        '  <Item><Person.P_Id>111</Person.P_Id><Person.P_Name>山田</Person.P_Name></Item>' +
        '  <Item><Person.P_Id>222</Person.P_Id><Person.P_Name>佐藤</Person.P_Name></Item>' +
        '</Candidate>';
    
    @testSetup
    static void setup() {
        // 有効なトークンをカスタム設定に設定（getAccessToken がキャッシュから返すように）
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            Access_Token__c = 'mock_access_token',
            Token_Expires_At__c = System.now().addHours(1),
            Is_Development_Mode__c = false,
            API_Call_Count__c = 0
        );
        upsert settings;
    }
    
    // ========== 既存のテスト ==========
    
    @isTest
    static void testGetAllCandidates_SinglePage() {
        Test.setMock(HttpCalloutMock.class, new SinglePageMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getAllCandidates(null);
        Test.stopTest();
        
        System.assertEquals(1, candidates.size());
        System.assertEquals('12345', candidates[0].getPersonId());
        System.assertEquals('テスト 太郎', candidates[0].getPersonName());
    }
    
    @isTest
    static void testGetAllCandidates_MultiPage() {
        Test.setMock(HttpCalloutMock.class, new MultiPageMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getAllCandidates(null);
        Test.stopTest();
        
        System.assertEquals(2, candidates.size());
        System.assertEquals('111', candidates[0].getPersonId());
        System.assertEquals('山田 一郎', candidates[0].getPersonName());
        System.assertEquals('222', candidates[1].getPersonId());
        System.assertEquals('佐藤 花子', candidates[1].getPersonName());
    }
    
    @isTest
    static void testGetAllCandidates_WithMaxRecords() {
        Test.setMock(HttpCalloutMock.class, new MultiPageMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getAllCandidates(1);
        Test.stopTest();
        
        System.assertEquals(1, candidates.size());
        System.assertEquals('111', candidates[0].getPersonId());
    }
    
    @isTest
    static void testGetCandidatesSince_WithCondition() {
        Test.setMock(HttpCalloutMock.class, new ConditionMock());
        
        Datetime lastSync = Datetime.newInstance(2023, 1, 1, 0, 0, 0);
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getCandidatesSince(null, lastSync);
        Test.stopTest();
        
        System.assertEquals(1, candidates.size());
    }
    
    @isTest
    static void testGetAllCandidates_ApiErrorCode() {
        Test.setMock(HttpCalloutMock.class, new ApiErrorMock());
        
        Test.startTest();
        try {
            PORTERSDataService.getAllCandidates(null);
            System.assert(false);
        } catch (PORTERSDataService.PORTERSException e) {
            System.assert(e.getMessage().contains('APIエラー: 101'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetAllCandidates_HttpError() {
        Test.setMock(HttpCalloutMock.class, new HttpErrorMock());
        
        Test.startTest();
        try {
            PORTERSDataService.getAllCandidates(null);
            System.assert(false);
        } catch (PORTERSDataService.PORTERSException e) {
            System.assert(e.getMessage().contains('個人連絡先データの取得に失敗しました'));
        }
        Test.stopTest();
    }
    
    // ========== 追加テスト（カバレッジ向上） ==========
    
    /**
     * 条件なし（lastSyncTime = null）の差分取得
     */
    @isTest
    static void testGetCandidatesSince_NoCondition() {
        Test.setMock(HttpCalloutMock.class, new NoConditionMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getCandidatesSince(null, null);
        Test.stopTest();
        
        System.assertEquals(1, candidates.size());
    }
    
    /**
     * 空のレスポンス（件数0）でループが正常終了することを確認
     */
    @isTest
    static void testGetCandidates_EmptyResponse() {
        Test.setMock(HttpCalloutMock.class, new EmptyResponseMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getAllCandidates(null);
        Test.stopTest();
        
        System.assertEquals(0, candidates.size());
    }
    
    /**
     * レスポンスに Total 属性が存在しない場合、total = 0 として処理されること
     */
    @isTest
    static void testGetCandidates_TotalMissing() {
        Test.setMock(HttpCalloutMock.class, new TotalMissingMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getAllCandidates(null);
        Test.stopTest();
        
        // 1件返ってくるが total が無いため、次のページを取得しない（hasMore = false）
        System.assertEquals(1, candidates.size());
    }
    
    /**
     * APIエラーコードが返り、Message 要素が存在しない場合のエラーメッセージ確認
     */
    @isTest
    static void testGetCandidates_ErrorCodeWithoutMessage() {
        Test.setMock(HttpCalloutMock.class, new ErrorCodeOnlyMock());
        
        Test.startTest();
        try {
            PORTERSDataService.getAllCandidates(null);
            System.assert(false, '例外が発生しなかった');
        } catch (PORTERSDataService.PORTERSException e) {
            System.assert(e.getMessage().contains('APIエラー: 999'), 'エラーコードのみのメッセージ');
        }
        Test.stopTest();
    }
    
    /**
     * buildQueryString のパラメータ空値スキップ動作の確認
     */
    @isTest
    static void testBuildQueryString_SkipEmpty() {
        Test.setMock(HttpCalloutMock.class, new BuildQueryStringMock());
        
        // lastSyncTime = null で condition が空文字になる → condition パラメータがURLに含まれない
        PORTERSDataService.getCandidatesSince(null, null);
        // Mock 内で条件パラメータが含まれないことを検証済み
    }
    
    /**
     * maxRecords がちょうど総件数と同じ場合、切り詰めが発生しないこと
     */
    @isTest
    static void testGetCandidates_ExactMaxRecords() {
        Test.setMock(HttpCalloutMock.class, new MultiPageMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getAllCandidates(2);
        Test.stopTest();
        
        System.assertEquals(2, candidates.size(), 'maxRecords=2 で全件取得されること');
    }
    
    /**
     * maxRecords がページサイズより小さい場合、最初のページ内で切り詰めが行われること
     */
    @isTest
    static void testGetCandidates_MaxRecordsLessThanPageSize() {
        Test.setMock(HttpCalloutMock.class, new SinglePageTwoItemsMock());
        
        Test.startTest();
        List<PORTERSDataService.Candidate> candidates = PORTERSDataService.getAllCandidates(1);
        Test.stopTest();
        
        System.assertEquals(1, candidates.size(), 'maxRecords=1 で最初の1件のみ取得されること');
    }
    
    // ========== Mockクラス ==========
    
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
            String encodedCondition = EncodingUtil.urlEncode('Person.P_UpdateDate>', 'UTF-8');
            System.assert(url.contains(encodedCondition), '条件が正しくエンコードされていること');
            
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
    
    // 追加のMockクラス
    
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
    
    private class EmptyResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><Candidate Total="0" Count="0" Start="0"><Code>0</Code></Candidate>');
            return res;
        }
    }
    
    private class TotalMissingMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><Candidate><Code>0</Code><Item><Person.P_Id>111</Person.P_Id><Person.P_Name>テスト</Person.P_Name></Item></Candidate>');
            return res;
        }
    }
    
    private class ErrorCodeOnlyMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('<?xml version="1.0" encoding="UTF-8"?><Candidate><Code>999</Code></Candidate>');
            return res;
        }
    }
    
    private class BuildQueryStringMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            String url = req.getEndpoint();
            System.assert(!url.contains('condition='), 'conditionパラメータが含まれていないこと');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(SINGLE_ITEM_XML);
            return res;
        }
    }
    
    private class SinglePageTwoItemsMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(TWO_ITEMS_IN_PAGE_XML);
            return res;
        }
    }
}