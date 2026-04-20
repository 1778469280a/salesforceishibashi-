public with sharing class CustomNavigationMenuController {
    @AuraEnabled(cacheable=true)
    public static Map<String, Integer> getBadgeCounts() {
        Map<String, Integer> results = new Map<String, Integer>{
            'process' => 0,
            'like' => 0
        };

        // ゲストユーザーの場合はクエリを実行せず0を返す
        if (Auth.CommunitiesUtil.isGuestUser()) {
            return results;
        }

        try {
            // 現在ログインしているユーザーのID
            Id currentUserId = UserInfo.getUserId();

            // ① 応募状況（SelectionProcess__c）の集計
            // ※必要に応じて「AND OwnerId = :currentUserId」などのユーザ絞り込みを追加してください
            results.put('process', [
                SELECT COUNT() 
                FROM SelectionProcess__c 
                WHERE LatestProcessStatus__c = 'JOB打診'
            ]);

            // ② 気になる（InterestedJob__c）の集計
            results.put('like', [
                SELECT COUNT() 
                FROM InterestedJob__c WHERE IsArchive__c = false
            ]);

        } catch (Exception e) {
            System.debug('バッジ件数取得エラー: ' + e.getMessage());
        }

        return results;
    }
}