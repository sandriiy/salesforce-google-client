@IsTest
private class GAsyncTest {
    @IsTest
    private static void shouldChainQueueableJobsWithDeepClone() {
        Test.startTest();
        GAsync.queueable(new AccountInsertJob(new List<String>{ 'GASYNC_JOB_1' }))
            .deepClone()
            .chain(new AccountInsertJob(new List<String>{ 'GASYNC_JOB_2' }))
            .deepClone()
            .enqueue();
        Test.stopTest();

        List<Account> accounts = [
            SELECT Name
            FROM Account
            WHERE Name IN ('GASYNC_JOB_1', 'GASYNC_JOB_2')
            ORDER BY Name ASC
        ];

        Assert.areEqual(2, accounts.size());
        Assert.areEqual('GASYNC_JOB_1', accounts[0].Name);
        Assert.areEqual('GASYNC_JOB_2', accounts[1].Name);
    }

    private class AccountInsertJob extends GQueueableJob {
        private List<String> accountNames;

        private AccountInsertJob(List<String> accountNames) {
            this.accountNames = accountNames == null
                ? new List<String>()
                : new List<String>(accountNames);
        }

        public override GQueueableJob cloneForDeepCopy() {
            return (GQueueableJob) JSON.deserialize(JSON.serialize(this), AccountInsertJob.class);
        }

        public override void work() {
            List<Account> accountsToInsert = new List<Account>();
            for (String accountName : this.accountNames) {
                accountsToInsert.add(new Account(Name = accountName));
            }

            if (!accountsToInsert.isEmpty()) {
                insert accountsToInsert;
            }
        }
    }
}
