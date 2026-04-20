public class DynamicEmailTemplateRenderer {
    
    public class FlowInput {
        @InvocableVariable(label='メールテンプレートID' required=true)
        public Id templateId;
        
        @InvocableVariable(label='起点となるレコードID' required=true)
        public Id recordId;
    }
    
    public class FlowOutput {
        @InvocableVariable(label='成功フラグ')
        public Boolean isSuccess;
        @InvocableVariable(label='エラーメッセージ')
        public String errorMessage;
        @InvocableVariable(label='件名 (置換済)')
        public String subject;
        @InvocableVariable(label='HTML本文 (置換済)')
        public String htmlBody;
        @InvocableVariable(label='テキスト本文 (置換済)')
        public String plainTextBody;
    }

    @InvocableMethod(label='テンプレート置換' description='テンプレート内の差し込み項目渡したレコードの値で置換します')
    public static List<FlowOutput> renderTemplate(List<FlowInput> inputs) {
        List<FlowOutput> results = new List<FlowOutput>();
        
        // 1. テンプレートを一括取得 (バルク処理対応)
        Set<Id> templateIds = new Set<Id>();
        for(FlowInput input : inputs) templateIds.add(input.templateId);
        
        Map<Id, EmailTemplate> templateMap = new Map<Id, EmailTemplate>([
            SELECT Id, Subject, HtmlValue, Body FROM EmailTemplate WHERE Id IN :templateIds
        ]);
        
        for (FlowInput input : inputs) {
            FlowOutput output = new FlowOutput();
            try {
                EmailTemplate tmpl = templateMap.get(input.templateId);
                String subject = tmpl.Subject != null ? tmpl.Subject : '';
                String htmlBody = tmpl.HtmlValue != null ? tmpl.HtmlValue : '';
                String plainBody = tmpl.Body != null ? tmpl.Body : '';
                
                // 起点となるオブジェクト名を取得 (例: 'Contact', 'CustomObject__c')
                String sObjectName = input.recordId.getSobjectType().getDescribe().getName();
                
                // 2. 正規表現で {!xxx} をすべて抽出
                Set<String> mergeFields = new Set<String>();
                mergeFields.addAll(extractMergeFields(subject));
                mergeFields.addAll(extractMergeFields(htmlBody));
                mergeFields.addAll(extractMergeFields(plainBody));
                
                if(!mergeFields.isEmpty()) {
                    // 3. SOQL用の項目リストを作成
                    Set<String> queryFields = new Set<String>();
                    for(String mf : mergeFields) {
                        // $User などのグローバル変数は今回はSOQL対象外とする
                        if(mf.startsWithIgnoreCase('$')) continue;
                        
                        // 例: Contactから起動した際の {!Contact.LastName} -> LastName に変換
                        // 例: {!Account.Name} -> Account.Name のまま (リレーションとして扱う)
                        String qf = mf;
                        if(mf.startsWithIgnoreCase(sObjectName + '.')) {
                            qf = mf.substring(sObjectName.length() + 1);
                        }
                        queryFields.add(qf);
                    }
                    
                    // 4. 動的SOQLの組み立てと実行
                    if (!queryFields.isEmpty()) {
                        String query = 'SELECT ' + String.join(new List<String>(queryFields), ',') + 
                                       ' FROM ' + sObjectName + 
                                       ' WHERE Id = \'' + input.recordId + '\' LIMIT 1';
                        
                        SObject record = Database.query(query);
                        
                        // 5. 文字列の置換処理
                        for(String mf : mergeFields) {
                            if(mf.startsWithIgnoreCase('$')) continue; // グローバル変数はスキップ
                            
                            String qf = mf.startsWithIgnoreCase(sObjectName + '.') 
                                        ? mf.substring(sObjectName.length() + 1) : mf;
                            
                            // ドット区切り(親レコード)に対応した値の取得
                            String val = getFieldValue(record, qf);
                            String replaceTarget = '{!' + mf + '}';
                            
                            subject = subject.replace(replaceTarget, val);
                            htmlBody = htmlBody.replace(replaceTarget, val);
                            plainBody = plainBody.replace(replaceTarget, val);
                        }
                    }
                }
                
                output.subject = subject;
                output.htmlBody = htmlBody;
                output.plainTextBody = plainBody;
                output.isSuccess = true;
                
            } catch (Exception e) {
                output.isSuccess = false;
                output.errorMessage = e.getMessage() + ' (行: ' + e.getLineNumber() + ')';
                System.debug(LoggingLevel.ERROR, 'エラー: ' + output.errorMessage);
            }
            results.add(output);
        }
        return results;
    }
    
    // --- ヘルパーメソッド群 ---

    /**
     * テキストの中から {!xxx} の xxx の部分を抽出する
     */
    private static Set<String> extractMergeFields(String text) {
        Set<String> results = new Set<String>();
        if(String.isBlank(text)) return results;
        
        Pattern p = Pattern.compile('\\{!(.+?)\\}');
        Matcher m = p.matcher(text);
        while(m.find()) {
            results.add(m.group(1));
        }
        return results;
    }
    
    /**
     * SObjectからドット区切り（例: Account.Name）の項目値を再帰的に取得する
     */
    private static String getFieldValue(SObject record, String fieldPath) {
        if(record == null) return '';
        
        if(fieldPath.contains('.')) {
            // ドットで分割（親オブジェクト名と、それ以下のパス）
            List<String> parts = fieldPath.split('\\.', 2);
            SObject parentObj = record.getSObject(parts[0]);
            return getFieldValue(parentObj, parts[1]); // 再帰呼び出し
        } else {
            Object val = record.get(fieldPath);
            return val != null ? String.valueOf(val) : '';
        }
    }
}