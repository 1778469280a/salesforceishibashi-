public with sharing class JobListController {
    @AuraEnabled(cacheable=true)
    public static List<Job__c> getJobList() {
        return [
            SELECT Id, JobPosition__c, WorkLocation2__c, JobCategory1__c,
                   MaxAnnualSalary__c, MinAnnualSalary__c, Company__r.MainIndustry__c,
                   JobDescription__c, LastModifiedDate, LastViewedDate
            FROM Job__c
            ORDER BY LastModifiedDate DESC
        ];
    }
}