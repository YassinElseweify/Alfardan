@isTest
private class AF_BusinessHoursServiceTest {
    @isTest
    static void testAddBusinessHoursDuration() {
        BusinessHours bh = [SELECT Id, Name FROM BusinessHours WHERE IsDefault = true LIMIT 1];

        AF_BusinessHoursService.Request req = new AF_BusinessHoursService.Request();
        req.businessHoursName = bh.Name;
        req.startDateTime = DateTime.now();
        req.durationMillis = 900000;

        Test.startTest();
        List<AF_BusinessHoursService.Response> responses =
            AF_BusinessHoursService.addBusinessHoursDuration(
                new List<AF_BusinessHoursService.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Expected one response');
        System.assertNotEquals(null, responses[0].resultDateTime, 'Expected resultDateTime to be not null');
    }

    @isTest
    static void testUnknownBusinessHoursFallsBackToCalendarMath() {
        AF_BusinessHoursService.Request req = new AF_BusinessHoursService.Request();
        req.businessHoursName = 'Does Not Exist';
        req.startDateTime = DateTime.now();
        req.durationMillis = 3600000;

        Test.startTest();
        List<AF_BusinessHoursService.Response> responses =
            AF_BusinessHoursService.addBusinessHoursDuration(
                new List<AF_BusinessHoursService.Request>{ req }
            );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Expected one response');
        System.assertEquals(
            req.startDateTime.addSeconds(3600),
            responses[0].resultDateTime,
            'Expected resultDateTime to match calendar calculation'
        );
    }
}