/**
 * 求人カード表示用のコントローラクラス
 * ログインユーザーのお気に入り情報を考慮した求人リストの取得と、
 * お気に入り状態の切り替え機能を提供します。
 */
public with sharing class JobCardsController {

    /**
     * 求人情報をラップするラッパークラス
     * AuraEnabled フィールドを持つことで、LWC とのデータ受け渡しを容易にします。
     */
    public class JobWrapper {
        @AuraEnabled public Id Id;                      // 求人ID
        @AuraEnabled public String JobPosition;         // 求人タイトル（ポジション名）
        @AuraEnabled public String WorkLocation2;       // 勤務地
        @AuraEnabled public String JobCategory1;        // 職種
        @AuraEnabled public String MainIndustry;        // 業種
        @AuraEnabled public Decimal MaxAnnualSalary;    // 年収上限（万円）
        @AuraEnabled public Decimal MinAnnualSalary;    // 年収下限（万円）
        @AuraEnabled public String JobDescription;      // 仕事内容
        @AuraEnabled public Datetime LastModifiedDate;  // 最終更新日時
        @AuraEnabled public Datetime LastViewedDate;    // 最終閲覧日時
        @AuraEnabled public Boolean IsFavorite;         // お気に入りフラグ
    }

    /**
     * ログインユーザー向けの求人リストを取得します。
     * - 最大10件まで、最終更新日時の降順で取得します。
     * - ユーザーが「気になる求人」に追加済みのレコードは IsFavorite フラグが true になります。
     *
     * @return  求人情報を含む JobWrapper のリスト
     */
    @AuraEnabled
    public static List<JobWrapper> getJobs() {
        // ログインユーザーが未アーカイブの「気になる求人」として登録している Job__c のIDセットを取得
        Set<Id> favoriteJobIds = new Set<Id>();
        for (InterestedJob__c fav : [
            SELECT Job__c FROM InterestedJob__c
            WHERE CreatedById = :UserInfo.getUserId() AND IsArchive__c = false
        ]) {
            favoriteJobIds.add(fav.Job__c);
        }

        // 求人情報を取得（最終更新日時の降順、最大10件）
        List<Job__c> jobs = [
            SELECT Id, JobPosition__c, WorkLocation2__c, JobCategory1__c,
                   MaxAnnualSalary__c, MinAnnualSalary__c, Company__r.MainIndustry__c,
                   JobDescription__c, LastModifiedDate, LastViewedDate
            FROM Job__c
            ORDER BY LastModifiedDate DESC
            LIMIT 10
        ];

        // 取得した求人をラッパーに変換し、お気に入りフラグを付与
        List<JobWrapper> result = new List<JobWrapper>();
        for (Job__c j : jobs) {
            JobWrapper wrapper = new JobWrapper();
            wrapper.Id = j.Id;
            wrapper.JobPosition = j.JobPosition__c;
            wrapper.WorkLocation2 = j.WorkLocation2__c;
            wrapper.MainIndustry = j.Company__r.MainIndustry__c;
            wrapper.JobCategory1 = j.JobCategory1__c;
            wrapper.MaxAnnualSalary = j.MaxAnnualSalary__c;
            wrapper.MinAnnualSalary = j.MinAnnualSalary__c;
            wrapper.JobDescription = j.JobDescription__c;
            wrapper.LastModifiedDate = j.LastModifiedDate;
            wrapper.LastViewedDate = j.LastViewedDate;
            wrapper.IsFavorite = favoriteJobIds.contains(j.Id);
            result.add(wrapper);
        }
        return result;
    }

    /**
     * 指定された求人に対するお気に入り状態を切り替えます。
     * - 既存の InterestedJob__c レコードが存在する場合、IsArchive__c を !isFavorite に更新します。
     * - 存在しない場合、isFavorite = true なら新規レコードを作成します。
     *
     * @param jobId       対象の求人ID（Job__c.Id）
     * @param isFavorite  設定したいお気に入り状態（true: お気に入りに追加 / false: お気に入りから削除）
     * @return            処理が成功した場合は true、例外発生時は false
     */
    @AuraEnabled
    public static Boolean toggleFavoriteJob(String jobId, Boolean isFavorite) {
        try {
            Id userId = UserInfo.getUserId();
            // 現在のユーザーによる当該求人に対する InterestedJob__c レコードを検索
            List<InterestedJob__c> existingRecords = [
                SELECT Id, IsArchive__c FROM InterestedJob__c
                WHERE Job__c = :jobId AND CreatedById = :userId
                LIMIT 1
            ];

            if (!existingRecords.isEmpty()) {
                // 既存レコードがある場合：アーカイブ状態を設定（未アーカイブ＝お気に入り）
                InterestedJob__c favRecord = existingRecords[0];
                favRecord.IsArchive__c = !isFavorite;   // isFavorite = true → 未アーカイブ(false)
                favRecord.Aggregation__c = true;
                update favRecord;
            } else {
                // 既存レコードがない場合：isFavorite = true なら新規作成
                if (isFavorite) {
                    InterestedJob__c newFavRecord = new InterestedJob__c();
                    newFavRecord.Job__c = jobId;
                    newFavRecord.IsArchive__c = false;   // お気に入り（未アーカイブ）
                    newFavRecord.Aggregation__c = true;
                    insert newFavRecord;
                }
                // isFavorite = false かつレコードが存在しない場合は何もしない
            }
            return true;
        } catch (Exception e) {
            System.debug('お気に入り状態の切り替えに失敗しました：' + e.getMessage());
            return false;
        }
    }
}