@isTest
private class PORTERSHttpClientTest {
    
    @testSetup
    static void setup() {
        // 有効なトークンキャッシュを設定（PORTERSAuthHelper.getAccessToken() がキャッシュから返す）
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            Access_Token__c = 'test_token',
            Token_Expires_At__c = System.now().addHours(1),
            Is_Development_Mode__c = false
        );
        upsert settings;
    }
    
    @isTest
    static void testSend_Success() {
        Test.setMock(HttpCalloutMock.class, new SuccessMock());
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');
        
        Test.startTest();
        HttpResponse res = PORTERSHttpClient.send(req);
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('{"result":"ok"}', res.getBody());
    }
    
    @isTest
    static void testSend_RetryOn500() {
        Test.setMock(HttpCalloutMock.class, new Retry500Mock());
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');
        
        Test.startTest();
        HttpResponse res = PORTERSHttpClient.send(req);
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('Success after retry', res.getBody());
    }
    
    @isTest
    static void testSend_RetryOn401() {
        // 401 応答後に forceRefreshToken が呼ばれ、新たなトークンで再試行されることを確認
        Test.setMock(HttpCalloutMock.class, new Retry401Mock());
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');
        
        Test.startTest();
        HttpResponse res = PORTERSHttpClient.send(req);
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('Success after 401', res.getBody());
    }
    
    @isTest
    static void testSend_RetryOnNetworkException() {
        Test.setMock(HttpCalloutMock.class, new NetworkExceptionMock());
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');
        
        Test.startTest();
        HttpResponse res = PORTERSHttpClient.send(req);
        Test.stopTest();
        
        System.assertEquals(200, res.getStatusCode());
        System.assertEquals('Success after network error', res.getBody());
    }
    
    @isTest
    static void testSend_MaxRetriesExhausted_500() {
        Test.setMock(HttpCalloutMock.class, new Always500Mock());
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');
        
        Test.startTest();
        try {
            PORTERSHttpClient.send(req);
            System.assert(false, '例外が発生しなかった');
        } catch (PORTERSHttpClient.PORTERSException e) {
            System.assert(e.getMessage().contains('再試行の最大回数に達しました'),
                '想定された例外メッセージではありません: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    @isTest
    static void testSend_MaxRetriesExhausted_Network() {
        Test.setMock(HttpCalloutMock.class, new AlwaysNetworkExceptionMock());
        HttpRequest req = new HttpRequest();
        req.setEndpoint('https://api.example.com/test');
        req.setMethod('GET');
        
        Test.startTest();
        try {
            PORTERSHttpClient.send(req);
            System.assert(false, '例外が発生しなかった');
        } catch (PORTERSHttpClient.PORTERSException e) {
            System.assert(e.getMessage().contains('再試行の最大回数に達しました'),
                '想定された例外メッセージではありません: ' + e.getMessage());
        }
        Test.stopTest();
    }
    
    // ========== Mock クラス ==========
    
    private class SuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"result":"ok"}');
            return res;
        }
    }
    
    private class Retry500Mock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(500);
                res.setBody('Internal Server Error');
            } else {
                res.setStatusCode(200);
                res.setBody('Success after retry');
            }
            return res;
        }
    }
    
    private class Retry401Mock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (callCount == 1) {
                res.setStatusCode(401);
                res.setBody('Unauthorized');
            } else {
                res.setStatusCode(200);
                res.setBody('Success after 401');
            }
            return res;
        }
    }
    
    private class NetworkExceptionMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            if (callCount == 1) {
                throw new System.CalloutException('Connection timeout');
            } else {
                HttpResponse res = new HttpResponse();
                res.setStatusCode(200);
                res.setBody('Success after network error');
                return res;
            }
        }
    }
    
    private class Always500Mock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }
    
    private class AlwaysNetworkExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new System.CalloutException('Connection timeout');
        }
    }
}