global class PORTERS_BATCH_CandiDataScheduler implements Schedulable,Database.AllowsCallouts {

     global void execute(SchedulableContext ctx) {
        Database.executeBatch(new PORTERS_BATCH_CandiData(),10);
    }
}