// Removes all permission set assignments (non-profile) from the specified users,
// reassigns them to a reduced-access profile, then assigns a single permission set group.
// Update the three ID variables before running in Anonymous Apex.

List<Id> userIds = new List<Id>{
    '<userid>','<userid>','<userid>'
};

Id profileId      = '<profile id to be assigned>';
Id permSetGroupId = '<permission set group id to be assigned>';

// Step 1: delete all non-profile permission set assignments for these users
List<PermissionSetAssignment> toDelete = [
    SELECT Id, PermissionSet.IsOwnedByProfile
    FROM PermissionSetAssignment
    WHERE AssigneeId IN :userIds
];

List<PermissionSetAssignment> safeToDelete = new List<PermissionSetAssignment>();
for (PermissionSetAssignment psa : toDelete) {
    if (!psa.PermissionSet.IsOwnedByProfile) {
        safeToDelete.add(psa);
    }
}
delete safeToDelete;

// Step 2: reassign users to the reduced-access profile
List<User> usersToUpdate = [SELECT Id, ProfileId FROM User WHERE Id IN :userIds];
for (User u : usersToUpdate) {
    u.ProfileId = profileId;
}
update usersToUpdate;

// Step 3: assign the reduced-access permission set group
List<PermissionSetAssignment> toInsert = new List<PermissionSetAssignment>();
for (Id uid : userIds) {
    toInsert.add(new PermissionSetAssignment(
        AssigneeId          = uid,
        PermissionSetGroupId = permSetGroupId
    ));
}
insert toInsert;
