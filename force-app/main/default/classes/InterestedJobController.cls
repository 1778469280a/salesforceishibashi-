public with sharing class InterestedJobController {
    /**
     * ログインユーザーが「気になる求人」として保存した、アーカイブされていないレコードの一覧を返します。
     * 求人情報 (Job__c) の一部フィールドも同時に取得し、最終更新日時の降順で並べ替えます。
     *
     * @return  未アーカイブの InterestedJob__c レコードのリスト
     */
    @AuraEnabled
    public static List<InterestedJob__c> getInterestedJobs() {
        return [
            SELECT Id, Job__c, LastModifiedDate,
                   Job__r.JobPosition__c, Job__r.JobDescription__c,
                   Job__r.MinAnnualSalary__c, Job__r.MaxAnnualSalary__c,
                   Job__r.WorkLocation2__c, Job__r.JobCategory1__c, Job__r.Company__r.MainIndustry__c,
                   Job__r.LastModifiedDate, Job__r.LastViewedDate
            FROM InterestedJob__c
            WHERE IsArchive__c = false
            ORDER BY LastModifiedDate DESC
        ];
    }

    /**
     * 指定された「気になる求人」レコードをアーカイブします（IsArchive__c を true に更新）。
     *
     * @param jobId  アーカイブ対象の InterestedJob__c レコードの ID
     */
    @AuraEnabled
    public static void archiveSingleJob(Id jobId) {
        InterestedJob__c job = [SELECT Id FROM InterestedJob__c WHERE Id = :jobId];
        job.IsArchive__c = true;
        job.Aggregation__c = true;
        update job;
    }

    /**
     * 複数の「気になる求人」レコードを一括でアーカイブします。
     *
     * @param jobIds  アーカイブ対象の InterestedJob__c レコードの ID リスト
     */
    @AuraEnabled
    public static void archiveBulkJobs(List<Id> jobIds) {
        List<InterestedJob__c> jobs = [SELECT Id FROM InterestedJob__c WHERE Id IN :jobIds];
        for (InterestedJob__c job : jobs) {
            job.IsArchive__c = true;
            job.Aggregation__c = true;
        }
        update jobs;
    }
}