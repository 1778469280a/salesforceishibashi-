global class PORTERSScheduledSync implements Schedulable {
    global void execute(SchedulableContext sc) {
        Database.executeBatch(new PORTERSIncrementalSyncBatch(), 1);
    }
}