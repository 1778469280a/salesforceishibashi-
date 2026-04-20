public class PORTERS_API_GetCandiData {
    public static PORTERS_DTO_CandidateResponse getCandiData(String fields,Datetime lastSyncTime,Integer start) {
       PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
       Integer PARTITION_ID = null;
       String BASE_URL = null;
       String CLIENT_ID = null;
       if(settings != null){
            PARTITION_ID = Integer.valueOf(settings.PARTITION_ID__c);
            BASE_URL = settings.apiUrl__c;
            CLIENT_ID = settings.Client_Id__c;
       } else {
           throw new PORTERSException('API設定が見つかりません。');
       }
       String condition = '';
        if (lastSyncTime != null) {
            String timeStr = lastSyncTime.format('yyyy/MM/dd HH:mm:ss');
            condition = 'Person.P_UpdateDate:ge=' + timeStr;
        }
        Map<String, String> params = new Map<String, String>{
            'partition' => String.valueOf(2012),
            'count' => String.valueOf(200),
            'start' => String.valueOf(start),
            'field' => fields,
            'itemstate' => 'existing'
        };
        if (String.isNotBlank(condition)) {
            params.put('condition', condition);
        }
        String endpoint = BASE_URL + '/v1/candidate?' + buildQueryString(params);
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        String token = getAccessToken();
        req.setHeader('X-porters-hrbc-oauth-token', token);
        req.setHeader('Content-Type', 'application/xml; charset=UTF-8');
        req.setHeader('X-P-ConnectAPI-Version', '2');
        Http http = new Http();
        HttpResponse res = http.send(req);
        if (res.getStatusCode() == 200) {
            return parseXml(res.getBody());
        } else {
            throw new PORTERSException('個人連絡先データの取得に失敗しました。HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
    public static String getAccessToken() {
        try {
            PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
            String BASE_URL = null;
            String CLIENT_ID = null;
            if(settings != null){
                BASE_URL = settings.apiUrl__c;
                CLIENT_ID = settings.Client_Id__c;
            } else {
                throw new PORTERSException('API設定が見つかりません。');
            }
            // ステップ1: 一時的な認可コード（code）を取得
            String authCode = getAuthorizationCode(BASE_URL, CLIENT_ID);
            // ステップ2: codeを使ってアクセストークンを取得
            String tokenResult = getAccessTokenFromCode(authCode, BASE_URL, CLIENT_ID);

            return tokenResult;
        } catch (Exception e) {
            // エラー発生時はカウントを増やさない（簡易対応）
            throw new PORTERSException('Access Token 取得失敗: ' + e.getMessage());
        }
    }
    private static String getAuthorizationCode(String BASE_URL, String CLIENT_ID) {
        String endpoint = BASE_URL + '/v1/oauth' +
            '?response_type=code_direct' +
            '&app_id=' + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8') +
            '&scope=' + EncodingUtil.urlEncode('candidate_r,resume_r,user_r,option_r,partition_r', 'UTF-8');

        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');

        HttpResponse res = new Http().send(req);
        // カウントはここでは行わない

        if (res.getStatusCode() != 200) {
            throw new PORTERSException('Code 取得失敗、HTTPステータスコード: ' + res.getStatusCode() + ' 応答: ' + res.getBody());
        }

        Dom.Document doc = new Dom.Document();
        doc.load(res.getBody());
        for (Dom.XMLNode child : doc.getRootElement().getChildElements()) {
            if (child.getName() == 'Code') {
                return child.getText();
            }
        }
        throw new PORTERSException('応答に Code ノードが見つかりません');
    }

    private static String getAccessTokenFromCode(String authCode, String BASE_URL, String CLIENT_ID) {
        String clientSecret = SecretUtil.getDecryptedSecret();
        if (String.isBlank(clientSecret)) {
            throw new PORTERSException('Client Secret が設定されていないか、復号に失敗しました。');
        }

        String TOKEN_ENDPOINT = BASE_URL + '/v1/token';
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

        req.setBody('grant_type=oauth_code' +
            '&app_id=' + EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8') +
            '&secret=' + EncodingUtil.urlEncode(clientSecret, 'UTF-8') +
            '&code=' + EncodingUtil.urlEncode(authCode, 'UTF-8'));

        HttpResponse res = new Http().send(req);
        // カウントはここでは行わない

        if (res.getStatusCode() != 200) {
            throw new PORTERSException('トークン取得失敗、HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }

        Dom.Document doc = new Dom.Document();
        doc.load(res.getBody());
        Dom.XMLNode root = doc.getRootElement();

        String accessToken = '';
        String errorCode = null;
        String errorMessage = null;

        for (Dom.XMLNode child : root.getChildElements()) {
            String nodeName = child.getName();
            if (nodeName == 'Error') {
                errorCode = child.getText();
            } else if (nodeName == 'Message') {
                errorMessage = child.getText();
            } else if (nodeName == 'AccessToken') {
                accessToken = child.getText();
            } 
        }

        if (errorCode != null && errorCode != '0') {
            throw new PORTERSException('Token API error: ' + errorCode + ' - ' + (errorMessage != null ? errorMessage : '不明なエラー'));
        }

        if (String.isBlank(accessToken) || accessToken == 'null') {
            throw new PORTERSException('トークン応答に有効な access_token が見つかりません');
        }

        return accessToken;
    }
    /**
     * パラメータマップをURLクエリ文字列に変換（URLエンコード済み）
     */
    private static String buildQueryString(Map<String, String> params) {
        List<String> pairs = new List<String>();
        for (String key : params.keySet()) {
            String value = params.get(key);
            if (String.isNotBlank(value)) {
                pairs.add(key + '=' + EncodingUtil.urlEncode(value, 'UTF-8'));
            }
        }
        return String.join(pairs, '&');
    }
    private static PORTERS_DTO_CandidateResponse parseXml(String xml) {
        PORTERS_DTO_CandidateResponse res = new PORTERS_DTO_CandidateResponse();
        res.result = new List<PORTERS_DTO_CandidateResponse.Wrapper>();

        Dom.Document doc = new Dom.Document();
        doc.load(xml);
        Dom.XMLNode root = doc.getRootElement();

        String totalAttr = root.getAttributeValue('Total', null);
        if(totalAttr != null) res.totalCount = Integer.valueOf(totalAttr);

        for(Dom.XMLNode itemNode : root.getChildElements()) {
            if(itemNode.getName() != 'Item') continue;
            PORTERS_DTO_CandidateResponse.Wrapper w = new PORTERS_DTO_CandidateResponse.Wrapper();
            for(Dom.XMLNode f : itemNode.getChildElements()) {
                String val = f.getText();
                if (String.isBlank(val)) continue;
                
                switch on f.getName() {
                
                    when 'Person.P_Id' {
                        w.personId = val;
                    }
                    when 'Person.P_Name' {
                        w.personName = val;
                    }
                    when 'Person.P_Mail' {
                        w.mail = val;
                    }
                    when 'Person.P_Telephone' {
                        w.telephone = val;
                    }
                    when 'Person.P_Mobile' {
                        w.mobile = val;
                    }
                    when 'Person.P_MobileMail' {
                        w.mobileMail= val;
                    }
                    when 'Person.P_RegistrationDate' {
                        w.registrationDate= val;
                    }
                    when 'Person.P_RegisteredBy' {
                        w.registeredBy= val;
                    }
                    when 'Person.P_UpdateDate' {
                        w.updateDate = val;
                    }
                    when 'Person.P_UpdatedBy' {
                        w.updatedBy = val;
                    }
                }
            }
            res.result.add(w);
        }
        return res;
    }
    public class PORTERSException extends Exception {}
}