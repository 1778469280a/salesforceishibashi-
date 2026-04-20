global class PORTERSResumeScheduledSync implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new PORTERSResumeIncrementalSyncBatch(), 1);
    }
}