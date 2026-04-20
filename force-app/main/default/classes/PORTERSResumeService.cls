/**
 * PORTERS Resume Service（キャンディデイトデータ用）
 * ・PORTERS APIからキャンディデイト（Resume）データを取得する
 * ・全件取得、差分取得（更新日ベース）に対応
 * ・自動ページング処理を含む
 */
public without sharing class PORTERSResumeService {
    private static final String BASE_URL = 'https://api-hrbc-jp.porterscloud.com';
    
    /**
     * キャンディデイト情報を保持する内部クラス
     * フィールドは動的なMapで保持し、必要なゲッターメソッドを提供する
     */
    public class Resume {
        public Map<String, String> fields { get; set; }
        
        public Resume() {
            fields = new Map<String, String>();
        }
        
        // 各フィールドのゲッター（マッピングに基づく）
        public String getResumeId() {
            return fields.get('Resume.P_Id');
        }
        
        public String getCandidateName() {
            return fields.get('Resume.P_Candidate');
        }
        
        public String getUpdateDate() {
            return fields.get('Resume.P_UpdateDate');
        }
        
        // 任意のフィールドを取得する汎用メソッド
        public String get(String fieldName) {
            return fields.get(fieldName);
        }
    }
    
    /**
     * 全件取得（最大件数指定可能）
     * @param maxRecords 取得最大件数（nullの場合は全件）
     * @return Resumeリスト
     */
    public static List<Resume> getAllResumes(Integer maxRecords) {
        // 注意: Partition IDは環境に応じて変更する必要があります（実際は設定から取得推奨）
        Integer partitionId = 2012; 
        String fields = buildFieldList();
        return getResumesInternal(partitionId, fields, null, maxRecords);
    }
    
    /**
     * 差分取得（更新日時が最終同期日時より新しいもののみ）
     * @param maxRecords 取得最大件数
     * @param lastSyncTime 最終同期日時（この日時以降に更新されたデータを取得）
     * @return Resumeリスト
     */
    public static List<Resume> getResumesSince(Integer maxRecords, Datetime lastSyncTime) {
        Integer partitionId = 2012; 
        String fields = buildFieldList();
        
        String condition = '';
        if (lastSyncTime != null) {
            // APIが要求する日時フォーマットに変換（例: 'yyyy-MM-dd HH:mm:ss'）
            String timeStr = lastSyncTime.format('yyyy-MM-dd HH:mm:ss');
            condition = 'Resume.P_UpdateDate>\'' + timeStr + '\'';
        }
        return getResumesInternal(partitionId, fields, condition, maxRecords);
    }
    
    /**
     * リクエストするフィールドリストを構築する（マッピングに基づく全フィールド）
     * @return カンマ区切りのフィールド名文字列
     */
    private static String buildFieldList() {
        return 'Resume.P_RegisterChannel,' +
               'Resume.U_4519E06428F3E45FB1C14E878185BE,' +
               'Resume.U_45A05CBAF79D5527F38A6F59E1243B,' +
               'Resume.U_E49E1480A206956CDD882F6A2063E7,' +
               'Resume.P_Id,' +
               'Resume.U_AC5A0D55E86D3363238C61F123390E,' +
               'Resume.U_LASTLOGIN,' +
               'Resume.U_91DBD8B96BAAD6B33B538CF2494377,' +
               'Resume.P_Candidate,' +
               'Resume.P_DateOfBirth,' +
               'Resume.P_Gender,' +
               'Resume.U_4F79E5889587A2E73847A8B269B808,' +
               'Resume.U_7F3DF7F61EEF0679AA432646777832,' +
               'Resume.U_5247D11C2262F3D9D357DA3D7D472B,' +
               'Resume.P_Phase,' +
               'Resume.P_PhaseDate,' +
               'Resume.U_673275A4DA445C9B23AC18BDD7C4DC,' +
               'Resume.U_85DEA8FA18EF17830FD8A036EC95A4,' +
               'Resume.P_Education,' +
               'Resume.U_217F6B518AF9B5910F86DE3553210E,' +
               'Resume.P_TelephoneReference,' +
               'Resume.P_MobileReference,' +
               'Resume.P_Mail,' +
               'Resume.P_MobileMail,' +
               'Resume.U_57CF0FC339534D5E1CCAB9E5720732,' +
               'Resume.U_40A13BD8D79CFAA685ED4C454030D3,' +
               'Resume.P_CurrentStatus,' +
               'Resume.P_ChangeJobsCount,' +
               'Resume.U_97A8BC60EE4C6181D71B62B0A94867,' +
               'Resume.U_C5A71273732B694582E953EE29B262,' +
               'Resume.U_48B3606404C39777B9C4D652EB9B33,' +
               'Resume.U_983513B1B1284C1AE08155656440DE,' +
               'Resume.U_7790CB5A294982B42C78415C082D80,' +
               'Resume.U_459C918AD0E71B7D760A7B466FEC2D,' +
               'Resume.U_5598122582348E10065B3A9B2FCC79,' +
               'Resume.U_7C79BBCF39E0D849E54929A8D70B06,' +
               'Resume.U_AEEC844BBC2B3D25C87D589DDCDC28,' +
               'Resume.U_223D0173F7AB1E5F4A15DC0DB0904C,' +
               'Resume.U_BC07D210E9789C7E4C16092C2718F0,' +
               'Resume.U_959F4DF5330A30BF416EE53592D689,' +
               'Resume.U_DF0E1BF1E942DE5B44759F145F26CC,' +
               'Resume.U_A1D41116DCC9F246FBE2505927D801,' +
               'Resume.U_1342FD85C7DD1612C466A201748F45,' +
               'Resume.U_AA13AA68D5EF4EAC7F9E80626F6401,' +
               'Resume.U_7A82F71961342ABC309E82F3CB4549,' +
               'Resume.U_088F183F5A467370986D82D8A56820,' +
               'Resume.U_84014DC41521C8B72456DA0602B1DC,' +
               'Resume.U_6BFFD96228CF84803A26F4F04200F0,' +
               'Resume.U_D430BFCB51DF105C5546258FA6D8E2,' +
               'Resume.U_DDA38E8BC45B94D70819747CE7B627,' +
               'Resume.U_60E42092BAB538A1E256CE86B3418A,' +
               'Resume.U_96F0A72569A21441DA7E5F9D6ACBEA,' +
               'Resume.U_F2C3465D66ECA0A6227F731DB868B0,' +
               'Resume.U_AGENTSTATUS,' +
               'Resume.U_AGETNTSUSAGE,' +
               'Resume.U_4495E00E8A888DDC61CF3A56D104F8,' +
               'Resume.P_ExpectArea,' +
               'Resume.U_80F76B1B3D339C9387773F1C457E51,' +
               'Resume.U_KKSKGN,' +
               'Resume.U_CE0C8801E69FA2E26E349B09856C0C,' +
               'Resume.P_ExpectEmploymentType,' +
               'Resume.U_94A609C4275F50CC7C617F6CE0A409,' +
               'Resume.P_ExpectCondition,' +
               'Resume.U_F7E834098FD85B1A86E77396219E2B,' +
               'Resume.U_EF980BC1829E8EC05C300033CFABFC,' +
               'Resume.P_ExperiencedIndustry,' +
               'Resume.P_ExperiencedJobCategory,' +
               'Resume.P_CurrentSalary,' +
               'Resume.U_7A6877EFE8D7FB90A4DA9571370642,' +
               'Resume.U_D16C6D4F1B6C32B4AC53819D88043F,' +
               'Resume.U_8D0C259C0AFF6CDF1806A87DC5F439,' +
               'Resume.U_C4E94650CDEFC413E234DD7E6C9274,' +
               'Resume.U_971466A5917927863462EF570C1169,' +
               'Resume.U_8F8E666EE51CC8D00788940A3DC98C,' +
               'Resume.P_ExpectIndustry,' +
               'Resume.P_ExpectJobCategory,' +
               'Resume.P_CarrierSummary,' +
               'Resume.U_42902DED368132819B152E589AA578,' +
               'Resume.U_5475007220C4E3258472D5626A0563,' +
               'Resume.U_C80486912236BD021D1B63FFB762B4,' +
               'Resume.U_12A4C297CC5D159213875DA2210BF2,' +
               'Resume.U_ADE568278037E18C20F3AF78AAF8A8,' +
               'Resume.U_90AD127E5FCEBCD1AF01DDC8295708,' +
               'Resume.U_F205EBF7F6A862C6A9E8DDB135F797,' +
               'Resume.U_94E831023512892988CDD4FC4987EB,' +
               'Resume.U_13C45F7FFAFC1AB430E6038C76125A,' +
               'Resume.U_5F7FC5144BA471117A376B60BC8D90,' +
               'Resume.U_8E20986D8967D107BEE5D63870AD68,' +
               'Resume.U_DDF5A119155AD1F559BAA37C031C4E,' +
               'Resume.P_RegistrationDate,' +
               'Resume.P_RegisteredBy,' +
               'Resume.P_UpdateDate,' +
               'Resume.P_UpdatedBy,' +
               'Resume.U_GCLID,' +
               'Resume.U_B41102CD1A612DA93AA74B5462DE6E,' +
               'Resume.U_8B5178364C17E24A72A2113296D4A5,' +
               'Resume.U_9B5DE90D67C3C57A12D66F84AFA05F,' +
               'Resume.U_ACB4CAC6E89348FD55DF19E6E20155,' +
               'Resume.U_8EF0F79E169EAD365B63D86C9C80B8';
    }
    
    /**
     * 内部メソッド：共通の取得ロジック（ページング処理）
     * @param partitionId パーティションID
     * @param fields 取得するフィールドリスト（カンマ区切り）
     * @param condition 検索条件（例: Resume.P_UpdateDate>'2023-01-01 00:00:00'）
     * @param maxRecords 最大取得件数
     * @return Resumeリスト
     */
    private static List<Resume> getResumesInternal(Integer partitionId, String fields, String condition, Integer maxRecords) {
        List<Resume> allResumes = new List<Resume>();
        Integer start = 0;
        Integer pageSize = 200;   // APIの最大ページサイズ
        Boolean hasMore = true;
        
        while (hasMore) {
            // リクエストパラメータを構築
            Map<String, String> params = new Map<String, String>{
                'partition' => String.valueOf(partitionId),
                'count' => String.valueOf(pageSize),
                'start' => String.valueOf(start),
                'field' => fields,
                'itemstate' => 'existing'   // 削除されていないデータのみ
            };
            if (String.isNotBlank(condition)) {
                params.put('condition', condition);
            }
            
            String endpoint = BASE_URL + '/v1/resume?' + buildQueryString(params);
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            
            // 共通HTTPクライアントを使用（認証・リトライ処理含む）
            HttpResponse res = PORTERSHttpClient.send(req);
            
            if (res.getStatusCode() == 200) {
                List<Resume> pageResumes = parseResumes(res.getBody());
                allResumes.addAll(pageResumes);
                
                // 終了条件の判定
                if (pageResumes.size() < pageSize || (maxRecords != null && allResumes.size() >= maxRecords)) {
                    hasMore = false;
                }
                start += pageSize;
            } else {
                throw new PORTERSException('キャンディデイトデータの取得に失敗しました。HTTP ' + res.getStatusCode() + ': ' + res.getBody());
            }
        }
        
        // 最大件数指定がある場合は切り詰める
        if (maxRecords != null && allResumes.size() > maxRecords) {
            List<Resume> limitedList = new List<Resume>();
            for (Integer i = 0; i < maxRecords; i++) {
                limitedList.add(allResumes[i]);
            }
            allResumes = limitedList;
        }
        return allResumes;
    }
    
    /**
     * パラメータマップをURLクエリ文字列に変換（URLエンコード済み）
     * @param params パラメータマップ
     * @return クエリ文字列（先頭の?は含まない）
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
     * APIレスポンスXMLをパースしてResumeリストを生成する
     * @param xml APIからのXMLレスポンス文字列
     * @return Resumeリスト
     * @throws PORTERSException APIエラーコードが0以外の場合
     */
    private static List<Resume> parseResumes(String xml) {
        List<Resume> resumes = new List<Resume>();
        Dom.Document doc = new Dom.Document();
        doc.load(xml);
        Dom.XMLNode root = doc.getRootElement();
        
        // エラーコードのチェック（<Code>要素が0以外ならエラー）
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
        
        // <Item>要素を一つずつ処理
        for (Dom.XMLNode itemNode : root.getChildElements()) {
            if (itemNode.getName() == 'Item') {
                Resume resume = new Resume();
                for (Dom.XMLNode fieldNode : itemNode.getChildElements()) {
                    String fieldName = fieldNode.getName();
                    String fieldValue = fieldNode.getText();
                    resume.fields.put(fieldName, fieldValue);
                }
                resumes.add(resume);
            }
        }
        return resumes;
    }
    
    /**
     * カスタム例外クラス
     */
    public class PORTERSException extends Exception {}
}