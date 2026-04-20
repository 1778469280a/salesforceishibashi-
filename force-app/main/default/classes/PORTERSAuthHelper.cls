public with sharing class PORTERSAuthHelper {
    // トークンエンドポイント（固定）
    private static final String TOKEN_ENDPOINT = 'https://api-hrbc-jp.porterscloud.com/v1/token';
    // アプリケーションID（固定）
    private static final String CLIENT_ID = 'a8678131f29ea6faf1caa908a0f51c38';

    // トークン有効期限のデフォルト値（秒）
    private static final Integer DEFAULT_TOKEN_EXPIRES_SEC = 1800;

    public class TokenResult {
        public String accessToken { get; set; }
        public Integer expiresIn { get; set; }
    }

    public static String getAccessToken() {
        try {
            // ステップ1: 一時的な認可コード（code）を取得
            String authCode = getAuthorizationCode();
            // ステップ2: codeを使ってアクセストークンを取得
            TokenResult tokenResult = getAccessTokenFromCode(authCode);

            return tokenResult.accessToken;
        } catch (Exception e) {
            // エラー発生時はカウントを増やさない（簡易対応）
            throw new PORTERSException('Access Token 取得失敗: ' + e.getMessage());
        }
    }

    private static String getAuthorizationCode() {
        String endpoint = 'https://api-hrbc-jp.porterscloud.com/v1/oauth' +
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

    private static TokenResult getAccessTokenFromCode(String authCode) {
        String clientSecret = SecretUtil.getDecryptedSecret();
        if (String.isBlank(clientSecret)) {
            throw new PORTERSException('Client Secret が設定されていないか、復号に失敗しました。');
        }

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

        TokenResult result = new TokenResult();
        String errorCode = null;
        String errorMessage = null;

        for (Dom.XMLNode child : root.getChildElements()) {
            String nodeName = child.getName();
            if (nodeName == 'Error') {
                errorCode = child.getText();
            } else if (nodeName == 'Message') {
                errorMessage = child.getText();
            } else if (nodeName == 'AccessToken') {
                result.accessToken = child.getText();
            } else if (nodeName == 'AccessTokenExpiresIn') {
                result.expiresIn = Integer.valueOf(child.getText());
            }
        }

        if (errorCode != null && errorCode != '0') {
            throw new PORTERSException('Token API error: ' + errorCode + ' - ' + (errorMessage != null ? errorMessage : '不明なエラー'));
        }

        if (String.isBlank(result.accessToken) || result.accessToken == 'null') {
            throw new PORTERSException('トークン応答に有効な access_token が見つかりません');
        }

        return result;
    }

    public class PORTERSException extends Exception {}
}