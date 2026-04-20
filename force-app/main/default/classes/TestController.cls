public with sharing class TestController {

    @AuraEnabled(cacheable=true)
    public static List<Job__c> getJobs() {
        List<Job__c> jobs = [SELECT Id
                                    ,JobPosition__c  //ポジション
                                    ,WorkLocation2__c  //勤務地
                                    ,MaxAnnualSalary__c  //年収上限［万円］
                                    ,MinAnnualSalary__c  //年収下限［万円］
                                    ,JobDescription__c   //仕事内容
                                    ,LastModifiedDate
                                FROM Job__c 
                                WHERE LastModifiedDate != NULL ORDER BY LastModifiedDate DESC LIMIT 4 
                            ];

        return jobs;
    }
}