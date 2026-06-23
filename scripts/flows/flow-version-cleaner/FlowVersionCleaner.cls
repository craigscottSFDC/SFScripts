public class FlowVersionCleaner implements Queueable, Database.AllowsCallouts {

    private static final Integer CHUNK_SIZE = 10;

    @TestVisible
    private static Boolean skipEnqueueForTest = false;

    private final Integer versionsToKeep;
    private final List<String> idsToDelete;

    /**
     * Represents a single Flow version record returned by the Tooling API.
     * Maps to the Flow SObject fields queried during the identification phase.
     */
    private class FlowRecord {
        public String Id;
        public Integer VersionNumber;
        public String Status;
        public FlowDefinitionRef Definition;
    }

    /**
     * Nested reference object representing the parent Flow Definition.
     * Used to group Flow versions by their DeveloperName during processing.
     */
    private class FlowDefinitionRef {
        public String DeveloperName;
    }

    /**
     * Wrapper for the Tooling API query response envelope.
     * Deserializes the top-level size and records collection from the JSON body.
     */
    private class ToolingQueryResult {
        public Integer size;
        public List<FlowRecord> records;
    }

    /**
     * Phase 1 constructor. Initialises the job in query mode.
     * The idsToDelete list is intentionally null at this stage,
     * signalling the execute method to perform the Tooling API query first.
     *
     * @param versionsToKeep Number of most recent versions to retain per flow definition.
     */
    private FlowVersionCleaner(Integer versionsToKeep) {
        this.versionsToKeep = versionsToKeep;
        this.idsToDelete     = null;
    }

    /**
     * Phase 2 constructor. Initialises the job in delete mode with a pre-built list of IDs.
     * Used when chaining from Phase 1 or from a previous delete chunk job.
     * Marked TestVisible to allow direct instantiation from unit tests covering the delete phase.
     *
     * @param versionsToKeep Number of most recent versions to retain per flow definition.
     * @param idsToDelete    Full list of inactive Flow version IDs pending deletion.
     */
    @TestVisible
    private FlowVersionCleaner(Integer versionsToKeep, List<String> idsToDelete) {
        this.versionsToKeep = versionsToKeep;
        this.idsToDelete     = idsToDelete;
    }

    /**
     * Public entry point for the cleaner. Enqueues a Queueable job that identifies
     * and deletes old inactive Flow versions via the Tooling API, retaining only
     * the N most recent versions per flow definition by VersionNumber.
     * Active versions that fall outside the keep window are always preserved.
     *
     * Usage: FlowVersionCleaner.cleanOldFlowVersions(3);
     *
     * @param versionsToKeep Number of most recent versions to retain per flow. Must be >= 1.
     * @throws IllegalArgumentException if versionsToKeep is null or less than 1.
     */
    public static void cleanOldFlowVersions(Integer versionsToKeep) {
        if (versionsToKeep == null || versionsToKeep < 1) {
            throw new IllegalArgumentException('versionsToKeep must be at least 1.');
        }
        System.enqueueJob(new FlowVersionCleaner(versionsToKeep));
    }

    /**
     * Queueable execute method. Branches into one of two phases based on
     * whether idsToDelete has been populated.
     * Phase 1 performs the Tooling API query and chains into Phase 2.
     * Phase 2 deletes a chunk of IDs and chains again if any remain.
     *
     * @param context The QueueableContext provided by the platform at runtime.
     */
    public void execute(QueueableContext context) {
        if (idsToDelete == null) {
            List<String> ids = queryAndIdentifyIds();
            if (ids.isEmpty()) {
                System.debug('FlowVersionCleaner: No eligible flow versions to delete.');
                return;
            }
            System.debug('FlowVersionCleaner: ' + ids.size() + ' version(s) queued for deletion.');
            if (!skipEnqueueForTest) {
                System.enqueueJob(new FlowVersionCleaner(versionsToKeep, ids));
            }
        } else {
            deleteChunk();
        }
    }

    /**
     * Queries the Tooling API for all unmanaged Flow versions and determines
     * which ones are eligible for deletion. Versions are grouped by their
     * parent flow DeveloperName and ranked in descending VersionNumber order.
     * The top N versions per flow are retained unconditionally. Any version
     * ranked beyond N is added to the deletion list unless its Status is Active.
     *
     * @return A list of Tooling API Flow record IDs to be deleted.
     * @throws CalloutException if the Tooling API query returns a non-200 status code.
     */
    private List<String> queryAndIdentifyIds() {
        String baseUrl   = URL.getOrgDomainUrl().toExternalForm();
        String sessionId = UserInfo.getSessionId();

        String soql = 'SELECT+Id,VersionNumber,Status,Definition.DeveloperName'
            + '+FROM+Flow'
            + '+WHERE+ManageableState=\'unmanaged\''
            + '+ORDER+BY+Definition.DeveloperName,VersionNumber+DESC';

        HttpRequest req = new HttpRequest();
        req.setEndpoint(baseUrl + '/services/data/v62.0/tooling/query/?q=' + soql);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + sessionId);
        req.setHeader('Content-Type', 'application/json');

        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() != 200) {
            throw new CalloutException(
                'Tooling API query failed: ' + res.getStatus() + ' - ' + res.getBody()
            );
        }

        ToolingQueryResult result = (ToolingQueryResult) JSON.deserialize(
            res.getBody(), ToolingQueryResult.class
        );

        if (result == null || result.records == null || result.records.isEmpty()) {
            return new List<String>();
        }

        Map<String, List<FlowRecord>> versionsByFlow = new Map<String, List<FlowRecord>>();
        for (FlowRecord fr : result.records) {
            String devName = (fr.Definition != null) ? fr.Definition.DeveloperName : 'Unknown';
            if (!versionsByFlow.containsKey(devName)) {
                versionsByFlow.put(devName, new List<FlowRecord>());
            }
            versionsByFlow.get(devName).add(fr);
        }

        List<String> toDelete = new List<String>();
        for (String devName : versionsByFlow.keySet()) {
            Integer rank = 0;
            for (FlowRecord version : versionsByFlow.get(devName)) {
                rank++;
                if (rank <= versionsToKeep) {
                    continue;
                }
                if (version.Status == 'Active') {
                    continue;
                }
                toDelete.add(version.Id);
            }
        }
        return toDelete;
    }

    /**
     * Deletes a single chunk of Flow version IDs via individual Tooling API DELETE requests.
     * The chunk size is controlled by the CHUNK_SIZE constant to stay well within
     * the 120-second callout timeout and the 100-callout-per-transaction governor limit.
     * After processing the chunk, any remaining IDs are passed to a chained Queueable job.
     */
    private void deleteChunk() {
        Integer chunkStop  = Math.min(CHUNK_SIZE, idsToDelete.size());
        List<String> chunk = new List<String>();
        for (Integer i = 0; i < chunkStop; i++) {
            chunk.add(idsToDelete[i]);
        }

        List<String> remaining = new List<String>();
        for (Integer i = chunkStop; i < idsToDelete.size(); i++) {
            remaining.add(idsToDelete[i]);
        }

        String baseUrl   = URL.getOrgDomainUrl().toExternalForm();
        String sessionId = UserInfo.getSessionId();
        Http http        = new Http();
        Integer deleted  = 0;

        for (String flowId : chunk) {
            HttpRequest delReq = new HttpRequest();
            delReq.setEndpoint(baseUrl + '/services/data/v62.0/tooling/sobjects/Flow/' + flowId);
            delReq.setMethod('DELETE');
            delReq.setHeader('Authorization', 'Bearer ' + sessionId);

            HttpResponse delRes = http.send(delReq);

            if (delRes.getStatusCode() == 204) {
                deleted++;
            } else {
                System.debug(
                    'FlowVersionCleaner: Failed to delete Flow Id ' + flowId
                    + ' | ' + delRes.getStatus() + ' - ' + delRes.getBody()
                );
            }
        }

        System.debug('FlowVersionCleaner: Deleted ' + deleted + '/' + chunk.size()
            + ' in this chunk. Remaining: ' + remaining.size());

        if (!remaining.isEmpty()) {
            if (!skipEnqueueForTest) {
                System.enqueueJob(new FlowVersionCleaner(versionsToKeep, remaining));
            }
        } else {
            System.debug('FlowVersionCleaner: All deletions complete.');
        }
    }
}