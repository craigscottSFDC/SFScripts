// Replace <TargetClassName> with the Apex class name to target (supports LIKE wildcards).
String targetClassName = '<TargetClassName>';

List<AsyncApexJob> waitingJobs = [
    SELECT Id, CronTriggerId, JobType, ApexClass.Name
    FROM AsyncApexJob
    WHERE Status IN ('Queued', 'Holding', 'Preparing')
      AND ApexClass.Name LIKE :targetClassName
    LIMIT 200
];

for (AsyncApexJob job : waitingJobs) {
    try {
        if (job.JobType == 'ScheduledApex') {
            if (job.CronTriggerId != null) {
                System.abortJob(job.CronTriggerId);
            }
        } else {
            System.abortJob(job.Id);
        }
    } catch (Exception e) {
        System.debug(LoggingLevel.ERROR, 'Failed to abort Job ' + job.Id + ' for class ' + job.ApexClass.Name + ': ' + e.getMessage());
    }
}
