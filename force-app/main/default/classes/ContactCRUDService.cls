/**
 * Apex クラス: Contact の基礎 CRUD 操作 を実装
 * - 入力検証（必須項目/メール形式）
 * - 例外処理
 * - ログ記録
 *
 * 注意: このクラスは Force.com IDE / Salesforce DX で直接展開可能な形式です。
 */
public with sharing class ContactCRUDService {

    // ------------------------------
    // 入力データ DTO (日本語フィールド名)
    // ------------------------------
    public class 作成DTO {
        public String 名;          // 名 (FirstName)
        public String 姓;          // 姓 (LastName) — 必須
        public String メール;        // メール (Email) — 任意だが形式検証あり
        public String 電話;          // 電話 (Phone) — 任意
        public Id アカウントId;      // 取引先アカウントId (AccountId) — 任意
    }

    public class 更新DTO {
        public Id Id;               // 更新対象 Contact Id
        public String 名;             // 名 (FirstName)
        public String 姓;             // 姓 (LastName)
        public String メール;           // メール (Email)
        public String 電話;             // 電話 (Phone)
        public Id アカウントId;         // AccountId
    }

    // ------------------------------
    // カスタム例外: バリデーションエラー
    // ------------------------------
    public class バリデーションエラー extends Exception {}

    // ------------------------------
    // ログ定義
    // ------------------------------
    private static final Pattern EMAIL_PATTERN = Pattern.compile('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$');
    private static void ログ( String レベル, String メッセージ ) {
        System.debug(レベル + ': ' + メッセージ);
    }

    private static Boolean メール有効か( String メール ) {
        if (メール == null) return true; // 未入力は許容
        String _t = メール.trim();
        if (_t == '') return true; // 空白は未入力として許容
        Matcher m = EMAIL_PATTERN.matcher(_t);
        return m.matches();
    }

    // ------------------------------
    // バリデーション関数
    // ------------------------------
    private static List<String> 検証作成( 作成DTO dto ) {
        List<String> エラー = new List<String>();
        if (dto == null) {
            エラー.add('入力データが null です');
            return エラー;
        }
        if (dto.姓 == null || dto.姓.trim() == '') {
            エラー.add('姓は必須項目です');
        }
        if (!メール有効か(dto.メール)) {
            エラー.add('メール形式が無効です');
        }
        return エラー;
    }

    private static List<String> 検証更新( 更新DTO dto ) {
        List<String> エラー = new List<String>();
        if (dto == null || dto.Id == null) {
            エラー.add('更新には対象の ID が必要です');
            return エラー;
        }
        if (dto.姓 != null && dto.姓.trim() == '') {
            エラー.add('姓を空にすることはできません');
        }
        if (!メール有効か(dto.メール)) {
            エラー.add('メール形式が無効です');
        }
        return エラー;
    }

    // ------------------------------
    // 公開 API: CRUD
    // ------------------------------
    // 作成
    public static Id 作成( 作成DTO dto ) {
        List<String> エラー = 検証作成(dto);
        if (!エラー.isEmpty()) {
            String 連結 = '';
            for (String e : エラー) {
                if (連結 != '') 連結 += '; ';
                連結 += e;
            }
            ログ('ERROR', '作成時の検証エラー: ' + 連結);
            throw new バリデーションエラー('検証エラー: ' + 連結);
        }
        Contact  c = new Contact();
        // 日本語フィールド名は UK の API 名に対応させる
        c.FirstName = dto.名;
        c.LastName = dto.姓;
        c.Email = dto.メール;
        c.Phone = dto.電話;
        c.AccountId = dto.アカウントId;
        try {
            insert c;
            ログ('INFO', 'Contact 作成完了: ' + c.Id);
            return c.Id;
        } catch (DmlException e) {
            ログ('ERROR', 'Contact 作成で DML 例外: ' + e.getMessage());
            throw e;
        }
    }

    // 読み取り
    public static Contact 読み取り( Id id ) {
        if (id == null) {
            ログ('ERROR', '読み取り時に無効な ID が指定されました');
            throw new AuraHandledException('無効な ID です');
        }
        try {
            Contact c = [ SELECT Id, FirstName, LastName, Email, Phone, AccountId
                          FROM Contact
                          WHERE Id = :id
                          LIMIT 1 ];
            ログ('INFO', 'Contact 取得: ' + c.Id);
            return c;
        } catch (Exception e) {
            ログ('ERROR', 'Contact 取得エラー: ' + e.getMessage());
            throw e;
        }
    }

    // 更新
    public static void 更新( 更新DTO dto ) {
        List<String> エラー = 検証更新(dto);
        if (!エラー.isEmpty()) {
            String 連結 = '';
            for (String e : エラー) { if (連結 != '') 連結 += '; '; 連結 += e; }
            ログ('ERROR', '更新時の検証エラー: ' + 連結);
            throw new バリデーションエラー('検証エラー: ' + 連結);
        }
        try {
            Contact 既存 = [SELECT Id, FirstName, LastName, Email, Phone, AccountId
                          FROM Contact
                          WHERE Id = :dto.Id
                          LIMIT 1 FOR UPDATE];
            if (dto.名 != null) 既存.FirstName = dto.名;
            if (dto.姓 != null) 既存.LastName  = dto.姓;
            if (dto.メール != null) 既存.Email = dto.メール;
            if (dto.電話 != null) 既存.Phone = dto.電話;
            if (dto.アカウントId != null) 既存.AccountId = dto.アカウントId;
            update 既存;
            ログ('INFO', 'Contact 更新完了: ' + 既存.Id);
        } catch (Exception e) {
            ログ('ERROR', 'Contact 更新エラー: ' + e.getMessage());
            throw e;
        }
    }

    // 削除
    public static void 削除( Id id ) {
        if (id == null) {
            ログ('ERROR', '削除時に無効な ID が指定されました');
            throw new AuraHandledException('無効な ID です');
        }
        try {
            Contact  target = [SELECT Id FROM Contact WHERE Id = :id LIMIT 1];
            delete target;
            ログ('INFO', 'Contact 削除完了: ' + id);
        } catch (Exception e) {
            ログ('ERROR', 'Contact 削除エラー: ' + e.getMessage());
            throw e;
        }
    }
}
