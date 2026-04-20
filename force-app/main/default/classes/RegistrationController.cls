/**
 * 会員登録（仮登録メール送信）を担当するコントローラクラス
 */
public with sharing class RegistrationController {

    /**
     * Apex からフロントエンドに結果を返すためのラッパークラス
     */
    public class Result {
        @AuraEnabled public String type;    // 結果種別（Error / ExistingUser / NewUser）
        @AuraEnabled public String message; // メッセージ内容
    }

    /**
     * メールアドレスの入力を受け取り、既存ユーザーの有無をチェックした上で
     * 新規ユーザーの場合は仮登録メール（確認メール）を送信します。
     * AuraEnabled により LWC から呼び出し可能です。
     *
     * @param email 入力されたメールアドレス
     * @return      Result オブジェクト（type と message を含む）
     */
    @AuraEnabled
    public static Result checkAndSendEmail(String email) {
        Result res = new Result();

        // 入力チェック：メールアドレスが空白の場合
        if (String.isBlank(email)) {
            res.type = 'Error';
            res.message = '有効なメールアドレスを入力してください。';
            return res;
        }

        String usernameForQuery;
        if (email.endsWith('.hurex')) {
            usernameForQuery = email;
        } else {
            usernameForQuery = email + '.hurex';
        }
        // アクティブなユーザーとして既に登録されているか確認
        List<User> existingUsers = [SELECT Id, IsActive FROM User WHERE Username = :usernameForQuery AND IsActive = TRUE LIMIT 1];
        if (!existingUsers.isEmpty()) {
            // 既存ユーザーの場合
            res.type = 'ExistingUser';
            res.message = '既に登録済みのユーザーです。';
        } else {
            // 新規ユーザーの場合：仮登録メールを送信
            res.type = 'NewUser';
            res.message = '仮登録メールを送信しました。';
            String dynamicSiteUrl = Site.getBaseUrl();               // 現在のサイトのベースURLを取得
            sendTestVerificationEmail(email, dynamicSiteUrl);       // 非同期でメール送信処理を実行
        }
        return res;
    }

    /**
     * 仮登録メールを送信する非同期メソッド（@future）。
     * メールテンプレートと組織全体のメールアドレスを使用して確認URLを本文に埋め込みます。
     *
     * @param email           送信先のメールアドレス
     * @param dynamicSiteUrl  サイトのベースURL（Site.getBaseUrl() から渡される）
     */
    @future(callout=true)
    public static void sendTestVerificationEmail(String email, String dynamicSiteUrl) {
        // URL の補正（「/portalvforcesite」を「/portal」に置換）
        String correctBaseUrl = dynamicSiteUrl.replace('/portalvforcesite', '/portal');
        // 確認用URLの生成（サインアップページにメールアドレスをクエリパラメータとして付与）
        String verificationUrl = correctBaseUrl + '/signup?email=' + EncodingUtil.urlEncode(email, 'UTF-8');

        // メールテンプレートの取得（DeveloperName が 'EmailTemplateetst' のもの）
        List<EmailTemplate> templates = [SELECT Id, Subject, HtmlValue, Body FROM EmailTemplate WHERE DeveloperName = 'EmailTemplateetst' LIMIT 1];
        if (templates.isEmpty()) {
            System.debug('エラー：メールテンプレートが見つかりません');
            return;
        }

        EmailTemplate template = templates[0];
        // HTML 本文があればそれを使い、なければプレーンテキスト本文を使用
        String body = template.HtmlValue != null ? template.HtmlValue : template.Body;
        if (String.isBlank(body)) {
            System.debug('エラー：メールテンプレートの本文が空です');
            return;
        }

        // テンプレート内のプレースホルダ {!VerificationUrl} を実際のURLで置換
        body = body.replace('{!VerificationUrl}', verificationUrl);

        // 組織全体のメールアドレス（送信元）を取得（DisplayName が 'テスト用' のもの）
        List<OrgWideEmailAddress> oweaList = [SELECT Id FROM OrgWideEmailAddress WHERE DisplayName = 'テスト用' LIMIT 1];
        if (oweaList.isEmpty()) {
            System.debug('エラー：組織全体のメールアドレスが見つかりません');
            return;
        }
        OrgWideEmailAddress owea = oweaList[0];

        // メールの作成と送信
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setSaveAsActivity(false);                // 活動履歴に保存しない
        mail.setCharset('UTF-8');
        mail.setToAddresses(new String[]{ email });
        mail.setSubject(template.Subject);
        mail.setHtmlBody(body);
        mail.setUseSignature(false);                  // 署名を付けない
        mail.setOrgWideEmailAddressId(owea.Id);       // 組織全体のメールアドレスを送信元に設定

        Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail }, false);
    }
}