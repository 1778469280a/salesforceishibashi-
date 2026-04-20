/**
 * PORTERS Data Sync（個人連絡先同期クラス）
 * ・PORTERSから取得した個人連絡先データをSalesforceオブジェクトに同期（upsert）する
 * ・フィールドマッピングに基づき、API項目をカスタム項目に変換
 * ・外部ID（IndividualContactId__c）をキーにして重複を防止
 */
public with sharing class PORTERSDataSync {
    
    // フィールドマッピング：PORTERS API 項目名 → Salesforce 項目 API 名
    private static final Map<String, String> FIELD_MAPPING = new Map<String, String>{
        'Person.P_Id'               => 'IndividualContactId__c',
        'Person.P_Name'             => 'IndividualName__c',
        'Person.P_Telephone'        => 'IndividualPhone__c',
        'Person.P_Mobile'           => 'IndividualMobilePhone__c',
        'Person.P_Mail'             => 'IndividualEmail__c',
        'Person.P_MobileMail'       => 'IndividualMobileEmail__c',
        'Person.P_RegistrationDate' => 'CreatedDate__c',
        'Person.P_RegisteredBy'     => 'CreatedBy__c',
        'Person.P_UpdateDate'       => 'LastModifiedDate__c',
        'Person.P_UpdatedBy'        => 'LastModifiedBy__c'
    };
    
    // 同期先オブジェクトのAPI名（実際の環境に合わせて変更）
    private static final String TARGET_OBJECT = 'IF_pts_Can__c';
    
    /**
     * 個人連絡先リストをSalesforceに同期する
     * @param candidates PORTERSから取得したCandidateリスト
     * @return SyncResult 同期結果（成功件数、失敗件数、エラー詳細）
     * @throws PORTERSException 対象オブジェクトまたは外部IDフィールドが存在しない場合
     */
    public static SyncResult syncCandidates(List<PORTERSDataService.Candidate> candidates) {
        SyncResult result = new SyncResult();
        
        // 入力チェック
        if (candidates == null || candidates.isEmpty()) {
            return result;
        }
        
        // 対象オブジェクトのSObjectTypeを取得
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(TARGET_OBJECT);
        if (targetType == null) {
            throw new PORTERSException('対象オブジェクト ' + TARGET_OBJECT + ' が存在しません。オブジェクト名を確認してください。');
        }
        
        List<SObject> recordsToUpsert = new List<SObject>();
        
        // 各個人連絡先をSalesforceレコードに変換
        for (PORTERSDataService.Candidate cand : candidates) {
            SObject record = targetType.newSObject();
            
            // マッピングに従ってフィールドを設定
            for (String portersField : FIELD_MAPPING.keySet()) {
                String sfField = FIELD_MAPPING.get(portersField);
                String value = cand.fields.get(portersField);
                if (String.isNotBlank(value)) {
                    record.put(sfField, value);
                }
            }
            
            // 外部ID（Person.P_Id）を設定（必須）
            String externalId = cand.getPersonId();
            if (String.isNotBlank(externalId)) {
                record.put('IndividualContactId__c', externalId);
                recordsToUpsert.add(record);
            } else {
                result.failedCount++;
                result.errors.add('個人連絡先に Person.P_Id がありません。同期できません。');
            }
        }
        
        // upsert実行
        if (!recordsToUpsert.isEmpty()) {
            // try {
                // 外部IDフィールドの存在確認
                Schema.SObjectField externalIdField = targetType.getDescribe().fields.getMap().get('IndividualContactId__c');
                if (externalIdField == null) {
                    throw new PORTERSException('外部ID項目 IndividualContactId__c が存在しません。項目名を確認してください。');
                }
                
                // 部分許容モードでupsert
                Database.UpsertResult[] upsertResults = Database.upsert(recordsToUpsert, externalIdField, true);
                
            //     // 結果を集計
            //     for (Integer i = 0; i < upsertResults.size(); i++) {
            //         Database.UpsertResult ur = upsertResults[i];
            //         if (ur.isSuccess()) {
            //             result.successCount++;
            //         } else {
            //             result.failedCount++;
            //             String errorMsg = 'レコード (外部ID: ' + recordsToUpsert[i].get('IndividualContactId__c') + ') 失敗: ';
            //             for (Database.Error err : ur.getErrors()) {
            //                 errorMsg += err.getMessage() + '; ';
            //             }
            //             result.errors.add(errorMsg);
            //         }
            //     }
            // } catch (Exception e) {
            //     // 予期せぬ例外は全件失敗として扱う
            //     result.failedCount = recordsToUpsert.size();
            //     result.errors.add('一括 upsert 例外: ' + e.getMessage());
            // }
        }
        
        return result;
    }
    
    /**
     * 同期結果を保持する内部クラス
     */
    public class SyncResult {
        public Integer successCount { get; set; }   // 成功件数
        public Integer failedCount { get; set; }    // 失敗件数
        public List<String> errors { get; set; }    // エラー詳細リスト
        
        public SyncResult() {
            successCount = 0;
            failedCount = 0;
            errors = new List<String>();
        }
    }
    
    /**
     * カスタム例外クラス
     */
    public class PORTERSException extends Exception {}
}