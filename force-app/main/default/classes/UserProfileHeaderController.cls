public with sharing class UserProfileHeaderController {
    
    @AuraEnabled(cacheable=true)
    public static List<SelectionProcess__c> getSelectionProcesses() {
        // ログイン中のユーザーIDを取得
        Id currentUserId = UserInfo.getUserId();

        // ユーザー自身のレコードを取得（集計せず、ステータス項目だけ取得）
        return [
            SELECT Id, LatestProcessStatus__c
            FROM SelectionProcess__c
            WHERE LatestProcessStatus__c != null
            AND JobPosition__c != null
        ];
    }
}