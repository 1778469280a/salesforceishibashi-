@isTest
private class PORTERS_BATCH_ResumeData_Test {

    /*
     * Mock PORTERS API Response
     */
    private class ResumeMock implements HttpCalloutMock {

        public HTTPResponse respond(HTTPRequest req) {

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);

            String endpoint = req.getEndpoint();

            // OAuth Code
            if(endpoint.contains('/v1/oauth')){
                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<Response>' +
                    '<Code>TEST_CODE</Code>' +
                    '</Response>'
                );
            }

            // Token
            else if(endpoint.contains('/v1/token')){
                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<Response>' +
                    '<AccessToken>TEST_TOKEN</AccessToken>' +
                    '<Error>0</Error>' +
                    '</Response>'
                );
            }

            // Resume API
            else if(endpoint.contains('/v1/resume')){
                res.setBody(
                    '<?xml version="1.0" encoding="UTF-8"?>' +
                    '<Response Total="1">' +
                        '<Item>' +
                            '<Resume.P_Id>1001</Resume.P_Id>' +
                            '<Resume.P_Name>テスト履歴書</Resume.P_Name>' +
                            '<Resume.P_Candidate>' +
                                '<Candidate>' +
                                    '<Candidate.P_Id>CAN001</Candidate.P_Id>' +
                                '</Candidate>' +
                            '</Resume.P_Candidate>' +
                            '<Resume.P_UpdateDate>2026/04/08 10:00:00</Resume.P_UpdateDate>' +
                        '</Item>' +
                    '</Response>'
                );
            }

            return res;
        }
    }


    @isTest
    static void testBatchResumeData() {

        /*
         * Setup Custom Setting
         */
        PORTERSAPI_Settings__c setting = new PORTERSAPI_Settings__c(
            SetupOwnerId = UserInfo.getOrganizationId(),
            PARTITION_ID__c = '1',
            apiUrl__c = 'https://test.porters.jp',
            Client_Id__c = 'TESTCLIENT',
            LastResumeSyncTime__c = System.now().addDays(-1)
        );
        insert setting;


        /*
         * Setup Candidate Master
         */
        IF_pts_Can__c can = new IF_pts_Can__c(
            IndividualContactId__c = 'CAN001'
        );
        insert can;


        /*
         * Mock SecretUtil if needed
         */
        Test.setMock(HttpCalloutMock.class, new ResumeMock());


        Test.startTest();

        Database.executeBatch(new PORTERS_BATCH_ResumeData(),1);

        Test.stopTest();


        /*
         * Verify Resume Inserted
         */
        List<IF_pts_resume__c> resumes = [
            SELECT Id,
                   Name,
                   IndividualContactId__c,
                   IF_pts_CanId__c
            FROM IF_pts_resume__c
        ];

        System.assertEquals(1, resumes.size());

        System.assertEquals(
            can.Id,
            resumes[0].IF_pts_CanId__c
        );


        /*
         * Verify Finish Updated Sync Time
         */
        PORTERSAPI_Settings__c updatedSetting =
            PORTERSAPI_Settings__c.getOrgDefaults();

        System.assertNotEquals(
            null,
            updatedSetting.LastResumeSyncTime__c
        );
    }
}