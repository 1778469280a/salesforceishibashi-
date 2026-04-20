global class PORTERS_BATCH_ResumeDataScheduler implements Schedulable,Database.AllowsCallouts {

     global void execute(SchedulableContext ctx) {
        Database.executeBatch(new PORTERS_BATCH_ResumeData(),10);
    }
}