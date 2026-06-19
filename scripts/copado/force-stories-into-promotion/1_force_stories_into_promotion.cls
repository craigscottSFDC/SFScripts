// 1. Paste your newly created Promotion ID here
Id promotionId = '<PromotionId>';

// 2. Your list of User Story IDs to force into the promotion
List<Id> storyIds = new List<Id>{
    '<UserStoryId1>',
    '<UserStoryId2>'
};

List<copado__Promoted_User_Story__c> objectsToInsert = new List<copado__Promoted_User_Story__c>();

for (Id storyId : storyIds) {
    objectsToInsert.add(new copado__Promoted_User_Story__c(
        copado__User_Story__c = storyId,
        copado__Promotion__c = promotionId
    ));
}

if (!objectsToInsert.isEmpty()) {
    insert objectsToInsert;
    System.debug('Successfully forced ' + objectsToInsert.size() + ' stories into the promotion.');
}
