public with sharing class RecentJobViewedController {
    public class JobWrapper {
        @AuraEnabled public Id Id;                    // 求人ID
        @AuraEnabled public String JobPosition;       // 求人タイトル（ポジション名）
        @AuraEnabled public String WorkLocation2;     // 勤務地
        @AuraEnabled public String JobCategory1;      // 職種（大分類）
        @AuraEnabled public Decimal MaxAnnualSalary;  // 年収上限（万円）
        @AuraEnabled public Decimal MinAnnualSalary;  // 年収下限（万円）
        @AuraEnabled public String JobDescription;    // 仕事内容
        @AuraEnabled public Datetime LastModifiedDate;// 最終更新日時
        @AuraEnabled public Datetime LastViewedDate;  // 最終閲覧日時
        @AuraEnabled public Boolean IsFavorite;       // お気に入り登録済みフラグ
        @AuraEnabled public String MainIndustry;      // 企業.メイン業種
    }
    // テスト実行時に強制的に例外を発生させるためのフラグ（@TestVisible でテストクラスからアクセス可能）
    @TestVisible
    private static Boolean testForceException = false;

    @AuraEnabled(cacheable=true)
    public static List<Job__c> getRecentViewedJobs() {
        try {
            if (Test.isRunningTest() && testForceException) {
                throw new DmlException('テストによる強制例外');
            }

            return [
                SELECT Id, Name, JobPosition__c, LastViewedDate
                FROM Job__c
                WHERE LastViewedDate != NULL
                ORDER BY LastViewedDate DESC
                LIMIT 4
            ];
        } catch (Exception e) {
            throw new AuraHandledException('求人情報の取得に失敗しました: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<JobWrapper> getRecentViewedDetailJobs() {
        try {
            List<JobWrapper> result = new List<JobWrapper>();
            if (Test.isRunningTest() && testForceException) {
                throw new DmlException('テストによる強制例外');
            }

            List<Job__c> jobs = [
                SELECT Id, JobPosition__c, WorkLocation2__c, JobCategory1__c, 
                MaxAnnualSalary__c, MinAnnualSalary__c, JobDescription__c,
                LastModifiedDate, LastViewedDate, Company__r.MainIndustry__c
                FROM Job__c
                WHERE LastViewedDate != NULL
                ORDER BY LastViewedDate DESC
            ];

            Set<Id> favoriteJobIds = new Set<Id>();
            Id userId = UserInfo.getUserId();
            if (userId != null) {
                for (InterestedJob__c fav : [SELECT Job__c FROM InterestedJob__c WHERE CreatedById = :userId AND IsArchive__c = false LIMIT 2000]) {
                    favoriteJobIds.add(fav.Job__c);
                }
            }

            for (Job__c j : jobs) {
                JobWrapper wrapper = new JobWrapper();
                wrapper.Id = j.Id;
                wrapper.JobPosition = j.JobPosition__c;
                wrapper.WorkLocation2 = j.WorkLocation2__c;
                wrapper.JobCategory1 = j.JobCategory1__c;
                wrapper.MaxAnnualSalary = j.MaxAnnualSalary__c;
                wrapper.MinAnnualSalary = j.MinAnnualSalary__c;
                wrapper.JobDescription = j.JobDescription__c;
                wrapper.LastModifiedDate = j.LastModifiedDate;
                wrapper.LastViewedDate = j.LastViewedDate;
                wrapper.IsFavorite = favoriteJobIds.contains(j.Id);
                wrapper.MainIndustry = j.Company__r != null ? j.Company__r.MainIndustry__c : null;
                result.add(wrapper);
            }
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('求人情報の取得に失敗しました: ' + e.getMessage());
        }
    }
}