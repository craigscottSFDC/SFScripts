public class FlowVersionCleaner {

    public static void cleanOldFlowVersions(Integer versionsToKeep) {
        if (versionsToKeep < 1 || versionsToKeep > 10) {
            throw new IllegalArgumentException('Please keep between 1 and 10 versions.');
        }

        // Get all flow definitions
        List<FlowDefinition> allFlowDefs = [
            SELECT Id, DeveloperName
            FROM FlowDefinition
            WHERE ManageableState = 'unmanaged'
        ];

        List<Flow> flowsToDelete = new List<Flow>();

        for (FlowDefinition def : allFlowDefs) {
            List<FlowVersionView> versions = [
                SELECT Id, Status, VersionNumber, DefinitionId
                FROM FlowVersionView
                WHERE DefinitionId = :def.Id
                ORDER BY VersionNumber DESC
            ];

            // Retain the top X versions, skip active versions in the remainder
            List<FlowVersionView> oldVersions = versions.size() > versionsToKeep
                ? versions.subList(versionsToKeep, versions.size())
                : new List<FlowVersionView>();

            for (FlowVersionView oldVersion : oldVersions) {
                if (oldVersion.Status != 'Active') {
                    flowsToDelete.add(new Flow(Id = oldVersion.Id));
                }
            }
        }

        if (!flowsToDelete.isEmpty()) {
            try {
                delete flowsToDelete;
                System.debug('Deleted ' + flowsToDelete.size() + ' old flow versions.');
            } catch (Exception e) {
                System.debug('Error deleting flows: ' + e.getMessage());
            }
        } else {
            System.debug('No flow versions to delete.');
        }
    }
}
