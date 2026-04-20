public with sharing class ProcessController {
    @AuraEnabled(cacheable=true)
    public static List<SelectionProcess__c> getProcesses() {
        return [
            SELECT 
                Id, 
                JobPosition__c,
                LastModifiedDate,
                LatestProcessStatus__c,
                First_interview_date__c,
                Second_interview_date__c,
                Third_interview_date__c,
                Final_interview_date__c,
                JobPosition__r.Id,
                JobPosition__r.Company__r.Name,
                JobPosition__r.JobPosition__c,
                JobPosition__r.JobCategory1__c,
                JobPosition__r.WorkLocation2__c,
                JobPosition__r.LastViewedDate
            FROM SelectionProcess__c
            WHERE LatestProcessStatus__c != null
            AND JobPosition__c != null
            ORDER BY LastModifiedDate DESC 
        ];
    } 
}