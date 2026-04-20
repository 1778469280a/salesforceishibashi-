public with sharing class LinkedMultiplePicklistController {
    
    /**
     * LWCの初期表示に必要なデータをまとめて返すラッパークラス
     */
    public class PicklistWrapper {
        @AuraEnabled public List<Map<String, String>> mappings; // メタデータのマッピング
        @AuraEnabled public String currentParentValues;       // 既存レコードの親項目の値
        @AuraEnabled public String currentChildValues;        // 既存レコードの子項目の値
    }

    /**
     * メタデータからのマッピング取得と、既存レコードからの値取得を一括で行う
     */
    @AuraEnabled(cacheable=true)
    public static PicklistWrapper getInitialData(
        String metadataName, String mParentField, String mChildField,
        String objectName, String oParentField, String oChildField, String recordId
    ) {
        PicklistWrapper wrapper = new PicklistWrapper();
        wrapper.mappings = new List<Map<String, String>>();

        try {
            // 1. カスタムメタデータから親子マッピングを取得
            // String.escapeSingleQuotes でSQLインジェクションを防止
            String mQuery = 'SELECT ' + String.escapeSingleQuotes(mParentField) + ', ' + 
                            String.escapeSingleQuotes(mChildField) + 
                            ' FROM ' + String.escapeSingleQuotes(metadataName);
            
            for (SObject m : Database.query(mQuery)) {
                wrapper.mappings.add(new Map<String, String>{
                    'parent' => (String)m.get(mParentField), 
                    'child' => (String)m.get(mChildField)
                });
            }

            // 2. 既存レコードから現在の選択リスト値を取得（recordIdがある場合のみ）
            if (String.isNotBlank(recordId) && String.isNotBlank(objectName) && 
                String.isNotBlank(oParentField) && String.isNotBlank(oChildField)) {
                
                String oQuery = 'SELECT ' + String.escapeSingleQuotes(oParentField) + ', ' + 
                                String.escapeSingleQuotes(oChildField) + 
                                ' FROM ' + String.escapeSingleQuotes(objectName) + 
                                ' WHERE Id = :recordId LIMIT 1';
                                
                List<SObject> records = Database.query(oQuery);
                if (!records.isEmpty()) {
                    wrapper.currentParentValues = (String)records[0].get(oParentField);
                    wrapper.currentChildValues = (String)records[0].get(oChildField);
                }
            }
        } catch (Exception e) {
            // エラー時はLWC側でキャッチできるようにAuraHandledExceptionを投げる
            throw new AuraHandledException('データ取得中にエラーが発生しました: ' + e.getMessage());
        }
        return wrapper;
    }
}