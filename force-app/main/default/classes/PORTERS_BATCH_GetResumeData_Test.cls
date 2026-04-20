@IsTest
private class PORTERS_BATCH_GetResumeData_Test {

    /**
     * 汎用Mock（シナリオ切替型）
     */
    private class PORTERSMock implements HttpCalloutMock {

        String mode;

        PORTERSMock(String mode){
            this.mode = mode;
        }

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            // =========================
            // OAuth
            // =========================
            if (endpoint.contains('/v1/oauth')) {

                if(mode == 'oauth_error'){
                    res.setStatusCode(500);
                    res.setBody('error');
                    return res;
                }

                res.setStatusCode(200);
                res.setBody('<Response><Code>dummy_code</Code></Response>');
                return res;
            }

            // =========================
            // Token
            // =========================
            if (endpoint.contains('/v1/token')) {

                if(mode == 'token_http_error'){
                    res.setStatusCode(500);
                    res.setBody('error');
                    return res;
                }

                if(mode == 'token_logic_error'){
                    res.setStatusCode(200);
                    res.setBody('<Response><Error>1</Error><Message>fail</Message></Response>');
                    return res;
                }

                res.setStatusCode(200);
                res.setBody('<Response><AccessToken>dummy_token</AccessToken><Error>0</Error></Response>');
                return res;
            }

            // =========================
            // Resume
            // =========================
            if (endpoint.contains('/v1/resume')) {

                if(mode == 'resume_http_error'){
                    res.setStatusCode(500);
                    res.setBody('error');
                    return res;
                }

                if(mode == 'resume_empty'){
                    res.setStatusCode(200);
                    res.setBody('<Response Total="0"></Response>');
                    return res;
                }

                if(mode == 'resume_bad_xml'){
                    res.setStatusCode(200);
                    res.setBody('<Response><Item>'); // 壊れXML
                    return res;
                }

                // 正常
                res.setStatusCode(200);
                res.setBody(
                    '<Response Total="1">' +
                        '<Item>' +
                            '<Resume.P_Id>123</Resume.P_Id>' +
                            '<Resume.P_Candidate>山田太郎</Resume.P_Candidate>' +
                            '<Resume.P_Mail>test@test.com</Resume.P_Mail>' +
                            '<Resume.P_UpdateDate>2025-01-01 10:00:00</Resume.P_UpdateDate>' +
            
                            '<Resume.P_CurrentSalary>600</Resume.P_CurrentSalary>' +
            
                            '<Resume.P_RegistrationDate>2025-01-01</Resume.P_RegistrationDate>' +

                            '<Resume.P_PhaseDate>2025-01-01 12:00:00</Resume.P_PhaseDate>' +
            
                            '<Resume.P_Gender>Male</Resume.P_Gender>' +
                            '<Resume.P_ExpectArea>Tokyo</Resume.P_ExpectArea>' +
                            '<Resume.P_ExpectJobCategory>Engineer</Resume.P_ExpectJobCategory>' +
            
                            '<Resume.U_4F79E5889587A2E73847A8B269B808>1000001</Resume.U_4F79E5889587A2E73847A8B269B808>' +
                            '<Resume.U_5247D11C2262F3D9D357DA3D7D472B>東京都港区</Resume.U_5247D11C2262F3D9D357DA3D7D472B>' +
            
                        '</Item>' +
                    '</Response>'
                );
                return res;
            }

            res.setStatusCode(400);
            return res;
        }
    }

    // =========================
    // 正常系（フル）
    // =========================
    @IsTest
    static void test_success_full() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('success'));

        Test.startTest();

        PORTERS_DTO_ResumeDateResponse res =
            PORTERS_BATCH_GetResumeData.getResumeData(System.now().addDays(-1), 0);

        Test.stopTest();

        System.assertEquals(2, res.totalCount);
        System.assertEquals(2, res.result.size());
    }

    // =========================
    // lastSyncTime なし
    // =========================
    @IsTest
    static void test_no_condition() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('success'));

        Test.startTest();

        PORTERS_BATCH_GetResumeData.getResumeData(null, 2000);

        Test.stopTest();
    }

    // =========================
    // OAuth失敗
    // =========================
    @IsTest
    static void test_oauth_error() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('oauth_error'));

        Test.startTest();

        try{
            PORTERS_BATCH_GetResumeData.getResumeData(System.now(), 0);
            System.assert(false);
        }catch(Exception e){
            System.assert(e.getMessage().contains('Code'));
        }

        Test.stopTest();
    }

    // =========================
    // Token HTTP失敗
    // =========================
    @IsTest
    static void test_token_http_error() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('token_http_error'));

        Test.startTest();

        try{
            PORTERS_BATCH_GetResumeData.getResumeData(System.now(), 0);
            System.assert(true);
        }catch(Exception e){
            System.assert(e.getMessage().contains('トークン'));
        }

        Test.stopTest();
    }

    // =========================
    // Token業務エラー
    // =========================
    @IsTest
    static void test_token_logic_error() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('token_logic_error'));

        Test.startTest();

        try{
            PORTERS_BATCH_GetResumeData.getResumeData(System.now(), 0);
            System.assert(false);
        }catch(Exception e){
            System.assert(e.getMessage().contains('Token API error'));
        }

        Test.stopTest();
    }

    // =========================
    // Resume HTTPエラー
    // =========================
    @IsTest
    static void test_resume_http_error() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('resume_http_error'));

        Test.startTest();

        try{
            PORTERS_BATCH_GetResumeData.getResumeData(System.now(), 0);
            System.assert(false);
        }catch(Exception e){
            System.assert(e.getMessage().contains('HTTP'));
        }

        Test.stopTest();
    }

    // =========================
    // 空データ
    // =========================
    @IsTest
    static void test_resume_empty() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('resume_empty'));

        Test.startTest();

        PORTERS_DTO_ResumeDateResponse res =
            PORTERS_BATCH_GetResumeData.getResumeData(System.now(), 0);

        Test.stopTest();

        System.assertEquals(0, res.totalCount);
    }

    // =========================
    // XML壊れ
    // =========================
    @IsTest
    static void test_bad_xml() {

        Test.setMock(HttpCalloutMock.class, new PORTERSMock('resume_bad_xml'));

        Test.startTest();

        try{
            PORTERS_BATCH_GetResumeData.getResumeData(System.now(), 0);
            System.assert(false);
        }catch(Exception e){
            System.assert(true);
        }

        Test.stopTest();
    }
}