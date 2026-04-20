@IsTest
private class PORTERS_API_GetCandiData_Test {

    /**
     * ========================================
     * Mockクラス（正常系）
     * OAuth / Token / Candidate 全部対応
     * ========================================
     */
    private class SuccessMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            String endpoint = req.getEndpoint();

            // -----------------------------
            // OAuth（認可コード取得）
            // -----------------------------
            if (endpoint.contains('/v1/oauth')) {
                res.setStatusCode(200);
                res.setBody('<Response><Code>dummy_code</Code></Response>');
                return res;
            }

            // -----------------------------
            // Token取得
            // -----------------------------
            if (endpoint.contains('/v1/token')) {
                res.setStatusCode(200);
                res.setBody(
                    '<Response>' +
                        '<AccessToken>dummy_token</AccessToken>' +
                        '<Error>0</Error>' +
                    '</Response>'
                );
                return res;
            }

            // -----------------------------
            // Candidate取得（分页模拟）
            // -----------------------------
            if (endpoint.contains('/v1/candidate')) {

                if (endpoint.contains('start=0')) {
                    res.setBody(buildXml(2));
                } else {
                    res.setBody(buildXml(1));
                }

                res.setStatusCode(200);
                return res;
            }

            res.setStatusCode(400);
            res.setBody('Unknown endpoint');
            return res;
        }

        /**
         * テスト用XML生成
         */
        private String buildXml(Integer count) {
            String xml = '<Response Total="' + count + '">';
            for (Integer i = 0; i < count; i++) {
                xml +=
                    '<Item>' +
                        '<Person.P_Id>' + i + '</Person.P_Id>' +
                        '<Person.P_Name>Test User ' + i + '</Person.P_Name>' +
                        '<Person.P_Mail>test' + i + '@mail.com</Person.P_Mail>' +
                        '<Person.P_Telephone>090000000' + i + '</Person.P_Telephone>' +
                        '<Person.P_Mobile>080000000' + i + '</Person.P_Mobile>' +
                        '<Person.P_MobileMail>test1' + i + '@mail.com</Person.P_MobileMail>' +
                        '<Person.P_RegistrationDate>2026-04-01</Person.P_RegistrationDate>' +
                        '<Person.P_RegisteredBy>system</Person.P_RegisteredBy>' +
                        '<Person.P_UpdatedBy>system</Person.P_UpdatedBy>' +
                        '<Person.P_UpdateDate>2026-01-01</Person.P_UpdateDate>' +
                    '</Item>';
            }
            xml += '</Response>';
            return xml;
        }
    }

    /**
     * ========================================
     * 異常系Mock（HTTPエラー）
     * ========================================
     */
    private class ErrorMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Server Error');
            return res;
        }
    }

    /**
     * ========================================
     * 正常系（条件あり + start=0）
     * ========================================
     */
    @IsTest
    static void test_success_withCondition() {

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Datetime lastSync = Datetime.now().addDays(-1);

        Test.startTest();

        PORTERS_DTO_CandidateResponse res =
            PORTERS_API_GetCandiData.getCandiData(
                'Person.P_Id,Person.P_Name,Person.P_Telephone,Person.P_Mail,Person.P_Mobile,Person.P_MobileMail,Person.P_RegistrationDate,Person.P_RegisteredBy,Person.P_UpdateDate,Person.P_UpdatedBy',
                lastSync,
                0
            );
        List<IF_pts_Can__c> allRecords = new List<IF_pts_Can__c>();
        for(PORTERS_DTO_CandidateResponse.Wrapper wrapper:res.result){
            IF_pts_Can__c ptsCan = new IF_pts_Can__c();
            ptsCan = res.convertToIF(wrapper);
            allRecords.add(ptsCan);
        }
            
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(2, res.totalCount);
        System.assertEquals(2, res.result.size());

        System.assertEquals('0', allRecords[0].IndividualContactId__c);
        System.assertEquals('Test User 0', allRecords[0].IndividualName__c);
    }

    /**
     * ========================================
     * 正常系（条件なし + 分页）
     * ========================================
     */
    @IsTest
    static void test_success_noCondition_nextPage() {

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();

        PORTERS_DTO_CandidateResponse res =
            PORTERS_API_GetCandiData.getCandiData(
                'Person.P_Id,Person.P_Name',
                null,
                100
            );

        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assertEquals(1, res.result.size());
    }

    /**
     * ========================================
     * Token取得テスト
     * ========================================
     */
    @IsTest
    static void test_getAccessToken() {

        Test.setMock(HttpCalloutMock.class, new SuccessMock());

        Test.startTest();

        String token = PORTERS_API_GetCandiData.getAccessToken();

        Test.stopTest();

        System.assertEquals('dummy_token', token);
    }

    /**
     * ========================================
     * 異常系テスト（HTTPエラー）
     * ========================================
     */
    @IsTest
    static void test_httpError() {

        Test.setMock(HttpCalloutMock.class, new ErrorMock());

        Test.startTest();

        try {
            PORTERS_API_GetCandiData.getCandiData(
                'Person.P_Id',
                null,
                0
            );
            System.assert(false, '例外が発生するはず');
        } catch (Exception e) {
            System.assert(e.getMessage().contains('HTTP'));
        }

        Test.stopTest();
    }
}