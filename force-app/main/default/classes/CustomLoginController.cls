public without sharing class CustomLoginController {
    
    @AuraEnabled
    public static String doLogin(String email, String password, String startUrl) {
        try {
            // ★ポイント：入力されたメールアドレスに '.portal' を結合して一意のユーザー名にする
            String username = email + '.hurex';
            
            // Site.loginメソッドで認証を実行（成功時は遷移先URL、失敗時は例外発生またはnull）
            PageReference pageRef = Site.login(username, password, startUrl);
            
            if (pageRef != null) {
                return pageRef.getUrl(); // 成功：リダイレクト先のURLを返す
            } else {
                return 'ERROR: メールアドレスまたはパスワードが正しくありません。';
            }
        } catch (Auth.LoginDiscoveryException e) {
            return 'ERROR: ログイン情報が正しくないか、アカウントがロックされています。';
        } catch (Exception e) {
            // その他の予期せぬエラー
            return 'ERROR: ログイン処理中にエラーが発生しました。(' + e.getMessage() + ')';
        }
    }
}