public class PORTERS_BATCH_ResumeData implements Database.Batchable<Integer>, Database.AllowsCallouts {

    private Datetime lastSyncTime;
    Integer pageSize = 200;
    // 使用するフィールド（getCandidatesSince と同じ）
    public PORTERS_BATCH_ResumeData (){
        PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
        this.lastSyncTime = settings.LastResumeSyncTime__c; 
    }

    public Iterable<Integer> start(Database.BatchableContext bc){
       
        PORTERS_DTO_ResumeDateResponse res =
            PORTERS_API_GetResumeData.getResumeData(lastSyncTime, 0);

        Integer totalCount = res.totalCount;

        Integer totalPage = (Integer)Math.ceil((Double)totalCount / pageSize);

        List<Integer> pages = new List<Integer>{0};
        /*
        for(Integer i=0;i<=totalPage;i++){
            pages.add(i);
        }
*/
        return pages;
    }
    
    public void execute(Database.BatchableContext bc, List<Integer> scope){

        List<IF_pts_resume__c> allRecords =
            new List<IF_pts_resume__c>();
        Set<String> contactIDSet = new Set<String>();
        for(Integer page : scope){
            Integer start = page * pageSize;
            PORTERS_DTO_ResumeDateResponse res =
            PORTERS_API_GetResumeData.getResumeData(lastSyncTime, 0);
    
            for(PORTERS_DTO_ResumeDateResponse.Wrapper wrapper:res.result){
                IF_pts_resume__c resume = new IF_pts_resume__c();
                resume = res.convertToIF(wrapper);
                contactIDSet.add(resume.IndividualContactID__c);
                allRecords.add(resume);
            }
        }
        Map<String,Id> contactIDMap = new Map<String,Id>();
        for (IF_pts_Can__c can : [SELECT Id, IndividualContactId__c FROM IF_pts_Can__c WHERE IndividualContactId__c IN:contactIDSet]) {
            contactIDMap.put(can.IndividualContactId__c, can.Id);
        }
        for (IF_pts_resume__c record : allRecords) {
            if (record.IndividualContactId__c != NULL && contactIDMap.containsKey(record.IndividualContactId__c)) {
               record.IF_pts_CanId__c =  contactIDMap.get(record.IndividualContactId__c);
            }
        }
        if(!allRecords.isEmpty()){
            Database.insert(allRecords,true);
        }
    }
    
    public void finish(Database.BatchableContext bc){
        PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
        settings.LastResumeSyncTime__c = System.now();
        upsert settings;

    }
}