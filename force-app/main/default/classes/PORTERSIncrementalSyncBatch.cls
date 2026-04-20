/**
 * 差分同期バッチ（個人連絡先）
 * コールアウト上限100回対応版（ページ単位でコールアウトを分散）
 */
global class PORTERSIncrementalSyncBatch implements Database.Batchable<Integer>, Database.AllowsCallouts {
    
    private Datetime lastSyncTime;
    private static Integer successCount = 0;
    private static Integer failedCount = 0;
    private static List<String> errors = new List<String>();
    
    // ページサイズ（APIの最大値200）
    private static final Integer PAGE_SIZE = 2000;
    // 使用するフィールド（getCandidatesSince と同じ）
    private static final String FIELDS = 'Person.P_Id,Person.P_Name,Person.P_Telephone,Person.P_Mail,Person.P_Mobile,Person.P_MobileMail,Person.P_RegistrationDate,Person.P_RegisteredBy,Person.P_UpdateDate,Person.P_UpdatedBy';
    // パーティションID（環境に応じて変更、またはカスタム設定から取得）
    private static final Integer PARTITION_ID = 2012;
    
    global PORTERSIncrementalSyncBatch() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        this.lastSyncTime = settings.LastSyncTime__c;
    }
    
    global Iterable<Integer> start(Database.BatchableContext bc) {
        // 1ページ目を取得して総件数を把握（1回のコールアウト）
        PORTERSDataService.PageResult firstPage = PORTERSDataService.getCandidatesPage(
            PARTITION_ID, FIELDS, lastSyncTime, 0, PAGE_SIZE
        );
        
        Integer totalRecords = firstPage.total;
        Integer totalPages = (totalRecords + PAGE_SIZE - 1) / PAGE_SIZE;
        
        // ページインデックス（0～totalPages-1）のリストを返す
        List<Integer> pageIndices = new List<Integer>();
        // for (Integer i = 0; i < totalPages; i++) {
        for (Integer i = 0; i < 2; i++) {
            pageIndices.add(i);
        }
        return pageIndices;
    }
    
    global void execute(Database.BatchableContext bc, List<Integer> scope) {
        Integer pageIndex = scope[0];
        Integer start = pageIndex * PAGE_SIZE;
        
        // try {
            // 1ページ分のデータを取得（1回のコールアウト）
            PORTERSDataService.PageResult pageResult = PORTERSDataService.getCandidatesPage(
                PARTITION_ID, FIELDS, lastSyncTime, start, PAGE_SIZE
            );
            
            // 同期実行
            PORTERSDataSync.SyncResult result = PORTERSDataSync.syncCandidates(pageResult.items);
        //     successCount += result.successCount;
        //     failedCount += result.failedCount;
        //     errors.addAll(result.errors);
            
        // } catch (Exception e) {
        //     failedCount += 1;
        //     errors.add('execute例外: ' + e.getMessage());
        // }
    }
    
    global void finish(Database.BatchableContext bc) {
        // 同期が1件以上成功した場合のみ最終同期日時を更新
        if (successCount > 0) {
            PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
            settings.LastSyncTime__c = System.now();
            upsert settings;
        }
    }
}