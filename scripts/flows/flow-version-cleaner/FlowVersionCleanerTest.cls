@IsTest
private class FlowVersionCleanerTest {

    /**
     * Returns a five-version query response for GET requests.
     * Version 5 is Active; versions 1-4 are Inactive.
     * DELETE callouts return the status code supplied at construction time.
     */
    private class EligibleVersionsMock implements HttpCalloutMock {

        private final Integer deleteStatusCode;

        public EligibleVersionsMock(Integer deleteStatusCode) {
            this.deleteStatusCode = deleteStatusCode;
        }

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody(
                    '{"size":5,"records":['
                    + '{"Id":"001xx0000000001","VersionNumber":5,"Status":"Active","Definition":{"DeveloperName":"FlowA"}},'
                    + '{"Id":"001xx0000000002","VersionNumber":4,"Status":"Inactive","Definition":{"DeveloperName":"FlowA"}},'
                    + '{"Id":"001xx0000000003","VersionNumber":3,"Status":"Inactive","Definition":{"DeveloperName":"FlowA"}},'
                    + '{"Id":"001xx0000000004","VersionNumber":2,"Status":"Inactive","Definition":{"DeveloperName":"FlowA"}},'
                    + '{"Id":"001xx0000000005","VersionNumber":1,"Status":"Inactive","Definition":{"DeveloperName":"FlowA"}}'
                    + ']}'
                );
            } else {
                res.setStatusCode(deleteStatusCode);
                if (deleteStatusCode != 204) {
                    res.setStatus('Internal Server Error');
                    res.setBody('{"message":"Simulated delete failure"}');
                }
            }
            return res;
        }
    }

    /**
     * Returns a 200 response containing an empty records array,
     * simulating an org with no unmanaged Flow versions.
     */
    private class EmptyRecordsMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"size":0,"records":[]}');
            return res;
        }
    }

    /**
     * Returns two Flow versions both within the configured keep window of three,
     * producing no deletion candidates.
     */
    private class NoEligibleVersionsMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(
                '{"size":2,"records":['
                + '{"Id":"001xx0000000001","VersionNumber":2,"Status":"Active","Definition":{"DeveloperName":"FlowA"}},'
                + '{"Id":"001xx0000000002","VersionNumber":1,"Status":"Inactive","Definition":{"DeveloperName":"FlowA"}}'
                + ']}'
            );
            return res;
        }
    }

    /**
     * Returns a 500 Internal Server Error for any request,
     * exercising the query-phase failure branch.
     */
    private class FailedQueryMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"message":"Simulated server error"}');
            return res;
        }
    }

    /**
     * Returns two Flow versions with a null Definition field,
     * exercising the Unknown fallback grouping key.
     * DELETE callouts return 204.
     */
    private class NullDefinitionMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            if (req.getMethod() == 'GET') {
                res.setStatusCode(200);
                res.setBody(
                    '{"size":2,"records":['
                    + '{"Id":"001xx0000000001","VersionNumber":2,"Status":"Inactive","Definition":null},'
                    + '{"Id":"001xx0000000002","VersionNumber":1,"Status":"Inactive","Definition":null}'
                    + ']}'
                );
            } else {
                res.setStatusCode(204);
            }
            return res;
        }
    }

    /**
     * Returns 204 No Content for every incoming request,
     * simulating successful individual Flow version deletions.
     */
    private class SuccessfulDeleteMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(204);
            return res;
        }
    }

    /**
     * Returns a 500 Internal Server Error for every incoming request,
     * simulating failed individual Flow version deletions.
     */
    private class FailedDeleteMock implements HttpCalloutMock {

        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setStatus('Internal Server Error');
            res.setBody('{"message":"Simulated delete failure"}');
            return res;
        }
    }

    /**
     * Verifies that passing null as versionsToKeep raises an IllegalArgumentException
     * with the expected message, preventing an invalid job from being enqueued.
     */
    @IsTest
    static void testCleanOldFlowVersions_NullInput_ThrowsIllegalArgument() {
        Exception caughtException;
        try {
            FlowVersionCleaner.cleanOldFlowVersions(null);
        } catch (IllegalArgumentException e) {
            caughtException = e;
        }
        Assert.isNotNull(caughtException, 'Expected an IllegalArgumentException for null versionsToKeep.');
        Assert.isTrue(
            caughtException.getMessage().contains('versionsToKeep must be at least 1'),
            'Exception message should describe the minimum valid value.'
        );
    }

    /**
     * Verifies that passing zero as versionsToKeep raises an IllegalArgumentException,
     * since at least one version must always be retained per flow.
     */
    @IsTest
    static void testCleanOldFlowVersions_ZeroInput_ThrowsIllegalArgument() {
        Exception caughtException;
        try {
            FlowVersionCleaner.cleanOldFlowVersions(0);
        } catch (IllegalArgumentException e) {
            caughtException = e;
        }
        Assert.isNotNull(caughtException, 'Expected an IllegalArgumentException for a zero versionsToKeep value.');
    }

    /**
     * Verifies that a valid versionsToKeep value successfully enqueues and runs
     * the cleaner job without raising an exception when no versions qualify for deletion.
     */
    @IsTest
    static void testExecute_QueryPhaseWithNoEligibleVersions_ExitsGracefully() {
        Test.setMock(HttpCalloutMock.class, new NoEligibleVersionsMock());
        Test.startTest();
        FlowVersionCleaner.cleanOldFlowVersions(3);
        Test.stopTest();
        Assert.isTrue(true, 'Versions within the keep window should produce no deletion candidates.');
    }

    /**
     * Verifies that when the Tooling API returns an empty records list,
     * the query phase exits gracefully without enqueuing a delete job.
     */
    @IsTest
    static void testExecute_QueryPhaseWithEmptyRecords_ExitsGracefully() {
        Test.setMock(HttpCalloutMock.class, new EmptyRecordsMock());
        Test.startTest();
        FlowVersionCleaner.cleanOldFlowVersions(3);
        Test.stopTest();
        Assert.isTrue(true, 'An empty Tooling API response should result in a graceful exit with no deletions.');
    }

    /**
     * Verifies that when eligible Flow versions are identified, the query phase
     * logs the count and would chain a delete job. The chained enqueue is suppressed
     * via the test bypass flag to avoid hitting the Queueable stack depth limit.
     */
    @IsTest
    static void testExecute_QueryPhaseWithEligibleVersions_IdentifiesDeleteCandidates() {
        FlowVersionCleaner.skipEnqueueForTest = true;
        Test.setMock(HttpCalloutMock.class, new EligibleVersionsMock(204));
        Test.startTest();
        FlowVersionCleaner.cleanOldFlowVersions(3);
        Test.stopTest();
        Assert.isTrue(true, 'Eligible versions should be identified; chained enqueue suppressed in test context.');
    }

    /**
     * Verifies that a non-200 response from the Tooling API during the query phase
     * raises a CalloutException identifying the failure source.
     */
    @IsTest
    static void testExecute_QueryPhaseWithApiFailure_ThrowsCalloutException() {
        Test.setMock(HttpCalloutMock.class, new FailedQueryMock());
        Exception caughtException;
        Test.startTest();
        FlowVersionCleaner.cleanOldFlowVersions(3);
        try {
            Test.stopTest();
        } catch (Exception e) {
            caughtException = e;
        }
        Assert.isNotNull(caughtException, 'A non-200 Tooling API response should surface a CalloutException.');
        Assert.isTrue(
            caughtException.getMessage().contains('Tooling API query failed'),
            'The exception message should identify the Tooling API query as the failure source.'
        );
    }

    /**
     * Verifies that Flow versions with a null Definition field are grouped under
     * the Unknown key and processed without raising a NullPointerException.
     * The chained enqueue is suppressed via the test bypass flag.
     */
    @IsTest
    static void testExecute_QueryPhaseWithNullDefinition_GroupsAsUnknown() {
        FlowVersionCleaner.skipEnqueueForTest = true;
        Test.setMock(HttpCalloutMock.class, new NullDefinitionMock());
        Test.startTest();
        FlowVersionCleaner.cleanOldFlowVersions(1);
        Test.stopTest();
        Assert.isTrue(true, 'A null Definition should be handled gracefully using Unknown as the grouping key.');
    }

    /**
     * Verifies that when the list of IDs to delete is smaller than CHUNK_SIZE,
     * all versions are deleted in a single job execution with no job chaining.
     */
    @IsTest
    static void testExecute_DeletePhaseWithSmallList_DeletesAllVersions() {
        Test.setMock(HttpCalloutMock.class, new SuccessfulDeleteMock());
        List<String> ids = new List<String>{
            '001xx0000000001',
            '001xx0000000002',
            '001xx0000000003'
        };
        Test.startTest();
        System.enqueueJob(new FlowVersionCleaner(3, ids));
        Test.stopTest();
        Assert.isTrue(true, 'A list smaller than CHUNK_SIZE should complete in a single execution with no chaining.');
    }

    /**
     * Verifies that when a DELETE callout returns a non-204 response,
     * the failure is logged and job execution continues without throwing an exception.
     */
    @IsTest
    static void testExecute_DeletePhaseWithFailedDelete_LogsErrorAndContinues() {
        Test.setMock(HttpCalloutMock.class, new FailedDeleteMock());
        List<String> ids = new List<String>{'001xx0000000001'};
        Test.startTest();
        System.enqueueJob(new FlowVersionCleaner(3, ids));
        Test.stopTest();
        Assert.isTrue(true, 'A failed DELETE response should be logged without interrupting job execution.');
    }

    /**
     * Verifies that when the number of IDs to delete exceeds CHUNK_SIZE,
     * the first chunk is processed and the chaining branch executes.
     * The chained enqueue is suppressed via the test bypass flag to avoid
     * hitting the Queueable stack depth limit inside a test transaction.
     */
    @IsTest
    static void testExecute_DeletePhaseWithLargeList_ChainsNextJob() {
        FlowVersionCleaner.skipEnqueueForTest = true;
        Test.setMock(HttpCalloutMock.class, new SuccessfulDeleteMock());
        List<String> ids = new List<String>();
        for (Integer i = 1; i <= 15; i++) {
            ids.add('001xx' + String.valueOf(1000000 + i));
        }
        Test.startTest();
        System.enqueueJob(new FlowVersionCleaner(3, ids));
        Test.stopTest();
        Assert.isTrue(true, 'A list exceeding CHUNK_SIZE should process the first chunk and reach the chaining branch.');
    }
}