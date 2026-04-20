@isTest
private class PORTERSAuthHelperTest {
    
    @testSetup
    static void setup() {
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            Is_Development_Mode__c = true,
            API_Call_Count__c = 0,
            Client_Secret__c = 'dummy_encrypted_secret'
        );
        upsert settings;
    }
    
    @isTest
    static void testGetAccessTokenFromCache() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.Access_Token__c = 'cached_token';
        settings.Token_Expires_At__c = System.now().addHours(1);
        update settings;
        
        Test.startTest();
        String token = PORTERSAuthHelper.getAccessToken();
        Test.stopTest();
        
        System.assertEquals('cached_token', token);
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(0, settings.API_Call_Count__c, 'キャッシュ利用時はカウント増えない');
    }
    
    @isTest
    static void testGetAccessTokenNewToken() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.Access_Token__c = 'expired_token';
        settings.Token_Expires_At__c = System.now().addHours(-1);
        update settings;
        
        Test.setMock(HttpCalloutMock.class, new TokenSuccessMock());
        
        Test.startTest();
        String token = PORTERSAuthHelper.getAccessToken();
        Test.stopTest();
        
        System.assertEquals('mock_access_token', token);
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(2, settings.API_Call_Count__c, '成功時は2回カウント増える');
    }
    
    @isTest
    static void testCallLimitExceeded() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.API_Call_Count__c = 30;
        settings.Is_Development_Mode__c = true;
        update settings;
        
        Test.startTest();
        try {
            PORTERSAuthHelper.getAccessToken();
            System.assert(false, '上限例外が発生しなかった');
        } catch (PORTERSAuthHelper.PORTERSException e) {
            System.assert(e.getMessage().contains('開発モードの API 呼び出し制限に達しました'));
        }
        Test.stopTest();
    }
    
    @isTest
    static void testCallLimitNotAppliedInProdMode() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.API_Call_Count__c = 30;
        settings.Is_Development_Mode__c = false;
        update settings;
        
        Test.setMock(HttpCalloutMock.class, new TokenSuccessMock());
        
        Test.startTest();
        String token = PORTERSAuthHelper.getAccessToken();
        Test.stopTest();
        
        System.assertEquals('mock_access_token', token);
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(32, settings.API_Call_Count__c, '本番モードでは上限を超えてもカウントが増える');
    }
    
    @isTest
    static void testGetAccessTokenCodeFailure() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.Access_Token__c = null;
        settings.Token_Expires_At__c = null;
        update settings;
        
        Test.setMock(HttpCalloutMock.class, new CodeFailureMock());
        
        Test.startTest();
        try {
            PORTERSAuthHelper.getAccessToken();
            System.assert(false, '例外が発生しなかった');
        } catch (PORTERSAuthHelper.PORTERSException e) {
            System.assert(e.getMessage().contains('Code 取得失敗'), '適切なエラーメッセージ');
        }
        Test.stopTest();
        
        // コード取得失敗時は HTTP リクエストは発生したが、カウントは増やさない（簡易対応）
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(0, settings.API_Call_Count__c, '失敗時はカウントを増やさない');
    }
    
    @isTest
    static void testGetAccessTokenTokenApiError() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        settings.Access_Token__c = null;
        settings.Token_Expires_At__c = null;
        update settings;
        
        Test.setMock(HttpCalloutMock.class, new TokenApiErrorMock());
        
        Test.startTest();
        try {
            PORTERSAuthHelper.getAccessToken();
            System.assert(false, '例外が発生しなかった');
        } catch (PORTERSAuthHelper.PORTERSException e) {
            System.assert(e.getMessage().contains('Token API error'), '適切なエラーメッセージ');
        }
        Test.stopTest();
        
        // コード取得は成功したがトークン交換で失敗 → カウントは増やさない（簡易対応）
        settings = PORTERS_Settings__c.getOrgDefaults();
        System.assertEquals(0, settings.API_Call_Count__c, '失敗時はカウントを増やさない');
    }
    
    // ==================== Mockクラス ====================
    
    private class TokenSuccessMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/oauth')) {
                res.setStatusCode(200);
                res.setBody('<Authentication><Code>test_code_123</Code></Authentication>');
            } else if (req.getEndpoint().contains('/v1/token')) {
                res.setStatusCode(200);
                res.setBody('<Authentication><AccessToken>mock_access_token</AccessToken><AccessTokenExpiresIn>3600000</AccessTokenExpiresIn><Error>0</Error><Message>success</Message></Authentication>');
            } else {
                res.setStatusCode(404);
            }
            return res;
        }
    }
    
    private class CodeFailureMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(404);
            res.setBody('Not Found');
            return res;
        }
    }
    
    private class TokenApiErrorMock implements HttpCalloutMock {
        private Integer callCount = 0;
        public HttpResponse respond(HttpRequest req) {
            callCount++;
            HttpResponse res = new HttpResponse();
            if (req.getEndpoint().contains('/v1/oauth')) {
                res.setStatusCode(200);
                res.setBody('<Authentication><Code>test_code_123</Code></Authentication>');
            } else {
                res.setStatusCode(400);
                res.setBody('<Authentication><Error>101</Error><Message>Invalid client secret</Message></Authentication>');
            }
            return res;
        }
    }
}