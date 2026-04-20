@isTest
private class PORTERS_BATCH_CandiData_Test {

    /**
     * PORTERS API Callout Mock
     */
    private class PORTERSCandidateMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            String endpoint = req.getEndpoint();

            /*
             * OAuth認可コード取得API
             */
            if(endpoint.contains('/v1/oauth')){

                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<Response>' +
                        '<Code>TEST_AUTH_CODE</Code>' +
                    '</Response>'
                );

            }

            /*
             * AccessToken取得API
             */
            else if(endpoint.contains('/v1/token')){

                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<Response>' +
                        '<AccessToken>TEST_ACCESS_TOKEN</AccessToken>' +
                        '<Error>0</Error>' +
                    '</Response>'
                );

            }

            /*
             * Candidate取得API
             */
            else if(endpoint.contains('/v1/candidate')){

                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<Response Total="1">' +
                        '<Item>' +
                            '<Person.P_Id>P001</Person.P_Id>' +
                            '<Person.P_Name>テスト太郎</Person.P_Name>' +
                            '<Person.P_Telephone>0311111111</Person.P_Telephone>' +
                            '<Person.P_Mail>test@example.com</Person.P_Mail>' +
                            '<Person.P_Mobile>09011112222</Person.P_Mobile>' +
                            '<Person.P_MobileMail>mobile@test.com</Person.P_MobileMail>' +
                            '<Person.P_RegistrationDate>2026/04/08 10:00:00</Person.P_RegistrationDate>' +
                            '<Person.P_RegisteredBy>Admin</Person.P_RegisteredBy>' +
                            '<Person.P_UpdateDate>2026/04/08 10:00:00</Person.P_UpdateDate>' +
                            '<Person.P_UpdatedBy>Admin</Person.P_UpdatedBy>' +
                        '</Item>' +
                    '</Response>'
                );

            }

            return res;
        }
    }


    /**
     * Batch正常処理テスト
     */
    @isTest
    static void testBatchExecuteSuccess() {

        /*
         * 設定データ作成
         */
        PORTERS_Settings__c settings = new PORTERS_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            LastSyncTime__c = System.now().addDays(-1)
        );
        insert settings;


        /*
         * API設定データ作成
         */
        PORTERSAPI_Settings__c apiSettings = new PORTERSAPI_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            PARTITION_ID__c = '2012',
            apiUrl__c = 'https://test.porters.jp',
            Client_Id__c = 'TEST_CLIENT'
        );
        insert apiSettings;


        /*
         * Mock設定
         */
        Test.setMock(HttpCalloutMock.class, new PORTERSCandidateMock());


        Test.startTest();

        Database.executeBatch(new PORTERS_BATCH_CandiData(), 1);

        Test.stopTest();


        /*
         * IF_pts_Can__c登録確認
         */
        List<IF_pts_Can__c> canList = [
            SELECT Id,
                   Name,
                   IndividualContactId__c
            FROM IF_pts_Can__c
        ];

        System.assertEquals(
            1,
            canList.size(),
            '候補者データが1件登録されること'
        );


        /*
         * 最終同期日時更新確認
         */
        PORTERS_Settings__c updatedSettings =
            PORTERS_Settings__c.getOrgDefaults();

        System.assertNotEquals(
            null,
            updatedSettings.LastSyncTime__c,
            'LastSyncTimeが更新されること'
        );

    }

}