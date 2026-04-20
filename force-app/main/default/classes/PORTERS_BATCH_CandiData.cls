public class PORTERS_BATCH_CandiData implements Database.Batchable<Integer>, Database.AllowsCallouts {

    private Datetime lastSyncTime;
    Integer pageSize = 200;
    // 使用するフィールド（getCandidatesSince と同じ）
    private static final String FIELDS = 'Person.P_Id,Person.P_Name,Person.P_Telephone,Person.P_Mail,Person.P_Mobile,Person.P_MobileMail,Person.P_RegistrationDate,Person.P_RegisteredBy,Person.P_UpdateDate,Person.P_UpdatedBy';
    public PORTERS_BATCH_CandiData(){
        PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
        this.lastSyncTime = settings.LastSyncTime__c; 
    }

    public Iterable<Integer> start(Database.BatchableContext bc){
       
        PORTERS_DTO_CandidateResponse res =
            PORTERS_API_GetCandiData.getCandiData(FIELDS,lastSyncTime, 0);

        Integer totalCount = res.totalCount;

        Integer totalPage = (Integer)Math.ceil((Double)totalCount / pageSize);

        List<Integer> pages = new List<Integer>();
        pages.add(0);
        //for(Integer i=0;i<totalPage;i++){
        //    pages.add(i);
        //}

        return pages;
    }
    
    public void execute(Database.BatchableContext bc, List<Integer> scope){

        List<IF_pts_Can__c> allRecords =
            new List<IF_pts_Can__c>();
    
        for(Integer page : scope){
            Integer start = page * pageSize;
            PORTERS_DTO_CandidateResponse res =
                PORTERS_API_GetCandiData.getCandiData(FIELDS,lastSyncTime, start);
    
            for(PORTERS_DTO_CandidateResponse.Wrapper wrapper:res.result){
                IF_pts_Can__c ptsCan = new IF_pts_Can__c();
                ptsCan = res.convertToIF(wrapper);
                allRecords.add(ptsCan);
            }
        }
    
        if(!allRecords.isEmpty()){
            Database.insert(allRecords,true);
        }
    }
    
    public void finish(Database.BatchableContext bc){
        PORTERSAPI_Settings__c settings = PORTERSAPI_Settings__c.getOrgDefaults();
        settings.LastSyncTime__c = System.now();
        upsert settings;

    }
}