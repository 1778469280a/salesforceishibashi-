public with sharing class BatchLauncher {
    @AuraEnabled
    public static void runCandiDataBatch(){
        Database.executeBatch(new PORTERS_BATCH_CandiData(), 200);
    }
    @AuraEnabled
    public static void runResumeBatch(){
        Database.executeBatch(new PORTERS_BATCH_ResumeData(), 200);
    }
}