/**
 * 差分同期バッチ（キャンディデイト）
 * ・前回の同期日時以降に更新されたキャンディデイトデータのみを取得し、Salesforceに upsert する
 * ・バッチの状態を保持するため Database.Stateful を実装
 * ・開始・実行・終了の各フェーズで処理を分離
 */
global class PORTERSResumeIncrementalSyncBatch implements Database.Batchable<SObject>, Database.Stateful {
    
    // バッチ開始時刻（終了時に最終同期日時として使用）
    private Datetime startTime;
    // 前回の同期日時（差分取得の基準）
    private Datetime lastSyncTime;
    // 同期結果を蓄積するオブジェクト
    private PORTERSResumeSync.SyncResult syncResult;
    
    /**
     * コンストラクタ
     * ・カスタム設定から前回同期日時を読み込む
     * ・現在時刻を開始時刻として記録
     * ・同期結果オブジェクトを初期化
     */
    global PORTERSResumeIncrementalSyncBatch() {
        PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
        this.lastSyncTime = settings.LastResumeSyncTime__c;          // 最終同期日時（未設定の場合は null）
        this.startTime = System.now();                          // バッチ開始時刻を保存
        this.syncResult = new PORTERSResumeSync.SyncResult();   // 結果保持用
    }
    
    /**
     * バッチの開始時に呼ばれる
     * ・実際の処理対象レコードはここでは返さず、ダミーのリストを返す
     * ・後続の execute で全データを一度に処理する
     * @return ダミーの SObject リスト（実際のデータ取得は execute 内で実施）
     */
    global Iterable<SObject> start(Database.BatchableContext bc) {
        // ダミーレコードを1件含むリスト（実際のデータ処理は execute で行うため）
        return new List<SObject>{ new IF_pts_resume__c(Id=null) };
    }
    
    /**
     * バッチの実行時に呼ばれる
     * ・前回同期日時以降に更新された履歴書データを取得
     * ・取得したデータを Salesforce に upsert
     * ・結果を syncResult に蓄積
     * @param bc バッチコンテキスト（未使用）
     * @param scope start で返したダミーリスト（実際には使用しない）
     */
    global void execute(Database.BatchableContext bc, List<SObject> scope) {
        try {
            // 差分データを取得（前回同期日時を条件に）
            List<PORTERSResumeService.Resume> resumes = PORTERSResumeService.getResumesSince(null, lastSyncTime);
            // Salesforce へ同期
            PORTERSResumeSync.SyncResult result = PORTERSResumeSync.syncResumes(resumes);
            // 結果を集計
            syncResult.successCount += result.successCount;
            syncResult.failedCount += result.failedCount;
            syncResult.errors.addAll(result.errors);
        } catch (Exception e) {
            // 予期せぬ例外が発生した場合も失敗としてカウント
            syncResult.failedCount += 1;
            syncResult.errors.add('execute 例外: ' + e.getMessage());
        }
    }
    
    /**
     * バッチの終了時に呼ばれる
     * ・同期が一部でも成功した場合、または全件失敗でない場合に最終同期日時を更新
     * ・更新する日時はバッチ開始時刻（startTime）を使用
     * ・更新した日時は次回バッチ実行時の差分取得条件として使用される
     * @param bc バッチコンテキスト（未使用）
     */
    global void finish(Database.BatchableContext bc) {
        // 同期が1件以上成功した場合、または失敗が0件の場合に日時を更新
        if (syncResult.successCount > 0 || syncResult.failedCount == 0) {
            PORTERS_Settings__c settings = PORTERS_Settings__c.getOrgDefaults();
            settings.LastResumeSyncTime__c = this.startTime;   // バッチ開始時刻を最終同期日時として保存
            update settings;
        }
    }
}