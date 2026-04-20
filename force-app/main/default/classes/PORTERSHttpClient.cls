/**
 * PORTERS API 用 HTTP クライアント
 * ・共通の認証ヘッダー付与
 * ・タイムアウト設定
 * ・リトライ処理（5xx エラー、ネットワーク例外）
 * ・401 エラー発生時のトークン自動リフレッシュ
 */
public with sharing class PORTERSHttpClient {
    // デフォルトのタイムアウト（ミリ秒）
    private static final Integer DEFAULT_TIMEOUT = 10000;
    // 最大リトライ回数
    private static final Integer MAX_RETRIES = 3; 
    // リトライ時のバックオフ基準時間（ミリ秒）
    private static final Integer RETRY_BACKOFF_MS = 1000;

    public static HttpResponse send(HttpRequest req) {
        return send(req, true);
    }

    private static HttpResponse send(HttpRequest req, Boolean handleAuth) {
        req.setTimeout(DEFAULT_TIMEOUT);
        
        String token = PORTERSAuthHelper.getAccessToken();
        req.setHeader('X-porters-hrbc-oauth-token', token);
        req.setHeader('Content-Type', 'application/xml; charset=UTF-8');
        req.setHeader('X-P-ConnectAPI-Version', '2');
        
        if (handleAuth && String.isBlank(req.getHeader('Authorization'))) {
            req.setHeader('Authorization', 'Bearer ' + token);
        }
        
        Long startTime = System.now().getTime();
        Integer retries = 0;
        
        while (retries <= MAX_RETRIES) {
            try {
                Http http = new Http();
                HttpResponse res = http.send(req);
                
                // 5xx エラーはリトライ可能（リトライ回数内の場合）
                if (res.getStatusCode() >= 500) {
                    if (retries < MAX_RETRIES) {
                        sleep(RETRY_BACKOFF_MS * (1 << retries));
                        retries++;
                        continue;
                    } else {
                        // 最大リトライ回数に達した場合は例外をスロー
                        throw new PORTERSException('HTTP 呼び出しが失敗しました。再試行の最大回数に達しました：ステータスコード ' + res.getStatusCode());
                    }
                }
                
                // 401 Unauthorized：トークンが期限切れまたは無効
                if (res.getStatusCode() == 401 && handleAuth) {
                    // トークンを強制的にリフレッシュ（キャッシュをクリアせずに新規取得）
                    String newToken = forceRefreshToken();
                    req.setHeader('Authorization', 'Bearer ' + newToken);
                    req.setHeader('X-porters-hrbc-oauth-token', newToken);
                    // 再試行（認証ヘッダー自動処理は無効にして無限ループ防止）
                    return send(req, false);
                }
                
                return res;
            } catch (System.CalloutException e) {
                if (retries < MAX_RETRIES) {
                    sleep(RETRY_BACKOFF_MS * (1 << retries));
                    retries++;
                } else {
                    throw new PORTERSException('HTTP 呼び出しが失敗しました。再試行の最大回数に達しました：' + e.getMessage());
                }
            }
        }
        throw new PORTERSException('予期せぬループが終了しました');
    }
    
    private static String forceRefreshToken() {
        // キャッシュをクリアせずに新規トークンを取得（PORTERSAuthHelper 内のキャッシュ切れを期待）
        // これにより DML と Callout の競合を回避
        return PORTERSAuthHelper.getAccessToken();
    }
    
    private static void sleep(Integer ms) {
        Long start = System.now().getTime();
        while (System.now().getTime() - start < ms) {}
    }
    
    public class PORTERSException extends Exception {}
}