/**
 * PORTERS Data Service（個人連絡先データ用）
 * ・PORTERS APIから個人連絡先データを取得する
 * ・全件取得、差分取得（更新日ベース）に対応
 * ・自動ページング処理を含む
 */
public without sharing class PORTERSDataService {
    private static final String BASE_URL = 'https://api-hrbc-jp.porterscloud.com';
    
    /**
     * 個人連絡先情報を保持する内部クラス
     */
    public class Candidate {
        public Map<String, String> fields { get; set; }
        
        public Candidate() {
            fields = new Map<String, String>();
        }

        public String getPersonId() {
            return fields.get('Person.P_Id');
        }
        
        public String getPersonName() {
            return fields.get('Person.P_Name');
        }
        
        public String getPersonTelephone() {
            return fields.get('Person.P_Telephone');
        }
        
        public String getPersonMail() {
            return fields.get('Person.P_Mail');
        }
        
        public String getPersonMobile() {
            return fields.get('Person.P_Mobile');
        }
        
        public String getPersonMobileMail() {
            return fields.get('Person.P_MobileMail');
        }

        public String getRegistrationDate() {
            return fields.get('Person.P_RegistrationDate');
        }
        
        public String getRegisteredBy() {
            return fields.get('Person.P_RegisteredBy');
        }
        
        public String getUpdateDate() {
            return fields.get('Person.P_UpdateDate');
        }
        
        public String getUpdatedBy() {
            return fields.get('Person.P_UpdatedBy');
        }

        public String getCustomField(String fieldName) {
            return fields.get(fieldName);
        }
    }
    
    /**
     * ページ結果を保持するクラス（総件数付き）
     */
    public class PageResult {
        public List<Candidate> items;
        public Integer total;
        
        public PageResult(List<Candidate> items, Integer total) {
            this.items = items;
            this.total = total;
        }
    }
    
    /**
     * 全件取得（最大件数指定可能）
     * @param maxRecords 取得最大件数（nullの場合は全件）
     * @return Candidateリスト
     */
    public static List<Candidate> getAllCandidates(Integer maxRecords) {
        Integer partitionId = 2012; // 環境に応じて変更
        String fields = 'Person.P_Id,Person.P_Name,Person.P_Telephone,Person.P_Mail,Person.P_Mobile,Person.P_MobileMail,Person.P_RegistrationDate,Person.P_RegisteredBy,Person.P_UpdateDate,Person.P_UpdatedBy';
        return getCandidatesInternal(partitionId, fields, null, maxRecords);
    }
    
    /**
     * 差分取得（更新日時が最終同期日時より新しいもののみ）
     * @param maxRecords 取得最大件数
     * @param lastSyncTime 最終同期日時
     * @return Candidateリスト
     */
    public static List<Candidate> getCandidatesSince(Integer maxRecords, Datetime lastSyncTime) {
        Integer partitionId = 2012; 
        String fields = 'Person.P_Id,Person.P_Name,Person.P_Telephone,Person.P_Mail,Person.P_Mobile,Person.P_MobileMail,Person.P_RegistrationDate,Person.P_RegisteredBy,Person.P_UpdateDate,Person.P_UpdatedBy';
        String condition = '';
        if (lastSyncTime != null) {
            String timeStr = lastSyncTime.format('yyyy-MM-dd HH:mm:ss');
            condition = 'Person.P_UpdateDate>\'' + timeStr + '\'';
        }
        return getCandidatesInternal(partitionId, fields, condition, maxRecords);
    }
    
    /**
     * 単一ページの個人連絡先データを取得する（差分条件付き）
     * @param partitionId    パーティションID
     * @param fields         取得フィールド（カンマ区切り）
     * @param lastSyncTime   最終同期日時（nullの場合は全件）
     * @param start          開始インデックス（0から）
     * @param pageSize       ページサイズ（最大200）
     * @return PageResult    ページデータと総件数を含むオブジェクト
     */
    public static PageResult getCandidatesPage(Integer partitionId, String fields, Datetime lastSyncTime, Integer start, Integer pageSize) {
        String condition = '';
        if (lastSyncTime != null) {
            String timeStr = lastSyncTime.format('yyyy-MM-dd HH:mm:ss');
            condition = 'Person.P_UpdateDate>\'' + timeStr + '\'';
        }
        
        Map<String, String> params = new Map<String, String>{
            'partition' => String.valueOf(partitionId),
            'count' => String.valueOf(pageSize),
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
        
        HttpResponse res = PORTERSHttpClient.send(req);
        
        if (res.getStatusCode() == 200) {
            return parseCandidatesWithTotal(res.getBody());
        } else {
            throw new PORTERSException('個人連絡先データの取得に失敗しました。HTTP ' + res.getStatusCode() + ': ' + res.getBody());
        }
    }
    
    /**
     * 内部メソッド：共通の取得ロジック（ページング処理）
     */
    private static List<Candidate> getCandidatesInternal(Integer partitionId, String fields, String condition, Integer maxRecords) {
        List<Candidate> allCandidates = new List<Candidate>();
        Integer start = 0;
        Integer pageSize = 200;   // APIの最大ページサイズ
        Boolean hasMore = true;
        
        while (hasMore) {
            Map<String, String> params = new Map<String, String>{
                'partition' => String.valueOf(partitionId),
                'count' => String.valueOf(pageSize),
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
            
            HttpResponse res = PORTERSHttpClient.send(req);
            
            if (res.getStatusCode() == 200) {
                PageResult page = parseCandidatesWithTotal(res.getBody());
                allCandidates.addAll(page.items);
                
                // 終了条件の判定：取得件数が0件 または start+取得件数 >= 総件数 または maxRecordsに達した場合
                if (page.items.isEmpty() || start + page.items.size() >= page.total) {
                    hasMore = false;
                } else if (maxRecords != null && allCandidates.size() >= maxRecords) {
                    hasMore = false;
                } else {
                    start += page.items.size();
                }
            } else {
                throw new PORTERSException('個人連絡先データの取得に失敗しました。HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        }
        
        // 最大件数指定がある場合は切り詰める
        if (maxRecords != null && allCandidates.size() > maxRecords) {
            List<Candidate> limitedList = new List<Candidate>();
            for (Integer i = 0; i < maxRecords; i++) {
                limitedList.add(allCandidates[i]);
            }
            allCandidates = limitedList;
        }
        return allCandidates;
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
    
    /**
     * APIレスポンスXMLをパースし、候補リストと総件数を返す
     */
    private static PageResult parseCandidatesWithTotal(String xml) {
        List<Candidate> candidates = new List<Candidate>();
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
        Dom.XMLNode root = doc.getRootElement();
        
        // 総件数を取得
        Integer total = 0;
        String totalAttr = root.getAttributeValue('Total', null);
        if (totalAttr != null) {
            total = Integer.valueOf(totalAttr);
        }
        
        // エラーコードのチェック
        for (Dom.XMLNode child : root.getChildElements()) {
            if (child.getName() == 'Code' && child.getText() != '0') {
                String errorMsg = 'APIエラー: ' + child.getText();
                for (Dom.XMLNode msgNode : root.getChildElements()) {
                    if (msgNode.getName() == 'Message') {
                        errorMsg += ' - ' + msgNode.getText();
                        break;
                    }
                }
                throw new PORTERSException(errorMsg);
            }
        }
        
        // <Item>要素を処理
        for (Dom.XMLNode itemNode : root.getChildElements()) {
            if (itemNode.getName() == 'Item') {
                Candidate cand = new Candidate();
                for (Dom.XMLNode fieldNode : itemNode.getChildElements()) {
                    String fieldName = fieldNode.getName();
                    String fieldValue = fieldNode.getText();
                    cand.fields.put(fieldName, fieldValue);
                }
                candidates.add(cand);
            }
        }
        
        return new PageResult(candidates, total);
    }
    
    public class PORTERSException extends Exception {}
}